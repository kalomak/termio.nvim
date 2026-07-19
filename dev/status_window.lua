local M = {}
local state = {}
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local status = dofile(root .. "/dev/status.lua")
local buffer_events = {
  CursorMoved = true,
  CursorMovedI = true,
  TermRequest = true,
  TextChanged = true,
  TextChangedI = true,
}

local function render()
  if state.rendering then
    return
  end
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  state.rendering = true
  local ok, err = pcall(function()
    local lines = status.snapshot_lines()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
      vim.api.nvim_win_set_height(state.win, #lines)
    end
    vim.bo[state.buf].modifiable = true
    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    vim.bo[state.buf].modifiable = false
  end)
  state.rendering = false
  if not ok then
    error(err)
  end
end

local function request_render(args)
  if args and args.buf and args.buf == state.buf then
    return
  end
  if args and buffer_events[args.event] and args.buf then
    local terminal = _G.termio_debug and _G.termio_debug.terminal or {}
    local is_editor = vim.api.nvim_buf_is_valid(args.buf) and vim.b[args.buf].termio_editor
    if args.buf ~= terminal.buf and not is_editor then
      return
    end
  end
  if state.render_pending then
    return
  end
  state.render_pending = true
  vim.schedule(function()
    state.render_pending = false
    render()
  end)
end

local function open_window()
  local current_win = vim.api.nvim_get_current_win()
  vim.cmd("botright new")
  state.win = vim.api.nvim_get_current_win()
  state.buf = vim.api.nvim_get_current_buf()
  vim.bo[state.buf].buftype = "nofile"
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].swapfile = false
  vim.bo[state.buf].modifiable = false
  vim.wo[state.win].number = false
  vim.wo[state.win].relativenumber = false
  vim.wo[state.win].signcolumn = "no"
  vim.wo[state.win].wrap = false
  vim.wo[state.win].winfixheight = true
  vim.api.nvim_buf_set_name(state.buf, "termio://status")
  vim.api.nvim_set_current_win(current_win)
end

function M.setup()
  status.setup()
  open_window()
  vim.keymap.set("n", "<Leader>s", function()
    status.copy_and_dump()
  end, { desc = "Copy termio status" })
  local group = vim.api.nvim_create_augroup("termio-dev-status", { clear = true })
  vim.api.nvim_create_autocmd({
    "BufEnter",
    "CursorMoved",
    "CursorMovedI",
    "ModeChanged",
    "TermClose",
    "TermOpen",
    "TermRequest",
    "TextChanged",
    "TextChangedI",
    "WinEnter",
  }, {
    group = group,
    callback = request_render,
  })
  render()
end

return M
