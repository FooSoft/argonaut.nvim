local Builder = require('argonaut.builder')
local Cursor  = require('argonaut.cursor')
local Options = require('argonaut.options')
local Range   = require('argonaut.range')

local function reflow(toggle_wrapping)
    local range = Range.find_closest()
    if not range then
        return false
    end

    local trace = range:hit_test(Cursor.get_current())

    local line_first = vim.fn.getline(range.start_cursor.row)
    local line_last = vim.fn.getline(range.stop_cursor.row)

    local indent_level = #line_first:match('^(%s*)')
    local indent_block = '\t'
    if vim.o.expandtab then
        indent_level = math.floor(indent_level / vim.o.shiftwidth)
        indent_block = string.rep(' ', vim.o.shiftwidth)
    end

    local range_prefix = line_first:sub(indent_level * #indent_block + 1, range.start_cursor.col - 1)
    local range_suffix = line_last:sub(range.stop_cursor.col + 1)

    local builder = Builder.new(indent_level, indent_block)
    builder:write(range_prefix)
    if toggle_wrapping then
        range:write(builder, not range:is_wrapped())
    else
        range:write(builder, range:is_wrapped())
    end
    builder:write(range_suffix)
    builder:endline()
    builder:output(range.start_cursor.row, range.stop_cursor.row)

    local new_range = Range.find_at_cursor(range.start_cursor)
    assert(new_range)
    if trace then
        new_range:hit_search(trace, 1).cursor:set_current()
    else
        new_range.start_cursor:set_current()
    end

    return true
end

local function inspect()
    local range = Range.find_closest()
    if range then
        local trace = range:hit_test(Cursor.get_current())
        if trace then
            dump(trace)
        else
            print('No range trace!')
        end
    else
        print('No range found!')
    end
end

return {
    inspect = inspect,
    reflow = reflow,
    setup = Options.setup,
}
