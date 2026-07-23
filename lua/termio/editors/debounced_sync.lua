local config = require("termio.config")
local M = {}
local command_events = { "TextChanged", "TextChangedI" }
local cursor_events = { "CursorMoved", "CursorMovedI" }
local states = {}

local function register_debounce(events, delay_ms, state, debounce, callback)
  vim.api.nvim_create_autocmd(events, {
    buffer = state.edit_buf,
    callback = function()
      if state.suspended then
        return
      end
      local latest = state.read_state(state.edit_buf)
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
        callback(state.edit_buf, state.latest)
      end, delay_ms)
    end,
  })
end

---Debounce editor command and cursor synchronization independently.
---@param edit_buf integer
---@param read_state fun(edit_buf: integer): table?
---@param callbacks { command: fun(edit_buf: integer, state: table), cursor: fun(edit_buf: integer, state: table) }
function M.register(edit_buf, read_state, callbacks)
  local state = {
    edit_buf = edit_buf,
    read_state = read_state,
    suspended = false,
    command = { generation = 0 },
    cursor = { generation = 0 },
  }
  states[edit_buf] = state
  if config.options.editor.command_debounce_ms ~= nil then
    register_debounce(
      command_events,
      config.options.editor.command_debounce_ms,
      state,
      state.command,
      callbacks.command
    )
  end
  if config.options.editor.cursor_debounce_ms ~= nil then
    register_debounce(
      cursor_events,
      config.options.editor.cursor_debounce_ms,
      state,
      state.cursor,
      callbacks.cursor
    )
  end
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = edit_buf,
    callback = function()
      states[edit_buf] = nil
    end,
  })
end

---Suspend synchronization and cancel pending callbacks.
---@param edit_buf integer
function M.suspend(edit_buf)
  local state = states[edit_buf]
  state.suspended = true
  M.cancel(edit_buf)
end

---Resume synchronization.
---@param edit_buf integer
function M.resume(edit_buf)
  states[edit_buf].suspended = false
end

---Cancel pending command and cursor synchronization.
---@param edit_buf integer
function M.cancel(edit_buf)
  local state = states[edit_buf]
  state.command.generation = state.command.generation + 1
  state.cursor.generation = state.cursor.generation + 1
end

return M
