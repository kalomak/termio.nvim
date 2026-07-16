local helpers = require("termio.util.helpers")
local config = require("termio.config")
local shell_integration = require("termio.shell_integration")

local M = {}

local function prompt_cursor_is_rendered(buf, cursor)
  if not vim.api.nvim_buf_is_valid(buf) then
    return false
  end
  local line = vim.api.nvim_buf_get_lines(buf, cursor[1] - 1, cursor[1], false)[1] or ""
  local prompt_end_column_is_rendered = #line >= cursor[2]
  return prompt_end_column_is_rendered
end

local function emit_prompt_rendered(buf, cursor)
  local timeout = config.options.timeouts.render_command
  local deadline = vim.uv.now() + timeout.limit_ms

  local function check_rendered(delay)
    vim.defer_fn(function()
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      if prompt_cursor_is_rendered(buf, cursor) then
        vim.api.nvim_exec_autocmds("User", {
          pattern = "TermioPromptRendered",
          data = { buf = buf, cursor = cursor },
        })
      elseif vim.uv.now() < deadline then
        check_rendered(timeout.interval_ms)
      end
    end, delay)
  end

  check_rendered(0)
end

---@param sequence string
---@return { command: string, cursor: integer }?
local function parse_command_state(sequence)
  local payload = sequence:match("^\27]633;E;(.*)$")
  if not payload then
    return nil
  end
  payload = payload:gsub("\7$", ""):gsub("\27\\$", "")
  local cursor, command = payload:match("^(%d+);(.*)$")
  return command and { command = command, cursor = tonumber(cursor) } or nil
end

---@param sequence string
---@return string?
local function parse_title(sequence)
  return sequence:match("^\27%][012];(.-)\7") or sequence:match("^\27%][012];(.-)\27\\")
end

---@param buffers table<integer, table>
---@param args vim.api.keyset.create_autocmd.callback_args
---@return boolean handled
function M.handle_term_request(buffers, args)
  local state = helpers.ensure_buffer_state(buffers, args.buf)
  local sequence = args.data.sequence
  local command_state = parse_command_state(sequence)
  if command_state then
    state.shell_state.command = command_state.command
    state.shell_state.cursor = command_state.cursor
    state.shell_query_pending = false
    return true
  end
  local title = parse_title(sequence)
  if title then
    state.terminal_title = title
    return true
  end
  if sequence:match("^\27]133;A") then
    state.prompt_start_cursor = args.data.cursor
    state.shell_phase = "prompt"
    return true
  end
  if sequence:match("^\27]133;B") then
    state.prompt_end_cursor = args.data.cursor
    state.active_prompt_cursor = args.data.cursor
    state.active_prompt_source = "osc133"
    state.active_prompt_process = nil
    state.shell_phase = "input"
    emit_prompt_rendered(args.buf, args.data.cursor)
    return true
  end
  if sequence:match("^\27]133;C") then
    state.active_prompt_cursor = nil
    state.active_prompt_source = nil
    state.active_prompt_process = nil
    state.shell_phase = "output"
    return true
  end
  if sequence:match("^\27]133;D") then
    state.shell_phase = "finished"
    state.shell_exit_status = tonumber(sequence:match("^\27]133;D;?(%d*)"))
    state.shell_state.command = ""
    state.shell_state.cursor = nil
    return true
  end
  local shell = shell_integration.parse_shell(sequence)
  if shell then
    state.shell_kind = shell.kind
    state.shell_integration = shell
    return true
  end
  return false
end

return M
