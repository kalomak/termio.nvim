local Helpers = require("tests.helpers")
local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      child.setup()
      child.set_size(24, 80)
      child.lua([[require("termio").setup({ editor = { type = "minimal" } })]])
    end,
    post_once = child.stop,
  },
})

local function open_shell(command, left_count)
  child.cmd([[terminal env PS1='$ ' zsh -df]])
  local terminal_buf = child.api.nvim_get_current_buf()
  Helpers.wait_until(child, function()
    local lines = child.api.nvim_buf_get_lines(terminal_buf, 0, -1, false)
    return vim.tbl_contains(lines, "$ ")
  end)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input(command .. ("<Left>"):rep(left_count or 0))
  Helpers.wait_until(child, function()
    local text = table.concat(child.api.nvim_buf_get_lines(terminal_buf, 0, -1, false))
    return text:find(command, 1, true) ~= nil
  end)
  if left_count and left_count > 0 then
    Helpers.wait_until(child, function()
      return child.api.nvim_win_get_cursor(0)[2] == #"$ " + #command - left_count
    end)
  end
  return terminal_buf
end

local function open_popup(command, left_count)
  local terminal_buf = open_shell(command, left_count)
  child.api.nvim_input("<Esc>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt"
  end)
  return terminal_buf
end

T["probes prompt, command, and cursor without shell integration"] = function()
  open_popup("echo old", 3)
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ echo old")
  MiniTest.expect.equality(child.api.nvim_win_get_cursor(0), { 1, 7 })
end

T["passes the command state to the read callback"] = function()
  open_shell("echo old", 3)
  child.lua([[require("termio").read(function(command) ReadCommand = command end)]])
  Helpers.wait_until(child, function()
    return child.lua_get([[ReadCommand ~= nil]])
  end)
  MiniTest.expect.equality(child.lua_get([[ReadCommand]]), { text = "echo old", cursor = 5 })
end

T["saves by pasting into the cleared shell command"] = function()
  local terminal_buf = open_popup("echo old")
  child.api.nvim_set_current_line("$ echo new")
  child.api.nvim_input("<Esc>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() == terminal_buf
  end)
  Helpers.wait_until(child, function()
    local text = table.concat(child.api.nvim_buf_get_lines(terminal_buf, 0, -1, false), "\n")
    return text:find("$ echo new", 1, true) ~= nil
  end)
end

T["handles a cached prompt row below the current command"] = function()
  open_shell("echo old")
  local terminal_buf = child.api.nvim_get_current_buf()
  child.lua([[require("termio.api").get_cache(...).prompt_row = 999]], { terminal_buf })
  child.api.nvim_input("<Esc>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_option_value("buftype", { buf = 0 }) == "prompt"
  end)
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ echo old")
end

T["reads a 300-word wrapped command on first open"] = function()
  local words = {}
  for index = 1, 300 do
    words[index] = "word"
  end
  local command = table.concat(words, " ")
  open_popup(command)
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ " .. command)
end

return T
