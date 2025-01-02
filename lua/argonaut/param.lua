local ParamCursorCell = {}
ParamCursorCell.__index = ParamCursorCell

function ParamCursorCell.new(cursor)
    local param_cell_cursor = {cursor = cursor}
    return setmetatable(param_cell_cursor, ParamCursorCell)
end

function ParamCursorCell:write(builder)
    builder:write(self.cursor:get_value())
end

function ParamCursorCell:hit_test(cursor)
    if self.cursor == cursor then
        return {}
    end
end

function ParamCursorCell:hit_search()
    return self.cursor
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
    local param_cell_range = {range = range}
    return setmetatable(param_cell_range, ParamRangeCell)
end

function ParamRangeCell:write(builder, wrapped)
    self.range:write(builder, wrapped)
end

function ParamRangeCell:hit_test(cursor)
    return self.range:hit_test(cursor)
end

function ParamRangeCell:hit_search(trace, depth)
    return self.range:hit_search(trace, depth + 1)
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

function Param:stripped()
    local cells = {}
    for i = self:find_index_begin(), self:find_index_end() do
        table.insert(cells, self.cells[i])
    end

    return Param.new(self.range, self.index, cells)
end

function Param:hit_test(cursor)
    for i, cell in ipairs(self.cells) do
        local trace = cell:hit_test(cursor)
        if trace then
            table.insert(trace, 1, i)
            return trace
        end
    end
end

function Param:hit_search(trace, depth)
    local index = trace[depth]
    return self.cells[index]:hit_search(depth)
end

function Param:write(builder, wrapped)
    for i = self:find_index_begin(), self:find_index_end() do
        self.cells[i]:write(builder, wrapped)
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

function Param:find_index_begin()
    for i = 1, #self.cells do
        if not self.cells[i]:is_empty() then
            return i
        end
    end
end

function Param:find_index_end()
    for i = #self.cells, 1, -1 do
        if not self.cells[i]:is_empty() then
            return i
        end
    end
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
    return self:find_index_begin() == nil
end

return Param
