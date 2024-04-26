--
-- Cursor
--

local Cursor = {}
Cursor.mt = {__index = Cursor}

function Cursor.new(row, col)
    local cursor = {row = row, col = col}
    return setmetatable(cursor, Cursor.mt)
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

function Cursor.mt.__eq(self, other)
    return self.row == other.row and self.col == other.col
end

--
-- BracePair
--

local BracePair = {}
BracePair.mt = {__index = BracePair}

function BracePair.new(open, close)
    local pair = {open = open, close = close}
    return setmetatable(pair, BracePair.mt)
end

function BracePair.from_brace(brace)
    local all_pairs = {
        {'(', ')'},
        {'[', ']'},
        {'{', '}'},
        {'<', '>'},
    }

    for _, pair in ipairs(all_pairs) do
        if pair[1] == brace or pair[2] == brace then
            return BracePair.new(pair[1], pair[2])
        end
    end
end

function BracePair:get_escaped()
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

function BracePair:find_closest(backward)
    -- See flags: https://neovim.io/doc/user/builtin.html#search()
    local flags = 'Wcn'
    if backward then
        flags = 'Wbn'
    end

    local ignore_func = function()
        local cursor = Cursor.get_current()
        return cursor:is_string()
    end

    local escaped_pair = self:get_escaped()
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
BraceStack.mt = {__index = BraceStack}

function BraceStack.new()
    local stack = {stack = {}}
    return setmetatable(stack, BraceStack.mt)
end

function BraceStack:update(brace)
    local pair = BracePair.from_brace(brace)
    if pair then
        if brace == pair.close and self:top() == pair.open then
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
BraceRange.mt = {__index = BraceRange}

function BraceRange.new(start, stop, pair)
    local range = {
        start = start,
        stop = stop,
        pair = pair,
    }

    return setmetatable(range, BraceRange.mt)
end

function BraceRange.find_closest(pair)
    local stop = pair:find_closest(false)
    if stop then
        local start = pair:find_closest(true)
        if start then
            return BraceRange.new(start, stop, pair)
        end
    end
end

function BraceRange.find_closest_any()
    local range_compare = function(range_1, range_2)
        local cursor = Cursor:get_current()

        local row_diff1 = cursor.row - range_1.start.row
        local row_diff2 = cursor.row - range_2.start.row
        if row_diff1 < row_diff2 then
            return -1
        elseif row_diff1 > row_diff2 then
            return 1
        end

        local col_diff1 = cursor.col - range_1.start.col
        local col_diff2 = cursor.col - range_2.start.col
        if col_diff1 < col_diff2 then
            return -1
        elseif col_diff1 > col_diff2 then
            return 1
        end

        return 0
    end

    local ranges = {}
    for _, brace in ipairs({'(', '[', '{', '<'}) do
        local pair = BracePair.from_brace(brace)
        local range = BraceRange.find_closest(pair)
        if range then
            table.insert(ranges, range)
        end
    end

    if #ranges > 0 then
        vim.fn.sort(ranges, range_compare)
        return ranges[1]
    end
end

function BraceRange:is_wrapped()
    return self.start.row < self.stop.row
end

--
-- Param
--

local Param = {}
Param.mt = {__index = Param}

function Param.new(text, pair)
    local param = {
        text = text,
        pair = pair,
        offset = nil,
    }

    return setmetatable(param, Param.mt)
end

function Param:append(char)
    self.text = self.text .. char
end

function Param:capture()
    self.offset = #self.text
end

function Param:stripped()
    return self.text:match('^%s*(.-)%s*$')
end

--
-- ParamList
--

local ParamList = {}
ParamList.mt = {__index = ParamList}

function ParamList.new()
    local params = {
        current = nil,
        parsed = {},
    }

    return setmetatable(params, ParamList.mt)
end

function ParamList:flush()
    if self.current then
        table.insert(self.parsed, self.current)
        self.current = nil
    end
end

function ParamList:update(char, brace_stack, range, cursor)
    if not cursor:is_string() then
        brace_stack:update(char)
        if brace_stack:empty() and char == ',' then
            self:flush()
            return
        end
    end

    if self.current then
        self.current:append(char)
    else
        self.current = Param.new(char, range)
    end

    if cursor == Cursor.get_current() then
        self.current:capture()
    end
end

function ParamList:parse(range)
    local brace_stack = BraceStack:new()

    for row = range.start.row, range.stop.row do
        local line = vim.fn.getline(row)

        local start_col = 1
        if row == range.start.row then
            start_col = range.start.col + 1
        end

        local stop_col = #line
        if row == range.stop.row then
            stop_col = range.stop.col - 1
        end

        for col = start_col, stop_col do
            self:update(line:sub(col, col), brace_stack, range, Cursor.new(row, col))
        end
    end

    self:flush()
end

--
-- WrapContext
--

local WrapContext = {}
WrapContext.mt = {__index = WrapContext}

function WrapContext.new(opt)
    local wrap_context = {
        opt = opt,
        indent = '',
        prefix = '',
        suffix = '',
        range = nil,
        params = nil,
    }

    return setmetatable(wrap_context, WrapContext.mt)
end

function WrapContext:parse()
    self.range = BraceRange.find_closest_any()
    if not self.range then
        return false
    end

    local first_line = vim.fn.getline(self.range.start.row)
    self.indent = first_line:match('^(%s*)')
    self.prefix = first_line:sub(#self.indent + 1, self.range.start.col)

    local last_line = vim.fn.getline(self.range.stop.row)
    self.suffix = last_line:sub(self.range.stop.col)

    self.params = ParamList.new()
    self.params:parse(self.range)

    return true
end

function WrapContext:wrap()
    vim.fn.setline(
        self.range.start.row,
        self.indent .. self.prefix
    )

    local row = self.range.start.row
    for i, param in ipairs(self.params.parsed) do
        local first_param = i == 1
        local last_param = i == #self.params.parsed

        local line = ''
        if self.opt.comma_first then
            line = line .. self.indent .. self.opt.line_prefix
            if not first_param then
                line = line .. ', '
            end
            line = line .. param:stripped()
        else
            line = line .. self.indent .. self.opt.line_prefix .. param:stripped()
            if not last_param or self.opt.tail_comma then
                line = line .. ','
            end
        end

        if last_param and not self.opt.wrap_closing_brace then
            line = line .. self.suffix
        end

        vim.fn.append(row, line)
        vim.fn.execute(string.format('%d>', row + 1))

        if first_param and self.opt.comma_first_indent then
            local prev_shiftwidth = vim.o.shiftwidth
            vim.o.shiftwidth = prev_shiftwidth - 2
            vim.fn.execute(string.format('%d>', row + 1))
            vim.o.shiftwidth = prev_shiftwidth
        end

        row = row + 1
    end

    if self.opt.wrap_closing_brace then
        vim.fn.append(row, self.indent .. self.suffix)
    end
end

function WrapContext:unwrap()
    local line = self.indent .. self.prefix

    for i, param in ipairs(self.params.parsed) do
        line = line .. param:stripped()
        if i < #self.params.parsed then
            line = line .. ', '
        end
    end

    line = line .. self.suffix

    vim.fn.setline(self.range.start.row, line)
    vim.fn.execute(string.format('%d,%dd_', self.range.start.row + 1, self.range.stop.row))
end

function WrapContext:toggle()
    if self.range:is_wrapped() then
        self:unwrap()
    else
        self:wrap()
    end
end

return {
    WrapContext = WrapContext,
}
