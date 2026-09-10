-- Positions use one-based rows and byte columns, matching Vim's search APIs.
-- Traversal still moves by whole UTF-8 characters, never individual bytes.
local Cursor = {}
Cursor.__index = Cursor

local function character_start(line, col)
    while col > 1 do
        local byte = line:byte(col)
        if not byte or byte < 128 or byte >= 192 then
            break
        end
        col = col - 1
    end
    return col
end

function Cursor.new(row, col)
    local cursor = { row = row, col = col }
    return setmetatable(cursor, Cursor)
end

function Cursor.get_first()
    return Cursor.new(1, 1)
end

function Cursor.get_last()
    local row = vim.fn.line('$')
    local line = vim.fn.getline(row)
    return Cursor.new(row, character_start(line, math.max(1, #line)))
end

function Cursor.get_current()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return Cursor.new(row, col)
end

function Cursor:set_current()
    vim.fn.cursor({ self.row, self.col })
end

function Cursor:get_value()
    local line = vim.fn.getline(self.row)
    return line:match('.[\128-\191]*', self.col) or ''
end

function Cursor:get_syntax_name()
    local syn_id = vim.fn.synID(self.row, self.col, false)
    return vim.fn.synIDattr(syn_id, 'name')
end

function Cursor:is_valid()
    return self.row > 0 and self.col > 0
end

function Cursor:is_comment()
    return self:has_syntax('comment')
end

function Cursor:is_string()
    return self:has_syntax('string') or self:has_syntax('character')
end

function Cursor:has_syntax(kind)
    -- An escape or delimiter can have its own group inside a string/comment.
    -- Check enclosing groups and highlight links as well as the immediate name.
    for _, syn_id in ipairs(vim.fn.synstack(self.row, self.col)) do
        local name = vim.fn.synIDattr(syn_id, 'name'):lower()
        local linked_name = vim.fn.synIDattr(vim.fn.synIDtrans(syn_id), 'name'):lower()
        if name:find(kind, 1, true) or linked_name == kind then
            return true
        end
    end
    return false
end

-- With allow_line_break, column #line + 1 represents the newline for selections.
-- Both traversal directions retain column 1 on empty lines.
function Cursor:get_previous(allow_line_break)
    if self > Cursor.get_first() then
        local previous_cursor = Cursor.new(self.row, self.col - 1)

        if previous_cursor.col < 1 then
            previous_cursor.row = previous_cursor.row - 1
            local line = vim.fn.getline(previous_cursor.row)

            local max_length = math.max(1, #line)
            if allow_line_break then
                max_length = #line + 1
            end

            previous_cursor.col = max_length
        end

        previous_cursor.col = character_start(vim.fn.getline(previous_cursor.row), previous_cursor.col)
        return previous_cursor
    end
end

function Cursor:get_next(allow_line_break)
    local line = vim.fn.getline(self.row)
    local next_cursor = Cursor.new(self.row, self.col + math.max(1, #self:get_value()))

    local max_length = #line
    if allow_line_break then
        max_length = max_length + 1
    end

    if next_cursor.col > max_length then
        if self.row == vim.fn.line('$') then
            return
        end
        next_cursor.row = next_cursor.row + 1
        next_cursor.col = 1
    end

    return next_cursor
end

function Cursor.__lt(cursor_1, cursor_2)
    return cursor_1.row < cursor_2.row
        or (cursor_1.row == cursor_2.row and cursor_1.col < cursor_2.col)
end

function Cursor.__eq(cursor_1, cursor_2)
    return cursor_1.row == cursor_2.row and cursor_1.col == cursor_2.col
end

function Cursor:to_string()
    return string.format('(%d, %d, "%s")', self.row, self.col, self:get_value())
end

return Cursor
