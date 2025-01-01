local ParamCell = {}
ParamCell.__index = ParamCell

function ParamCell.new(value, type)
    assert(type == 'range' or type == 'cursor')
    local param_cell = {value = value, type = type}
    return setmetatable(param_cell, ParamCell)
end

function ParamCell:write(builder, wrapped)
    if self.type == 'range' then
        self.value:write(builder, wrapped)
    elseif self.type == 'cursor' then
        builder:write(self.value:get_value())
    end
end

function ParamCell:hit_test(cursor)
    if self.type == 'range' then
        return self.value:hit_test(cursor)
    elseif self.type == 'cursor' and self.value == cursor then
        return {}
    end
end

function ParamCell:hit_search(trace, depth)
    if self.type == 'range' then
        return self.value:hit_search(trace, depth + 1)
    elseif self.type == 'cursor' then
        return self.value
    end
end

function ParamCell:get_start_row()
    if self.type == 'range' then
        return self.value.start_cursor.row
    elseif self.type == 'cursor' then
        return self.value.row
    end
end

function ParamCell:get_stop_row()
    if self.type == 'range' then
        return self.value.stop_cursor.row
    elseif self.type == 'cursor' then
        return self.value.row
    end
end

function ParamCell:is_empty()
    return self.type == 'cursor' and not self.value:get_value():match('%S')
end

local Param = {}
Param.__index = Param

function Param.new(range, index, cells)
    local param = {range = range, index = index, cells = cells or {}}
    return setmetatable(param, Param)
end

function Param:append(value, type)
    table.insert(self.cells, ParamCell.new(value, type))
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
