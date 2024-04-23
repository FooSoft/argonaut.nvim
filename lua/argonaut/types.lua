--
--
-- Cursor
--

Cursor = {}

function Cursor.new(row, col)
    local cursor = {row = row, col = col}
    return setmetatable(cursor, {__index = Cursor})
end

function Cursor.get()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return Cursor.new(row, col)
end

function Cursor:is_valid()
    return self.row > 0 and self.col > 0
end

function Cursor:is_string()
    local syn_id = vim.fn.synID(self.row, self.col, false)
    local syn_attr = vim.fn.synIDattr(syn_id, 'name')
    return syn_attr:find('String$')
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
    for _, brace_pair in ipairs({{'(', ')'}, {'[', ']'}, {'{', '}'}, {'<', '>'}}) do
        if brace_pair[1] == brace or brace_pair[2] == brace then
            return BracePair.new(brace_pair[1], brace_pair[2])
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
            local cursor = Cursor:get()
            return cursor:is_string()
        end
    )

    local cursor = Cursor.new(unpack(position))
    if cursor:is_valid() then
        return cursor
    end
end

--
-- BraceStack
--

BraceStack = {}

function BraceStack.new()
    local stack = {stack = {}}
    return setmetatable(stack, {__index = BraceStack})
end

function BraceStack:update(brace)
    local brace_pair = BracePair.new(brace)
    if brace_pair then
        if brace == brace_pair.close and self:top() == brace_pair.open then
            self:pop()
        else
            self:push(brace)
        end
    end
end

function BraceStack:push(brace)
    table.insert(self.stack, brace)
end

function BraceStack:pop()
    assert(not self:empty())
    return table.remove(self.stack, #self.stack)
end

function BraceStack:empty()
    return #self.stack == 0
end

function BraceStack:top()
    return #self.stack[#self.stack]
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

function BraceRange.find_closest()
    local brace_range_compare = function(brace_range_1, brace_range_2)
        local cursor = Cursor:get()

        local row_diff1 = cursor.row - brace_range_1.start_cursor.row
        local row_diff2 = cursor.row - brace_range_2.start_cursor.row
        if row_diff1 < row_diff2 then
            return -1
        elseif row_diff1 > row_diff2 then
            return 1
        end

        local col_diff1 = cursor.col - brace_range_1.start_cursor.col
        local col_diff2 = cursor.col - brace_range_2.start_cursor.col
        if col_diff1 < col_diff2 then
            return -1
        elseif col_diff1 > col_diff2 then
            return 1
        end

        return 0
    end

    local brace_ranges = {}
    for _, brace in ipairs({'(', '[', '{', '<'}) do
        local brace_pair = BracePair.from_brace(brace)
        local brace_range = BraceRange.find(brace_pair)
        if brace_range then
            table.insert(brace_ranges, brace_range)
        end
    end

    if #brace_ranges > 0 then
        return vim.fn.sort(brace_ranges, brace_range_compare)[1]
    end
end
