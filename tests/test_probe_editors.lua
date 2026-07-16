local Helpers = require("tests.helpers")
local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = child.setup,
    post_once = child.stop,
  },
})

local function open_editor(editor)
  child.lua([[require("termio").setup({ editor = { type = ... } })]], { editor })
  child.cmd([[terminal env PS1='$ ' zsh -df]])
  local terminal_buf = child.api.nvim_get_current_buf()
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_line() == "$ "
  end)
  child.api.nvim_input("iecho old")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_line() == "$ echo old"
  end)
  child.api.nvim_input("<Esc>")
  return terminal_buf
end

T["centered uses the probe API"] = function()
  local terminal_buf = open_editor("centered")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt"
  end)
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ echo old")
  child.api.nvim_set_current_line("$ echo new")
  child.api.nvim_input("<Esc>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() == terminal_buf
      and child.api.nvim_get_current_line():match("^%$ echo new%s*$") ~= nil
  end)
end

T["overlay uses the probe API"] = function()
  open_editor("overlay")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt"
  end)
  MiniTest.expect.equality(child.api.nvim_win_get_config(0).relative, "editor")
end

T["integrated paints a local draft"] = function()
  local terminal_buf = open_editor("integrated")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_option_value("modifiable", { buf = terminal_buf })
  end)
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ echo old")
end

T["integrated writes the local draft"] = function()
  local terminal_buf = open_editor("integrated")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_option_value("modifiable", { buf = terminal_buf })
  end)
  child.api.nvim_set_current_line("$ echo new")
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_line() == "$ echo new"
  end)
end

return T
