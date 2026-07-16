local Helpers = require("tests.helpers")
local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.setup()
      child.lua([[require("termio").setup()]])
      child.cmd([[terminal env PS1='$ ' zsh -df]])
      Helpers.wait_until(child, function()
        return child.api.nvim_get_current_line() == "$ "
      end)
      child.api.nvim_input("i")
      Helpers.wait_for_mode(child, "t")
    end,
    post_once = child.stop,
  },
})

T["reads command text and cursor without shell integration"] = function()
  child.api.nvim_input("echo old<Left><Left><Left>")
  Helpers.wait_until(child, function()
    return child.api.nvim_win_get_cursor(0)[2] == 7
  end)
  child.lua([[require("termio").read(function(command) ProbeCommand = command end)]])
  Helpers.wait_until(child, function()
    return child.lua_get([[ProbeCommand ~= nil]])
  end)
  MiniTest.expect.equality(child.lua_get([[ProbeCommand]]), { text = "echo old", cursor = 5 })
end

T["minimal editor opens the probed command"] = function()
  child.api.nvim_input("echo old")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_line() == "$ echo old"
  end)
  child.api.nvim_input("<Esc>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt"
  end)
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ echo old")
end

return T
