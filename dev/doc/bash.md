# Bash

## Options

- `bind -x`: best shell-script option. Gives access to `READLINE_LINE`, `READLINE_POINT`, and `READLINE_MARK`, and can copy changes back to readline.
- Prompt hooks: useful for command lifecycle markers, but not for reading or editing the active readline buffer.
- Traps/signals: can wake bash in some states, but do not give shell script reliable access to active readline state.
- `READLINE_LINE` in normal shell code: not available except through `bind -x`.
- Compiled loadable builtin: could use readline C globals/hooks such as `rl_line_buffer`, `rl_point`, and `rl_event_hook`, but adds build, ABI, loading, and trust costs.

## `bind -x` Flow

1. Readline receives the bound key.
2. Bash clears the visible readline line.
3. Bash exports `READLINE_LINE`, `READLINE_POINT`, and `READLINE_MARK`.
4. Bash runs the bound shell command.
5. Bash copies `READLINE_LINE`, `READLINE_POINT`, and `READLINE_MARK` back into readline.
6. Bash calls readline redraw.
7. Control returns to readline.

## Marker and redraw ordering

`termio.nvim` used to wake bash readline through `bind -x` for shell-side actions.

Observed failure:

- Shell query state is correct, e.g. `command_len = 1270`, `cursor = 1270`.
- Terminal buffer render is stale or truncated when integrated code reads it.
- A fixed wait after the bash wake makes the issue disappear.

### Bash Source

Bash 5.3 runs `bind -x` handlers in `bashline.c:bash_execute_unix_command()`.

Before the handler:

```c
rl_clear_visible_line ();
fflush (rl_outstream);
```

After the handler and after copying back `READLINE_LINE`, `READLINE_POINT`, and `READLINE_MARK`:

```c
/* and restore the readline buffer and display after command execution. */
if (ce && r != 124)
  rl_redraw_prompt_last_line ();
else
  rl_forced_update_display ();
```

There is no check for whether readline state changed. A marker-only `bind -x` handler still redraws.

### Tested Facts

- A marker printed by a `bind -x` handler appears before Bash's post-handler redraw.
- `OSC 133;B` from `PS1` appears before readline writes the command text.
- Control bytes inside `READLINE_LINE` are displayed as printable notation, e.g. `^[]633;R^G`, not emitted as raw OSC.
- A `bind -x` wake can still force a redraw even when no readline state changes.
