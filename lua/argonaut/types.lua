--
-- Cursor
--

Cursor = {}

function Cursor.new(row, col)
    local cursor = {row = row, col = col}
    return setmetatable(cursor, {__index = Cursor})
end

function Cursor.current()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return Cursor.new(row, col)
end

function Cursor:is_string_literal()
    local syn_id = vim.fn.synID(self.row, self.col, false)
    local syn_attr = vim.fn.synIDattr(syn_id, 'name')
    return syn_attr:find('String$')
end

function Cursor:is_valid()
    return self.row > 0 and self.col > 0
end

--
-- BracePair
--

BracePair = {}

function BracePair.new(brace_open, brace_close)
    local brace_pair = {open = brace_open, close = brace_close}
    return setmetatable(brace_pair, {__index = BracePair})
end

function BracePair.from_brace(brace)
    for _, brace_set in ipairs({{'(', ')'}, {'[', ']'}, {'{', '}'}, {'<', '>'}}) do
        if brace_set[1] == brace or brace_set[2] == brace then
            return BracePair.new(brace_set[1], brace_set[2])
        end
    end
end

function BracePair:escaped()
    local escape_brace = function(brace_raw)
        if brace_raw == '[' or brace_raw == ']' then
            return '\\' .. brace_raw
        else
            return brace_raw
        end
    end

    return BracePair.new(escape_brace(self.open), escape_brace(self.close))
end

function BracePair:find(backward)
    -- See flags: https://neovim.io/doc/user/builtin.html#search()
    local flags = 'Wcn'
    if backward then
        flags = 'Wbn'
    end

    local escaped_pair = self:escaped()
    local position = vim.fn.searchpairpos(
        escaped_pair.open,
        '',
        escaped_pair.close,
        flags,
        function()
            local cursor = Cursor:current()
            return cursor:is_string_literal()
        end
    )

    local cursor = Cursor.new(unpack(position))
    if cursor:is_valid() then
        return cursor
    end
end

--
-- BraceRange
--

BraceRange = {}

function BraceRange.new(start_cursor, stop_cursor, brace_pair, brace_params)
    local brace_range = {
        start_cursor = start_cursor,
        stop_cursor = stop_cursor,
        brace_pair = brace_pair,
        brace_params = brace_params,
    }

    return setmetatable(brace_range, {__index = BraceRange})
end

function BraceRange.find(brace_pair)
    local start_cursor = brace_pair:find(false)
    if start_cursor then
        local stop_cursor = brace_pair:find(true)
        if stop_cursor then
            return BraceRange.new(start_cursor, stop_cursor, brace_pair, {})
        end
    end
end
