local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
local debug_options = dofile(root .. "/dev/debug_options.lua")

local M = {}

function M.setup(opts)
  opts = opts or {}
  vim.fn.writefile({}, vim.fs.joinpath(vim.fn.stdpath("log"), "termio.log"))
  if opts.before_setup then
    opts.before_setup()
  end
  local options = debug_options.build()
  require("termio").setup(options)
end

return M
