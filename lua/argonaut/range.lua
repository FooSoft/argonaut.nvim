local Cursor  = require('argonaut.cursor')
local Options = require('argonaut.options')
local Pairing = require('argonaut.pairing')
local Param   = require('argonaut.param')

local Range = {}
Range.__index = Range

local function find_closest_pair(pairing)
    local stop_cursor = pairing:find_closest(true)
    if stop_cursor then
        local start_cursor = pairing:find_closest(false)
        if start_cursor then
            return Range.new(start_cursor, stop_cursor, pairing)
        end
    end
end

local function find_closest()
    local ranges = {}
    for _, brace in pairs({'(', '[', '{', '<'}) do
        local pairing = Pairing.from_brace(brace)
        local range = find_closest_pair(pairing)
        if range then
            table.insert(ranges, range)
        end
    end

    if #ranges > 0 then
        table.sort(ranges)
        local range = ranges[1]
        range:parse()
        return range
    end
end

local function find_at_cursor(start_cursor)
    local pairing = Pairing.from_brace(start_cursor:get_value())
    if pairing then
        local cursor_current = Cursor:get_current()
        start_cursor:set_current()
        local stop_cursor = pairing:find_closest(true)
        cursor_current:set_current()
        if stop_cursor then
            local range = Range.new(start_cursor, stop_cursor, pairing)
            range:parse()
            return range
        end
    end
end

function Range.new(start_cursor, stop_cursor, pairing)
    local range = {
        start_cursor = start_cursor,
        stop_cursor = stop_cursor,
        pairing = pairing,
        params = {},
    }

    return setmetatable(range, Range)
end

function Range:parse()
    local param = nil
    local param_index = 1

    local append_param_value = function(cell)
        if not param then
            param = Param.new(self, param_index)
            param_index = param_index + 1
        end
        param:append(cell)
    end

    local append_param = function()
        if param and not param:is_empty() then
            table.insert(self.params, param:stripped())
        end
        param = nil
    end

    local cursor = self.start_cursor:get_next()
    while cursor ~= self.stop_cursor do
        local value = cursor:get_value()

        if cursor:is_string() or cursor:is_comment() then
            append_param_value(Param.new_cursor_cell(cursor))
        else
            local range = find_at_cursor(cursor)
            if range then
                append_param_value(Param.new_range_cell(range))
                cursor = range.stop_cursor
            elseif value == ',' then
                append_param()
            else
                append_param_value(Param.new_cursor_cell(cursor))
            end
        end

        cursor = cursor:get_next()
    end

    append_param()
end

function Range:hit_test(cursor)
    if self:contains(cursor) then
        local trace = nil
        for i, param in pairs(self.params) do
            local trace_param = param:hit_test(cursor)
            if trace_param then
                trace = {i}
                for _, trace_param_frame in ipairs(trace_param) do
                    table.insert(trace, trace_param_frame)
                end
                break
            end
        end

        if not trace then
            trace = {0}
        end

        return trace
    end
end

function Range:hit_search(trace, depth)
    local index = trace[depth]
    if index == 0 then
        return self.start_cursor
    else
        return self.params[index]:hit_search(trace, depth + 1)
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

function Range:contains(cursor)
    return cursor >= self.start_cursor and cursor <= self.stop_cursor
end

function Range:query_option(name)
    return Options.query(name, self.pairing)
end

function Range:is_wrapped()
    for _, param in ipairs(self.params) do
        if param:is_wrapped() then
            return true
        end
    end
    return false
end

function Range.__lt(range_1, range_2)
    local cursor = Cursor:get_current()

    local row_diff1 = range_1.start_cursor.row - cursor.row
    local col_diff1 = range_1.start_cursor.col - cursor.col
    local row_diff2 = range_2.start_cursor.row - cursor.row
    local col_diff2 = range_2.start_cursor.col - cursor.col

    if row_diff1 < row_diff2 then
        return false
    elseif row_diff1 > row_diff2 then
        return true
    elseif col_diff1 < col_diff2 then
        return false
    elseif col_diff1 > col_diff2 then
        return true
    else
        return true
    end
end

return {
    find_closest = find_closest,
    find_at_cursor = find_at_cursor,
}
