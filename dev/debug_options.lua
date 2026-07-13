local M = {}

function M.build()
  local options = {
    debug = vim.env.TERMIO_DEBUG == "1",
    editor = {
      type = vim.env.TERMIO_EDITOR or "integrated",
      popup = {
        open_on_focus = vim.env.TERMIO_OPEN_ON_FOCUS == "1",
      },
    },
  }
  if vim.env.TERMIO_BACKEND and vim.env.TERMIO_BACKEND ~= "" then
    options.backend = vim.env.TERMIO_BACKEND
  end
  return options
end

return M
