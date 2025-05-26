local Cursor = require('argonaut.cursor')

local Pairing = {}
Pairing.__index = Pairing

function Pairing.new(open, close)
    local pair = {
        open = open,
        close = close
    }

    return setmetatable(pair, Pairing)
end

function Pairing.from_brace(brace)
    local all_pairs = {
        { '(', ')' },
        { '[', ']' },
        { '{', '}' },
        { '<', '>' },
    }

    for _, pair in ipairs(all_pairs) do
        if pair[1] == brace or pair[2] == brace then
            return Pairing.new(pair[1], pair[2])
        end
    end
end

function Pairing:get_escaped()
    local escape_func = function(brace_raw)
        if brace_raw == '[' or brace_raw == ']' then
            return '\\' .. brace_raw
        else
            return brace_raw
        end
    end

    return Pairing.new(
        escape_func(self.open),
        escape_func(self.close)
    )
end

function Pairing:find_closest_pair(allow_current)
    local stop_cursor = self:find_closest(true, allow_current)
    if stop_cursor then
        local start_cursor = self:find_closest(false, allow_current)
        if start_cursor then
            return { start_cursor = start_cursor, stop_cursor = stop_cursor }
        end
    end
end

function Pairing:find_closest(forward, allow_current)
    local ignore_list = {}

    if not allow_current then
        local cursor_1 = Cursor:get_current()
        local pairing = Pairing.from_brace(cursor_1:get_value())
        if pairing then
            local cursor_2 = pairing:find_closest(forward, true)
            if cursor_2 and cursor_1:get_value() ~= cursor_2:get_value() then
                table.insert(ignore_list, cursor_2)
            end
        end
    end

    -- See flags: https://neovim.io/doc/user/builtin.html#search()
    local flags = 'Wnb'
    if forward then
        flags = 'Wn'
    end

    local ignore_func = function()
        local cursor = Cursor.get_current()
        if cursor:is_comment() or cursor:is_string() then
            return true
        end

        for _, ignore_cursor in ipairs(ignore_list) do
            if ignore_cursor == cursor then
                return true
            end
        end

        return false
    end

    local escaped_pair = self:get_escaped()
    local cursor = Cursor.new(unpack(vim.fn.searchpairpos(
        escaped_pair.open,
        '',
        escaped_pair.close,
        flags,
        ignore_func
    )))

    if cursor:is_valid() then
        return cursor
    end
end

return Pairing
