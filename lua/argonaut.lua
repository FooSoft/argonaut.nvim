-- local function closest_range(pos, range1, range2)
--     rowDiff = range1
--
-- end
--

local function get_cursor_pos()
    local _, row, col, _ = unpack(vim.fn.getpos('.'))
    return {row = row, col = col}
end

local function find_range(brace_pair)
    local filter = 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"'
    local start = vim.fn.searchpairpos(brace_pair[0], '', brace_pair[1], 'Wnb', filter)
    local stop = vim.fn.searchpairpos(brace_pair[0], '', brace_pair[1], 'Wcn', filter)
    return {row1 = start[1], col1 = start[2], row2 = stop[1], col2 = stop[2]}
end

local function find_ranges(brace_pairs)
    local ranges = {}
    for _, brace_pair in ipairs(brace_pairs) do
        table.insert(ranges, find_range(brace_pair))
    end
    return ranges
end

local function find_range_closest(brace_pairs, pos)
    local ranges = find_ranges(brace_pairs)
    return ranges[0]
end

local function wrap_toggle()
    local brace_pairs = {{'(', ')'}, {'[', ']'}, {'{', '}'}}
    find_range_closest(get_cursor_pos(), brace_pairs)
end

return {
    wrap_toggle = wrap_toggle
}
