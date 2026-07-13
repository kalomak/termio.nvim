# Terminal Render Control

`termopen()` / `jobstart(..., { term = true })` connects the PTY directly to Neovim's terminal emulator. Job output is rendered automatically. `on_stdout` can observe the stream, but cannot block, delay, or rewrite what appears in the terminal buffer.

Typed input appears in the buffer only when the child process echoes it back. Disable echo in the child process if typed input should not be visible.
