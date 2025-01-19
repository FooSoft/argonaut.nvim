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

function ParamCursorCell:get_start_row()
    return self.cursor.row
end

function ParamCursorCell:get_stop_row()
    return self.cursor.row
end

function ParamCursorCell:is_empty()
    return not self.cursor:get_value():match('%S')
end

local ParamRangeCell = {}
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
        table.insert(trace, 1, {type = 'range_cell'})
        return trace
    end
end

function ParamRangeCell:is_before_cursor(cursor)
    return self.range.start_cursor < cursor
end

function ParamRangeCell:is_after_cursor(cursor)
    return self.range.stop_cursor > cursor
end

function ParamRangeCell:hit_search(trace, depth)
    local frame = trace[depth]
    assert(frame.type == 'range_cell')

    if depth == #trace then
        return self
    else
        return self.range:hit_search(trace, depth + 1)
    end
end

function ParamRangeCell:get_start_row()
    return self.range.start_cursor.row
end

function ParamRangeCell:get_stop_row()
    return self.range.stop_cursor.row
end

function ParamRangeCell:is_empty()
    return false
end

local Param = {}
Param.__index = Param

function Param.new(range, index, cells)
    local param = {range = range, index = index, cells = cells or {}}
    return setmetatable(param, Param)
end

function Param.new_cursor_cell(cursor)
    return ParamCursorCell.new(cursor)
end

function Param.new_range_cell(range)
    return ParamRangeCell.new(range)
end

function Param:append(cell)
    table.insert(self.cells, cell)
end

function Param:hit_test(cursor)
    local start_index = self:get_start_index()
    local stop_index = self:get_stop_index()

    for i = 1, start_index - 1, 1 do
        local cell = self.cells[i]
        if cell:hit_test(cursor) then
            cursor = cursor:get_next()
        end
    end

    for i = #self.cells, stop_index + 1, -1 do
        local cell = self.cells[i]
        if cell:hit_test(cursor) then
            cursor = cursor:get_previous()
        end
    end

    for i, cell in ipairs(self.cells) do
        local trace = cell:hit_test(cursor)
        if trace then
            table.insert(trace, 1, {
                type = 'param',
                cell_count = #self.cells,
                cell_index = i - start_index + 1,
            })

            return trace
        end
    end
end

function Param:hit_search(trace, depth)
    local frame = trace[depth]
    assert(frame.type == 'param')

    if depth == #trace then
        return self
    else
        local index_clamped = frame.cell_index + self:get_start_index() - 1
        assert(index_clamped <= #self.cells)
        return self.cells[index_clamped]:hit_search(trace, depth + 1)
    end
end

function Param:write(builder, wrapped)
    for i = self:get_start_index(), self:get_stop_index() do
        self.cells[i]:write(builder, wrapped)
    end
end

function Param:is_before_cursor(cursor)
    if #self.cells > 0 then
        return self.cells[1]:is_before_cursor(cursor)
    end
end

function Param:is_after_cursor(cursor)
    if #self.cells > 0 then
        return self.cells[#self.cells]:is_after_cursor(cursor)
    end
end

function Param:get_previous()
    if self.index > 1 then
        return self.range.params[self.index - 1]
    end
end

function Param:get_next()
    if self.index < #self.range.params then
        return self.range.params[self.index + 1]
    end
end

function Param:get_start_row()
    if #self.cells > 0 then
        return self.cells[1]:get_start_row()
    end
end

function Param:get_stop_row()
    if #self.cells > 0 then
        return self.cells[#self.cells]:get_stop_row()
    end
end

function Param:get_start_index()
    for i = 1, #self.cells do
        if not self.cells[i]:is_empty() then
            return i
        end
    end
end

function Param:get_stop_index()
    for i = #self.cells, 1, -1 do
        if not self.cells[i]:is_empty() then
            return i
        end
    end
end

function Param:is_contiguous()
    local start_index = self:get_start_index()
    local stop_index = self:get_stop_index()

    for i = start_index, stop_index - 1 do
        local cell = self.cells[i]
        local next_cell = self.cells[i + 1]
        if cell:get_stop_row() ~= next_cell:get_start_row() then
            return false
        end
    end

    return true
end

function Param:is_wrapped()
    local previous_param = self:get_previous()
    if previous_param then
        return previous_param:get_stop_row() ~= self:get_start_row()
    else
        return self.range.start_cursor.row ~= self:get_start_row()
    end
end

function Param:is_empty()
    return self:get_start_index() == nil
end

return Param
