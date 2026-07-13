---Opens a popup when terminal-normal movement enters the editable command area.
---Experimental.

local api = require("termio.api")
local editable_zone = require("termio.editable_zone")
local helpers = require("termio.util.helpers")

local M = {}
local outside_cursor = { 0, 0 }

local function has_open_editor(buffers, target_buf)
  for _, ctx in pairs(buffers or {}) do
    if ctx.target_buf == target_buf and vim.api.nvim_win_is_valid(ctx.edit_win) then
      return true
    end
  end
  return false
end

local function cursor_is_on_prompt(cursor, prompt_start, prompt_end)
  return prompt_start
    and prompt_end
    and cursor[1] == prompt_start[1]
    and cursor[2] >= prompt_start[2]
    and cursor[2] <= prompt_end[2]
end

local function update_focus_cursor(buf, cursor)
  local state = helpers.ensure_buffer_state(api.buffers, buf)
  local previous_cursor = state.focus_cursor
  state.focus_cursor = cursor or outside_cursor
  return previous_cursor
end

local function open_on_focused_command(buf, open, buffers, win, cursor, previous_cursor)
  if vim.api.nvim_get_mode().mode ~= "nt" or vim.api.nvim_get_current_buf() ~= buf then
    return
  end
  local state = helpers.ensure_buffer_state(api.buffers, buf)
  if state.editor_opening or has_open_editor(buffers, buf) then
    return
  end
  local prompt_start, prompt_end = api.prompt_range(buf)
  local on_editable_zone = editable_zone.contains(buf, cursor)
    or cursor_is_on_prompt(cursor, prompt_start, prompt_end)
  local was_on_editable_zone = previous_cursor
    and (
      editable_zone.contains(buf, previous_cursor)
      or cursor_is_on_prompt(previous_cursor, prompt_start, prompt_end)
    )
  if not previous_cursor or was_on_editable_zone or not on_editable_zone then
    return
  end
  state.editor_opening = true
  local ok, opened = pcall(open, {
    target_buf = buf,
    target_win = win,
    cursor = api.cursor_index_in_command(win, buf),
  })
  state.editor_opening = nil
  if not ok then
    error(opened)
  end
end

---Open the popup when terminal focus lands on the editable command.
---@param buf integer Terminal buffer receiving the autocmds.
---@param open function Callback that opens the editor for `buf`.
---@param buffers table? Open popup editor buffers keyed by edit buffer.
function M.register(buf, open, buffers)
  local group = vim.api.nvim_create_augroup("termio-popup-focus-" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("CmdlineEnter", {
    group = group,
    buffer = buf,
    callback = function()
      local cmdtype = vim.fn.getcmdtype()
      if cmdtype == "/" or cmdtype == "?" then
        update_focus_cursor(buf)
      end
    end,
  })
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = group,
    buffer = buf,
    callback = function()
      local win = helpers.visible_window(buf)
      if win then
        local cursor = vim.api.nvim_win_get_cursor(win)
        local previous_cursor = update_focus_cursor(buf, cursor)
        open_on_focused_command(buf, open, buffers, win, cursor, previous_cursor)
      end
    end,
  })
  vim.api.nvim_create_autocmd("WinLeave", {
    group = group,
    buffer = buf,
    callback = function()
      local win = helpers.visible_window(buf)
      if win then
        update_focus_cursor(buf, vim.api.nvim_win_get_cursor(win))
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
end

return M
