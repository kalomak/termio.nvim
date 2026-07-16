local config = require("termio.config")
local state = require("termio.state")

local M = {}

---@param keys string
---@return string
function M.term_codes(keys)
  return vim.api.nvim_replace_termcodes(keys, true, false, true)
end

---@param buf integer
---@return boolean
function M.is_terminal_channel_open(buf)
  if vim.bo[buf].buftype ~= "terminal" then
    return false
  end
  local chan = vim.bo[buf].channel
  if not chan or chan == 0 then
    return false
  end
  local ok, info = pcall(vim.api.nvim_get_chan_info, chan)
  return ok and info.exitcode == -1
end

---@param buf integer
---@return boolean
function M.is_enabled_terminal(buf)
  if vim.bo[buf].buftype ~= "terminal" then
    return false
  end
  local pattern = config.options.editor.terminal_name_pattern
  if not pattern then
    return true
  end
  local ok, regex = pcall(vim.regex, pattern)
  if not ok then
    error("termio: invalid editor.terminal_name_pattern: " .. tostring(pattern))
  end
  return regex:match_str(vim.api.nvim_buf_get_name(buf)) ~= nil
end

---@param buf integer
---@return boolean
function M.is_editor_disabled(buf)
  if not state.is_enabled() then
    return true
  end
  if vim.bo[buf].buftype == "terminal" and not M.is_terminal_channel_open(buf) then
    return true
  end
  local is_disabled = config.options.editor.is_disabled
  if type(is_disabled) ~= "function" then
    error("termio: config.editor.is_disabled must be a function")
  end
  return is_disabled(buf) == true
end

return M
