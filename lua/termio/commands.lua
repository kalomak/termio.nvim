local api = require("termio.api")

local M = {}

function M.setup()
  vim.api.nvim_create_user_command("TermioReadCommand", function()
    api.read(function(command)
      vim.api.nvim_echo({ { command.text == "" and "(empty)" or command.text } }, false, {})
      api.write(command.text)
    end)
  end, {})
  vim.api.nvim_create_user_command("TermioWriteCommand", function(opts)
    api.read(function()
      api.write(opts.args)
    end)
  end, { nargs = "*" })
  vim.api.nvim_create_user_command("TermioEnable", function()
    require("termio").enable()
  end, {})
  vim.api.nvim_create_user_command("TermioDisable", function()
    require("termio").disable()
  end, {})
  vim.api.nvim_create_user_command("TermioToggle", function()
    require("termio").toggle()
  end, {})
end

return M
