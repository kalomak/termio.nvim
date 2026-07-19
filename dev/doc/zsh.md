# Zsh

Zsh uses ZLE and is slightly friendlier to integrate with than other shells.

## Useful ZLE fields

- `BUFFER` / `CURSOR`: authoritative editable command state. `ls <Tab>` stayed `cursor=3 buffer="ls "`; `ls A<Tab>` became `cursor=13 buffer="ls AGENTS.md "`.
- `LBUFFER` / `RBUFFER`: same command state split at cursor. Best payload shape for sync/cursor math.
- `SUFFIX_ACTIVE`, `SUFFIX_START`, `SUFFIX_END`: useful for auto-removable inserted suffixes. `ls A<Tab>` had `suffix_active=1 suffix_start=12 suffix_end=13`.
- `BUFFERLINES`: editable command screen-line count, not completion list rows. Stayed `1` in tests.
- `PREDISPLAY` / `POSTDISPLAY`: empty for normal completion lists in tests. Not useful for list rows.
- `compstate[list_lines]`, `compstate[list]`, `compstate[nmatches]`, `compstate[insert]`, `compstate[old_list]`, `compstate[unambiguous]`: likely best for exact completion-list info, but only available inside completion widgets/functions, not a plain wrapper around `zle .expand-or-complete`.
