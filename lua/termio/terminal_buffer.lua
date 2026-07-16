local M = {}

---Read terminal rows after a command start cursor.
---@param buf integer
---@param start_cursor integer[]
---@param stop_at_blank? boolean
---@return string[]
function M.command_rows(buf, start_cursor, stop_at_blank)
  local row, start_col = unpack(start_cursor)
  local rows = {}
  for index = row, vim.api.nvim_buf_line_count(buf) do
    local line = vim.api.nvim_buf_get_lines(buf, index - 1, index, false)[1] or ""
    if stop_at_blank and line == "" then
      break
    end
    if index == row then
      line = line:sub(start_col + 1)
    end
    rows[#rows + 1] = line
  end
  return rows
end

---Read command text after a start cursor.
---@param buf integer
---@param start_cursor integer[]
---@param stop_at_blank? boolean
---@return string
function M.command_text(buf, start_cursor, stop_at_blank)
  return table.concat(M.command_rows(buf, start_cursor, stop_at_blank), "")
end

---Convert a command-relative byte offset to a buffer cursor.
---@param buf integer
---@param start_cursor integer[]
---@param offset integer
---@return integer[]
function M.location_from_offset(buf, start_cursor, offset)
  local row, col = unpack(start_cursor)
  col = col + offset
  while row < vim.api.nvim_buf_line_count(buf) do
    local line = vim.api.nvim_buf_get_lines(buf, row - 1, row, false)[1] or ""
    if col <= #line then
      return { row, col }
    end
    col = col - #line
    row = row + 1
  end
  return { row, col }
end

return M
