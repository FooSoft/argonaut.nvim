local ParamCursorCell = {}
ParamCursorCell.__index = ParamCursorCell

function ParamCursorCell.new(cursor)
    local cell = {cursor = cursor}
    return setmetatable(cell, ParamCursorCell)
end

function ParamCursorCell:write(builder)
    builder:write(self.cursor:get_value())
end

function ParamCursorCell:hit_test(cursor)
    if self.cursor == cursor then
        return {{char = self.cursor:get_value(), type = 'cursor_cell'}}
    end
end

function ParamCursorCell:hit_search(trace, depth)
    local frame = trace[depth]
    assert(frame.type == 'cursor_cell')
    assert(frame.char == self.cursor:get_value())
    assert(depth == #trace)

    return self
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

function ParamCursorCell:is_empty()
    return not self.cursor:get_value():match('%S')
end

return ParamCursorCell
