# Completions

Completions and autosuggestions make detecting where the command ends non-trivial.
Example: `ls<Tab>` shows matches below command the command in zsh.

## Current state

- Zsh emits `OSC 633;CL;<cursor>;<command>` when completion is triggered. Termio tracks that completions might be visible until it clears them or receives `OSC 133;A` for a new prompt.
- This only works for zsh and fish, which maybe is enough.

## Other solutions

### Probe

`C-e` moves cursor to last point in editable command.
- Problem: cursor jitter.

### Parse from terminal buffer output

Parsing what is a completion from the terminal buffer is tempting, but there is no way to do it in a consistent way. This might change if soft-wrapping behaviour changes when changing to libghostty from libvterm.
