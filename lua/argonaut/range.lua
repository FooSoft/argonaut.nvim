local Cursor  = require('argonaut.cursor')
local Options = require('argonaut.options')
local Pairing = require('argonaut.pairing')
local Param   = require('argonaut.param')

-- A range owns arguments; each argument contains characters or nested ranges.
-- Nested ranges are single cells, so their commas cannot split the parent list.
local Range   = { type = 'range' }
Range.__index = Range

local function find_closest(allow_current)
    local ranges = {}
    for _, brace in pairs({ '(', '[', '{', '<' }) do
        local pairing = Pairing.from_brace(brace)
        local pair = pairing:find_closest_pair(allow_current)
        if pair then
            local range = Range.new(pair.start_cursor, pair.stop_cursor, pairing)
            if range then
                table.insert(ranges, range)
            end
        end
    end

    if #ranges > 0 then
        -- The latest opening brace identifies the innermost valid range.
        table.sort(ranges, function(a, b)
            return b.start_cursor < a.start_cursor
        end)
        return ranges[1]
    end
end

-- The second return value marks an invalid nested range. Callers must abort
-- instead of treating its braces and commas as ordinary parent argument text.
local function find_at_cursor(start_cursor, parent_range)
    local value = start_cursor:get_value()
    local pairing = Pairing.from_brace(value)
    if pairing and value == pairing.open then
        local cursor_current = Cursor:get_current()
        start_cursor:set_current()

        local stop_cursor = pairing:find_closest(true, true)
        cursor_current:set_current()

        if not stop_cursor then
            -- An unmatched angle bracket may be a comparison operator.
            return nil, value ~= '<'
        end

        if parent_range and parent_range.stop_cursor <= stop_cursor then
            return nil, true
        end

        local range = Range.new(start_cursor, stop_cursor, pairing)
        return range, range == nil
    end
end

function Range.new(start_cursor, stop_cursor, pairing)
    assert(start_cursor < stop_cursor)
    assert(start_cursor:get_value() == pairing.open)
    assert(stop_cursor:get_value() == pairing.close)

    local range = {
        start_cursor = start_cursor,
        stop_cursor = stop_cursor,
        pairing = pairing,
        params = {},
    }

    setmetatable(range, Range)
    if range:parse() then
        return range
    end
end

function Range:parse()
    local param = nil

    local append_param_value = function(cell)
        if not param then
            param = Param.new(self, #self.params + 1)
        end
        param:append_cell(cell)
    end

    local append_param = function()
        local contiguous = true
        if param and not param:is_empty() then
            table.insert(self.params, param)
            contiguous = param:is_contiguous()
        end
        param = nil
        return contiguous
    end

    if self.stop_cursor.row - self.start_cursor.row > self:query_option('limit_rows') then
        return false
    end
    for row = self.start_cursor.row, self.stop_cursor.row do
        local first_col = row == self.start_cursor.row and self.start_cursor.col or 1
        local last_col = row == self.stop_cursor.row and self.stop_cursor.col or #vim.fn.getline(row)
        if last_col - first_col > self:query_option('limit_cols') then
            return false
        end
    end

    local cursor = self.start_cursor:get_next()
    while cursor ~= self.stop_cursor do
        local value = cursor:get_value()

        -- Moving a comment can turn following arguments or braces into comment text.
        if cursor:is_comment() then
            return false
        elseif cursor:is_string() then
            append_param_value(Param.new_cursor_cell(cursor))
        else
            local range, invalid = find_at_cursor(cursor, self)
            if invalid then
                return false
            elseif range then
                append_param_value(Param.new_range_cell(range))
                assert(range.stop_cursor < self.stop_cursor)
                cursor = range.stop_cursor
            elseif value == ')' or value == ']' or value == '}' then
                return false
            elseif value == ',' then
                -- Leading/repeated commas must not silently erase empty arguments.
                if not param or param:is_empty() or not append_param() then
                    return false
                end
            else
                append_param_value(Param.new_cursor_cell(cursor))
            end
        end

        cursor = cursor:get_next()
    end

    -- Empty final content is valid for empty lists and trailing commas.
    return append_param()
end

-- Traces describe a path from the range through its arguments/cells to a cursor.
-- hit_search follows that path; truncating it selects an enclosing object instead.
function Range:hit_test(cursor)
    if not self:contains_cursor(cursor) or #self.params == 0 then
        return
    end

    local frame = {
        type = self.type,
        pairing = self.pairing.open .. self.pairing.close,
        param_count = #self.params,
        param_index = 0,
    }

    -- A separator belongs to the preceding argument for picking and navigation.
    for i = 2, #self.params do
        local param = self.params[i]
        local previous_param = self.params[i - 1]
        if previous_param:is_before_cursor(cursor) and param:is_after_cursor(cursor) then
            if not previous_param:hit_test(cursor) and not param:hit_test(cursor) then
                cursor = cursor:get_previous()
                break
            end
        end
    end

    for i, param in pairs(self.params) do
        local trace = param:hit_test(cursor)
        if trace then
            frame.param_index = i
            table.insert(trace, 1, frame)
            return trace
        end
    end
end

function Range:hit_search(trace, depth)
    local frame = trace[depth]
    assert(frame.type == self.type)
    assert(frame.pairing == self.pairing.open .. self.pairing.close)
    assert(frame.param_count == #self.params)
    assert(frame.param_index <= #self.params)

    if depth == #trace then
        return self
    else
        return self.params[frame.param_index]:hit_search(trace, depth + 1)
    end
end

function Range:write(builder, wrapped)
    -- Parent writers omit wrapped for child cells to preserve each child's layout.
    if wrapped == nil then
        wrapped = self:is_wrapped()
    end

    local pad = self:query_option('brace_pad')
    builder:write(self.pairing.open, self.start_cursor)
    if #self.params == 0 then
        if pad then
            builder:write(' ')
        end
        builder:write(self.pairing.close, self.stop_cursor)
        return
    end

    if not wrapped then
        if pad then
            builder:write(' ')
        end
        for i, param in ipairs(self.params) do
            param:write(builder)
            if i < #self.params then
                builder:write(', ')
            end
        end
        if pad then
            builder:write(' ')
        end
        builder:write(self.pairing.close, self.stop_cursor)
        return
    end

    local comma_prefix = self:query_option('comma_prefix')
    local last_wrap = self:query_option('brace_last_wrap')
    local last_indent = self:query_option('brace_last_indent')
    builder:endline()
    builder:push_indent()

    for i, param in ipairs(self.params) do
        local last = i == #self.params
        if comma_prefix then
            if i > 1 then
                builder:write(', ')
            elseif self:query_option('comma_prefix_indent') then
                builder:write('  ')
            end
        end
        param:write(builder)
        if (last and self:query_option('comma_last')) or (not last and not comma_prefix) then
            builder:write(',')
        end
        if not last then
            builder:endline()
        end
    end

    if last_wrap then
        builder:endline()
        if not last_indent then
            builder:pop_indent()
        end
        if pad then
            builder:write(' ')
        end
    end
    builder:write(self.pairing.close, self.stop_cursor)
    if not last_wrap or last_indent then
        -- Restore the parent's depth even when the closing brace stays on this line.
        builder:pop_indent()
    end
end

function Range:contains_cursor(cursor)
    return cursor >= self.start_cursor and cursor <= self.stop_cursor
end

function Range:is_contiguous()
    for _, param in ipairs(self.params) do
        if not param:is_contiguous() then
            return false
        end
    end

    return true
end

function Range:is_wrapped()
    -- Compare unpadded argument boundaries, ignoring line breaks inside child ranges.
    local previous_cursor = self.start_cursor
    for _, param in ipairs(self.params) do
        local start_cursor = param.cells[param:get_left_padding() + 1]:get_start_cursor()
        if start_cursor.row ~= previous_cursor.row then
            return true
        end
        previous_cursor = param.cells[#param.cells - param:get_right_padding()]:get_stop_cursor()
    end

    return previous_cursor.row ~= self.stop_cursor.row
end

function Range:query_option(name)
    return Options.query(name, self.pairing)
end

function Range:dump(log)
    log:write(self.type)
    log:indent()

    log:write('start_cursor = %s', self.start_cursor:to_string())
    log:write('stop_cursor = %s', self.stop_cursor:to_string())
    for _, param in ipairs(self.params) do
        param:dump(log)
    end

    log:unindent()
end

return {
    find_closest = find_closest,
    find_at_cursor = find_at_cursor,
}
