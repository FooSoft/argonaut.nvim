local Cursor = {}
Cursor.__index = Cursor

function Cursor.new(row, col)
    local cursor = {row = row, col = col}
    return setmetatable(cursor, Cursor)
end

function Cursor.get_first()
    return Cursor.new(1, 1)
end

function Cursor.get_last()
    local row = vim.fn.line('$')
    local line = vim.fn.getline(row)
    return Cursor.new(row, #line)
end

function Cursor.get_current()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return Cursor.new(row, col)
end

function Cursor:set_current()
    vim.fn.setcursorcharpos({self.row, self.col})
end

function Cursor:get_value()
    local line = vim.fn.getline(self.row)
    return line:sub(self.col, self.col)
end

function Cursor:get_syntax_name()
    local syn_id = vim.fn.synID(self.row, self.col, false)
    return vim.fn.synIDattr(syn_id, 'name')
end

function Cursor:is_valid()
    return self.row > 0 and self.col > 0
end

function Cursor:is_comment()
    local name = self:get_syntax_name()
    return name:find('Comment$') ~= nil
end

function Cursor:is_string()
    local name = self:get_syntax_name()
    return name:find('String$') ~= nil
end

function Cursor:get_previous(allow_line_break)
    if self > Cursor.get_first() then
        local previous_cursor = Cursor.new(self.row, self.col - 1)

        if previous_cursor.col < 1 then
            previous_cursor.row = previous_cursor.row - 1
            local line = vim.fn.getline(previous_cursor.row )

            local max_length = #line
            if allow_line_break then
                max_length = max_length + 1
            end

            previous_cursor.col = max_length
        end

        return previous_cursor
    else
        print(self:to_string(), Cursor.get_first():to_string())
    end
end

function Cursor:get_next(allow_line_break)
    if self < Cursor.get_last() then
        local line = vim.fn.getline(self.row)
        local next_cursor = Cursor.new(self.row, self.col + 1)

        local max_length = #line
        if allow_line_break then
            max_length = max_length + 1
        end

        if next_cursor.col > max_length then
            next_cursor.row = next_cursor.row + 1
            next_cursor.col = 1
        end

        return next_cursor
    end
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

function Cursor:to_string()
    return string.format('(%d, %d, "%s")', self.row, self.col, self:get_value())
end

return Cursor
