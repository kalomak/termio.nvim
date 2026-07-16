local api = require("termio.api")
local autoresize = require("termio.editors.autoresize")
local config = require("termio.config")
local fixbuf = require("termio.editors.fixbuf")
local helpers = require("termio.util.helpers")
local keymaps = require("termio.util.keymaps")
local terminal_buffer = require("termio.terminal_buffer")

local M = {}

function M.new(opts)
  return setmetatable(opts or {}, { __index = M })
end

function M:build_context(ctx)
  ctx = ctx or {}
  ctx.target_buf = ctx.target_buf or vim.api.nvim_get_current_buf()
  ctx.target_win = ctx.target_win or vim.fn.bufwinid(ctx.target_buf)
  return ctx
end

function M.apply_window_style(win)
  local style = config.options.editor.popup.style
  if style.winhighlight then
    vim.wo[win].winhighlight = style.winhighlight
  end
end

function M.feed_key(key, mode)
  vim.api.nvim_feedkeys(helpers.term_codes(key), mode, false)
end

---@param ctx table
---@param command CommandState
---@return table
function M:prepare_data(ctx, command)
  local prompt = api.get_cache(ctx.target_buf).prompt
  ctx.original_command = command.text
  return {
    prompt = prompt,
    command = command,
    cursor = ctx.cursor or command.cursor,
    lines = vim.split(prompt .. command.text, "\n", { plain = true }),
  }
end

function M.prompt_start_cursor(buf)
  return { 1, #vim.fn.prompt_getprompt(buf) }
end

function M.command_text(buf)
  return table.concat(terminal_buffer.command_rows(buf, M.prompt_start_cursor(buf)), "\n")
end

function M.normal_cursor_offset(command, cursor)
  return math.min(cursor or #command, math.max(#command - 1, 0))
end

function M.set_initial_cursor(edit_buf, edit_win, command, cursor)
  vim.api.nvim_win_set_cursor(
    edit_win,
    terminal_buffer.location_from_offset(
      edit_buf,
      M.prompt_start_cursor(edit_buf),
      M.normal_cursor_offset(command, cursor)
    )
  )
end

function M.clear(edit_buf, edit_win)
  local start_cursor = M.prompt_start_cursor(edit_buf)
  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, { vim.fn.prompt_getprompt(edit_buf) })
  vim.api.nvim_win_set_cursor(edit_win, start_cursor)
end

local function clamp_prompt_buffer_cursor(edit_buf)
  local prompt = vim.fn.prompt_getprompt(edit_buf)
  local cursor = vim.api.nvim_win_get_cursor(0)
  if cursor[1] == 1 and cursor[2] < #prompt then
    vim.api.nvim_win_set_cursor(0, { 1, #prompt })
  end
end

local function register_cursor_clamp(edit_buf)
  vim.api.nvim_create_autocmd("CursorMoved", {
    group = vim.api.nvim_create_augroup("termio-popup-prompt-" .. edit_buf, { clear = true }),
    buffer = edit_buf,
    callback = function()
      clamp_prompt_buffer_cursor(edit_buf)
    end,
  })
end

function M.focus_target(ctx)
  if vim.api.nvim_win_is_valid(ctx.target_win) then
    vim.api.nvim_set_current_win(ctx.target_win)
  end
end

function M.close(buffers, edit_buf, ctx, edit_win)
  ctx = ctx or buffers[edit_buf]
  if not ctx then
    return
  end
  edit_win = edit_win or ctx.edit_win
  if vim.api.nvim_win_is_valid(edit_win) then
    vim.api.nvim_win_close(edit_win, true)
  end
  M.focus_target(ctx)
  buffers[edit_buf] = nil
end

local function finish(buffers, edit_buf, ctx, edit_win, command, submit)
  M.close(buffers, edit_buf, ctx, edit_win)
  api.write(command, ctx.target_buf)
  if submit then
    api.send(api.get_cache(ctx.target_buf), "\r")
  end
end

function M.action_handlers(opts)
  local function save(submit)
    finish(
      opts.buffers,
      opts.edit_buf,
      opts.ctx,
      opts.edit_win,
      M.command_text(opts.edit_buf),
      submit
    )
  end
  local function pass_through(key, mode)
    save(false)
    vim.cmd.startinsert()
    M.feed_key(key, mode)
  end
  return {
    submit = function()
      save(true)
      vim.cmd.startinsert()
    end,
    clear = function()
      M.clear(opts.edit_buf, opts.edit_win)
    end,
    write = function()
      save(false)
    end,
    save_and_close = function()
      save(false)
    end,
    close = function()
      finish(opts.buffers, opts.edit_buf, opts.ctx, opts.edit_win, opts.ctx.original_command)
      vim.cmd.startinsert()
    end,
    toggle = opts.toggle,
    pass_through_insert = function(key)
      pass_through(key, "t")
    end,
    pass_through_normal = function(key)
      pass_through(key, "n")
    end,
    down = function()
      vim.cmd("normal! gj")
    end,
    up = function()
      vim.cmd("normal! gk")
    end,
  }
end

function M:handlers(ctx, edit_buf, edit_win)
  return M.action_handlers({
    buffers = self.buffers,
    ctx = ctx,
    edit_buf = edit_buf,
    edit_win = edit_win,
    toggle = function()
      self.toggle()
    end,
  })
end

---Create a prompt editor buffer.
---@param data table
---@return integer
function M:create_buffer(data)
  local edit_buf = vim.api.nvim_create_buf(false, true)
  vim.bo[edit_buf].buftype = "prompt"
  vim.bo[edit_buf].bufhidden = "wipe"
  vim.bo[edit_buf].filetype = config.options.editor.filetype
  vim.b[edit_buf].termio_editor = config.options.editor.type
  vim.b[edit_buf].termio_fixed_editor = true
  vim.fn.prompt_setprompt(edit_buf, data.prompt)
  vim.api.nvim_buf_set_lines(edit_buf, 0, -1, false, data.lines)
  vim.bo[edit_buf].modified = false
  return edit_buf
end

---@param ctx? table
---@return boolean opened
function M:open(ctx)
  ctx = self:build_context(ctx)
  if helpers.is_editor_disabled(ctx.target_buf) then
    return false
  end
  api.read(function(command)
    vim.cmd.stopinsert()
    local data = self:prepare_data(ctx, command)
    local edit_buf, edit_win = self:create_editor_window(ctx, data)
    M.apply_window_style(edit_win)
    M.set_initial_cursor(edit_buf, edit_win, command.text, data.cursor)
    self:register({
      edit_buf = edit_buf,
      edit_win = edit_win,
      ctx = ctx,
      max_height = self:max_height(ctx, edit_win),
    })
    if self.after_open then
      self:after_open(ctx, edit_buf, edit_win)
    end
  end)
  return true
end

function M.register_buffer(opts)
  opts.buffers[opts.edit_buf] = vim.tbl_extend("force", opts.ctx, { edit_win = opts.edit_win })
  opts.buffers[opts.edit_buf].keymaps = M.apply_keymaps(opts.edit_buf, opts.handlers)
  autoresize.register(opts.edit_buf, opts.edit_win, opts.max_height)
  fixbuf.register(opts.edit_buf, opts.edit_win, opts.ctx.target_win)
  register_cursor_clamp(opts.edit_buf)
  vim.api.nvim_create_autocmd("BufWipeout", {
    buffer = opts.edit_buf,
    callback = function()
      opts.buffers[opts.edit_buf] = nil
    end,
  })
end

function M:register(opts)
  opts.buffers = self.buffers
  opts.handlers = self:handlers(opts.ctx, opts.edit_buf, opts.edit_win)
  M.register_buffer(opts)
end

local function map_editor_keys(group, handlers)
  for _, source in ipairs({ config.options.editor.keys, config.options.editor.popup.keys }) do
    for mode, mappings in pairs(source or {}) do
      for lhs, action in pairs(type(mappings) == "table" and mappings or {}) do
        if type(action) == "string" and action ~= "open" then
          local handler = assert(handlers[action], "termio: unknown popup key action: " .. action)
          group:map(mode, lhs, function()
            handler(lhs)
          end)
        end
      end
    end
  end
end

local function map_pass_through_keys(group, handlers)
  local options = config.options.editor.popup
  for _, key in ipairs(options.pass_through_insert_keys or {}) do
    group:map("i", key, function()
      handlers.pass_through_insert(key)
    end)
  end
  for _, key in ipairs(options.pass_through_normal_keys or {}) do
    group:map("n", key, function()
      handlers.pass_through_normal(key)
    end)
  end
end

function M.apply_keymaps(edit_buf, handlers)
  local group = keymaps.group({ buffer = edit_buf })
  map_editor_keys(group, handlers)
  map_pass_through_keys(group, handlers)
  return group
end

function M.register_terminal_open(name, open)
  local group = vim.api.nvim_create_augroup(name, { clear = true })
  vim.api.nvim_create_autocmd("TermOpen", {
    group = group,
    callback = function(args)
      if helpers.is_enabled_terminal(args.buf) then
        local maps = keymaps.group({ buffer = args.buf })
        maps:map("t", config.options.editor.open, function()
          open({ target_buf = args.buf, target_win = vim.fn.bufwinid(args.buf) })
        end)
      end
    end,
  })
end

function M:setup_terminal_open(name)
  M.register_terminal_open(name, function(ctx)
    return self:open(ctx)
  end)
end

return M
