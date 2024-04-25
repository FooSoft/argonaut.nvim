--
-- Cursor
--

local Cursor = {}

function Cursor.new(row, col)
    local cursor = {row = row, col = col}
    return setmetatable(cursor, {__index = Cursor})
end

function Cursor:is_valid()
    return self.row > 0 and self.col > 0
end

function Cursor:is_string()
    assert(self:is_valid())
    local syn_id = vim.fn.synID(self.row, self.col, false)
    local syn_attr = vim.fn.synIDattr(syn_id, 'name')
    return syn_attr:find('String$')
end

function Cursor.get_current()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return Cursor.new(row, col)
end

function Cursor:set_current()
    assert(self:is_valid())
    vim.fn.secursorcharpos({self.row, self.col})
end

--
-- BracePair
--

local BracePair = {}

function BracePair.new(open, close)
    local brace_pair = {open = open, close = close}
    return setmetatable(brace_pair, {__index = BracePair})
end

function BracePair.from_brace(brace)
    local brace_pairs = {
        {'(', ')'},
        {'[', ']'},
        {'{', '}'},
        {'<', '>'},
    }

    for _, brace_pair in ipairs(brace_pairs) do
        if brace_pair[1] == brace or brace_pair[2] == brace then
            return BracePair.new(brace_pair[1], brace_pair[2])
        end
    end
end

function BracePair:escaped()
    local escape_func = function(brace_raw)
        if brace_raw == '[' or brace_raw == ']' then
            return '\\' .. brace_raw
        else
            return brace_raw
        end
    end

    return BracePair.new(
        escape_func(self.open),
        escape_func(self.close)
    )
end

function BracePair:find_closest(backward, cursor)
    if not cursor then
        cursor = Cursor.get_current()
    end

    -- See flags: https://neovim.io/doc/user/builtin.html#search()
    local flags = 'Wcn'
    if backward then
        flags = 'Wbn'
    end

    local ignore_func = function()
        return cursor:is_string()
    end

    local escaped_pair = self:escaped()
    local position = vim.fn.searchpairpos(
        escaped_pair.open,
        '',
        escaped_pair.close,
        flags,
        ignore_func
    )

    local brace_cursor = Cursor.new(unpack(position))
    if brace_cursor:is_valid() then
        return brace_cursor
    end
end

--
-- BraceStack
--

local BraceStack = {}

function BraceStack.new()
    local stack = {stack = {}}
    return setmetatable(stack, {__index = BraceStack})
end

function BraceStack:update(brace)
    local brace_pair = BracePair.from_brace(brace)
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

local BraceRange = {}

function BraceRange.new(start_cursor, stop_cursor, brace_pair, brace_params)
    local brace_range = {
        start_cursor = start_cursor,
        stop_cursor = stop_cursor,
        brace_pair = brace_pair,
        brace_params = brace_params,
    }

    return setmetatable(brace_range, {__index = BraceRange})
end

function BraceRange.find_closest(brace_pair)
    local stop_cursor = brace_pair:find_closest(false)
    if stop_cursor then
        local start_cursor = brace_pair:find_closest(true)
        if start_cursor then
            return BraceRange.new(start_cursor, stop_cursor, brace_pair, {})
        end
    end
end

function BraceRange.find_closest_any()
    local brace_range_compare = function(brace_range_1, brace_range_2)
        local cursor = Cursor:get_current()

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
        local brace_range = BraceRange.find_closest(brace_pair)
        if brace_range then
            table.insert(brace_ranges, brace_range)
        end
    end

    if #brace_ranges > 0 then
        vim.fn.sort(brace_ranges, brace_range_compare)
        return brace_ranges[1]
    end
end

function BraceRange:is_wrapped()
    return self.start_cursor.row < self.stop_cursor.row
end

--
-- Arg
--

local Arg = {}

function Arg.new(text, brace_pair)
    local arg = {
        text = text,
        brace_pair = brace_pair,
    }

    return setmetatable(arg, {__index = Arg})
end

function Arg:append(char)
    self.text = self.text .. char
end

--
-- ArgList
--

local ArgList = {}

function ArgList.new()
    local arg_list = {
        arg = nil,
        args = {},
    }

    return setmetatable(arg_list, {__index = ArgList})
end

function ArgList:flush()
    if self.arg then
        table.insert(self.args, self.arg)
        self.arg = nil
    end
end

function ArgList:update(char, brace_stack, brace_range, cursor)
    if not cursor:is_string() then
        brace_stack:update(char)
        if brace_stack:empty() and char == ',' then
            self:flush()
            return
        end
    end

    if self.arg then
        self.arg:append(char)
    else
        self.arg = Arg.new(char, brace_range)
    end
end

function ArgList:parse(brace_range)
    local brace_stack = BraceStack:new()

    for row = brace_range.start_cursor.row, brace_range.stop_cursor.row do
        local line = vim.fn.getline(row)

        local start_col = 1
        if row == brace_range.start_cursor.row then
            start_col = brace_range.start_cursor.col + 1
        end

        local stop_col = #line
        if row == brace_range.stop_cursor.row then
            stop_col = brace_range.stop_cursor.col - 1
        end

        for col = start_col, stop_col do
            self:update(line:sub(col, col), brace_stack, brace_range, Cursor.new(row, col))
        end
    end

    self:flush()
end

--
-- WrapContext
--

local WrapContext = {}

function WrapContext.new(opts)
    local wrap_context = {
        opts = opts,
        indent = '',
        prefix = '',
        suffix = '',
        brace_range = nil,
        arg_list = nil,
    }

    return setmetatable(wrap_context, {__index = WrapContext})
end

function WrapContext:parse()
    self.brace_range = BraceRange.find_closest_any()
    if not self.brace_range then
        return false
    end

    local first_line = vim.fn.getline(self.brace_range.start_cursor.row)
    self.indent = first_line:match('^(%s*)')
    self.prefix = first_line:sub(#self.indent + 1, self.brace_range.start_cursor.col)

    local last_line = vim.fn.getline(self.brace_range.stop_cursor.row)
    self.suffix = last_line:sub(self.brace_range.stop_cursor.col)

    self.arg_list = ArgList.new()
    self.arg_list:parse(self.brace_range)

    return true
end

function WrapContext:wrap()
    local line = self.indent .. self.prefix

    for i, arg in ipairs(self.arg_list.args) do
        line = line .. arg.text
        if i < #self.arg_list.args then
            line = line .. ', '
        end
    end

    line = line .. self.suffix

    vim.fn.setline(self.brace_range.start_cursor.row, line)
    vim.fn.execute(string.format(
        '%d,%dd_',
        self.brace_range.start_cursor.row + 1,
        self.brace_range.stop_cursor.row
    ))
end

function WrapContext:unwrap()
    vim.fn.setline(
        self.brace_range.start_cursor.row,
        self.indent .. self.prefix
    )

    -- local cursor_pos = nil
    local row = self.brace_range.start_cursor.row
    for _, arg in ipairs(self.arg_list.args) do
        -- local on_last_row = i == #brace_range.params

        local line = self.indent .. arg.text
        -- if opts.tail_comma or not on_last_row then
            line = line .. ','
        -- end

        -- if on_last_row and not opts.wrap_closing_brace then
        --     line = line .. brace_range.suffix
        -- end

        vim.fn.append(row, line)
        vim.fn.execute(string.format('%d>', row + 1))

        -- if param.offset then
        --     cursor_pos = get_cursor_pos()
        --     cursor_pos.col = cursor_pos.col + param.offset
        --     cursor_pos.row = row + 1
        -- end

        row = row + 1
    end

    vim.fn.append(row, self.indent .. self.suffix)

    -- if opts.wrap_closing_brace then
    --     vim.fn.append(row, brace_range.indent .. brace_range.suffix)
    -- end
    --
    -- if cursor_pos then
    --     vim.fn.setcursorcharpos({cursor_pos.row, cursor_pos.col})
    -- end
end

function WrapContext:toggle()
    if self.brace_range:is_wrapped() then
        self:wrap()
    else
        self:unwrap()
    end
end

return {
    WrapContext = WrapContext,
}
