local M = {}
local state = {}
local default_log_path = vim.fs.joinpath(vim.fn.stdpath("log"), "termio.log")

local function stop_following()
  if state.timer then
    state.timer:stop()
    state.timer:close()
    state.timer = nil
  end
end

local function follow_output()
  if
    not (
      state.win
      and vim.api.nvim_win_is_valid(state.win)
      and state.buf
      and vim.api.nvim_buf_is_valid(state.buf)
    )
  then
    stop_following()
    return
  end
  vim.api.nvim_win_set_cursor(state.win, { vim.api.nvim_buf_line_count(state.buf), 0 })
end

local function start_following()
  stop_following()
  state.timer = assert(vim.uv.new_timer())
  state.timer:start(0, 100, vim.schedule_wrap(follow_output))
  vim.api.nvim_create_autocmd("VimLeavePre", {
    group = vim.api.nvim_create_augroup("termio-dev-log-window", { clear = true }),
    callback = stop_following,
  })
end

---Focus the dev log window.
function M.focus()
  vim.api.nvim_set_current_win(assert(state.win, "termio dev: log window is not open"))
end

---Open the dev log in a right-side window.
---@param log_path? string
---@return integer window
function M.setup(log_path)
  log_path = log_path or default_log_path
  local current_win = vim.api.nvim_get_current_win()
  if vim.fn.filereadable(log_path) == 0 then
    vim.fn.writefile({}, log_path)
  end
  vim.cmd("botright vnew")
  state.win = vim.api.nvim_get_current_win()
  state.buf = vim.api.nvim_get_current_buf()
  assert(
    vim.fn.jobstart({ "tail", "-n", "100", "-f", log_path }, { term = true }) > 0,
    "termio dev: failed to tail log"
  )
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].swapfile = false
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"
  vim.wo[state.win].wrap = false
  vim.wo[state.win].winfixwidth = true
  start_following()
  vim.api.nvim_set_current_win(current_win)
  return state.win
end

return M
