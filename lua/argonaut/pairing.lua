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
        {'(', ')'},
        {'[', ']'},
        {'{', '}'},
        {'<', '>'},
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

function Pairing:find_closest(forward)
    -- See flags: https://neovim.io/doc/user/builtin.html#search()
    local flags = 'Wnbc'
    if forward then
        flags = 'Wn'
    end

    local ignore_func = function()
        local cursor = Cursor.get_current()
        return cursor:is_literal()
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
