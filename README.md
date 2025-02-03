# argonaut.nvim

Argonaut is a Neovim extension for manipulating function arguments, lists, and dictionaries. It is the successor to
[vim-argwrap](https://foosoft.net/projects/vim-argwrap), a much more basic extension I created for Vim many years ago.
Argonaut has more features, handles edge cases better, and is much easier to work on compared to its predecessor.

![](img/demo.gif)

Features include:
*   Wrapping and unwrapping of argument lists.
*   Reformatting argument lists for consistency.
*   Navigating forwards and backwards in argument lists.
*   Declaring function objects for individual arguments.

## Configuration

The plugin is configured via the `setup` function. Options may be provided to change the default settings shown below.

```lua
require('argonaut').setup({
    brace_last_indent = false,
    brace_last_wrap = true,
    brace_pad = false,
    comma_last = false,
    comma_prefix = false,
    comma_prefix_indent = false,
    limit_cols = 512,
    limit_rows = 64,
    by_filetype = {
        go = {comma_last = true},
    },
})
```

Global options can be overridden for specific file types by inserting a configuration in the `by_filetype` table. In the
sample configuration shown above, we force all wrapped brace ranges in Go to end with a comma.

Per-brace configuration is possible by assigning tables instead of raw values. The following configuration only pads
curly braces:

```lua
brace_pad = {['{'] = true},
```
The table should be keyed on the type of brace you wish to specialize, where `*` matches everything.

#### `brace_last_indent`

Specifies if the closing brace should be indented to argument depth.

```lua
-- brace_last_indent = true

Foo(
    wibble,
    wobble,
    wubble
    )
```

```lua
-- brace_last_indent = false

Foo(
    wibble,
    wobble,
    wubble
)
```

#### `brace_last_wrap`

Specifies if the closing brace should be wrapped to a new line.

```lua
-- brace_last_wrap = true

Foo(
    wibble,
    wobble,
    wubble
)
```

```lua
-- brace_last_wrap = false

Foo(
    wibble,
    wobble,
    wubble)
```

#### `brace_pad`

Specifies which brace types should be padded on the inside with spaces.

```lua
-- brace_pad = true

[ 1, 2, 3 ]
```

```lua
-- brace_pad = false

[1, 2, 3]
```

### `comma_last`

Specifies which closing brace should be preceded with a comma when wrapping lines.

```lua
-- comma_last = true
[
    1,
    2,
    3,
]

-- comma_last = false
[
    1,
    2,
    3
]
```

### `comma_prefix`

Specifies if the argument comma delimiter should be placed before arguments.

```lua
-- comma_prefix = true

Foo(
    wibble
    , wobble
    , wubble
)
```

```lua
-- comma_prefix = false

Foo(
    wibble,
    wobble,
    wubble
)
```

### `comma_prefix_indent`

Specifies if the first argument should be indented when used in conjunction with `comma_prefix`.

```lua
-- comma_prefix_indent = true

Foo(
      wibble
    , wobble
    , wubble
)
```

```lua
-- comma_prefix_indent = false

Foo(
    wibble
    , wobble
    , wubble
)
```

### `limit_cols`

Limits the maximum number of columns to consider for argument parsing.

### `limit_rows`

Limits the maximum number of rows to consider for argument parsing.

## Commands

Commands are not mapped by default; an example set of bindings is shown below.

```lua
vim.keymap.set('n', '<leader>a', ':<c-u>ArgonautToggle<cr>', {noremap = true, silent = true})
vim.keymap.set({'x', 'o'}, 'ia', ':<c-u>ArgonautObject inner<cr>', {noremap = true, silent = true})
vim.keymap.set({'x', 'o'}, 'aa', ':<c-u>ArgonautObject outer<cr>', {noremap = true, silent = true})
vim.keymap.set({'x', 'o', 'n'}, '<leader>n', ':<c-u>ArgonautObject inner<cr>', {noremap = true, silent = true})
vim.keymap.set({'x', 'o', 'n'}, '<leader>p', ':<c-u>ArgonautObject outer<cr>', {noremap = true, silent = true})
```

### `ArgonautToggle`

Wraps or unwraps the brace range containing the cursor.

### `ArgonautReflow`

Reformats a brace range according to the active configuration.

### `ArgonautObject`

Several text objects are supported; an object mode must be passed to this command as an argument.

*   `inner`: selects argument text not including the comma and any padding
*   `outer`: selects argument text including the comma and any padding
*   `previous`: moves cursor to the previous argument
*   `next`: moves cursor to the next argument
*   `beginning`: moves cursor to the beginning of the argument
*   `end`: moves cursor to the end of the argument

### `ArgonautInspect`

Inspect the parsing and picking state for a brace range (development feature).

### `ArgonautReload`

Reloads the extension, applying any code changes (development feature).
