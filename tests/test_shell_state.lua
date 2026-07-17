local T = MiniTest.new_set()

local function state_for(sequence, cursor)
  require("termio.config").setup()
  local shell_state = require("termio.shell_state")
  local buffers = {}
  local buf = vim.api.nvim_get_current_buf()
  shell_state.handle_term_request(buffers, {
    buf = buf,
    data = { sequence = sequence, cursor = cursor or { 1, 0 } },
  })
  return buffers[buf]
end

T["OSC133 prompt end activates prompt"] = function()
  local state = state_for("\027]133;B\007", { 2, 4 })

  MiniTest.expect.equality(state.prompt_end_cursor, { 2, 4 })
  MiniTest.expect.equality(state.active_prompt_cursor, { 2, 4 })
  MiniTest.expect.equality(state.active_prompt_source, "osc133")
  MiniTest.expect.equality(state.shell_phase, "input")
end

T["latest OSC133 prompt end becomes active prompt"] = function()
  local shell_state = require("termio.shell_state")
  local state = state_for("\027]133;B\007", { 1, 2 })
  local buf = vim.api.nvim_get_current_buf()

  shell_state.handle_term_request({ [buf] = state }, {
    buf = buf,
    data = { sequence = "\027]133;B\007", cursor = { 2, 4 } },
  })

  MiniTest.expect.equality(state.prompt_end_cursor, { 2, 4 })
  MiniTest.expect.equality(state.active_prompt_cursor, { 2, 4 })
end

T["OSC133 prompt end emits prompt rendered event"] = function()
  local event_buf
  vim.api.nvim_create_autocmd("User", {
    pattern = "TermioPromptRendered",
    once = true,
    callback = function(args)
      event_buf = args.data.buf
    end,
  })

  local buf = vim.api.nvim_get_current_buf()
  state_for("\027]133;B\007", { 1, 0 })

  -- TODO: no fixed waits
  vim.wait(100, function()
    return event_buf ~= nil
  end)
  MiniTest.expect.equality(event_buf, buf)
end

T["OSC133 prompt rendered event waits for rendered cursor"] = function()
  local event_buf
  vim.api.nvim_create_autocmd("User", {
    pattern = "TermioPromptRendered",
    once = true,
    callback = function(args)
      event_buf = args.data.buf
    end,
  })

  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "" })
  state_for("\027]133;B\007", { 1, 4 })

  -- TODO: no fixed waits
  vim.wait(10, function()
    return event_buf ~= nil
  end)
  MiniTest.expect.equality(event_buf, nil)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "$ ab" })
  -- TODO: no fixed waits
  vim.wait(100, function()
    return event_buf ~= nil
  end)
  MiniTest.expect.equality(event_buf, buf)
end

T["OSC133 preexec clears active prompt"] = function()
  local shell_state = require("termio.shell_state")
  local state = state_for("\027]133;B\007", { 2, 4 })

  shell_state.handle_term_request({ [vim.api.nvim_get_current_buf()] = state }, {
    buf = vim.api.nvim_get_current_buf(),
    data = { sequence = "\027]133;C\007", cursor = { 2, 8 } },
  })

  MiniTest.expect.equality(state.prompt_end_cursor, { 2, 4 })
  MiniTest.expect.equality(state.active_prompt_cursor, nil)
  MiniTest.expect.equality(state.active_prompt_source, nil)
  MiniTest.expect.equality(state.shell_phase, "output")
end

T["OSC633 integration marker stores shell"] = function()
  local state = state_for("\027]633;I;zsh\007")

  MiniTest.expect.equality(state.shell_kind, "zsh")
  MiniTest.expect.equality(state.shell_integration.kind, "zsh")
end

T["OSC633 command marker stores shell command state"] = function()
  local state = state_for("\027]633;E;4;echo test\007")

  MiniTest.expect.equality(state.shell_state.command, "echo test")
  MiniTest.expect.equality(state.shell_state.cursor, 4)
  MiniTest.expect.equality(state.shell_query_pending, false)
end

T["OSC633 completion marker stores command and completion state"] = function()
  local state = state_for("\027]633;CL;3;ls foo\007", { 2, 4 })

  MiniTest.expect.equality(state.shell_state, { command = "ls foo", cursor = 3 })
  MiniTest.expect.equality(state.might_have_completions, true)
end

T["OSC133 prompt start clears completion state"] = function()
  local shell_state = require("termio.shell_state")
  local state = state_for("\027]633;CL;3;ls foo\007")
  local buf = vim.api.nvim_get_current_buf()

  shell_state.handle_term_request({ [buf] = state }, {
    buf = buf,
    data = { sequence = "\027]133;A\007", cursor = { 2, 0 } },
  })

  MiniTest.expect.equality(state.might_have_completions, false)
end

T["OSC title stores terminal title"] = function()
  local state = state_for("\027]2;python\007")

  MiniTest.expect.equality(state.terminal_title, "python")
end

T["term request stores title in api buffer state"] = function()
  local api = require("termio.api")
  local buf = vim.api.nvim_get_current_buf()

  require("termio.shell_state").handle_term_request(api.buffers, {
    buf = buf,
    data = { sequence = "\027]0;node\007", cursor = { 1, 0 } },
  })

  MiniTest.expect.equality(api.buffers[buf].terminal_title, "node")
end

return T
