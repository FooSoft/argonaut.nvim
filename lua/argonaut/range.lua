local Cursor  = require('argonaut.cursor')
local Options = require('argonaut.options')
local Pairing = require('argonaut.pairing')
local Param   = require('argonaut.param')

local Range = {type = 'range'}
Range.__index = Range

local function find_closest(allow_current)
    local ranges = {}
    for _, brace in pairs({'(', '[', '{', '<'}) do
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
        local range_compare = function(range_1, range_2)
            local cursor = Cursor:get_current()

            local row_diff_1 = range_1.start_cursor.row - cursor.row
            local col_diff_1 = range_1.start_cursor.col - cursor.col
            local row_diff_2 = range_2.start_cursor.row - cursor.row
            local col_diff_2 = range_2.start_cursor.col - cursor.col

            if row_diff_1 < row_diff_2 then
                return false
            elseif row_diff_1 > row_diff_2 then
                return true
            elseif col_diff_1 < col_diff_2 then
                return false
            elseif col_diff_1 > col_diff_2 then
                return true
            else
                return true
            end
        end

        table.sort(ranges, range_compare)
        return ranges[1]
    end
end

local function find_at_cursor(start_cursor, parent_range)
    local value = start_cursor:get_value()
    local pairing = Pairing.from_brace(value)
    if pairing and value == pairing.open then
        local cursor_current = Cursor:get_current()
        start_cursor:set_current()

        local stop_cursor = pairing:find_closest(true ,true)
        cursor_current:set_current()

        if not stop_cursor then
            return
        end

        if parent_range and parent_range.stop_cursor <= stop_cursor then
            return
        end

        return Range.new(start_cursor, stop_cursor, pairing)
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
    local param_index = 1

    local append_param_value = function(cell)
        if not param then
            param = Param.new(self, param_index)
            param_index = param_index + 1
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

    if self.start_cursor.row == self.stop_cursor.row then
        if self.stop_cursor.col - self.start_cursor.col > self:query_option('limit_cols') then
            return
        end
    else
        if self.stop_cursor.row - self.start_cursor.row > self:query_option('limit_rows') then
            return
        end
    end

    local cursor = self.start_cursor:get_next()
    while cursor ~= self.stop_cursor do
        local value = cursor:get_value()

        if cursor:is_string() or cursor:is_comment() then
            append_param_value(Param.new_cursor_cell(cursor))
        else
            local range = find_at_cursor(cursor, self)
            if range then
                append_param_value(Param.new_range_cell(range))
                assert(range.stop_cursor < self.stop_cursor)
                cursor = range.stop_cursor
            elseif value == ',' then
                if not append_param() then
                    return false
                end
            else
                append_param_value(Param.new_cursor_cell(cursor))
            end
        end

        cursor = cursor:get_next()
    end

    return append_param()
end

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

    if cursor == self.start_cursor and self.params[1]:is_after_cursor(cursor) then
        cursor = cursor:get_next()
    elseif cursor == self.stop_cursor and self.params[#self.params]:is_before_cursor(cursor) then
        cursor = cursor:get_previous()
    end

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
    if wrapped == nil then
        wrapped = self:is_wrapped()
    end

    if wrapped then
        builder:write(self.pairing.open)

        if #self.params > 0 then
            builder:endline()
            builder:push_indent()

            for i, param in ipairs(self.params) do
                local is_first_param = i == 1
                local is_last_param = i == #self.params

                if self:query_option('comma_prefix') then
                    if is_first_param then
                        if self:query_option('comma_prefix_indent') then
                            builder:write('  ')
                        end
                    else
                        builder:write(', ')
                    end
                    param:write(builder)
                else
                    param:write(builder)
                    if not is_last_param or self:query_option('comma_last') then
                        builder:write(',')
                    end
                end

                if not is_last_param then
                    builder:endline()
                end
            end

            if self:query_option('brace_last_wrap') then
                builder:endline()
                builder:pop_indent()
            end
        end

        if not self:query_option('brace_last_wrap') then
            if self:query_option('brace_last_indent') then
                builder:indent()
            end

            if self:query_option('brace_pad') then
                builder:write(' ')
            end
        end

        builder:write(self.pairing.close)
    else
        builder:write(self.pairing.open)
        if self:query_option('brace_pad') then
            builder:write(' ')
        end

        for i, param in ipairs( self.params ) do
            param:write(builder)

            local is_last_param = i == #self.params
            if not is_last_param then
                builder:write(', ')
            end
        end

        if self:query_option('brace_pad') then
            builder:write(' ')
        end
        builder:write(self.pairing.close)
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
    local previous_cursor = self.start_cursor
    for _, param in ipairs(self.params) do
        local start_cursor = param:get_start_cursor()
        if start_cursor.row ~= previous_cursor.row then
            return true
        end
        previous_cursor = param:get_stop_cursor()
    end

    return false
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
