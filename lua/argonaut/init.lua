local Builder = require('argonaut.builder')
local Cursor  = require('argonaut.cursor')
local Log     = require('argonaut.log')
local Options = require('argonaut.options')
local Range   = require('argonaut.range')

local function reflow(toggle_wrapping)
    local range = Range.find_closest(false)
    if not range then
        return false
    end

    local trace = range:hit_test(Cursor.get_current())
    -- Resolve padding to an argument character; the builder tracks its new position
    -- without reparsing output that may exceed the input parsing limits.
    local source_cursor = trace and range:hit_search(trace, 1) or range.start_cursor

    local line_first = vim.fn.getline(range.start_cursor.row)
    local line_last = vim.fn.getline(range.stop_cursor.row)

    local indent_prefix = line_first:match('^%s*')
    local range_prefix = line_first:sub(#indent_prefix + 1, range.start_cursor.col - 1)
    local range_suffix = line_last:sub(range.stop_cursor.col + 1)

    local builder = Builder.new(indent_prefix, source_cursor)
    builder:write(range_prefix)
    if toggle_wrapping then
        range:write(builder, not range:is_wrapped())
    else
        range:write(builder, range:is_wrapped())
    end
    builder:write(range_suffix)
    builder:endline()
    builder:output(range.start_cursor.row, range.stop_cursor.row)

    return true
end

local function inspect()
    local range = Range.find_closest(false)
    if range then
        range:dump(Log:new())
        local trace = range:hit_test(Cursor.get_current())
        if trace then
            print(vim.inspect(trace))
        end
    end
end

local function object(mode)
    local range = Range.find_closest(false)
    if range then
        local trace = range:hit_test(Cursor.get_current())
        if trace then
            -- Drop the character/brace frame to address the containing argument.
            table.remove(trace, #trace)
            range:hit_search(trace, 1):object(mode)
        end
    end
end

return {
    inspect = inspect,
    object = object,
    reflow = reflow,
    setup = Options.setup,
}
