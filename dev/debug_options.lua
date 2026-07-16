local M = {}

function M.build()
  local options = {
    debug = vim.env.TERMIO_DEBUG == "1",
    editor = {
      type = vim.env.TERMIO_EDITOR or "integrated",
    },
  }
  return options
end

return M
