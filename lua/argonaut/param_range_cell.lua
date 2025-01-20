local ParamRangeCell = {type = 'param_range_cell'}
ParamRangeCell.__index = ParamRangeCell

function ParamRangeCell.new(range)
    local cell = {range = range}
    return setmetatable(cell, ParamRangeCell)
end

function ParamRangeCell:write(builder, wrapped)
    self.range:write(builder, wrapped)
end

function ParamRangeCell:hit_test(cursor)
    local trace = self.range:hit_test(cursor)
    if trace then
        table.insert(trace, 1, {type = self.type})
        return trace
    end
end

function ParamRangeCell:hit_search(trace, depth)
    local frame = trace[depth]
    assert(frame.type == self.type)

    if depth == #trace then
        return self
    else
        return self.range:hit_search(trace, depth + 1)
    end
end

function ParamRangeCell:is_empty()
    return false
end

function ParamRangeCell:is_before_cursor(cursor)
    return self.range.start_cursor < cursor
end

function ParamRangeCell:is_after_cursor(cursor)
    return self.range.stop_cursor > cursor
end

function ParamRangeCell:get_start_cursor()
    return self.range.start_cursor
end

function ParamRangeCell:get_stop_cursor()
    return self.range.stop_cursor
end

return ParamRangeCell
