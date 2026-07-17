local helpers = require("termio.util.helpers")

local M = { kind = "bash" }

---@param payload string
---@return boolean
function M.matches(payload)
  return payload == "bash"
end

function M.clear_completion_suggestions() end

---@param buf integer
function M.read_state(buf)
  helpers.send_bytes("\27[27;5;82~", buf)
end

-- Bash readline automatically clears stale cells with ESC[K after PTY writes.
function M.redraw_after_pty_write() end

return M
