# Development

## Dev Harness

Recommended for testing. Uses a minimal config without other plugins etc.

```sh
sh ./dev/run.sh --log-level debug --words 300
sh ./dev/run.sh --command neovide
SHELL=/opt/homebrew/bin/bash
```

Debug output: `stdpath("log")/termio.log`, cleared at startup and available through `:log termio`.

#### Args
- `--log-level trace|debug|info|warn|error|off`: set the termio log threshold (default: `debug`).
- `--words N`: prefill the terminal with a lorem command of `N` words.
- `--multi`: split the prefilled command over multiple shell lines.
- `--headless`: run without UI, then quit.
- `--command COMMAND`: use an alternative Neovim frontend (default: `nvim`).
- `--post-setup CMD`: run a Vim command before a headless run quits.
- `--config debug|own`: use the repo debug config or your own config.
- `--editor TYPE`: set the termio editor type.
- `--layout single|v|h`: open the terminal in one window, vertical split, or horizontal split.

#### Env vars
- `SHELL=/path/to/shell`: choose the shell used by `:terminal`, e.g. `/bin/bash`.

#### Keymaps in debug config
- `<leader>q`: quit.
- `<leader>c`: copy `:messages`.
- `<leader>bk`: delete the current buffer.
- `<leader>l`: open the termio log in the current window.
- `<leader>o`: open `./tmp/termdump.out`.
- `<leader>i`: write a snapshot to `./tmp/snapshot.out`.
- `<leader>s`: copy current termio status and append it to the termio log.
- `<leader>g`: run `:TermioReadCommand`.
- `<leader>w`: write a long lorem command through termio.
- `<leader>e`: show the editable zone.
- `K`: previous prompt marker.
- `J`: next prompt marker.


## Testing

Targeted test:
```sh
sh ./run_filtered_tests.sh tests/test_API.lua 'read_command'
```

Run all tests:

```sh
make test
make test-bash
make test-fish
```

Tests write debug output to `./tmp/test.out`.

Env vars:

- `TERMIO_TEST_SHELL=(bash|fish|zsh)`

Read some existing tests before writing new ones. Testing requires a lot of quirks since almost everything is async when working with the terminal.
