local api = require("termio.api")
local autoresize = require("termio.editors.autoresize")
local popup = require("termio.editors.popup")
local config = require("termio.config")
local M = popup.new({
  buffers = {},
  toggle = function()
    require("termio").toggle()
  end,
})

local function popup_options()
  return config.options.editor.popup
end

local function max_float_height(row)
  return math.max(1, vim.o.lines - row - vim.o.cmdheight)
end

local function command_screen_row(target_win, target_buf)
  local command_start = api.get_cache(target_buf).command_start
  local pos = vim.fn.screenpos(target_win, command_start[1], command_start[2] + 1)
  return math.max(pos.row - 1, 0)
end

local function popup_config(target_win, target_buf, lines)
  local win_row, col = unpack(vim.api.nvim_win_get_position(target_win))
  local row = win_row + command_screen_row(target_win, target_buf)
  local width = vim.api.nvim_win_get_width(target_win)
  local style = popup_options().style
  return {
    relative = "editor",
    style = style.window or "minimal",
    border = style.border or "none",
    width = width,
    height = autoresize.height_for_lines(lines, width, max_float_height(row)),
    row = row,
    col = col,
  }
end

local function set_editor_options(edit_buf, edit_win)
  vim.bo[edit_buf].modifiable = true
  vim.bo[edit_buf].swapfile = false
  vim.bo[edit_buf].textwidth = 0
  vim.bo[edit_buf].autoindent = false
  vim.bo[edit_buf].smartindent = false
  vim.bo[edit_buf].cindent = false
  vim.bo[edit_buf].formatoptions = vim.bo[edit_buf].formatoptions:gsub("[tca]", "")
  vim.wo[edit_win].wrap = true
end

function M:create_editor_window(ctx, data)
  local edit_buf = self:create_buffer(data)
  local edit_win =
    vim.api.nvim_open_win(edit_buf, true, popup_config(ctx.target_win, ctx.target_buf, data.lines))
  set_editor_options(edit_buf, edit_win)
  return edit_buf, edit_win
end

function M:max_height(_, edit_win)
  return max_float_height(vim.api.nvim_win_get_config(edit_win).row)
end

function M.setup()
  M:setup_terminal_open("termio-overlay")
end

return M
