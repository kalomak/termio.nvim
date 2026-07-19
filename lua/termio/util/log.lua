local M = {}
local level_names = { "TRACE", "DEBUG", "INFO", "WARN", "ERROR", "OFF" }
local notify_levels = {
  info = vim.log.levels.INFO,
  warn = vim.log.levels.WARN,
  error = vim.log.levels.ERROR,
}

-- Keep arbitrary log arguments readable and on one line in files and notifications.
local function format_values(...)
  local values = {}
  for i = 1, select("#", ...) do
    local value = select(i, ...)
    if type(value) == "string" then
      value = value:gsub("\n", "\\n")
    else
      value = value == nil and "nil" or vim.inspect(value, { newline = " ", indent = "" })
    end
    values[#values + 1] = value
  end
  return values
end

local function format_log(min_level, level, ...)
  if level < min_level then
    return nil
  end
  local seconds, microseconds = vim.uv.gettimeofday()
  local timestamp = os.date("%Y-%m-%d %H:%M:%S", seconds)
    .. string.format(".%03d", math.floor(microseconds / 1000))
  local parts = { string.format("[%s][%s]", level_names[level + 1], timestamp) }
  for _, value in ipairs(format_values(...)) do
    parts[#parts + 1] = value
  end
  return table.concat(parts, " ") .. "\n"
end

local logger

---Configure the termio logger.
---@param options table
function M.setup(options)
  logger = vim.log.new({
    name = "termio",
    level = options.log_level,
    format_func = format_log,
  })
end

local function get_logger()
  return assert(logger, "termio logger is not configured")
end

local function write(level, ...)
  get_logger()[level](...)
  if notify_levels[level] then
    vim.notify(table.concat(format_values(...), " "), notify_levels[level], { title = "termio" })
  end
end

---Write a trace event.
---@param ... any
function M.trace(...)
  write("trace", ...)
end

---Write a debug event.
---@param event string
---@param data any
function M.debug(event, data)
  write("debug", event, data)
end

---Write an informational event.
---@param ... any
function M.info(...)
  write("info", ...)
end

---Write a warning event.
---@param ... any
function M.warn(...)
  write("warn", ...)
end

---Write an error event.
---@param ... any
function M.error(...)
  write("error", ...)
end

return M
