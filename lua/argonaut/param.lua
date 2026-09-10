local Cursor = require('argonaut.cursor')
local ParamCursorCell = require('argonaut.param_cursor_cell')
local ParamRangeCell = require('argonaut.param_range_cell')

local Param = { type = 'param' }
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
    for i = 1 + self:get_left_padding(), #self.cells - self:get_right_padding() do
        self.cells[i]:write(builder, wrapped)
    end
end

function Param:hit_test(cursor)
    -- Padding is discarded on write, so pick the nearest surviving argument character.
    for i = 1, self:get_left_padding(), 1 do
        local cell = self.cells[i]
        if cell:hit_test(cursor) then
            cursor = cursor:get_next()
        end
    end

    for i = #self.cells, #self.cells - self:get_right_padding() + 1, -1 do
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
                cell_index = i - self:get_left_padding(),
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
        local unpadded_index = frame.cell_index + self:get_left_padding()
        assert(unpadded_index <= #self.cells)
        return self.cells[unpadded_index]:hit_search(trace, depth + 1)
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

function Param:is_empty()
    return self:get_left_padding() == nil
end

function Param:is_contiguous()
    -- Only nested range cells may span lines. Joining other line breaks could
    -- change an expression or a multiline string's contents.
    for i = 1 + self:get_left_padding(), #self.cells - self:get_right_padding() - 1 do
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

function Param:get_left_padding()
    for i = 1, #self.cells do
        local cell = self.cells[i]
        if not cell:is_empty() then
            return i - 1
        end
    end
end

function Param:get_right_padding()
    for i = #self.cells, 1, -1 do
        local cell = self.cells[i]
        if not cell:is_empty() then
            return #self.cells - i
        end
    end
end

function Param:object(mode)
    assert(#self.cells > 0)

    local previous_param = self:get_previous()
    local next_param = self:get_next()

    local get_first_unpadded_cell = function(param)
        return param.cells[param:get_left_padding() + 1]
    end

    local get_last_unpadded_cell = function(param)
        return param.cells[#param.cells - param:get_right_padding()]
    end

    local start_cursor = Cursor:get_current()
    local stop_cursor = nil
    local select = false

    if mode == 'inner' then
        select = true
        start_cursor = get_first_unpadded_cell(self):get_start_cursor()
        stop_cursor = get_last_unpadded_cell(self):get_stop_cursor()
    elseif mode == 'outer' then
        select = true
        -- Include the preceding comma when possible, otherwise the following one.
        if previous_param then
            start_cursor = get_last_unpadded_cell(previous_param):get_stop_cursor():get_next()
            stop_cursor = self.cells[#self.cells]:get_stop_cursor()
        else
            if next_param then
                start_cursor = get_first_unpadded_cell(self):get_start_cursor()
                stop_cursor = get_first_unpadded_cell(next_param):get_start_cursor():get_previous()
            else
                start_cursor = self.range.start_cursor:get_next(true)
                stop_cursor = self.range.stop_cursor:get_previous(true)
            end
        end
    elseif mode == 'previous' then
        if previous_param then
            stop_cursor = get_first_unpadded_cell(previous_param):get_start_cursor()
        end
    elseif mode == 'next' then
        if next_param then
            stop_cursor = get_first_unpadded_cell(next_param):get_start_cursor()
        end
    elseif mode == 'beginning' then
        stop_cursor = get_first_unpadded_cell(self):get_start_cursor()
    elseif mode == 'end' then
        stop_cursor = get_last_unpadded_cell(self):get_stop_cursor()
    else
        assert(false, 'invalid object mode')
    end

    if stop_cursor then
        local virtualedit_old = vim.o.virtualedit
        vim.opt.virtualedit = 'onemore'

        if select then
            if vim.o.selection == 'exclusive' then
                -- Cell endpoints are inclusive; Visual selection may exclude its end.
                stop_cursor = stop_cursor:get_next(true) or stop_cursor
            end
            start_cursor:set_current()
            vim.cmd('normal! v')
        end

        stop_cursor:set_current()
        vim.opt.virtualedit = virtualedit_old
    end
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

function Param:dump(log)
    log:write(self.type)
    log:indent()

    for _, cell in ipairs(self.cells) do
        cell:dump(log)
    end

    log:unindent()
end

return Param
