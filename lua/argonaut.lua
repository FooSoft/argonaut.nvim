local ArgonautConfig = {
    line_prefix = '',
    padded_braces = {},
    tail_comma = false,
    tail_comma_braces = {},
    tail_indent_braces = {},
    wrap_closing_brace = true,
    comma_first = false,
    comma_first_indent = false,
}

local function setup(opts)
    if opts then
        for key, value in pairs(opts) do
            ArgonautConfig[key] = value
        end
    end
end

local function find_range(brace_pair)
    local filter = 'synIDattr(synID(line("."), col("."), 0), "name") =~? "string"'
    local row1, col1 = unpack(vim.fn.searchpairpos(brace_pair[1], '', brace_pair[2], 'Wnb', filter))
    if row1 > 0 and col1 > 0 then
        local row2, col2 = unpack(vim.fn.searchpairpos(brace_pair[1], '', brace_pair[2], 'Wcn', filter))
        if row2 > 0 and col2 > 0 then
            return {
                brace_pair = brace_pair,
                row1 = row1,
                col1 = col1,
                row2 = row2,
                col2 = col2
            }
        end
    end
end

local function find_ranges(brace_pairs)
    local ranges = {}
    for _, brace_pair in ipairs(brace_pairs) do
        local range = find_range(brace_pair)
        if range then
            table.insert(ranges, find_range(brace_pair))
        end
    end

    if #ranges > 0 then
        return ranges
    end
end

local function compare_ranges(range1, range2)
    local _, row, col, _ = unpack(vim.fn.getpos('.'))

    local row_diff1 = row - range1.row1
    local row_diff2 = row - range2.row1
    if row_diff1 < row_diff2 then
        return -1
    elseif row_diff1 > row_diff2 then
        return 1
    end

    local col_diff1 = col - range1.col1
    local col_diff2 = col - range2.col1
    if col_diff1 < col_diff2 then
        return -1
    elseif col_diff1 > col_diff2 then
        return 1
    end

    return 0
end

local function find_range_closest(brace_pairs)
    local ranges = find_ranges(brace_pairs)
    print(#ranges)
    if ranges then
        return vim.fn.sort(ranges, compare_ranges)[1]
    end
end

local function reflow()
    local brace_pairs = {{'(', ')'}, {'[', ']'}, {'{', '}'}, {'<', '>'}}
    local range = find_range_closest(brace_pairs)
    if range then
        print(range.brace_pair[1])
    end
end

return {
    reflow = reflow,
    ssetup = setup,
}
