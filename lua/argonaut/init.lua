local config = require('argonaut.config')
local types = require('argonaut.types')

local function wrap_brace_range(brace_range, arg_list)
    vim.fn.setline(brace_range.start_cursor.row, arg_list.indent .. arg_list.prefix)

    -- local cursor_pos = nil
    local row = brace_range.start_cursor.row
    for _, arg in ipairs(arg_list.args) do
        -- local on_last_row = i == #brace_range.params

        local line = arg_list.indent .. arg.text
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

    vim.fn.append(row, arg_list.indent .. arg_list.suffix)

    -- if opts.wrap_closing_brace then
    --     vim.fn.append(row, brace_range.indent .. brace_range.suffix)
    -- end
    --
    -- if cursor_pos then
    --     vim.fn.setcursorcharpos({cursor_pos.row, cursor_pos.col})
    -- end
end

local function unwrap_brace_range(brace_range, arg_list)
    local line = arg_list.indent .. arg_list.prefix
    for i, arg in ipairs(arg_list.args) do
        line = line .. arg.text
        if i < #arg_list.args then
            line = line .. ', '
        end
    end
    line = line .. arg_list.suffix

    vim.fn.setline(brace_range.start_cursor.row, line)
    vim.fn.execute(string.format('%d,%dd_', brace_range.start_cursor.row + 1, brace_range.stop_cursor.row))
end

local function reflow()
    local brace_range = types.BraceRange.find_closest_any()
    if brace_range then
        local arg_list = types.ArgList.new()
        arg_list:parse(brace_range)

        if brace_range:is_wrapped() then
            unwrap_brace_range(brace_range, arg_list)
        else
            wrap_brace_range(brace_range, arg_list)
        end
    end
end

return {
    reflow = reflow,
    setup = config.set,
}
