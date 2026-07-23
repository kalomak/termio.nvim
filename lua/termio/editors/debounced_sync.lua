local api = require("termio.api")
local config = require("termio.config")
local M = {}
local command_events = { "TextChanged", "TextChangedI" }
local cursor_events = { "CursorMoved", "CursorMovedI" }
local states = {}

local function target_has_prompt(target_buf)
  return api.buffers[target_buf].prompt_end_cursor ~= nil
end

local function register_debounce(events, delay_ms, state, debounce, callback)
  vim.api.nvim_create_autocmd(events, {
    buffer = state.edit_buf,
    callback = function()
      if state.suspended or not target_has_prompt(state.target_buf) then
        return
      end
      local latest = state.read_state()
      if not latest then
        return
      end
      state.latest = latest
      debounce.generation = debounce.generation + 1
      local generation = debounce.generation
      vim.defer_fn(function()
        if generation ~= debounce.generation or not vim.api.nvim_buf_is_valid(state.edit_buf) then
          return
        end
        if target_has_prompt(state.target_buf) then
          callback(state.latest)
        end
      end, delay_ms)
    end,
  })
end

---Debounce editor command and cursor synchronization independently.
---@param edit_buf integer
---@param target_buf integer
---@param read_state fun(): { command: string, cursor: integer }?
function M.register(edit_buf, target_buf, read_state)
  local state = {
    edit_buf = edit_buf,
    target_buf = target_buf,
    read_state = read_state,
    suspended = false,
    command = { generation = 0 },
    cursor = { generation = 0 },
  }
  states[edit_buf] = state
  local function sync_command(editor_state)
    api.sync(editor_state, target_buf)
  end
  local function sync_cursor(editor_state)
    if editor_state.command == api.buffers[target_buf].shell_state.command then
      api.sync(editor_state, target_buf)
    end
  end
  if config.options.editor.command_debounce_ms ~= nil then
    register_debounce(
      command_events,
      config.options.editor.command_debounce_ms,
      state,
      state.command,
      sync_command
    )
  end
  if config.options.editor.cursor_debounce_ms ~= nil then
    register_debounce(
      cursor_events,
      config.options.editor.cursor_debounce_ms,
      state,
      state.cursor,
      sync_cursor
    )
  end
end

---Suspend synchronization and cancel pending callbacks.
---@param edit_buf integer
function M.suspend(edit_buf)
  local state = states[edit_buf]
  state.suspended = true
  state.command.generation = state.command.generation + 1
  state.cursor.generation = state.cursor.generation + 1
end

---Resume synchronization.
---@param edit_buf integer
function M.resume(edit_buf)
  states[edit_buf].suspended = false
end

return M
