local Helpers = {}

function Helpers.new_child_neovim()
  local child = MiniTest.new_child_neovim()

  function child.wait(ms)
    child.loop.sleep(ms or 1)
  end

  function child.setup()
    child.restart({ "-u", "scripts/minimal_init.lua" })
  end

  function child.set_size(lines, columns)
    child.o.lines = lines
    child.o.columns = columns
  end

  return child
end

function Helpers.wait_until(child, check, timeout)
  local deadline = vim.uv.now() + (timeout or 5000)
  while vim.uv.now() < deadline do
    if check() then
      return
    end
    child.wait()
  end
  error("timed out")
end

function Helpers.wait_for_mode(child, mode, timeout)
  Helpers.wait_until(child, function()
    return child.lua_get([[vim.api.nvim_get_mode().mode]]) == mode
  end, timeout)
end

function Helpers.open_shell(child, prompt, shell)
  prompt = prompt or "$ "
  shell = shell or vim.env.TERMIO_TEST_SHELL or "zsh"
  if shell == "zsh" then
    child.cmd(string.format([[terminal env PS1=%q zsh -df]], prompt))
  elseif shell == "bash" then
    child.cmd(string.format([[terminal env PS1=%q bash --noprofile --norc -i]], prompt))
  elseif shell == "fish" then
    child.cmd([[terminal fish --no-config -i]])
  else
    error("unsupported test shell: " .. shell)
  end
  local buf = child.api.nvim_get_current_buf()
  Helpers.wait_until(child, function()
    for _, line in ipairs(child.api.nvim_buf_get_lines(buf, 0, -1, false)) do
      if line:match("^" .. vim.pesc(prompt) .. "%s*$") then
        return true
      end
    end
    return false
  end)
  return buf
end

return Helpers
