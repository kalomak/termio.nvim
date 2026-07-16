-- Simple terminal read / write API + bundled popup editor
-- Open:
--  - read terminal state (cursor, text from last prompt)
--  - s

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
---@field edit_buf? integer
---@field edit_win? integer

local M = {
  options = {
    filetype = "bash",
    key = "<Esc>",
    poll_ms = 1,
    timeout_ms = 50,
  },
}
M.terminals = {}

-- Utilities

---Get or create state for a terminal buffer.
---@param buf integer
---@return TerminalBufferCache
M.get_cache = function(buf)
  M.terminals[buf] = M.terminals[buf] or { target_buf = buf, command = {} }
  return M.terminals[buf]
end

---@param tbufcache TerminalBufferCache
M.send = function(tbufcache, bytes)
  vim.api.nvim_chan_send(vim.bo[tbufcache.target_buf].channel, bytes)
end

---Convert Neovim's terminal cursor to the shell insertion position at line end.
---@param tbufcache TerminalBufferCache
---@param position integer[]
---@return integer[]
M.shell_cursor = function(tbufcache, position)
  local cursor = { position[1], position[2] }
  local line = vim.api.nvim_buf_get_lines(tbufcache.target_buf, cursor[1] - 1, cursor[1], false)[1]
  if cursor[2] == #line - 1 then
    cursor[2] = #line
  end
  return cursor
end

M.text_between = function(lines, first, last)
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
M.command_offset = function(lines, start, cursor)
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
---@param tbufcache TerminalBufferCache
---@param lines string[]
---@param command_start integer[]
---@param command_end integer[]
---@param original_cursor integer[]
M.infer_parts = function(tbufcache, lines, command_start, command_end, original_cursor)
  local first = { 1, command_start[2] }
  local last = { command_end[1] - command_start[1] + 1, command_end[2] }
  local cursor = { original_cursor[1] - command_start[1] + 1, original_cursor[2] }
  tbufcache.prompt = lines[1]:sub(1, first[2])
  tbufcache.prompt_row = command_start[1]
  tbufcache.command.text = M.text_between(lines, first, last)
  tbufcache.command.cursor = M.command_offset(lines, first, cursor)
  tbufcache.command.cursor = math.min(tbufcache.command.cursor, #tbufcache.command.text)
end

---@class TerminalState
---@field lines string[]
---@field cursor integer[]
---@field first_row integer

---Read terminal lines from the cached prompt through the buffer end.
---@param tbufcache TerminalBufferCache
---@return TerminalState
M.read_terminal_state = function(tbufcache)
  local cursor = vim.api.nvim_win_get_cursor(tbufcache.target_win)
  local first_row = tbufcache.prompt_row
  if not first_row or first_row > cursor[1] then
    first_row = 1
  end
  return {
    lines = vim.api.nvim_buf_get_lines(tbufcache.target_buf, first_row - 1, -1, false),
    cursor = cursor,
    first_row = first_row,
  }
end

---@class TerminalChange
---@field text? string
---@field cursor? integer[]

M.poll = function(tbufcache, callback, expected, previous, started)
  local terminal = M.read_terminal_state(tbufcache)
  local command = {
    text = table.concat(terminal.lines, "\n"),
    cursor = terminal.cursor,
  }
  tbufcache.terminal_cursor = command.cursor
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
      M.poll(tbufcache, callback, expected, previous, started)
    end, M.options.poll_ms)
  end
end

---Wait for the terminal state to change or time out.
---The timeout also continues with the latest state because unchanged can mean a completed shell action.
---@param callback fun()
---@param expected? TerminalChange
M.wait_for_terminal_change = function(tbufcache, callback, expected)
  local terminal = M.read_terminal_state(tbufcache)
  local previous = {
    text = table.concat(terminal.lines, "\n"),
    cursor = terminal.cursor,
  }
  local started = vim.uv.now()
  vim.defer_fn(function()
    M.poll(tbufcache, callback, expected, previous, started)
  end, M.options.poll_ms)
end

-- API

---Read the current terminal's command and cursor.
---@param callback fun(command: CommandState)
M.read = function(callback)
  local tbufcache = M.get_cache(vim.api.nvim_get_current_buf())
  tbufcache.target_win = vim.api.nvim_get_current_win()
  local terminal = M.read_terminal_state(tbufcache)
  tbufcache.terminal_cursor = terminal.cursor
  local original_cursor = M.shell_cursor(tbufcache, terminal.cursor)
  tbufcache.original_cursor = original_cursor
  M.send(tbufcache, "\5") -- C-e
  M.wait_for_terminal_change(tbufcache, function()
    local command_end = M.shell_cursor(tbufcache, tbufcache.terminal_cursor)
    tbufcache.command_end = command_end
    M.send(tbufcache, "\21") -- C-u
    M.wait_for_terminal_change(tbufcache, function()
      local command_start = M.shell_cursor(tbufcache, tbufcache.terminal_cursor)
      tbufcache.command_start = command_start
      local first = command_start[1] - terminal.first_row + 1
      local last = command_end[1] - terminal.first_row + 1
      local command_lines = vim.list_slice(terminal.lines, first, last)
      M.infer_parts(tbufcache, command_lines, command_start, command_end, original_cursor)
      callback(tbufcache.command)
    end)
  end)
end

---Write a command into the cleared shell input.
---@param command string
M.write = function(command)
  local tbufcache = M.get_cache(vim.api.nvim_get_current_buf())
  M.send(tbufcache, "\27[200~" .. command .. "\27[201~")
end

---Setup the terminal buffer
---@param buf integer
M.attach = function(buf)
  M.get_cache(buf)
  vim.keymap.set("t", M.options.key, M.open, { buffer = buf })
end

---Set up the standalone experiment without loading termio.
---@param opts? table
M.setup = function(opts)
  M.options = vim.tbl_extend("force", M.options, opts or {})
  local group = vim.api.nvim_create_augroup("termio-standalone-popup", { clear = true })
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(args)
      M.attach(args.buf)
    end,
  })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    callback = function(args)
      M.terminals[args.buf] = nil
    end,
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" then
      M.attach(buf)
    end
  end
  return M
end

-- Editor

---Convert a command byte offset to an editor cursor position.
---@param tbufcache TerminalBufferCache
---@param offset integer
---@return integer[] cursor
M.editor_cursor = function(tbufcache, offset)
  local lines = vim.api.nvim_buf_get_lines(tbufcache.edit_buf, 0, -1, false)
  local remaining = #tbufcache.prompt + offset
  for row, line in ipairs(lines) do
    if remaining <= #line then
      return { row, remaining }
    end
    remaining = remaining - #line - 1
  end
  return { #lines, #lines[#lines] }
end

M.editor_command = function(tbufcache)
  local lines = vim.api.nvim_buf_get_lines(tbufcache.edit_buf, 0, -1, false)
  lines[1] = lines[1]:sub(#tbufcache.prompt + 1)
  return table.concat(lines, "\n")
end

M.close = function(tbufcache)
  vim.api.nvim_win_close(tbufcache.edit_win, true)
  vim.api.nvim_set_current_win(tbufcache.target_win)
  vim.cmd.startinsert()
end

M.write_and_close = function(tbufcache, submit)
  local command = M.editor_command(tbufcache)
  M.close(tbufcache)
  M.write(command)
  if submit then
    M.send(tbufcache, "\r")
  end
end

M.cancel = function(tbufcache)
  M.close(tbufcache)
  M.write(tbufcache.command.text)
end

M.set_editor_keymaps = function(tbufcache)
  local opts = { buffer = tbufcache.edit_buf, nowait = true }
  vim.keymap.set("n", "<Esc>", function()
    M.write_and_close(tbufcache, false)
  end, opts)
  vim.keymap.set("n", "q", function()
    M.cancel(tbufcache)
  end, opts)
  vim.keymap.set({ "n", "i" }, "<CR>", function()
    M.write_and_close(tbufcache, true)
  end, opts)
end

M.float_config = function(tbufcache)
  local target_width = vim.api.nvim_win_get_width(tbufcache.target_win)
  local target_height = vim.api.nvim_win_get_height(tbufcache.target_win)
  local width = math.min(math.max(20, math.floor(target_width * 0.7)), target_width)
  local height =
    math.min(math.max(1, math.ceil(math.max(#tbufcache.command.text, 1) / width)), target_height)
  return {
    relative = "win",
    win = tbufcache.target_win,
    width = width,
    height = height,
    row = math.floor((target_height - height) / 2),
    col = math.floor((target_width - width) / 2),
    style = "minimal",
    border = "rounded",
  }
end

M.open_editor_window = function(tbufcache)
  local edit_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[edit_buf].buftype = "prompt"
  vim.bo[edit_buf].bufhidden = "wipe"
  vim.bo[edit_buf].filetype = M.options.filetype
  vim.fn.prompt_setprompt(edit_buf, tbufcache.prompt)
  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, { tbufcache.prompt .. tbufcache.command.text })
  local edit_win = vim.api.nvim_open_win(edit_buf, true, M.float_config(tbufcache))
  tbufcache.edit_buf, tbufcache.edit_win = edit_buf, edit_win
  M.set_editor_keymaps(tbufcache)
  local normal_offset = math.min(tbufcache.command.cursor, math.max(#tbufcache.command.text - 1, 0))
  vim.api.nvim_win_set_cursor(edit_win, M.editor_cursor(tbufcache, normal_offset))
end

---Read the current command and open it in the popup editor.
M.open = function()
  local tbufcache = M.get_cache(vim.api.nvim_get_current_buf())
  M.read(function()
    vim.cmd.stopinsert()
    M.open_editor_window(tbufcache)
  end)
end

return M
