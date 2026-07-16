# Integrated Editor

The integrated editor keeps the shell input empty while normal-mode edits are active:

1. Probe and clear the shell command.
2. Paint the returned command into the modifiable terminal buffer.
3. Let normal buffer edits change that local draft.
4. Write the draft once when entering terminal mode or submitting.

It does not synchronize shell cursor position or use shell redraw hooks.
