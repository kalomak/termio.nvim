local Termio = { buffers = {} }
local config = require("termio.config")
local helpers = require("termio.util.helpers")
local terminal_buffer = require("termio.terminal_buffer")
local shell_integration = require("termio.shell_integration")

shell_integration.use_buffers(Termio.buffers)

---@param buf integer
---@param cursor integer
---@param command string
---@private
local function move_shell_cursor(buf, cursor, command)
  local delta = #command - cursor
  if delta > 0 then
    helpers.send_bytes(("\27[D"):rep(delta), buf)
  end
end

local function can_send_shell_integration_signal(buf)
  return helpers.ensure_buffer_state(Termio.buffers, buf).active_prompt_source ~= "regex"
end

---@param target integer
---@param win? integer
---@param timeout_ms? integer
---@param backend "auto"|"buffer"
---@return { rows: string[], cursor: integer[]?, cursor_index: integer? }
---@private
local function read_raw_state(target, win, timeout_ms, backend)
  Termio.update_prompt_range(target)
  local _, prompt_end_cursor = Termio.prompt_range(target)
  if not prompt_end_cursor then
    error("termio: missing prompt end cursor")
  end
  if backend == "auto" and can_send_shell_integration_signal(target) then
    local shell_state = shell_integration.read_state(target, timeout_ms)
    if shell_state then
      return shell_state
    end
  end
  win = win or helpers.visible_window(target)
  return terminal_buffer.read_state(Termio.buffers, target, win, prompt_end_cursor)
end

---Update cached prompt range from configured prompt patterns.
---@param buf? integer
function Termio.update_prompt_range(buf)
  local target = helpers.current_buf(buf)
  helpers.assert_terminal(target)
  terminal_buffer.update_prompt_cursors_from_patterns(Termio.buffers, target)
end

---Return the cached prompt range, or nil when no prompt has been detected yet.
---@param buf? integer
---@return integer[]? prompt_start_cursor
---@return integer[]? prompt_end_cursor
function Termio.prompt_range(buf)
  local target = helpers.current_buf(buf)
  helpers.assert_terminal(target)
  return terminal_buffer.prompt_range(Termio.buffers, target)
end

---Return the cursor where command text starts after the prompt, or nil before prompt detection.
---@param buf? integer
---@return integer[]? cursor 1-based row, 0-based column
function Termio.command_start_cursor(buf)
  local _, prompt_end_cursor = Termio.prompt_range(buf)
  return prompt_end_cursor
end

---Return current cursor byte index inside command text, or nil before prompt detection.
---@param win integer
---@param buf? integer
---@return integer?
function Termio.cursor_index_in_command(win, buf)
  local target = helpers.current_buf(buf)
  local _, prompt_end_cursor = Termio.prompt_range(target)
  if not prompt_end_cursor then
    return nil
  end
  return terminal_buffer.read_state(Termio.buffers, target, win, prompt_end_cursor).cursor_index
end

---Query the current shell command buffer.
---@param buf? integer
---@param timeout_ms? integer
---@param backend? "auto"|"buffer" Communication backend. "auto" tries shell integration first; "buffer" reads rendered terminal text.
---@return string
function Termio.read_command(buf, timeout_ms, backend)
  return Termio.read_state(buf, nil, timeout_ms, backend).command
end

---Query the current shell command and cursor state.
---@param buf? integer
---@param win? integer
---@param timeout_ms? integer
---@param backend? "auto"|"buffer" Communication backend. "auto" tries shell integration first; "buffer" reads rendered terminal text.
---@return { command: string, cursor: integer? }
function Termio.read_state(buf, win, timeout_ms, backend)
  local target = helpers.current_buf(buf)
  helpers.assert_terminal(target)
  backend = backend or config.options.backend
  if backend ~= "auto" and backend ~= "buffer" then
    error("termio: backend must be 'auto' or 'buffer'")
  end
  return helpers.normalize_state(read_raw_state(target, win, timeout_ms, backend))
end

---Hide shell completion suggestions shown below the prompt.
---@param buf? integer
function Termio.clear_completion_suggestions(buf)
  local target = helpers.current_buf(buf)
  helpers.assert_terminal(target)
  local state = helpers.ensure_buffer_state(Termio.buffers, target)
  if not state.might_have_completions then
    return
  end
  if can_send_shell_integration_signal(target) then
    shell_integration.clear_completion_suggestions(target)
    state.might_have_completions = false
  end
end

---Clear the current shell command buffer.
---@param buf? integer
---@param opts? { wait_for_render?: boolean }
---@return boolean
function Termio.clear_command(buf, opts)
  opts = opts or {}
  local target = helpers.current_buf(buf)
  helpers.assert_terminal(target)
  helpers.send_keys("<C-e><C-u>", target)
  if can_send_shell_integration_signal(target) then
    shell_integration.redraw_after_pty_write(target)
  end
  local cleared = true
  if opts.wait_for_render ~= false then
    cleared = terminal_buffer.wait_until_command_is_rendered(
      target,
      Termio.command_start_cursor(target),
      "",
      true
    )
  end
  if not cleared then
    vim.notify("termio: failed to clear command", vim.log.levels.WARN)
    return false
  end
  local state = helpers.ensure_buffer_state(Termio.buffers, target)
  state.shell_state.command = ""
  state.shell_state.cursor = 0
  return true
end

---Write shell command buffer directly.
---@param command string
---@param buf? integer
---@param cursor? integer
function Termio.write_command(command, buf, cursor)
  local target = helpers.current_buf(buf)
  helpers.assert_terminal(target)
  if type(command) ~= "string" then
    error("termio: command must be a string")
  end
  local shell_command = helpers.replace_patterns(command, config.options.write_replace_patterns)
  local shell_cursor = cursor and math.max(0, math.min(cursor, #shell_command)) or #shell_command
  local state = helpers.ensure_buffer_state(Termio.buffers, target)
  local can_signal_shell = can_send_shell_integration_signal(target)
  Termio.clear_command(target, { wait_for_render = false })
  helpers.send_bytes("\27[200~" .. shell_command .. "\27[201~", target)
  move_shell_cursor(target, shell_cursor, shell_command)
  if can_signal_shell then
    shell_integration.redraw_after_pty_write(target)
  end
  state.shell_state.command = shell_command
  state.shell_state.cursor = shell_cursor
end

return Termio
