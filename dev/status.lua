local M = {}

local function format_cursor(cursor)
  if type(cursor) ~= "table" then
    return cursor == nil and "-" or tostring(cursor)
  end
  return string.format("%s:%s", cursor[1] or "-", cursor[2] or "-")
end

local function format_value(value)
  return value == nil and "-" or tostring(value)
end

local function format_command(command)
  if command == nil then
    return "-"
  end
  local text = command:gsub("\n", "\\n")
  text = text:gsub("^[ \t]+", function(space)
    return space:gsub(".", function(char)
      return char == "\t" and "→" or "·"
    end)
  end)
  text = text:gsub("[ \t]+$", function(space)
    return space:gsub(".", function(char)
      return char == "\t" and "→" or "·"
    end)
  end)
  return string.format("%q", text)
end

local function log_level_name(level)
  for name, value in pairs(vim.log.levels) do
    if value == level then
      return name
    end
  end
  return format_value(level)
end

local function valid_buf(buf)
  return buf and vim.api.nvim_buf_is_valid(buf) or false
end

local function valid_win(win)
  return win and vim.api.nvim_win_is_valid(win) or false
end

local function find_editor_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    if vim.b[buf].termio_editor then
      return win, buf, vim.b[buf].termio_editor
    end
  end
end

local function rendered_state(buf, win, buffer_state)
  if not buffer_state.prompt_end_cursor then
    return { command = nil, cursor = nil }
  end
  local terminal_buffer = require("termio.terminal_buffer")
  local raw = terminal_buffer.read_state(
    require("termio.api").buffers,
    buf,
    valid_win(win) and win or nil,
    buffer_state.prompt_end_cursor
  )
  return require("termio.util.helpers").normalize_state(raw)
end

local function editor_state(editor_buf, editor_win, editor_type, rendered)
  if not valid_buf(editor_buf) or not valid_win(editor_win) then
    return { command = nil, cursor = nil }
  end
  if editor_type == "integrated" then
    return rendered
  end
  local popup = require("termio.editors.popup")
  local start = popup.prompt_start_cursor(editor_buf)
  return {
    command = popup.command_text(editor_buf, start),
    cursor = popup.cursor_index(editor_buf, editor_win, start),
  }
end

local function popup_target(editor_type, editor_buf, terminal)
  if editor_type ~= "centered" and editor_type ~= "overlay" then
    return terminal.buf, terminal.win
  end
  local context = require("termio.editors." .. editor_type).buffers[editor_buf] or {}
  return context.target_buf or terminal.buf, context.target_win or terminal.win
end

local function cursor_zone(terminal, buffer_state)
  if not buffer_state.prompt_end_cursor or not valid_win(terminal.win) then
    return "-"
  end
  local cursor = vim.api.nvim_win_get_cursor(terminal.win)
  return require("termio.editable_zone").contains(terminal.buf, cursor) and "in-zone" or "outside"
end

function M.collect()
  local config = require("termio.config")
  local options = config.options or config.defaults
  local helpers = require("termio.util.helpers")
  local terminal = _G.termio_debug and _G.termio_debug.terminal or {}
  local buffer_state = valid_buf(terminal.buf)
      and helpers.ensure_buffer_state(require("termio.api").buffers, terminal.buf)
    or {}
  local rendered = valid_buf(terminal.buf)
      and rendered_state(terminal.buf, terminal.win, buffer_state)
    or { command = nil, cursor = nil }
  local shell = buffer_state.shell_state or {}
  local editor_win, editor_buf, editor_type = find_editor_window()
  local target_buf, target_win = popup_target(editor_type, editor_buf, terminal)
  local editor = editor_state(editor_buf, editor_win, editor_type, rendered)
  return {
    plugin = {
      enabled = require("termio.state").is_enabled(),
      log_level = log_level_name(options.log_level),
      backend = options.backend,
      editor = options.editor.type,
    },
    mode = vim.api.nvim_get_mode().mode,
    terminal = vim.tbl_extend("force", terminal, {
      open = valid_buf(terminal.buf) and helpers.is_terminal_channel_open(terminal.buf) or false,
      focused = valid_win(terminal.win) and vim.api.nvim_get_current_win() == terminal.win or false,
      title = buffer_state.terminal_title,
    }),
    shell = {
      kind = buffer_state.shell_kind,
      phase = buffer_state.shell_phase,
      exit = buffer_state.shell_exit_status,
      query_pending = buffer_state.shell_query_pending or false,
      completions = buffer_state.might_have_completions or false,
    },
    prompt = {
      source = buffer_state.active_prompt_source,
      start = buffer_state.prompt_start_cursor,
      finish = buffer_state.prompt_end_cursor,
      active = buffer_state.active_prompt_cursor,
      cursor = cursor_zone(terminal, buffer_state),
    },
    editor = {
      type = editor_type,
      open = valid_buf(editor_buf) and valid_win(editor_win),
      disabled = valid_buf(target_buf) and helpers.is_editor_disabled(target_buf) or true,
      buf = editor_buf,
      win = editor_win,
      target_buf = target_buf,
      target_win = target_win,
    },
    commands = { rendered = rendered, shell = shell, editor = editor },
  }
end

local function command_line(name, state)
  return string.format(
    "  %-8s %2s  %s",
    name,
    format_value(state.cursor),
    format_command(state.command)
  )
end

local function commands_equal(first, second)
  if first == nil or second == nil then
    return "-"
  end
  return tostring(first == second)
end

function M.render_lines(snapshot)
  local commands = snapshot.commands
  return {
    string.format(
      "termio:   enabled=%s log_level=%s backend=%s editor=%s mode=%s",
      format_value(snapshot.plugin.enabled),
      format_value(snapshot.plugin.log_level),
      format_value(snapshot.plugin.backend),
      format_value(snapshot.plugin.editor),
      format_value(snapshot.mode)
    ),
    string.format(
      "terminal: buf=%s win=%s chan=%s open=%s focused=%s title=%s",
      format_value(snapshot.terminal.buf),
      format_value(snapshot.terminal.win),
      format_value(snapshot.terminal.chan),
      format_value(snapshot.terminal.open),
      format_value(snapshot.terminal.focused),
      format_value(snapshot.terminal.title)
    ),
    string.format(
      "shell:    kind=%s phase=%s exit=%s query=%s completions=%s",
      format_value(snapshot.shell.kind),
      format_value(snapshot.shell.phase),
      format_value(snapshot.shell.exit),
      format_value(snapshot.shell.query_pending),
      format_value(snapshot.shell.completions)
    ),
    string.format(
      "prompt:   source=%s start=%s end=%s active=%s cursor=%s",
      format_value(snapshot.prompt.source),
      format_cursor(snapshot.prompt.start),
      format_cursor(snapshot.prompt.finish),
      format_cursor(snapshot.prompt.active),
      format_value(snapshot.prompt.cursor)
    ),
    string.format(
      "editor:   open=%s disabled=%s buf=%s win=%s target=%s/%s",
      format_value(snapshot.editor.open),
      format_value(snapshot.editor.disabled),
      format_value(snapshot.editor.buf),
      format_value(snapshot.editor.win),
      format_value(snapshot.editor.target_buf),
      format_value(snapshot.editor.target_win)
    ),
    "",
    "commands:",
    command_line("rendered", commands.rendered),
    command_line("shell", commands.shell),
    command_line("editor", commands.editor),
    string.format(
      "  equal: rendered/shell=%s rendered/editor=%s",
      commands_equal(commands.rendered.command, commands.shell.command),
      commands_equal(commands.rendered.command, commands.editor.command)
    ),
  }
end

function M.snapshot_lines(label)
  local lines = M.render_lines(M.collect())
  return label and label ~= "" and vim.list_extend({ "status: " .. label }, lines) or lines
end

function M.dump(label)
  local lines = M.snapshot_lines(label)
  require("termio.util.log").debug("status", lines)
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
