local api = require("termio.api")
local config = require("termio.config")
local commands = require("termio.commands")
local state = require("termio.state")
local active_editor

local M = {
  is_enabled = state.is_enabled,
  read = api.read,
  write = api.write,
}

local function load_editor()
  local editor = config.options.editor.type
  if editor == nil or editor == false then
    return nil
  elseif editor == "integrated" then
    return require("termio.editors.integrated")
  elseif editor == "minimal" then
    return require("termio.editors.minimal")
  elseif editor == "centered" then
    return require("termio.editors.centered")
  elseif editor == "overlay" then
    return require("termio.editors.overlay")
  end
  error(
    "termio: config.editor.type must be false, 'minimal', 'centered', 'integrated', or 'overlay'"
  )
end

---Enable termio integrations and reload enabled-only editor resources.
---@param opts? { notify?: boolean }
function M.enable(opts)
  state.enable(opts)
  if active_editor and active_editor.enable then
    active_editor.enable()
  end
end

---Disable termio integrations and unload enabled-only editor resources.
function M.disable()
  state.disable()
  if active_editor and active_editor.disable then
    active_editor.disable()
  end
end

function M.toggle()
  if state.is_enabled() then
    M.disable()
  else
    M.enable()
  end
end

---Initialize termio from the plugin entrypoint.
---@param opts? table
function M.setup(opts)
  config.setup(opts)
  api.setup()
  commands.setup()
  active_editor = load_editor()
  if active_editor then
    active_editor.setup()
  end
  M.enable({ notify = false })
  if M.initialized then
    return M
  end
  M.initialized = true
  return M
end

return M
