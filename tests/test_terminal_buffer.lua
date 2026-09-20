local Helpers = require("tests.helpers")
local T = MiniTest.new_set()
local child = Helpers.new_child_neovim()

T = MiniTest.new_set({
  hooks = {
    pre_case = function()
      Helpers.setup_child(child, [[{ backend = "buffer" }]])
    end,
    post_once = child.stop,
  },
})

T["buffer backend"] = MiniTest.new_set()

-- Buffer lines cannot reliably distinguish completions from wrapped commands.
-- T["buffer backend"]["read command ignores zsh completion rows"] = function()
--   local buf = Helpers.open_shell(child)
--   child.api.nvim_input("i")
--   Helpers.wait_for_mode(child, "t")
--   child.api.nvim_input("ls<Tab>")
--   Helpers.wait_until(child, function()
--     return child.lua_get(
--       [[table.concat(vim.api.nvim_buf_get_lines(..., 0, -1, false), "\n"):find("lsbom") ~= nil]],
--       { buf }
--     )
--   end)
--   MiniTest.expect.equality(child.lua_get([[require("termio").read_command(...)]], { buf }), "ls")
-- end

T["command_end_patterns"] = MiniTest.new_set()

local function read_command_text(lines, patterns)
  return child.lua_get(string.format(
    [[
    (function()
    require("termio.config").options.command_end_patterns = %s
    local buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, %s)
    return require("termio.terminal_buffer").command_text(buf, { 1, 2 })
    end)()
  ]],
    vim.inspect(patterns),
    vim.inspect(lines)
  ))
end

-- Interactive TUIs (e.g. codex) draw a frame below the input line.
T["command_end_patterns"]["stops reading at a matching row"] = function()
  MiniTest.expect.equality(
    read_command_text({ "> echo hi", "BOTTOM----", "gpt-5.1" }, { "^\\s*BOTTOM" }),
    "echo hi"
  )
end

-- The frame can also close on the command row itself.
T["command_end_patterns"]["stops reading inside a matching row"] = function()
  MiniTest.expect.equality(read_command_text({ "> echo hi   RIGHT" }, { "\\s*RIGHT" }), "echo hi")
end

-- A prompt pattern must not be mistaken for the end of the command it starts.
T["command_end_patterns"]["ignores matches before the command start"] = function()
  MiniTest.expect.equality(read_command_text({ "> echo hi" }, { "^>" }), "echo hi")
end

return T
