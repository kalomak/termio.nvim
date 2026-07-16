# TODO

- C-u to clear, C-a to read

## Probe coverage

- Test more shells and REPLs without startup integration.
- Investigate completion UI shown below the command.
- Test commands wider than the terminal scrollback window.

## Integrated editor

- Decide whether local draft edits should be constrained to the command area.
- Handle shell output arriving while a local draft is active.

## Popup editors

- Make upward and downward focus movement symmetric.
- Check overlay placement for wrapped prompts and split windows.

## Development

- Simplify the status window around `api.terminals`.
- Expose useful probe failures instead of only timing out.
