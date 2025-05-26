local ParamCursorCell = { type = 'param_cursor_cell' }
ParamCursorCell.__index = ParamCursorCell

function ParamCursorCell.new(cursor)
    local cell = { cursor = cursor }
    return setmetatable(cell, ParamCursorCell)
end

function ParamCursorCell:write(builder, _)
    builder:write(self.cursor:get_value())
end

function ParamCursorCell:hit_test(cursor)
    if self.cursor == cursor then
        return { { char = self.cursor:get_value(), type = self.type } }
    end
end

function ParamCursorCell:hit_search(trace, depth)
    local frame = trace[depth]
    assert(frame.type == self.type)
    assert(frame.char == self.cursor:get_value())
    assert(depth == #trace)

    return self.cursor
end

function ParamCursorCell:is_empty()
    return not self.cursor:get_value():match('%S')
end

function ParamCursorCell:is_before_cursor(cursor)
    return self.cursor < cursor
end

function ParamCursorCell:is_after_cursor(cursor)
    return self.cursor > cursor
end

function ParamCursorCell:get_start_cursor()
    return self.cursor
end

function ParamCursorCell:get_stop_cursor()
    return self.cursor
end

function ParamCursorCell:dump(log)
    log:write(self.type)
    log:indent()

    log:write('cursor = %s', self.cursor:to_string())

    log:unindent()
end

return ParamCursorCell
