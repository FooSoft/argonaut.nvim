ParamCursorCell = require('argonaut.param_cursor_cell')
ParamRangeCell = require('argonaut.param_range_cell')

local Param = {type = 'param'}
Param.__index = Param

function Param.new(range, index, cells)
    local param = {
        range = range,
        index = index,
        cells = cells or {},
    }

    return setmetatable(param, Param)
end

function Param:write(builder, wrapped)
    for i = self:get_start_index(), self:get_stop_index() do
        self.cells[i]:write(builder, wrapped)
    end
end

function Param:hit_test(cursor)
    -- skip cursor over spaces on the left
    local start_index = self:get_start_index()
    for i = 1, start_index - 1, 1 do
        local cell = self.cells[i]
        if cell:hit_test(cursor) then
            cursor = cursor:get_next()
        end
    end

    -- skip cursor over spaces on the right
    local stop_index = self:get_stop_index()
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
                type = self.type,
                cell_count = #self.cells,
                cell_index = i - start_index + 1,
            })

            return trace
        end
    end
end

function Param:hit_search(trace, depth)
    local frame = trace[depth]
    assert(frame.type == self.type)

    if depth == #trace then
        return self
    else
        local unpadded_index = frame.cell_index + self:get_start_index() - 1
        assert(unpadded_index <= #self.cells)
        return self.cells[unpadded_index]:hit_search(trace, depth + 1)
    end
end

function Param:is_empty()
    return self:get_start_index() == nil
end

function Param:is_contiguous()
    for i = self:get_start_index(), self:get_stop_index() - 1 do
        local cell = self.cells[i]
        local next_cell = self.cells[i + 1]
        if cell:get_stop_cursor().row ~= next_cell:get_start_cursor().row then
            return false
        end
    end

    return true
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

function Param:get_start_cursor()
    if #self.cells > 0 then
        return self.cells[1]:get_start_cursor()
    end
end

function Param:get_stop_cursor()
    if #self.cells > 0 then
        return self.cells[#self.cells]:get_stop_cursor()
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

function Param:get_start_index(row_limit)
    for i = 1, #self.cells do
        local cell = self.cells[i]
        if not cell:is_empty() or row_limit and cell:get_start_cursor().row ~= row_limit then
            return i
        end
    end
end

function Param:get_stop_index(row_limit)
    for i = #self.cells, 1, -1 do
        local cell = self.cells[i]
        if not cell:is_empty() or row_limit and cell:get_stop_cursor().row ~= row_limit then
            return i
        end
    end
end

function Param:select(inner)
    if #self.cells == 0 then
        return
    end

    local start_cursor = nil
    local stop_cursor = nil

    if inner then
        local start_index = self:get_start_index()
        start_cursor = self.cells[start_index]:get_start_cursor()

        local stop_index = self:get_stop_index()
        stop_cursor = self.cells[stop_index]:get_stop_cursor()
    else
        local previous_param = self:get_previous()
        if previous_param then
            local stop_index = previous_param:get_stop_index()
            start_cursor = previous_param.cells[stop_index]:get_stop_cursor():get_next()
            stop_cursor = self.cells[#self.cells]:get_stop_cursor()
        else
            local next_param = self:get_next()
            if next_param then
                start_cursor = self.cells[self:get_start_index()]:get_start_cursor()
                stop_cursor = next_param.cells[next_param:get_start_index()]:get_start_cursor():get_previous()
            else
                start_cursor = self.range.start_cursor:get_next(true)
                stop_cursor = self.range.stop_cursor:get_previous(true)
            end
        end
    end

    local ve_old = vim.opt.virtualedit
    vim.opt.virtualedit = 'onemore'
    start_cursor:set_current()
    vim.cmd(string.format(':normal! v'))
    stop_cursor:set_current()
    vim.opt.virtualedit = ve_old
end

function Param.new_cursor_cell(cursor)
    return ParamCursorCell.new(cursor)
end

function Param.new_range_cell(range)
    return ParamRangeCell.new(range)
end

function Param:append_cell(cell)
    table.insert(self.cells, cell)
end

return Param
