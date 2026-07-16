local api = require("termio.api")
local config = require("termio.config")
local helpers = require("termio.util.helpers")
local keymaps = require("termio.util.keymaps")
local terminal_buffer = require("termio.terminal_buffer")

local M = { buffers = {} }

local function build_context(ctx)
  ctx = ctx or {}
  local target_buf = ctx.target_buf or vim.api.nvim_get_current_buf()
  return {
    target_buf = target_buf,
    target_win = ctx.target_win or vim.fn.bufwinid(target_buf),
  }
end

local function command_start(buf)
  return api.get_cache(buf).command_start
end

local function command_text(buf)
  return terminal_buffer.command_text(buf, command_start(buf), true)
end

local function normal_cursor_offset(command)
  return math.min(command.cursor, math.max(#command.text - 1, 0))
end

local function replace_visible_command(buf, command)
  local cache = api.get_cache(buf)
  local first, last = cache.command_start, cache.command_end
  local last_line = vim.api.nvim_buf_get_lines(buf, last[1] - 1, last[1], false)[1]
  last = { last[1], #last_line }
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_text(
    buf,
    first[1] - 1,
    first[2],
    last[1] - 1,
    last[2],
    vim.split(command.text, "\n", { plain = true })
  )
  cache.command_end = terminal_buffer.location_from_offset(buf, first, #command.text)
end

local function start_editing(ctx, command)
  replace_visible_command(ctx.target_buf, command)
  local cursor = terminal_buffer.location_from_offset(
    ctx.target_buf,
    command_start(ctx.target_buf),
    normal_cursor_offset(command)
  )
  vim.api.nvim_win_set_cursor(ctx.target_win, cursor)
  M.buffers[ctx.target_buf].editing = true
end

---Open the current terminal command as a local terminal-buffer draft.
---@param ctx? table
---@return boolean opened
function M.open(ctx)
  ctx = build_context(ctx)
  if helpers.is_editor_disabled(ctx.target_buf) then
    return false
  end
  if M.buffers[ctx.target_buf].editing then
    vim.cmd.stopinsert()
    return true
  end
  api.read(function(command)
    api.wait_for_terminal_change(api.get_cache(ctx.target_buf), function()
      vim.cmd.stopinsert()
      start_editing(ctx, command)
    end)
  end)
  return true
end

---Write the local draft back to the cleared shell input.
---@param buf integer
---@return string command
function M.write(buf)
  local command = command_text(buf)
  M.buffers[buf].editing = false
  vim.bo[buf].modifiable = false
  api.write(command, buf)
  return command
end

local function finish_editing(buf, submit)
  M.write(buf)
  if submit then
    api.send(api.get_cache(buf), "\r")
  end
  vim.cmd.startinsert()
end

local function clear_draft(buf)
  local start = command_start(buf)
  local last = api.get_cache(buf).command_end
  local last_line = vim.api.nvim_buf_get_lines(buf, last[1] - 1, last[1], false)[1]
  last = { last[1], #last_line }
  vim.api.nvim_buf_set_text(buf, start[1] - 1, start[2], last[1] - 1, last[2], { "" })
  api.get_cache(buf).command_end = start
  vim.api.nvim_win_set_cursor(0, start)
end

local function run_action(buf, action)
  if helpers.is_editor_disabled(buf) then
    return
  end
  action()
end

local function configured_handlers(buf)
  return {
    open = function()
      M.open({ target_buf = buf })
    end,
    submit = function()
      if M.buffers[buf].editing then
        finish_editing(buf, true)
      else
        api.send(api.get_cache(buf), "\r")
      end
    end,
    clear = function()
      if M.buffers[buf].editing then
        clear_draft(buf)
      else
        api.send(api.get_cache(buf), "\5\21")
      end
    end,
    write = function()
      if M.buffers[buf].editing then
        finish_editing(buf, false)
      end
    end,
    save_and_close = function()
      finish_editing(buf, false)
    end,
    toggle = function()
      require("termio").toggle()
    end,
  }
end

local function map_config_keymaps(buf)
  local state = M.buffers[buf]
  local handlers = configured_handlers(buf)
  for mode, mappings in pairs(config.options.editor.keys) do
    for lhs, name in pairs(mappings) do
      local handler = handlers[name]
      if handler then
        local map = function()
          run_action(buf, handler)
        end
        if name == "toggle" then
          state.keymaps:always(mode, lhs, map)
        else
          state.keymaps:map(mode, lhs, map)
        end
      end
    end
  end
end

local function map_insert_keymaps(buf)
  for _, lhs in ipairs({ "i", "a", "I", "A" }) do
    M.buffers[buf].keymaps:map("n", lhs, function()
      run_action(buf, function()
        if M.buffers[buf].editing then
          finish_editing(buf, false)
        else
          vim.cmd.startinsert()
        end
      end)
    end)
  end
end

local function register_terminal(buf)
  vim.bo[buf].filetype = config.options.editor.filetype
  vim.b[buf].termio_editor = "integrated"
  M.buffers[buf] = {
    editing = false,
    keymaps = keymaps.group({ buffer = buf, enabled = not helpers.is_editor_disabled(buf) }),
  }
  map_config_keymaps(buf)
  map_insert_keymaps(buf)
  local group = vim.api.nvim_create_augroup("termio-integrated-" .. buf, { clear = true })
  vim.api.nvim_create_autocmd("BufWipeout", {
    group = group,
    buffer = buf,
    once = true,
    callback = function()
      M.buffers[buf] = nil
      pcall(vim.api.nvim_del_augroup_by_id, group)
    end,
  })
end

function M.enable()
  for _, state in pairs(M.buffers) do
    state.keymaps:enable()
  end
end

function M.disable()
  for _, state in pairs(M.buffers) do
    state.keymaps:disable()
  end
end

function M.setup()
  vim.api.nvim_create_autocmd("TermOpen", {
    group = vim.api.nvim_create_augroup("termio-integrated", { clear = true }),
    callback = function(args)
      if helpers.is_enabled_terminal(args.buf) then
        register_terminal(args.buf)
      end
    end,
  })
end

return M
