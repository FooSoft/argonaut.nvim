-- Run with ./test.sh from the repository root.
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.cmd('runtime plugin/argonaut.lua')
vim.cmd('syntax on')

local passed, failed = 0, 0

local function equal(expected, actual)
    assert(vim.deep_equal(expected, actual), '\nexpected: ' .. vim.inspect(expected) .. '\nactual:   ' .. vim.inspect(actual))
end

local function buffer(lines, cursor, options)
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, cursor or { 1, 4 })
    require('argonaut').setup(options or {})
end

local function lines()
    return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function toggle(expected)
    equal(true, require('argonaut').reflow(true))
    equal(expected, lines())
end

local function test(name, run)
    vim.cmd('normal! \027')
    vim.cmd('enew!')
    vim.bo.expandtab = true
    vim.bo.shiftwidth = 2
    vim.bo.tabstop = 8
    vim.bo.filetype = ''
    vim.bo.syntax = ''
    vim.o.selection = 'inclusive'
    vim.o.virtualedit = ''
    for module in pairs(package.loaded) do
        if module:match('^argonaut') then
            package.loaded[module] = nil
        end
    end
    local ok, err = xpcall(run, debug.traceback)
    if ok then
        passed = passed + 1
        print('PASS ' .. name)
    else
        failed = failed + 1
        print('FAIL ' .. name .. ': ' .. err)
    end
end

test('wrap and unwrap preserve surrounding text and cursor', function()
    buffer({ '  foo(alpha, beta); tail' }, { 1, 15 })
    toggle({ '  foo(', '    alpha,', '    beta', '  ); tail' })
    equal({ 3, 6 }, vim.api.nvim_win_get_cursor(0))
    toggle({ '  foo(alpha, beta); tail' })
    equal({ 1, 15 }, vim.api.nvim_win_get_cursor(0))
end)

test('shiftwidth zero uses tabstop', function()
    buffer({ 'foo(a, b)' })
    vim.bo.shiftwidth = 0
    vim.bo.tabstop = 4
    toggle({ 'foo(', '    a,', '    b', ')' })
end)

test('preserve indentation that is not a multiple of shiftwidth', function()
    buffer({ '   foo(a, b)' }, { 1, 7 })
    toggle({ '   foo(', '     a,', '     b', '   )' })
    equal({ 2, 5 }, vim.api.nvim_win_get_cursor(0))
end)

test('preserve mixed indentation with noexpandtab', function()
    buffer({ '\t  foo(a, b)' }, { 1, 7 })
    vim.bo.expandtab = false
    vim.bo.shiftwidth = 8
    toggle({ '\t  foo(', '\t  \t  a,', '\t  \t  b', '\t  )' })
end)

test('noexpandtab still respects shiftwidth', function()
    buffer({ 'foo(a, b)' })
    vim.bo.expandtab = false
    vim.bo.shiftwidth = 4
    toggle({ 'foo(', '    a,', '    b', ')' })
end)

test('nested closing braces on argument lines restore indentation', function()
    buffer({ 'foo(bar(', '  a,', '  b), c)' }, { 1, 4 }, { brace_last_wrap = false })
    toggle({ 'foo(', '  bar(', '    a,', '    b),', '  c)' })
end)

test('only a closing brace on another line still counts as wrapped', function()
    buffer({ 'foo(a, b', ')' })
    toggle({ 'foo(a, b)' })
end)

test('empty wrapped ranges collapse', function()
    buffer({ 'foo(', '', ')' }, { 2, 0 })
    toggle({ 'foo()' })
end)

test('trailing indentation does not hide a wrapped closing brace', function()
    buffer({ 'foo(a', '  )' })
    toggle({ 'foo(a)' })
end)

test('leading padding does not hide a wrapped first argument', function()
    buffer({ 'foo( ', '  a)' })
    toggle({ 'foo(a)' })
end)

test('unicode prefix and cursor survive wrapping', function()
    buffer({ 'résumé(éclair, βeta)' }, { 1, 20 })
    toggle({ 'résumé(', '  éclair,', '  βeta', ')' })
    equal({ 3, 4 }, vim.api.nvim_win_get_cursor(0))
    toggle({ 'résumé(éclair, βeta)' })
    equal({ 1, 20 }, vim.api.nvim_win_get_cursor(0))
end)

test('blank lines and padding are removed', function()
    buffer({ 'foo(', '', '  a,', '', '  b', ')' }, { 3, 2 })
    toggle({ 'foo(a, b)' })
end)

test('setup accepts no arguments and table options can become scalars', function()
    local argonaut = require('argonaut')
    argonaut.setup()
    argonaut.setup({ brace_pad = { ['('] = true } })
    argonaut.setup({ brace_pad = false })
    buffer({ 'foo(a, b)' })
    toggle({ 'foo(', '  a,', '  b', ')' })
end)

test('setup does not mutate supplied configuration', function()
    local options = { brace_pad = { ['('] = true } }
    require('argonaut').setup(options)
    require('argonaut').setup({ brace_pad = { ['['] = true } })
    equal({ brace_pad = { ['('] = true } }, options)
end)

test('filetype and per-brace overrides', function()
    buffer({ 'foo(a, b)' }, nil, {
        comma_last = true,
        by_filetype = { lua = { comma_last = { ['('] = false } } },
    })
    vim.bo.filetype = 'lua'
    toggle({ 'foo(', '  a,', '  b', ')' })
end)

test('quoted delimiters are not arguments', function()
    buffer({ 'foo("a,b)", c)' })
    vim.bo.syntax = 'lua'
    toggle({ 'foo(', '  "a,b)",', '  c', ')' })
end)

test('long strings use linked syntax groups', function()
    buffer({ 'foo([=[a,b)]=], c)' })
    vim.bo.syntax = 'lua'
    toggle({ 'foo(', '  [=[a,b)]=],', '  c', ')' })
end)

test('comments cannot swallow arguments or closing braces', function()
    buffer({ 'foo(a,', '  -- comment', ')' })
    vim.bo.syntax = 'lua'
    local before = lines()
    equal(false, require('argonaut').reflow(true))
    equal(before, lines())
end)

test('empty arguments cannot be silently removed', function()
    buffer({ 'foo(a,, b)' })
    local before = lines()
    equal(false, require('argonaut').reflow(true))
    equal(before, lines())
end)

test('trailing commas remain supported', function()
    buffer({ 'foo(a, b,)' })
    toggle({ 'foo(', '  a,', '  b', ')' })
end)

test('rewrapping can exceed input parsing limits', function()
    buffer({ 'foo(a, b)' }, nil, { limit_rows = 1 })
    toggle({ 'foo(', '  a,', '  b', ')' })
    equal({ 2, 2 }, vim.api.nvim_win_get_cursor(0))
end)

test('nested ranges rejected by the parser are not flattened', function()
    buffer({ 'foo(', '  bar(aaaa, bbbb),', '  c', ')' }, { 3, 2 }, { limit_cols = 10 })
    local before = lines()
    equal(false, require('argonaut').reflow(true))
    equal(before, lines())
end)

test('column limits apply to multiline ranges', function()
    buffer({ 'foo(', '  aaaaaaaaaaaaa,', '  b', ')' }, { 3, 2 }, { limit_cols = 10 })
    local before = lines()
    equal(false, require('argonaut').reflow(true))
    equal(before, lines())
end)

test('mismatched nested braces leave text unchanged', function()
    buffer({ 'foo([a, b), c]' }, { 1, 4 })
    local before = lines()
    equal(false, require('argonaut').reflow(true))
    equal(before, lines())
end)

test('prefix commas can be combined with a trailing comma', function()
    buffer({ 'foo(a, b)' }, nil, { comma_prefix = true, comma_prefix_indent = true, comma_last = true })
    toggle({ 'foo(', '    a', '  , b,', ')' })
    toggle({ 'foo(a, b)' })
end)

test('empty padded braces have only one space', function()
    buffer({ 'foo( )' }, nil, { brace_pad = true })
    equal(true, require('argonaut').reflow(false))
    equal({ 'foo( )' }, lines())
    vim.api.nvim_win_set_cursor(0, { 1, 4 })
    toggle({ 'foo( )' })
end)

test('one undo restores the entire wrapped range', function()
    buffer({ 'foo(a, b)', 'tail' })
    -- End the undo block containing fixture setup before running the command.
    vim.cmd('let &undolevels = &undolevels')
    toggle({ 'foo(', '  a,', '  b', ')', 'tail' })
    vim.cmd('silent undo')
    equal({ 'foo(a, b)', 'tail' }, lines())
end)

test('inspect prints the trace without an undefined global', function()
    buffer({ 'foo(a, b)' })
    local output = vim.api.nvim_exec2('ArgonautInspect', { output = true }).output
    assert(output:find('param_cursor_cell', 1, true))
end)

test('navigation preserves virtualedit', function()
    buffer({ 'foo(a, b)' })
    vim.o.virtualedit = 'block'
    require('argonaut').object('next')
    equal({ 1, 7 }, vim.api.nvim_win_get_cursor(0))
    equal('block', vim.o.virtualedit)
end)

test('inner object respects exclusive selection', function()
    buffer({ 'foo(alpha, beta)' })
    vim.o.selection = 'exclusive'
    require('argonaut').object('inner')
    vim.cmd('normal! y')
    equal('alpha', vim.fn.getreg('"'))
end)

test('nested argument navigation works at braces', function()
    buffer({ 'foo(bar(a, b), c)' }, { 1, 7 })
    require('argonaut').object('next')
    equal({ 1, 15 }, vim.api.nvim_win_get_cursor(0))
end)

test('unicode text objects select whole characters', function()
    buffer({ 'foo(éβ, c)' })
    vim.o.selection = 'exclusive'
    require('argonaut').object('inner')
    vim.cmd('normal! y')
    equal('éβ', vim.fn.getreg('"'))
end)

test('cursor traversal handles blank lines and multibyte characters', function()
    buffer({ 'é', '', 'β' }, { 1, 0 })
    local Cursor = require('argonaut.cursor')
    local first, last = Cursor.get_first(), Cursor.get_last()
    equal(nil, first:get_previous())
    equal(Cursor.new(2, 1), first:get_next())
    equal(last, first:get_next():get_next())
    equal(first, last:get_previous():get_previous())
    equal(nil, last:get_next())
    equal(Cursor.new(3, 3), last:get_next(true))
end)

test('nested ranges preserve wrapping and closing-brace indentation', function()
    buffer({ 'foo(bar(', '  a,', '  b), c)' }, { 1, 4 }, { brace_last_indent = true })
    toggle({ 'foo(', '  bar(', '    a,', '    b', '    ),', '  c', '  )' })
    toggle({ 'foo(bar(', '  a,', '  b', '  ), c)' })
end)

test('all formatting option combinations are stable under reflow', function()
    local names = {
        'brace_last_indent', 'brace_last_wrap', 'brace_pad',
        'comma_last', 'comma_prefix', 'comma_prefix_indent',
    }
    for mask = 0, 63 do
        local options = {}
        for i, name in ipairs(names) do
            options[name] = bit.band(mask, bit.lshift(1, i - 1)) ~= 0
        end
        buffer({ 'foo(bar(', '  a,', '  b), c, {})' }, { 1, 4 }, options)
        local argonaut = require('argonaut')
        equal(true, argonaut.reflow(true))
        local wrapped = lines()
        equal({ 2, 2 + (options.comma_prefix and options.comma_prefix_indent and 2 or 0) },
            vim.api.nvim_win_get_cursor(0))
        equal(true, argonaut.reflow(false))
        equal(wrapped, lines())
        equal(true, argonaut.reflow(true))
        local unwrapped = lines()
        equal(true, argonaut.reflow(false))
        equal(unwrapped, lines())
    end
end)

test('row limits leave distant braces unchanged', function()
    buffer({ 'foo(', '  a,', '  b', ')' }, { 2, 2 }, { limit_rows = 1 })
    local before = lines()
    equal(false, require('argonaut').reflow(true))
    equal(before, lines())
end)

print(string.format('\n%d passed, %d failed', passed, failed))
if failed > 0 then
    vim.cmd('cquit 1')
end
