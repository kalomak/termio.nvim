local M = {}

local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

local function inspect_text(value)
  if value == nil or value == "" then
    return "-"
  end
  local text = tostring(value):gsub("\n", "\\n")
  local function edge_marker(space)
    return space == "\t" and "→" or "·"
  end
  text = text:gsub("^[ \t]+", function(space)
    return space:gsub(".", edge_marker)
  end)
  return text:gsub("[ \t]+$", function(space)
    return space:gsub(".", edge_marker)
  end)
end

local function format_cursor(cursor)
  if type(cursor) ~= "table" then
    return cursor or "-"
  end
  return string.format("%s:%s", cursor[1] or "-", cursor[2] or "-")
end

local function debug_cursor(cursor)
  local value = format_cursor(cursor)
  return string.format(type(value) == "number" and "%2d" or "%2s", value)
end

local function get_log_path()
  return vim.o.verbosefile ~= "" and vim.o.verbosefile or root .. "/tmp/dev.out"
end

function M.collect()
  local api = _G.termio_debug and _G.termio_debug.standalone or require("termio.api")
  local cache = api.terminals[vim.api.nvim_get_current_buf()]
  if not cache then
    local _, first_cache = next(api.terminals)
    cache = first_cache
  end
  cache = cache or { command = {} }
  local terminal_text, channel = "-", "-"
  if cache.target_buf and vim.api.nvim_buf_is_valid(cache.target_buf) then
    channel = vim.bo[cache.target_buf].channel
  end
  if cache.target_win and vim.api.nvim_win_is_valid(cache.target_win) then
    terminal_text = table.concat(api.read_terminal_state(cache).lines, "\n")
  end
  local editor_text, editor_cursor = "-", "-"
  if cache.edit_buf and vim.api.nvim_buf_is_valid(cache.edit_buf) then
    editor_text = table.concat(vim.api.nvim_buf_get_lines(cache.edit_buf, 0, -1, false), "\n")
  end
  if cache.edit_win and vim.api.nvim_win_is_valid(cache.edit_win) then
    editor_cursor = vim.api.nvim_win_get_cursor(cache.edit_win)
  end
  local config = require("termio.config")
  local editor = (config.options or config.defaults).editor
  return {
    options = vim.tbl_extend(
      "keep",
      api.options,
      { key = editor.open, filetype = editor.filetype }
    ),
    cache = cache,
    channel = channel,
    terminal_text = terminal_text,
    editor_text = editor_text,
    editor_cursor = editor_cursor,
  }
end

function M.render_lines(snapshot)
  local cache = snapshot.cache
  return {
    string.format(
      "probe: mode=%s key=%s filetype=%s poll=%sms timeout=%sms",
      vim.api.nvim_get_mode().mode,
      snapshot.options.key,
      snapshot.options.filetype,
      snapshot.options.poll_ms,
      snapshot.options.timeout_ms
    ),
    string.format(
      "handles: term=%s/%s/%s editor=%s/%s",
      cache.target_buf or "-",
      cache.target_win or "-",
      snapshot.channel,
      cache.edit_buf or "-",
      cache.edit_win or "-"
    ),
    string.format(
      "state  : %s cmd: %s",
      debug_cursor(cache.command.cursor),
      inspect_text(cache.command.text)
    ),
    string.format("prompt : row=%s text: %s", cache.prompt_row or "-", inspect_text(cache.prompt)),
    string.format(
      "parts  : original=%s start=%s end=%s current=%s",
      format_cursor(cache.original_cursor),
      format_cursor(cache.command_start),
      format_cursor(cache.command_end),
      format_cursor(cache.terminal_cursor)
    ),
    string.format("terminal: %s", inspect_text(snapshot.terminal_text)),
    string.format(
      "editor : %s text: %s",
      format_cursor(snapshot.editor_cursor),
      inspect_text(snapshot.editor_text)
    ),
  }
end

function M.snapshot_lines(label)
  local lines = M.render_lines(M.collect())
  return label and label ~= "" and vim.list_extend({ "status: " .. label }, lines) or lines
end

function M.dump(label)
  local lines = M.snapshot_lines(label)
  vim.fn.writefile(vim.list_extend(lines, { "" }), get_log_path(), "a")
  return lines
end

function M.copy_and_dump(label)
  local lines = M.dump(label)
  vim.fn.setreg("+", table.concat(lines, "\n"))
  vim.notify("Copied termio status", vim.log.levels.INFO)
  return lines
end

function M.setup()
  _G.termio_debug = _G.termio_debug or {}
  _G.termio_debug.dump_status = M.dump
  _G.termio_debug.copy_status = M.copy_and_dump
end

return M
