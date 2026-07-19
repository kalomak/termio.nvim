# Technical roadmap

These are possible long-term improvements, not planned features.

## Completion markers

Problem:

- Shell integrations can trigger completion but cannot identify the rendered completion area.
- Terminal-buffer reads can mistake completions and suggestions for editable command text.

Goal:

- Emit markers around rendered completions and suggestions.
- Exclude marked text when reading command state from the terminal buffer.
- Research what completion state ZLE, Bash Readline, and Fish expose.

## Command boundaries without shell integration

See the [probe backend](./termio.md#probe-backend).

Command start:

- Adapt the cursor wait from the `minimal-api` branch.
- Send `<C-u>`, wait for the cursor to settle, and record its position.
- Add an option to force probing instead of shell integration or prompt markers.

Command end:

- Send `<C-e>`, wait for the cursor to settle, and record its position.
- Use the end position to exclude completions and suggestions.
- Investigate whether probing can avoid visible cursor movement.

## Continuous synchronization

- Debounce synchronization while the editor is open.
- Keep the command and shell cursor synchronized more often.
- Support the integrated editor without interrupting edits.
- Determine whether FIFO writes are still useful with continuous synchronization.
