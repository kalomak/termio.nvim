local api = require("termio.api")
local terminal_buffer = require("termio.terminal_buffer")

local M = {}

---Return the editable command zone in the terminal buffer.
---@param buf? integer
---@return { start_row: integer, start_col: integer, end_row: integer, end_col: integer }?
function M.get(buf)
  local target = buf or vim.api.nvim_get_current_buf()
  local cursor = api.get_cache(target).command_start
  if not cursor then
    return nil
  end
  local start_row, start_col = unpack(cursor)
  local command = terminal_buffer.command_text(target, cursor, true)
  local end_cursor = terminal_buffer.location_from_offset(target, cursor, #command)
  return {
    start_row = start_row,
    start_col = start_col,
    end_row = end_cursor[1],
    end_col = end_cursor[2],
  }
end

---Normalize Vim's cursor form for a command ending at the terminal wrap edge.
---@param buf integer
---@param cursor integer[] 1-based row, 0-based column
---@param zone? { start_row: integer, start_col: integer, end_row: integer, end_col: integer }
---@return integer[] cursor
function M.canonicalize_cursor_at_wrapped_command_end(buf, cursor, zone)
  zone = zone or M.get(buf)
  if not zone or cursor[2] ~= 0 or cursor[1] ~= zone.end_row + 1 then
    return cursor
  end
  local end_line = vim.api.nvim_buf_get_lines(buf, zone.end_row - 1, zone.end_row, false)[1] or ""
  if zone.end_col == #end_line then
    return { zone.end_row, zone.end_col }
  end
  return cursor
end

---Check if a cursor is inside the editable command zone.
---@param buf? integer
---@param cursor? integer[] 1-based row, 0-based column
---@return boolean
function M.contains(buf, cursor)
  local target = buf or vim.api.nvim_get_current_buf()
  local zone = M.get(target)
  if not zone then
    return false
  end
  local row, col = unpack(
    M.canonicalize_cursor_at_wrapped_command_end(
      target,
      cursor or vim.api.nvim_win_get_cursor(0),
      zone
    )
  )
  if row < zone.start_row or row > zone.end_row then
    return false
  end
  if row == zone.start_row and col < zone.start_col then
    return false
  end
  return row ~= zone.end_row or col <= zone.end_col
end

return M
