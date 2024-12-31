local Cursor = {}
Cursor.__index = Cursor

function Cursor.new(row, col)
    local cursor = {
        row = row,
        col = col,
    }

    return setmetatable(cursor, Cursor)
end

function Cursor.get_current()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return Cursor.new(row, col)
end

function Cursor:set_current()
    assert(self:is_valid())

    vim.fn.setcursorcharpos({self.row, self.col})
end

function Cursor:get_value()
    assert(self:is_valid())

    local line = vim.fn.getline(self.row)
    return line:sub(self.col, self.col)
end

function Cursor:is_valid()
    return self.row > 0 and self.col > 0
end

function Cursor:is_literal()
    assert(self:is_valid())

    local syn_id = vim.fn.synID(self.row, self.col, false)
    local syn_attr = vim.fn.synIDattr(syn_id, 'name')
    return syn_attr:find('String$') ~= nil or syn_attr:find('Comment$') ~= nil
end

function Cursor:next()
    assert(self:is_valid())

    local current_line = vim.fn.getline(self.row)
    local next_col = self.col + 1
    local next_row = self.row

    if next_col > #current_line then
        next_row = next_row + 1
        next_col = 1
    end

    return Cursor.new(next_row, next_col)
end

function Cursor.__lt(cursor_1, cursor_2)
    if cursor_1 == cursor_2 then
        return false
    end

    if cursor_1.row > cursor_2.row then
        return false
    end

    if cursor_1.row == cursor_2.row and cursor_1.col > cursor_2.col then
        return false
    end

    return true
end

function Cursor.__gt(cursor_1, cursor_2)
    if cursor_1 == cursor_2 then
        return false
    end

    if cursor_1.row < cursor_2.row then
        return false
    end

    if cursor_1.row == cursor_2.row and cursor_1.col < cursor_2.col then
        return false
    end

    return true
end

function Cursor.__eq(cursor_1, cursor_2)
    return cursor_1.row == cursor_2.row and cursor_1.col == cursor_2.col
end

return Cursor
