--
-- Cursor
--

local Cursor = {}
Cursor.__index = Cursor

function Cursor.new(row, col)
    local cursor = {row = row, col = col}
    return setmetatable(cursor, Cursor)
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

function Cursor.get_current()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return Cursor.new(row, col)
end

function Cursor:set_current()
    assert(self:is_valid())
    vim.fn.setcursorcharpos({self.row, self.col})
end

function Cursor.__eq(self, other)
    return self.row == other.row and self.col == other.col
end

--
-- BracePair
--

local BracePair = {}
BracePair.__index = BracePair

function BracePair.new(open, close)
    local pair = {open = open, close = close}
    return setmetatable(pair, BracePair)
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
        flags = 'Wcnb'
    end

    local ignore_func = function()
        local cursor = Cursor.get_current()
        return cursor:is_literal()
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

function BracePair.__eq(self, other)
    return self.open == other.open and self.close == other.close
end

--
-- BraceStack
--

local BraceStack = {}
BraceStack.__index = BraceStack

function BraceStack.new()
    local stack = {stack = {}}
    return setmetatable(stack, BraceStack)
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
    return self.stack[#self.stack]
end

--
-- BraceRange
--

local BraceRange = {}
BraceRange.__index = BraceRange

function BraceRange.new(start, stop, pair)
    local range = {
        start = start,
        stop = stop,
        pair = pair,
    }

    return setmetatable(range, BraceRange)
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
    local ranges = {}
    for _, brace in ipairs({'(', '[', '{', '<'}) do
        local pair = BracePair.from_brace(brace)
        local range = BraceRange.find_closest(pair)
        if range then
            table.insert(ranges, range)
        end
    end

    if #ranges > 0 then
        table.sort(ranges)
        return ranges[1]
    end
end

function BraceRange:get_rows()
    return self.stop.row - self.start.row
end

function BraceRange:is_wrapped()
    return self.start.row < self.stop.row
end

function BraceRange.__lt(range_1, range_2)
    local cursor = Cursor:get_current()

    local row_diff1 = range_1.start.row - cursor.row
    local col_diff1 = range_1.start.col - cursor.col
    local row_diff2 = range_2.start.row - cursor.row
    local col_diff2 = range_2.start.col - cursor.col

    if row_diff1 < row_diff2 then
        return false
    elseif row_diff1 > row_diff2 then
        return true
    elseif col_diff1 < col_diff2 then
        return false
    elseif col_diff1 > col_diff2 then
        return true
    else
        return true
    end
end

--
-- Param
--

local Param = {}
Param.__index = Param

function Param.new(pair, opt)
    local param = {
        pair = pair,
        opt = opt,
        text = '',
        literals = {},
        offset = nil,
        start = nil,
        stop = nil,
        terminator = nil,
    }

    return setmetatable(param, Param)
end

function Param:append(char, cursor)
    assert(cursor:is_valid())

    self.text = self.text .. char
    table.insert(self.literals, cursor:is_literal())

    if cursor == Cursor.get_current() then
        self.offset = #self.text
    end

    if not self.start then
        self.start = cursor
    end

    self.stop = cursor
end

function Param:terminate(cursor)
    self.terminator = cursor
    if self.terminator == Cursor.get_current() then
        self.offset = #self.text
    end
end

function Param:is_active()
    return self.offset ~= nil
end

function Param:slice(start, stop)
    assert(#self.text == #self.literals)

    local text = ''
    local literals = {}

    for i = start, stop do
        text = text .. self.text:sub(i, i)
        table.insert(literals, self.literals[i])
    end

    self.text = text
    self.literals = literals

    if self.offset then
        self.offset = math.min(self.offset, stop)
        self.offset = math.max(self.offset - start + 1, 1)
    end
end

function Param:trim()
    assert(#self.text == #self.literals)

    self:slice(1, #self.text - #self.text:match('%s*$'))
    self:slice(1 + #self.text:match('^%s*'), #self.text)

    if self.text:match('^' .. self.opt.line_prefix) then
        self:slice(1 + #self.opt.line_prefix, #self.text)
    end

    if self.opt.trim_inner_spaces then
        local text = ''
        local literals = {}
        local offset = self.offset

        for i = 1, #self.text do
            local char = self.text:sub(i, i)
            local literal = self.literals[i]

            if literal or not char:match('%s') or not text:match('%s$') then
                text = text .. char
                table.insert(literals, literal)
            elseif offset and offset >= i then
                self.offset = math.max(1, self.offset - 1)
            end
        end

        self.text = text
        self.literals = literals
    end

    return #self.text > 0
end

--
-- ParamList
--

local ParamList = {}
ParamList.__index = ParamList

function ParamList.new(range, opt)
    local params = {
        range = range,
        opt = opt,
        current = nil,
        parsed = {},
    }

    return setmetatable(params, ParamList)
end

function ParamList:flush(cursor)
    if self.current then
        if cursor then
            self.current:terminate(cursor)
        end

        if self.current:trim() then
            table.insert(self.parsed, self.current)
        end

        self.current = nil
    end
end

function ParamList:update(char, brace_stack, cursor)
    if not cursor:is_literal() then
        brace_stack:update(char)
        if brace_stack:empty() and char == ',' then
            self:flush(cursor)
            return
        end
    end

    if not self.current then
        self.current = Param.new(self.range, self.opt)
    end

    self.current:append(char, cursor)
end

function ParamList:parse()
    local brace_stack = BraceStack:new()

    for row = self.range.start.row, self.range.stop.row do
        local line = vim.fn.getline(row)

        local start_col = 1
        if row == self.range.start.row then
            start_col = self.range.start.col + 1
        end

        local stop_col = #line
        if row == self.range.stop.row then
            stop_col = self.range.stop.col - 1
        end

        for col = start_col, stop_col do
            self:update(line:sub(col, col), brace_stack, Cursor.new(row, col))
        end

        self:flush()
    end
end

--
-- Builder
--

local Builder = {}
Builder.__index = Builder

function Builder.new(indent_level, indent_block)
    local builder = {
        lines = {},
        line = '',
        indent_level = indent_level,
        indent_block = indent_block,
    }

    return setmetatable(builder, Builder)
end

function Builder:indent()
    self.indent_level = self.indent_level + 1
end

function Builder:unindent()
    assert(self.indent_level > 0)
    self.indent_level = self.indent_level - 1
end

function Builder:update(text)
    self.line = self.line .. text
end

function Builder:flush()
    local indent = string.rep(self.indent_block, self.indent_level)
    table.insert(self.lines, indent .. self.line)
    self.line = ''
end

function Builder:get_offset()
    local indent = string.rep(self.indent_block, self.indent_level)
    return Cursor.new(#self.lines, #self.line + #indent)
end

--
-- WrapContext
--

local WrapContext = {}
WrapContext.__index = WrapContext

function WrapContext.new(opt)
    local wrap_context = {
        opt = nil,
        base_opt = opt,
        indent = '',
        prefix = '',
        suffix = '',
        range = nil,
        params = nil,
    }

    return setmetatable(wrap_context, WrapContext)
end

function WrapContext:config_opt()
    self.opt = {}
    for key, value in pairs(self.base_opt) do
        if type(value) == 'table' then
            self.opt[key] = false
            for _, brace in ipairs(value) do
                if self.range.pair == BracePair.from_brace(brace) then
                    self.opt[key] = true
                    break
                end
            end
        else
            self.opt[key] = value
        end
    end
end

function WrapContext:config_indent(line)
    local padding = #line:match('^(%s*)')
    if vim.o.expandtab then
        self.indent_level = math.floor(padding / vim.o.shiftwidth)
        self.indent_block = string.rep(' ', vim.o.shiftwidth)
    else
        self.indent_level = padding
        self.indent_block = '\t'
    end
end

function WrapContext:parse()
    self.range = BraceRange.find_closest_any()
    if not self.range then
        return false
    end

    self:config_opt()

    if self.range:get_rows() > self.opt.line_max then
        return false
    end

    local first_line = vim.fn.getline(self.range.start.row)
    local last_line = vim.fn.getline(self.range.stop.row)
    self:config_indent(first_line)
    self.prefix = first_line:sub(self.indent_level * #self.indent_block + 1, self.range.start.col)
    self.suffix = last_line:sub(self.range.stop.col)

    self.params = ParamList.new(self.range, self.opt)
    self.params:parse()

    return true
end

function WrapContext:update_builder_param(builder, param)
    local cursor = nil
    if param:is_active() then
        cursor = builder:get_offset()
        cursor.row = cursor.row + self.range.start.row
        cursor.col = cursor.col + param.offset
    end

    builder:update(param.text)
    return cursor
end

function WrapContext:wrap()
    local builder = Builder.new(self.indent_level, self.indent_block)
    builder:update(self.prefix)
    builder:flush()
    builder:indent()

    local cursor = nil
    for i, param in ipairs(self.params.parsed) do
        local is_first_param = i == 1
        local is_last_param = i == #self.params.parsed

        if self.opt.comma_prefix then
            builder:update(self.opt.line_prefix)
            if not is_first_param then
                builder:update(', ')
            elseif self.opt.comma_prefix_indent and not is_last_param then
                builder:update('  ')
            end
            cursor = self:update_builder_param(builder, param) or cursor
        else
            builder:update(self.opt.line_prefix)
            cursor = self:update_builder_param(builder, param) or cursor
            if not is_last_param or self.opt.comma_last then
                builder:update(',')
            end
        end

        if is_last_param and not self.opt.brace_last_wrap then
            builder:update(self.suffix)
        end

        builder:flush()
    end

    if not self.opt.brace_last_indent then
        builder:unindent()
    end

    if self.opt.brace_last_wrap then
        builder:update(self.opt.line_prefix)
        builder:update(self.suffix)
        builder:flush()
    end

    local row = self.range.start.row
    for i, line in ipairs(builder.lines) do
        if i == 1 then
            vim.fn.setline(row, line)
        else
            vim.fn.append(row, line)
            row = row + 1
        end
    end

    if not cursor then
        cursor = self.range.start
    end

    cursor:set_current()
end

function WrapContext:unwrap()
    local padding = ''
    if self.opt.brace_pad then
        padding = ' '
    end

    local builder = Builder.new(
        self.indent_level,
        self.indent_block
    )
    builder:update(self.prefix)
    builder:update(padding)

    local cursor = nil
    for i, param in ipairs(self.params.parsed) do
        cursor = self:update_builder_param(builder, param) or cursor
        if i < #self.params.parsed then
            builder:update(', ')
        end
    end

    builder:update(padding)
    builder:update(self.suffix)
    builder:flush()

    vim.fn.setline(self.range.start.row, builder.lines[1])
    vim.fn.execute(string.format('%d,%dd_', self.range.start.row + 1, self.range.stop.row))

    if not cursor then
        cursor = self.range.start
    end

    cursor:set_current()
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
