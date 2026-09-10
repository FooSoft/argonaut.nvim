local Cursor = require('argonaut.cursor')

local Builder = {}
Builder.__index = Builder

function Builder.new(indent_prefix, source_cursor)
    local builder = {
        line = '',
        buffer = {},
        indent_level = 0,
        indent_prefix = indent_prefix,
        indent_width = vim.fn.shiftwidth(),
        expandtab = vim.bo.expandtab,
        tabstop = vim.bo.tabstop,
        source_cursor = source_cursor,
    }

    return setmetatable(builder, Builder)
end

function Builder:get_indent()
    -- Preserve the original whitespace, then add indentation in display columns.
    -- A tab may advance less than tabstop columns after a mixed whitespace prefix.
    local width = vim.fn.strdisplaywidth(self.indent_prefix)
    local target = width + self.indent_level * self.indent_width
    local indent = self.indent_prefix
    if not self.expandtab then
        local next_tab = width + self.tabstop - width % self.tabstop
        while next_tab <= target do
            indent = indent .. '\t'
            width = next_tab
            next_tab = next_tab + self.tabstop
        end
    end
    return indent .. string.rep(' ', target - width)
end

function Builder:push_indent()
    self.indent_level = self.indent_level + 1
end

function Builder:pop_indent()
    assert(self.indent_level > 0)
    self.indent_level = self.indent_level - 1
end

function Builder:write(text, source_cursor)
    -- Capture indentation when a line starts, before nested ranges change it.
    if not self.line_indent then
        self.line_indent = self:get_indent()
    end
    if source_cursor and source_cursor == self.source_cursor then
        -- Record the selected source character's new position as it is emitted.
        -- The row is relative to this output buffer until output() inserts it.
        self.output_cursor = Cursor.new(#self.buffer + 1, #self.line_indent + #self.line + 1)
    end
    self.line = self.line .. text
end

function Builder:endline()
    table.insert(self.buffer, (self.line_indent or self:get_indent()) .. self.line)
    self.line = ''
    self.line_indent = nil
end

function Builder:output(row_begin, row_end)
    vim.api.nvim_buf_set_lines(0, row_begin - 1, row_end, true, self.buffer)
    if self.output_cursor then
        Cursor.new(row_begin + self.output_cursor.row - 1, self.output_cursor.col):set_current()
    end
end

return Builder
