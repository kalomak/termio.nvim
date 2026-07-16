# Editors

- `minimal`: smallest centered popup, bundled directly around the probe API.
- `centered`: configurable centered prompt-buffer editor.
- `overlay`: shared prompt-buffer editor positioned over the terminal command.
- `integrated`: local draft painted into the terminal buffer until save or submit.

All editors use the same asynchronous probe: reading clears shell input, and closing writes one command back.
