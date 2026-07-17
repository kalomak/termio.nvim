local helpers = require("termio.util.helpers")

local M = { kind = "fish" }

---@param payload string
---@return boolean
function M.matches(payload)
  return payload == "fish"
end

---@param buf integer
function M.clear_completion_suggestions(buf)
  helpers.send_bytes("\27[27;5;67~", buf)
end

---@param buf integer
function M.read_state(buf)
  helpers.send_bytes("\27[27;5;82~", buf)
end

function M.redraw_after_pty_write() end

return M
