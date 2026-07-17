if set -q TERMIO_SHELL_INTEGRATION_LOADED
  return
end

set -g TERMIO_SHELL_INTEGRATION_LOADED 1

# Termio writes via bracketed paste; avoid fish selection-style paste highlight.
set -g fish_color_selection normal

function termio_shell_clear_transient_ui
  if commandline --paging-mode
    commandline -f cancel
  end
  if commandline --showing-suggestion
    commandline -f suppress-autosuggestion
  end
  commandline -f repaint
end

function termio_shell_read_state
  printf '\e]633;E;%d;%s\a' (commandline -C) (commandline)
end

if functions -q fish_user_key_bindings
  functions -c fish_user_key_bindings termio_original_fish_user_key_bindings
end

function termio_shell_bindings
  for termio_keymap in default insert visual
    bind -M $termio_keymap \ce end-of-line
    bind -M $termio_keymap \cu kill-whole-line
    bind -M $termio_keymap \e\[27\;5\;67~ termio_shell_clear_transient_ui
    bind -M $termio_keymap \e\[27\;5\;82~ termio_shell_read_state
  end
end

# Fish calls this after changing binding mode, so reapply both user and Termio bindings.
function fish_user_key_bindings
  if functions -q termio_original_fish_user_key_bindings
    termio_original_fish_user_key_bindings
  end
  termio_shell_bindings
end

termio_shell_bindings
printf '\e]633;I;fish\a'
