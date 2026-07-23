local Helpers = require("tests.helpers")
local T = MiniTest.new_set()
local child = Helpers.new_child_neovim()

T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      Helpers.setup_child(child, [[{ editor = { type = "centered" } }]])
      child.set_size(24, 80)
    end,
    post_once = child.stop,
  },
})

T["centered editor"] = MiniTest.new_set()

local function open_centered_editor(command)
  local terminal_buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input(command)
  Helpers.wait_for_read_command(child, terminal_buf, command)
  local terminal_win = child.api.nvim_get_current_win()
  child.lua([[require("termio.editors.centered").open({ target_buf = ... })]], { terminal_buf })
  Helpers.wait_for_mode(child, "n")
  return terminal_buf, terminal_win
end

T["centered editor"]["opens prompt command buffer in float"] = function()
  local _, terminal_win = open_centered_editor("echo old")
  local float_config = child.api.nvim_win_get_config(0)
  MiniTest.expect.equality(float_config.relative, "win")
  MiniTest.expect.equality(float_config.win, terminal_win)
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ echo old")
end

T["centered editor"]["opens at shell cursor"] = function()
  local terminal_buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo old<Left><Left><Left>")
  Helpers.wait_until(child, function()
    local state = child.lua_get([[require("termio.api").read_state(...)]], { terminal_buf })
    return state.command == "echo old" and state.cursor == 5
  end)

  child.lua([[require("termio.editors.centered").open({ target_buf = ... })]], { terminal_buf })
  Helpers.wait_for_mode(child, "n")
  MiniTest.expect.equality(child.api.nvim_win_get_cursor(0), { 1, 7 })
end

T["centered editor"]["save updates shell cursor"] = function()
  local terminal_buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo lorem ipsum")
  Helpers.wait_for_read_command(child, terminal_buf, "echo lorem ipsum")
  local terminal_win = child.api.nvim_get_current_win()

  child.api.nvim_input("<Esc>")
  Helpers.wait_for_mode(child, "n")
  child.api.nvim_input("b")
  MiniTest.expect.equality(child.api.nvim_win_get_cursor(0), { 1, 13 })

  child.api.nvim_input("<Esc>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() == terminal_buf
  end)
  MiniTest.expect.equality(
    child.lua_get(
      [[require("termio.api").cursor_index_in_command(...)]],
      { terminal_win, terminal_buf }
    ),
    11
  )

  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  MiniTest.expect.equality(
    child.lua_get(
      [[require("termio.api").cursor_index_in_command(...)]],
      { terminal_win, terminal_buf }
    ),
    11
  )
end

T["centered editor"]["normal p opens and pastes in popup"] = function()
  local terminal_buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo hello")
  Helpers.wait_for_read_command(child, terminal_buf, "echo hello")
  child.lua([[vim.fn.setreg('"', ' world', 'c')]])
  child.cmd("stopinsert")
  Helpers.wait_for_mode(child, "nt")
  child.api.nvim_input("p")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() ~= terminal_buf
  end)
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_line() == "$ echo hello world"
  end)
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ echo hello world")
end

T["centered editor"]["visual p opens and pastes in popup"] = function()
  local terminal_buf = Helpers.open_shell(child)
  child.api.nvim_input("i")
  Helpers.wait_for_mode(child, "t")
  child.api.nvim_input("echo hello world")
  Helpers.wait_for_read_command(child, terminal_buf, "echo hello world")
  child.lua([[vim.fn.setreg('"', 'goodbye', 'c')]])
  child.cmd("stopinsert")
  Helpers.wait_for_mode(child, "nt")
  child.api.nvim_input("bbvep")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() ~= terminal_buf
  end)
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_line() == "$ echo goodbye world"
  end)
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ echo goodbye world")
end

T["centered editor"]["clamps cursor after prompt"] = function()
  open_centered_editor("echo old")
  child.cmd("normal! 0")
  Helpers.wait_until(child, function()
    return child.api.nvim_win_get_cursor(0)[2] == 2
  end)
end

T["centered editor"]["writes command from prompt buffer"] = function()
  local terminal_buf = open_centered_editor("echo old")
  child.api.nvim_set_current_line("$ echo centered")
  child.lua([[require("termio.editors.centered").write()]])
  Helpers.wait_for_read_command(child, terminal_buf, "echo centered")
end

T["centered editor"]["debounces command sync"] = function()
  child.lua([[require("termio.config").options.editor.command_debounce_ms = 100]])
  local terminal_buf = open_centered_editor("echo old")
  child.api.nvim_set_current_line("$ echo centered")
  MiniTest.expect.equality(
    child.lua_get([[require("termio.api").read_state(...).command]], {
      terminal_buf,
    }),
    "echo old"
  )
  Helpers.wait_for_read_command(child, terminal_buf, "echo centered")
end

T["centered editor"]["insert enter submits command"] = function()
  local terminal_buf = open_centered_editor("echo insert")
  child.api.nvim_input("i<CR>")
  Helpers.wait_for_shell_output(child, terminal_buf, "insert")
  Helpers.wait_for_mode(child, "t")
end

T["centered editor"]["insert shift enter adds newline"] = function()
  open_centered_editor("echo first")
  child.api.nvim_input("A<S-CR>second")
  Helpers.wait_until(child, function()
    return child.lua_get([[vim.api.nvim_buf_line_count(0)]]) == 2
  end)
  MiniTest.expect.equality(
    child.api.nvim_buf_get_lines(0, 0, -1, false),
    { "$ echo first", "second" }
  )
end

T["centered editor"]["normal escape saves and closes"] = function()
  local terminal_buf = open_centered_editor("echo hello")
  child.api.nvim_set_current_line("$ echo changed")
  child.api.nvim_input("<Esc>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() == terminal_buf
  end)
  Helpers.wait_for_read_command(child, terminal_buf, "echo changed")
end

T["centered editor"]["q closes without submitting"] = function()
  local terminal_buf = open_centered_editor("echo hello")
  child.api.nvim_set_current_line("$ echo changed")
  child.api.nvim_input("q")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() == terminal_buf
  end)
  Helpers.wait_for_read_command(child, terminal_buf, "echo hello")
end

T["centered editor"]["tab passes through to terminal insert mode"] = function()
  local terminal_buf = open_centered_editor("echo hello")
  child.api.nvim_input("A")
  Helpers.wait_for_mode(child, "i")
  child.api.nvim_input("<Tab>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() == terminal_buf
  end)
  Helpers.wait_for_mode(child, "t")
end

T["centered editor"]["j and k move by visual lines"] = function()
  open_centered_editor(("echo lorem ipsum dolor sit amet "):rep(5))
  local start = child.api.nvim_win_get_cursor(0)
  child.api.nvim_input("j")
  child.wait(20)
  MiniTest.expect.equality(child.api.nvim_win_get_cursor(0)[1] >= start[1], true)
  child.api.nvim_input("k")
  child.wait(20)
  MiniTest.expect.equality(child.api.nvim_get_option_value("buftype", { buf = 0 }), "prompt")
end

T["centered editor"]["resizes when content grows"] = function()
  open_centered_editor("echo first")
  local initial_config = child.api.nvim_win_get_config(0)
  child.api.nvim_input("A<S-CR>second")
  Helpers.wait_until(child, function()
    return child.api.nvim_win_get_config(0).height == 2
  end)
  MiniTest.expect.equality(initial_config.height, 1)
end

T["centered editor"]["first-line normal pass-through returns to terminal"] = function()
  local terminal_buf = open_centered_editor("echo hello")
  Helpers.wait_for_mode(child, "n")
  child.api.nvim_input("{")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() == terminal_buf
  end)
end

T["centered editor"]["search keys pass through to terminal"] = function()
  local terminal_buf = open_centered_editor("echo hello")
  child.api.nvim_input("/")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() == terminal_buf and child.fn.getcmdtype() == "/"
  end)
  child.api.nvim_input("<Esc>")
end

T["centered editor"]["search match in command reopens editor"] = function()
  child.lua([[
    require("termio").setup({
      editor = { type = "centered", popup = { open_on_focus = true } },
    })
  ]])
  local terminal_buf = open_centered_editor("echo hello hello")
  child.api.nvim_input("?")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() == terminal_buf and child.fn.getcmdtype() == "?"
  end)
  child.api.nvim_input("hello<CR>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_buf() ~= terminal_buf
  end)
  MiniTest.expect.equality(child.bo.buftype, "prompt")
  MiniTest.expect.equality(child.api.nvim_win_get_cursor(0), { 1, 13 })
  child.api.nvim_input("cegoodbye<Esc>")
  MiniTest.expect.equality(child.api.nvim_get_current_line(), "$ echo hello goodbye")
end

T["centered editor"]["redirects opened files to target window"] = function()
  local _, terminal_win = open_centered_editor("echo old")
  child.cmd("edit README.md")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_win() == terminal_win
  end)
  Helpers.expect.match(child.api.nvim_buf_get_name(0), "README%.md$")
end

return T
