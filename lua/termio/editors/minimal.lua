local api = require("termio.api")
local config = require("termio.config")
local helpers = require("termio.util.helpers")

local M = {}

---Convert a command byte offset to an editor cursor position.
---@param cache TerminalBufferCache
---@param offset integer
---@return integer[]
function M.editor_cursor(cache, offset)
  local lines = vim.api.nvim_buf_get_lines(cache.edit_buf, 0, -1, false)
  local remaining = #cache.prompt + offset
  for row, line in ipairs(lines) do
    if remaining <= #line then
      return { row, remaining }
    end
    remaining = remaining - #line - 1
  end
  return { #lines, #lines[#lines] }
end

---@param cache TerminalBufferCache
---@return string
function M.editor_command(cache)
  local lines = vim.api.nvim_buf_get_lines(cache.edit_buf, 0, -1, false)
  lines[1] = lines[1]:sub(#cache.prompt + 1)
  return table.concat(lines, "\n")
end

---@param cache TerminalBufferCache
function M.close(cache)
  vim.api.nvim_win_close(cache.edit_win, true)
  vim.api.nvim_set_current_win(cache.target_win)
  vim.cmd.startinsert()
end

---@param cache TerminalBufferCache
---@param submit boolean
function M.write_and_close(cache, submit)
  local command = M.editor_command(cache)
  M.close(cache)
  api.write(command)
  if submit then
    api.send(cache, "\r")
  end
end

---@param cache TerminalBufferCache
function M.cancel(cache)
  M.close(cache)
  api.write(cache.command.text)
end

---@param cache TerminalBufferCache
function M.set_editor_keymaps(cache)
  local opts = { buffer = cache.edit_buf, nowait = true }
  vim.keymap.set("n", "<Esc>", function()
    M.write_and_close(cache, false)
  end, opts)
  vim.keymap.set("n", "q", function()
    M.cancel(cache)
  end, opts)
  vim.keymap.set({ "n", "i" }, "<CR>", function()
    M.write_and_close(cache, true)
  end, opts)
end

---@param cache TerminalBufferCache
---@return table
function M.float_config(cache)
  local target_width = vim.api.nvim_win_get_width(cache.target_win)
  local target_height = vim.api.nvim_win_get_height(cache.target_win)
  local width = math.min(math.max(20, math.floor(target_width * 0.7)), target_width)
  local height =
    math.min(math.max(1, math.ceil(math.max(#cache.command.text, 1) / width)), target_height)
  return {
    relative = "win",
    win = cache.target_win,
    width = width,
    height = height,
    row = math.floor((target_height - height) / 2),
    col = math.floor((target_width - width) / 2),
    style = "minimal",
    border = "rounded",
  }
end

---@param cache TerminalBufferCache
function M.open_editor_window(cache)
  local edit_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[edit_buf].buftype = "prompt"
  vim.bo[edit_buf].bufhidden = "wipe"
  vim.bo[edit_buf].filetype = config.options.editor.filetype
  vim.b[edit_buf].termio_editor = "minimal"
  vim.fn.prompt_setprompt(edit_buf, cache.prompt)
  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, { cache.prompt .. cache.command.text })
  local edit_win = vim.api.nvim_open_win(edit_buf, true, M.float_config(cache))
  cache.edit_buf, cache.edit_win = edit_buf, edit_win
  M.set_editor_keymaps(cache)
  local normal_offset = math.min(cache.command.cursor, math.max(#cache.command.text - 1, 0))
  vim.api.nvim_win_set_cursor(edit_win, M.editor_cursor(cache, normal_offset))
end

---Read the current command and open it in the minimal editor.
---@return boolean opened
function M.open()
  local buf = vim.api.nvim_get_current_buf()
  if helpers.is_editor_disabled(buf) then
    return false
  end
  local cache = api.get_cache(buf)
  api.read(function()
    vim.cmd.stopinsert()
    M.open_editor_window(cache)
  end)
  return true
end

---@param buf integer
function M.attach(buf)
  if not helpers.is_enabled_terminal(buf) then
    return
  end
  vim.keymap.set("t", config.options.editor.open, function()
    if not M.open() then
      vim.api.nvim_feedkeys(helpers.term_codes(config.options.editor.open), "n", false)
    end
  end, { buffer = buf })
end

function M.setup()
  local group = vim.api.nvim_create_augroup("termio-minimal", { clear = true })
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(args)
      M.attach(args.buf)
    end,
  })
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.bo[buf].buftype == "terminal" then
      M.attach(buf)
    end
  end
end

return M
