local api = require("termio.api")
local M = {}

---Debounce editor state synchronization to a terminal buffer.
---@param edit_buf integer
---@param target_buf integer
---@param read_state fun(): { command: string, cursor: integer }
---@param delay_ms integer?
function M.register(edit_buf, target_buf, read_state, delay_ms)
  if delay_ms == nil then
    return
  end
  local generation = 0
  vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "CursorMoved", "CursorMovedI" }, {
    buffer = edit_buf,
    callback = function()
      generation = generation + 1
      local scheduled_generation = generation
      vim.defer_fn(function()
        if scheduled_generation ~= generation or not vim.api.nvim_buf_is_valid(edit_buf) then
          return
        end
        api.sync(read_state(), target_buf)
      end, delay_ms)
    end,
  })
end

return M
