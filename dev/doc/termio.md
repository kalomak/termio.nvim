# Termio.nvim

## What is this plugin?

This is not a minimal approach to editing the terminal command line (for that, see `minimal-api` branch). This is an over-engineered attempt at making shell command editing feel as native as possible.

## How does terminal text editing work?

The process in the terminal, like ZLE for zsh or the Python REPL, owns the command state. The only consistent way to communicate with these applications is by sending bytes through the PTY. Fortunately, they all share some common ways to communicate. Most relevant to us, `<C-e>` goes to the end of the line, `<C-u>` clears the editable part of the command, left and right arrows move the cursor, and bracketed paste inserts text without application-specific formatting. This allows us to make a hacky read and write API by sending key-presses to the underlying process.

## API

### Shell integration backend

Shell integration queries the command and cursor directly from a supported shell's line editor. Termio sends a bound key sequence, and the loaded shell integration responds with the current state.

### OSC backend

The OSC backend tracks semantic markers emitted as terminal control sequences. OSC 133 `B` marks the end of the prompt and therefore the start of the command. Termio uses the marker position to read the command from rendered terminal text.

### Probe backend

The probe sends `<C-e>` and records the resulting terminal cursor as the command end. It then sends `<C-u>` and records the cursor as the command start. The command and original cursor position are inferred from the terminal text between these positions.

The command remains cleared after the read and can then be restored or replaced with bracketed paste. See the `minimal-api` branch for the implementation.

## Editors

#### `integrated`

- What: Takes over the normal mode of the terminal buffer.
- Good: No separate window, edit terminal command like any other text.
- Bad: Needs to fight with the shell process over the control of the terminal buffer. Needs to sync often since insert mode is not allowed (see [upstream wishlist](#upstream-wishlist)), so most jittery. Most likely to have bugs.

#### `centered`

- What: Opens a centered popup for editing the current command.
- Good: No syncing concerns. Simple. More control, e.g., completions.
- Bad: Separate window. Less seamless than editing in-place.

#### `overlay`

- What: Same as centered, but opens the window where the command is.
- Good: Bit more seamless than centered.
- Bad: More window/focus handling complexity.

## What is hard?

### API

It is surprisingly hard to tell where the command starts and ends.

#### [OSC](#osc-backend)

The OSC 133 `B` marker is a convention, not a standard. Terminal emulators inject their own shell integration scripts for users to add instead of the shell handling this itself. In some extreme cases, the parent even overrides the REPL's config, like [VS Code does for Python](https://github.com/microsoft/vscode-python/blob/main/python_files/pythonrc.py).

This approach also runs into a new problem, which is to infer where the command ends. Usually you can just read from command start to where the text ends, but it is actually possible that the terminal program renders suggestion and completions after the command. These are not editable and need to be ignored. There are no markers for where these start and end, and it is suprisingly hard to parse them from the rendered terminal buffer. 

> [!NOTE] It would be much easier to tell what is a completion if the neovim terminal was not soft-wrapped, then we could assume that the editable command is the current line.

#### [Probe](#probe-backend)

The hard part about the probe approach is removing jitter from the shell cursor jumps while being able to tell where the cursor is.

### Integrated editor

Integrated refers to the integrated editor. This editor edits the terminal buffer directly and syncs at some points, as opposed to the other editors that edit in separate windows and buffers.

### External editors

The hard part is making them feel seamless. There are a lot of cases where the user wants to jump to the from the editor to the terminal buffer, and making this seamless is pretty hard. Ideally the buffers need to be synced when a jump like this happens.

## Why are certain choices made?

### Why not just use the simple and most robust probe solution?

Jitter. This is really the only downside. 

## Upstream wishlist

- [ ] Allow insert mode in a modifiable terminal buffer. [Issue](https://github.com/neovim/neovim/issues/40805).
  - [ ] This was closed due to a misunderstanding. Reopen with clarification.
  - This would make the integrated editor 99% as smooth for editing as the other editors.
- [ ] Allow detaching from terminal updates temporarily. This would allow background sync even in the integrated editor. Currently, updates from the terminal process always render in the terminal buffer. There is no issue yet; feasibility is still being researched.
- [ ] Expose whether a terminal is using the alternate screen, so `editor.is_disabled` can ignore TUIs. [Issue](https://github.com/neovim/neovim/issues/40293).

## Glossary

- Command: editable text after the latest prompt marker.
- Command row: one terminal display row occupied by a command.
- Prompt: text shown before the command.
- Target: terminal buffer and window being edited by a bundled editor.
- Backend: source used to read the current command state.
- `auto` backend: query shell integration first, then fall back to terminal-buffer text.
- `buffer` backend: read rendered terminal-buffer text.
- [Shell integration backend](#shell-integration-backend): query the shell's line editor.
- [OSC backend](#osc-backend): locate the command using terminal control sequences.
- [Probe backend](#probe-backend): locate the command by moving and reading the terminal cursor.
- OSC 133: terminal escape-sequence convention used to mark prompt and command boundaries.

## Reference projects

Shell integration in [Ghostty](https://ghostty.org/docs/features/shell-integration),
[VS Code](https://code.visualstudio.com/docs/terminal/shell-integration), and
[Kitty](https://sw.kovidgoyal.net/kitty/shell-integration/).

## Developer documents

- [Contributing](./contributing.md)
- [Development](./development.md)
- [TODO](./todo.md)
- [Roadmap](./roadmap.md)
- [Sync](./sync.md)
- [Completions](./completions.md)
- [Neovim terminal](./neovim-terminal.md)
- [Bash](./bash.md)
- [Zsh](./zsh.md)
- [Related projects](./related-projects.md)
- [Shell keybinds](./shell-keybinds.md)
- [TUI detection](./tui-detection.md)
