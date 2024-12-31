local Builder = {}
Builder.__index = Builder

function Builder.new(indent_level, indent_block)
    local builder = {
        line = '',
        buffer = {},
        indent_level = indent_level,
        indent_block = indent_block,
    }

    return setmetatable(builder, Builder)
end

function Builder:indent()
    self:write(self.indent_block)
end

function Builder:push_indent()
    self.indent_level = self.indent_level + 1
end

function Builder:pop_indent()
    assert(self.indent_level > 0)
    self.indent_level = self.indent_level - 1
end

function Builder:write(text)
    self.line = self.line .. text
end

function Builder:endline()
    local indent = string.rep(self.indent_block, self.indent_level)
    table.insert(self.buffer, indent .. self.line)
    self.line = ''
end

function Builder:output(row_begin, row_end)
    local row = row_begin
    local row_count = row_end - row_begin + 1

    for i, line in ipairs(self.buffer) do
        if i <= row_count then
            vim.fn.setline(row, line)
        else
            vim.fn.append(row - 1, line)
        end
        row = row + 1
    end

    if row <= row_end then
        vim.fn.execute(string.format('%d,%dd_', row, row_end))
    end
end

return Builder
