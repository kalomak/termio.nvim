# termio.nvim

> [!NOTE]
> WIP. Expect bugs.

Edit the current terminal command with Neovim.

termio probes the terminal with standard shell editing keys. No shell integration or startup script is required.

## Setup

```lua
require("termio").setup()
```

With lazy.nvim:

```lua
{
  "Kallemakela/termio.nvim",
  opts = {},
}
```

## Config

Defaults live in `lua/termio/config.lua`.

```lua
require("termio").setup({
  editor = {
    type = "integrated", -- false | "minimal" | "centered" | "overlay" | "integrated"
    filetype = "bash",
    terminal_name_pattern = [[\v(:| )(/[^ ]*/)?(zsh|bash|fish)( |$)]],
    open = "<Esc>",
    is_disabled = function(buf)
      return false
    end,
    keys = {
      t = {
        ["<Esc>"] = "open",
        ["<CR>"] = "submit",
        ["<C-u>"] = "clear",
        ["<C-s>"] = "write",
        ["<M-t>"] = "toggle",
      },
      n = {
        ["<CR>"] = "submit",
        ["<C-u>"] = "clear",
        ["<C-s>"] = "write",
        ["<Esc>"] = "save_and_close",
        ["<M-t>"] = "toggle",
      },
    },
    popup = {
      style = {
        border = nil,
        window = nil,
        winhighlight = nil,
      },
      keys = {
        i = { ["<CR>"] = "submit", ["<C-u>"] = "clear", ["<C-s>"] = "write" },
        n = { q = "close", j = "down", k = "up" },
      },
      pass_through_insert_keys = { "<Up>", "<Tab>" },
      pass_through_normal_keys = { "}", "<C-d>", "<C-b>", "G", "L", "/", "?", "n", "N" },
    },
  },
})
```

## Editors

### `minimal`

Small centered prompt editor bundled directly around the API. `<Esc>` saves, `q` cancels, and `<CR>` submits.

### `centered`

The previous minimal editor. A centered popup with configurable actions, autoresizing, and pass-through keys.

### `overlay`

Uses the shared popup editor but places it over the terminal command.

### `integrated`

Paints a local editable draft into the terminal buffer. The shell input stays cleared until the draft is saved or submitted.

## API

`read` is asynchronous and clears the current shell input. Call `write` in the callback to restore or replace it.
Use `editor.type = false` for API-only setup.

```lua
local termio = require("termio")

termio.read(function(command)
  print(command.text, command.cursor)
  termio.write(command.text)
end)
```

`write(command, buf)` accepts an optional terminal buffer. It writes bracketed paste into input already cleared by `read`.

## Commands

```vim
:TermioReadCommand
:TermioWriteCommand echo hello
:TermioEnable
:TermioDisable
:TermioToggle
```

`TermioReadCommand` restores the command after printing it.

## Development

- [Development](./docs/development.md)
- [Roadmap](./docs/todo.md)
- [Related projects](./docs/related-projects.md)
