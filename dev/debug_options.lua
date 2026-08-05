local M = {}

function M.build()
  local log_level = (vim.env.TERMIO_LOG_LEVEL or "debug"):upper()
  local options = {
    log_level = assert(vim.log.levels[log_level]),
    prompt_patterns = { [[^>>> ]], [[^\.\.\. ]], [[^[›»] ]] },
    read_replace_patterns = { { [[^%s*gpt%-%d+%.%d+.*$]], "" } },
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
