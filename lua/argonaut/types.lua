Cursor = {}

function Cursor.new(x, y)
    local cursor = {
        x = x,
        y = y,
    }

    return setmetatable(cursor, {__index = Cursor})
end

function Cursor:print()
    print('x: ' .. self.x .. ' y: ' .. self.y)
end

BracePair = {}

function BracePair.new(brace)
    local escape = function(brace_raw)
        if brace_raw == '[' or brace_raw == ']' then
            return '\\' .. brace_raw
        else
            return brace_raw
        end
    end

    for _, brace_set in ipairs({{'(', ')'}, {'[', ']'}, {'{', '}'}, {'<', '>'}}) do
        if brace_set[1] == brace or brace_set[2] == brace then
            local brace_pair = {
                open = brace_set[1],
                close = brace_set[2],
                escaped = {
                    open = escape(brace_set[1]),
                    closed = escape(brace_set[2]),
                }
            }

            return setmetatable(brace_pair, {__index = BracePair})
        end
    end
end

BraceRange = {}

function BraceRange.new(start_cursor, stop_cursor, brace_pair, brace_params)
    local brace_range = {
        start_cursor = start_cursor,
        stop_cursor = stop_cursor,
        brace_pair = brace_pair,
        brace_params = brace_params or {},
    }

    return setmetatable(brace_range, {__index = BraceRange})
end
