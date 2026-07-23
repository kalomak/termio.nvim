local Helpers = require("tests.helpers")
local T = MiniTest.new_set()
local child = Helpers.new_child_neovim()

T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      Helpers.setup_child(child)
    end,
    post_once = child.stop,
  },
})

T["read_command()"] = MiniTest.new_set()

local function open_python_repl()
  if child.fn.executable("python3") == 0 then
    MiniTest.skip("python3 is not executable")
  end
  child.cmd("terminal python3 -q")
  local buf = child.api.nvim_get_current_buf()
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_line():match("^>>>%s*$") ~= nil
  end)
  return buf
end

T["read_command()"]["starts directly after OSC133;B cursor col"] = function()
  local prompt = "$ "
  local buf = Helpers.open_shell(child, prompt)
  child.lua(
    [[local buf, prompt = ...
    local api = require("termio.api")
    local state = require("termio.util.helpers").ensure_buffer_state(api.buffers, buf)
    state.prompt_start_cursor = { 1, 0 }
    state.prompt_end_cursor = { 1, #prompt }]],
    { buf, prompt }
  )
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo hello")
  Helpers.wait_for_read_command(child, buf, "echo hello")

  MiniTest.expect.equality(
    child.lua_get([[require("termio").read_command(...)]], { buf }),
    "echo hello"
  )
end

T["read_command()"]["applies configured read replace patterns"] = function()
  child.lua(
    [[require("termio.config").options.read_replace_patterns = { { "%s+$", "" }, { "keep", "read" } }]]
  )
  local buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo keep   ")
  Helpers.wait_for_read_command(child, buf, "echo read")
end

T["read_state()"] = MiniTest.new_set()

T["read_state()"]["reads state and updates cache"] = function()
  local buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo hello")
  Helpers.wait_for_read_command(child, buf, "echo hello")
  child.lua(
    [[require("termio.api").buffers[...].shell_state = { command = "stale", cursor = 0 }]],
    { buf }
  )
  local state = child.lua_get(
    [[require("termio.api").read_state(..., vim.api.nvim_get_current_win(), nil, "buffer")]],
    { buf }
  )
  local expected = { command = "echo hello", cursor = 10 }
  MiniTest.expect.equality(state, expected)
  MiniTest.expect.equality(
    child.lua_get([[require("termio.api").buffers[...].shell_state]], { buf }),
    expected
  )
end

T["read_command()"]["detects default Python REPL prompt regex"] = function()
  local buf = open_python_repl()
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("1 + 1")
  Helpers.wait_for_read_command(child, buf, "1 + 1")
  MiniTest.expect.equality(
    child.lua_get([[require("termio").command_start_cursor(...)]], { buf }),
    { 1, 4 }
  )
end

T["read_command()"]["regex prompt refresh keeps latest prompt"] = function()
  MiniTest.expect.equality(
    child.lua_get([[
      (function()
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "$ python", ">>> 1 + 1", "2", ">>> " })
      local buffers = { [buf] = { prompt_start_cursor = { 1, 0 } } }
      local _, prompt_end = require("termio.terminal_buffer").update_prompt_cursors_from_patterns(buffers, buf)
      return prompt_end
      end)()
    ]]),
    { 4, 4 }
  )
end

T["write_command()"] = MiniTest.new_set()

local function skip_fish_continuation_marker()
  if vim.env.TERMIO_TEST_SHELL == "fish" then
    MiniTest.skip("fish does not emit continuation OSC markers")
  end
end

T["write_command()"]["empty command after cursor stays empty"] = function()
  local buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.lua([[require("termio").write_command("", ..., 1)]], { buf })
  Helpers.wait_for_read_command(child, buf, "")
end

T["write_command()"]["replaces latest prompt segment"] = function()
  skip_fish_continuation_marker()
  local buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo \\<CR>")
  Helpers.wait_for_read_command(child, buf, "")
  child.api.nvim_input("hello")
  Helpers.wait_for_read_command(child, buf, "hello")
  child.lua([[require("termio").write_command("echo done", ...)]], { buf })
  Helpers.wait_for_read_command(child, buf, "echo done")
end

T["sync()"] = MiniTest.new_set()

local function setup_sync(initial_state)
  local buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.lua(
    [[require("termio").write_command(...)]],
    { initial_state.command, buf, initial_state.cursor }
  )
  Helpers.wait_for_read_command(child, buf, initial_state.command)
  return buf
end

local function wait_for_shell_cursor(buf, cursor)
  Helpers.wait_until(child, function()
    return child.lua_get([[require("termio.api").read_state(...).cursor]], { buf }) == cursor
  end)
end

T["sync()"]["moves from cached cursor to target cursor"] = function()
  local buf = setup_sync({ command = "echo hello", cursor = 7 })
  wait_for_shell_cursor(buf, 7)
  child.lua([[require("termio").sync({ command = "echo hello", cursor = 4 }, ...)]], { buf })
  wait_for_shell_cursor(buf, 4)
  child.lua([[require("termio").sync({ command = "echo hello", cursor = 6 }, ...)]], { buf })
  wait_for_shell_cursor(buf, 6)
  child.lua([[require("termio").sync({ command = "echo hello", cursor = 6 }, ...)]], { buf })
  wait_for_shell_cursor(buf, 6)
  child.lua([[require("termio.api").buffers[...].shell_state.cursor = nil]], { buf })
  child.lua([[require("termio").sync({ command = "echo hello", cursor = 4 }, ...)]], { buf })
  wait_for_shell_cursor(buf, 4)
end

T["sync()"]["updates changed command"] = function()
  local buf = setup_sync({ command = "echo old", cursor = 4 })
  wait_for_shell_cursor(buf, 4)
  child.lua([[require("termio").sync({ command = "echo new", cursor = 4 }, ...)]], { buf })
  Helpers.wait_for_read_command(child, buf, "echo new")
  wait_for_shell_cursor(buf, 4)
  child.lua([[require("termio").sync({ command = "echo new", cursor = 4 }, ...)]], { buf })
  Helpers.wait_for_read_command(child, buf, "echo new")
  wait_for_shell_cursor(buf, 4)
end

T["clear_completion_suggestions()"] = MiniTest.new_set()

local function clear_completion_suggestions(buf)
  child.lua([[require("termio.api").clear_completion_suggestions(...)]], { buf })
end

local function completion_state(buf)
  return child.lua_get([[require("termio.api").buffers[...].might_have_completions]], { buf })
end

T["clear_completion_suggestions()"]["only clears tracked completions"] = function()
  local buf = Helpers.open_shell(child)
  child.lua([[vim.g.completion_clear_calls = 0]])
  child.lua(
    [[require("termio.api").buffers[...].shell_integration.clear_completion_suggestions = function() vim.g.completion_clear_calls = vim.g.completion_clear_calls + 1 end]],
    { buf }
  )

  clear_completion_suggestions(buf)
  MiniTest.expect.equality(child.lua_get([[vim.g.completion_clear_calls]]), 0)

  child.lua([[require("termio.api").buffers[...].might_have_completions = true]], { buf })
  clear_completion_suggestions(buf)
  MiniTest.expect.equality(child.lua_get([[vim.g.completion_clear_calls]]), 1)
  MiniTest.expect.equality(completion_state(buf), false)

  clear_completion_suggestions(buf)
  MiniTest.expect.equality(child.lua_get([[vim.g.completion_clear_calls]]), 1)
end

T["clear_command()"] = MiniTest.new_set()

local shell = vim.env.TERMIO_TEST_SHELL or "zsh"
local keymap_commands = {
  bash = { default = "set -o emacs", vi = "set -o vi" },
  fish = { default = "fish_default_key_bindings", vi = "fish_vi_key_bindings" },
  zsh = { default = "bindkey -e", vi = "bindkey -v" },
}

local function test_clear_command_in_keymap(keymap)
  local buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.type_keys(keymap_commands[shell][keymap], "<CR>")
  Helpers.wait_for_read_command(child, buf, "")
  child.api.nvim_input("echo hello")
  Helpers.wait_for_read_command(child, buf, "echo hello")
  child.lua([[require("termio").clear_command(...)]], { buf })
  Helpers.wait_for_read_command(child, buf, "")
end

T["clear_command()"]["clears command in default mode"] = function()
  test_clear_command_in_keymap("default")
end

T["clear_command()"]["clears command in vi mode"] = function()
  test_clear_command_in_keymap("vi")
end

T["clear_command()"]["clears current command"] = function()
  local buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo hello")
  Helpers.wait_for_read_command(child, buf, "echo hello")
  child.lua([[require("termio").clear_command(...)]], { buf })
  Helpers.wait_for_read_command(child, buf, "")
end

T["clear_command()"]["clears latest prompt segment"] = function()
  skip_fish_continuation_marker()
  local buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo \\<CR>")
  Helpers.wait_for_read_command(child, buf, "")
  child.api.nvim_input("hello")
  Helpers.wait_for_read_command(child, buf, "hello")
  child.lua([[require("termio").clear_command(...)]], { buf })
  Helpers.wait_for_read_command(child, buf, "")
end

return T
