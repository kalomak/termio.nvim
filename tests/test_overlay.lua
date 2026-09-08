local Helpers = require("tests.helpers")
local T = MiniTest.new_set()
local child = Helpers.new_child_neovim()

T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      Helpers.setup_child(child, [[{ editor = { type = "overlay" } }]])
      child.set_size(24, 80)
    end,
    post_once = child.stop,
  },
})

T["overlay editor"] = MiniTest.new_set()

local function open_overlay(command)
  local terminal_buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input(command)
  Helpers.wait_for_read_command(child, terminal_buf, command)
  child.api.nvim_input("<Esc>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt"
  end)
  return terminal_buf
end

T["overlay editor"]["opens in normal mode from terminal escape"] = function()
  open_overlay("echo hello")
  Helpers.wait_for_mode(child, "n")
end

T["overlay editor"]["does not open during shell output"] = function()
  local terminal_buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("sleep 10<CR>")
  Helpers.wait_until(child, function()
    return child.lua_get([[require("termio.api").buffers[...].shell_phase]], { terminal_buf })
      == "output"
  end)
  child.lua([[
    local helpers = require("termio.util.helpers")
    helpers.send_keys = function(key, target_buf)
      _G.termio_sent_key = { key, target_buf }
    end
  ]])
  child.api.nvim_input("<Esc>")
  Helpers.wait_until(child, function()
    return child.lua_get([[_G.termio_sent_key ~= nil]])
  end)
  MiniTest.expect.equality(child.lua_get([[_G.termio_sent_key]]), { "<Esc>", terminal_buf })
  MiniTest.expect.equality(child.lua_get([[vim.api.nvim_get_mode().mode]]), "t")
end

T["overlay editor"]["opens tall enough for wrapped command"] = function()
  open_overlay(("echo lorem ipsum dolor sit amet "):rep(5))
  MiniTest.expect.equality(child.api.nvim_win_get_config(0).height > 1, true)
end

T["overlay editor"]["opens at prompt row for wrapped command"] = function()
  open_overlay(("echo lorem ipsum dolor sit amet consectetur adipiscing elit "):rep(6))
  MiniTest.expect.equality(child.api.nvim_win_get_config(0).row, 0)
end

return T
