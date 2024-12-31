local Param = {}
Param.__index = Param

local function is_empty_cell(cell)
    return cell.type == 'cursor' and not cell.value:get_value():match('%S')
end

local function get_param_start_row(param)
    local cell = param.cells[1]
    if cell.type == 'range' then
        return cell.value.start_cursor.row
    elseif cell.type == 'cursor' then
        return cell.value.row
    end
end

local function get_param_stop_row(param)
    local cell = param.cells[#param.cells]
    if cell.type == 'range' then
        return cell.value.stop_cursor.row
    elseif cell.type == 'cursor' then
        return cell.value.row
    end
end

function Param.new(range, index, cells)
    local param = {
        range = range,
        index = index,
        cells = cells or {},
    }

    return setmetatable(param, Param)
end

function Param:append(value, type)
    table.insert(self.cells, {
        value = value,
        type = type,
    })
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
        local trace = nil
        if cell.type == 'range' then
            local trace_param = cell.value:hit_test(cursor)
            if trace_param then
                trace = {i}
                for _, trace_param_frame in ipairs(trace_param) do
                    table.insert(trace, trace_param_frame)
                end
            end
        elseif cell.type == 'cursor' and cell.value == cursor then
            trace = {i}
        end

        if trace then
            return trace
        end
    end
end

function Param:hit_search(trace, depth)
    local index = trace[depth]
    local cell = self.cells[index]
    if cell.type == 'range' then
        return cell.value:hit_search(trace, depth + 1)
    elseif cell.type == 'cursor' then
        return cell.value
    end
end

function Param:write(builder, wrapped)
    for i = self:find_index_begin(), self:find_index_end() do
        local cell = self.cells[i]
        if cell.type == 'range' then
            cell.value:write(builder, wrapped)
        elseif cell.type == 'cursor' then
            builder:write(cell.value:get_value())
        end
    end
end

function Param:is_wrapped()
    local previous_param = self:get_previous()
    if previous_param then
        return get_param_stop_row(previous_param) ~= get_param_start_row(self)
    else
        return self.range.start_cursor.row ~= get_param_start_row(self)
    end
end

function Param:get_previous()
    if self.index > 1 then
        return self.range.params[self.index-1]
    end
end

function Param:find_index_begin()
    for i = 1, #self.cells do
        if not is_empty_cell(self.cells[i]) then
            return i
        end
    end
end

function Param:find_index_end()
    for i = #self.cells, 1, -1 do
        if not is_empty_cell(self.cells[i]) then
            return i
        end
    end
end

function Param:is_empty()
    return self:find_index_begin() == nil
end

return Param
