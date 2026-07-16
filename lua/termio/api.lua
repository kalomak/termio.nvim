---@class CommandState
---@field text? string
---@field cursor? integer

---@class TerminalBufferCache
---@field target_buf integer
---@field target_win? integer
---@field prompt? string
---@field prompt_row? integer
---@field command CommandState
---@field terminal_cursor? integer[]
---@field original_cursor? integer[]
---@field command_start? integer[]
---@field command_end? integer[]

local M = {
  options = {
    poll_ms = 1,
    timeout_ms = 50,
  },
  terminals = {},
}

---Get or create state for a terminal buffer.
---@param buf integer
---@return TerminalBufferCache
function M.get_cache(buf)
  M.terminals[buf] = M.terminals[buf] or { target_buf = buf, command = {} }
  return M.terminals[buf]
end

---@param cache TerminalBufferCache
---@param bytes string
function M.send(cache, bytes)
  vim.api.nvim_chan_send(vim.bo[cache.target_buf].channel, bytes)
end

---Convert Neovim's terminal cursor to the shell insertion position at line end.
---@param cache TerminalBufferCache
---@param position integer[]
---@return integer[]
function M.shell_cursor(cache, position)
  local cursor = { position[1], position[2] }
  local line = vim.api.nvim_buf_get_lines(cache.target_buf, cursor[1] - 1, cursor[1], false)[1]
  if cursor[2] == #line - 1 then
    cursor[2] = #line
  end
  return cursor
end

---@param lines string[]
---@param first integer[]
---@param last integer[]
---@return string
function M.text_between(lines, first, last)
  if first[1] == last[1] then
    return lines[first[1]]:sub(first[2] + 1, last[2])
  end
  local parts = { lines[first[1]]:sub(first[2] + 1) }
  for row = first[1] + 1, last[1] - 1 do
    parts[#parts + 1] = lines[row]
  end
  parts[#parts + 1] = lines[last[1]]:sub(1, last[2])
  return table.concat(parts)
end

---Return a cursor's character offset from the command start.
---@param lines string[]
---@param start integer[]
---@param cursor integer[]
---@return integer
function M.command_offset(lines, start, cursor)
  if start[1] == cursor[1] then
    return cursor[2] - start[2]
  end
  local offset = #lines[start[1]] - start[2]
  for row = start[1] + 1, cursor[1] - 1 do
    offset = offset + #lines[row]
  end
  return offset + cursor[2]
end

---Cache the prompt and command state inferred from the probe cursors.
---@param cache TerminalBufferCache
---@param lines string[]
---@param command_start integer[]
---@param command_end integer[]
---@param original_cursor integer[]
function M.infer_parts(cache, lines, command_start, command_end, original_cursor)
  local first = { 1, command_start[2] }
  local last = { command_end[1] - command_start[1] + 1, command_end[2] }
  local cursor = { original_cursor[1] - command_start[1] + 1, original_cursor[2] }
  cache.prompt = lines[1]:sub(1, first[2])
  cache.prompt_row = command_start[1]
  cache.command.text = M.text_between(lines, first, last)
  cache.command.cursor = M.command_offset(lines, first, cursor)
  cache.command.cursor = math.min(cache.command.cursor, #cache.command.text)
end

---@class TerminalState
---@field lines string[]
---@field cursor integer[]
---@field first_row integer

---Read terminal lines from the cached prompt through the buffer end.
---@param cache TerminalBufferCache
---@return TerminalState
function M.read_terminal_state(cache)
  local cursor = vim.api.nvim_win_get_cursor(cache.target_win)
  local first_row = cache.prompt_row
  if not first_row or first_row > cursor[1] then
    first_row = 1
  end
  return {
    lines = vim.api.nvim_buf_get_lines(cache.target_buf, first_row - 1, -1, false),
    cursor = cursor,
    first_row = first_row,
  }
end

---@class TerminalChange
---@field text? string
---@field cursor? integer[]

---@param cache TerminalBufferCache
---@param callback fun()
---@param expected? TerminalChange
---@param previous table
---@param started integer
function M.poll(cache, callback, expected, previous, started)
  local terminal = M.read_terminal_state(cache)
  local command = { text = table.concat(terminal.lines, "\n"), cursor = terminal.cursor }
  cache.terminal_cursor = command.cursor
  local has_expected = expected and (expected.text ~= nil or expected.cursor ~= nil)
  local text_matches = not expected or expected.text == nil or command.text == expected.text
  local cursor_matches = not expected
    or expected.cursor == nil
    or vim.deep_equal(command.cursor, expected.cursor)
  local ready = has_expected and text_matches and cursor_matches
    or not has_expected and not vim.deep_equal(command, previous)
  if ready or vim.uv.now() - started >= M.options.timeout_ms then
    callback()
  else
    vim.defer_fn(function()
      M.poll(cache, callback, expected, previous, started)
    end, M.options.poll_ms)
  end
end

---Wait for the terminal state to change or time out.
---@param cache TerminalBufferCache
---@param callback fun()
---@param expected? TerminalChange
function M.wait_for_terminal_change(cache, callback, expected)
  local terminal = M.read_terminal_state(cache)
  local previous = { text = table.concat(terminal.lines, "\n"), cursor = terminal.cursor }
  local started = vim.uv.now()
  vim.defer_fn(function()
    M.poll(cache, callback, expected, previous, started)
  end, M.options.poll_ms)
end

---Read and clear the current terminal's command and cursor.
---@param callback fun(command: CommandState)
function M.read(callback)
  local cache = M.get_cache(vim.api.nvim_get_current_buf())
  cache.target_win = vim.api.nvim_get_current_win()
  local terminal = M.read_terminal_state(cache)
  cache.terminal_cursor = terminal.cursor
  local original_cursor = M.shell_cursor(cache, terminal.cursor)
  cache.original_cursor = original_cursor
  M.send(cache, "\5") -- C-e
  M.wait_for_terminal_change(cache, function()
    local command_end = M.shell_cursor(cache, cache.terminal_cursor)
    cache.command_end = command_end
    M.send(cache, "\21") -- C-u
    M.wait_for_terminal_change(cache, function()
      local command_start = M.shell_cursor(cache, cache.terminal_cursor)
      cache.command_start = command_start
      local first = command_start[1] - terminal.first_row + 1
      local last = command_end[1] - terminal.first_row + 1
      local command_lines = vim.list_slice(terminal.lines, first, last)
      M.infer_parts(cache, command_lines, command_start, command_end, original_cursor)
      callback(cache.command)
    end)
  end)
end

---Write a command into a cleared terminal input.
---@param command string
---@param buf? integer
function M.write(command, buf)
  local cache = M.get_cache(buf or vim.api.nvim_get_current_buf())
  M.send(cache, "\27[200~" .. command .. "\27[201~")
end

---Initialize API options and cache cleanup.
---@param opts? table
function M.setup(opts)
  M.options = vim.tbl_extend("force", M.options, opts or {})
  local group = vim.api.nvim_create_augroup("termio-api", { clear = true })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      M.terminals[args.buf] = nil
    end,
  })
end

return M
