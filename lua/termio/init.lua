local api = require("termio.api")
local config = require("termio.config")
local commands = require("termio.commands")
local log = require("termio.util.log")
local shell_state = require("termio.shell_state")
local state = require("termio.state")
local active_editor

---@toc_entry Editors
---@text
--- *termio* *termio-editors*
---
--- Default editor: `integrated`.
---
--- OVERLAY EDITOR ~
---
--- This editor is a separate window/buffer from the terminal.
--- Uses `buftype='prompt'`, includes the shell prompt in the first line, and opens
--- in normal mode.
--- It is the smoothest editing experience but it requires complexity to handle:
--- - changing buffer when in the editor window
--- - moving seamlessly in and out of the window when navigating the terminal
---
--- INTEGRATED EDITOR ~
---
--- This editor integrates to the terminal buffer directly. Pros: no extra window,
--- cons: hacky, needs to fight with pty over the buffer state.

---@toc_entry TUI detection
---@text
--- *termio-tui-detection*
---
--- Development notes and an example for tracking terminal alt-screen state:
--- https://github.com/kalomak/termio.nvim/blob/main/dev/doc/tui-detection.md

---@toc_entry Frequently asked questions
---@text
--- *termio-faq*

local Termio = {
  is_enabled = state.is_enabled,
  read_command = api.read_command,
  update_prompt_range = api.update_prompt_range,
  prompt_range = api.prompt_range,
  clear_command = api.clear_command,
  write_command = api.write_command,
  move_shell_cursor = api.move_shell_cursor,
  sync = api.sync,
  command_start_cursor = api.command_start_cursor,
  cursor_index_in_command = api.cursor_index_in_command,
}

local function load_editor()
  local editor = config.options.editor.type
  if editor == nil then
    return nil
  elseif editor == "integrated" then
    return require("termio.editors.integrated")
  elseif editor == "centered" then
    return require("termio.editors.centered")
  elseif editor == "overlay" then
    return require("termio.editors.overlay")
  end
  error("termio: config.editor.type must be nil, 'centered', 'integrated', or 'overlay'")
end

---Enable termio integrations and reload enabled-only editor resources.
---@param opts? { notify?: boolean }
function Termio.enable(opts)
  state.enable(opts)
  if active_editor and active_editor.enable then
    active_editor.enable()
  end
end

---Disable termio integrations and unload enabled-only editor resources.
function Termio.disable()
  state.disable()
  if active_editor and active_editor.disable then
    active_editor.disable()
  end
end

function Termio.toggle()
  if state.is_enabled() then
    Termio.disable()
  else
    Termio.enable()
  end
end

local function create_autocmds()
  vim.api.nvim_create_autocmd("TermRequest", {
    group = vim.api.nvim_create_augroup("termio-osc133", { clear = true }),
    callback = function(args)
      shell_state.handle_term_request(api.buffers, args)
    end,
  })
end

---Initialize termio from the plugin entrypoint.
---@param opts? table
function Termio.setup(opts)
  config.setup(opts)
  log.setup(config.options)
  commands.setup()
  active_editor = load_editor()
  if active_editor then
    active_editor.setup()
  end
  Termio.enable({ notify = false })
  if Termio.initialized then
    return Termio
  end
  create_autocmds()
  Termio.initialized = true
  return Termio
end

return Termio
