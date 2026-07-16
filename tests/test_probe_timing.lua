local Helpers = require("tests.helpers")
local child = Helpers.new_child_neovim()

local T = MiniTest.new_set({
  hooks = {
    pre_once = function()
      child.setup()
      child.lua([[require("termio").setup({ editor = { type = false } })]])
      Helpers.open_shell(child, "$ ", "zsh")
      child.api.nvim_input("i")
      Helpers.wait_for_mode(child, "t")
      child.api.nvim_input("bindkey -e<CR>")
      Helpers.wait_until(child, function()
        return child.api.nvim_get_current_line() == "$ " and child.api.nvim_win_get_cursor(0)[1] > 1
      end)
    end,
    post_once = child.stop,
  },
})

local function median(values)
  table.sort(values)
  return values[math.ceil(#values / 2)]
end

local function measure(clear_together)
  child.api.nvim_input("echo benchmark<Left><Left><Left><Left>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_line() == "$ echo benchmark"
      and child.api.nvim_win_get_cursor(0)[2] == 12
  end)
  child.lua(
    [[
      local together = ...
      local api = require("termio.api")
      local cache = api.get_cache(vim.api.nvim_get_current_buf())
      cache.target_win = vim.api.nvim_get_current_win()
      cache.prompt_row = vim.api.nvim_win_get_cursor(0)[1]
      ProbeTiming = nil
      local started = vim.uv.hrtime()
      local deadline = vim.uv.now() + 5000
      local function wait_until_cleared()
        local state = api.read_terminal_state(cache)
        if state.lines[1]:match("^%$ %s*$") and state.cursor[2] == 2 then
          ProbeTiming = { elapsed_ms = (vim.uv.hrtime() - started) / 1e6 }
          return
        end
        if vim.uv.now() >= deadline then
          ProbeTiming = { error = "command was not cleared: " .. vim.inspect(state.lines[1]) }
          return
        end
        vim.defer_fn(wait_until_cleared, 1)
      end
      if together then
        api.send(cache, "\5\21")
        wait_until_cleared()
      else
        api.send(cache, "\5")
        api.wait_for_terminal_change(cache, function()
          api.send(cache, "\21")
          wait_until_cleared()
        end)
      end
    ]],
    { clear_together }
  )
  Helpers.wait_until(child, function()
    return child.lua_get([[ProbeTiming ~= nil]])
  end, 7000)
  local result = child.lua_get([[ProbeTiming]])
  if result.error then
    error(result.error)
  end
  MiniTest.expect.equality(child.api.nvim_get_current_line():match("^%$ %s*$") ~= nil, true)
  return result.elapsed_ms
end

local function capture_combined_cursor()
  child.api.nvim_input("echo benchmark<Left><Left><Left><Left>")
  Helpers.wait_until(child, function()
    return child.api.nvim_get_current_line() == "$ echo benchmark"
      and child.api.nvim_win_get_cursor(0)[2] == 12
  end)
  child.lua([[
    local api = require("termio.api")
    local cache = api.get_cache(vim.api.nvim_get_current_buf())
    cache.target_win = vim.api.nvim_get_current_win()
    cache.prompt_row = vim.api.nvim_win_get_cursor(0)[1]
    local probe = { autocmd_positions = {}, on_lines_positions = {}, poll_positions = {} }
    ProbeCursor = probe
    local group = vim.api.nvim_create_augroup("termio-probe-cursor", { clear = true })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
      group = group,
      callback = function()
        table.insert(probe.autocmd_positions, vim.api.nvim_win_get_cursor(0)[2])
      end,
    })
    vim.api.nvim_buf_attach(cache.target_buf, false, {
      on_lines = function()
        table.insert(probe.on_lines_positions, vim.api.nvim_win_get_cursor(0)[2])
      end,
    })
    api.send(cache, "\5\21")
    local deadline = vim.uv.now() + 5000
    local function wait_until_cleared()
      local state = api.read_terminal_state(cache)
      table.insert(probe.poll_positions, state.cursor[2])
      if state.lines[1]:match("^%$ %s*$") and state.cursor[2] == 2 then
        probe.cleared = true
        vim.api.nvim_del_augroup_by_id(group)
        vim.api.nvim_buf_detach(cache.target_buf)
        return
      end
      if vim.uv.now() >= deadline then
        probe.error = "command was not cleared"
        return
      end
      vim.defer_fn(wait_until_cleared, 1)
    end
    wait_until_cleared()
  ]])
  Helpers.wait_until(child, function()
    return child.lua_get([[ProbeCursor.cleared or ProbeCursor.error ~= nil]])
  end, 7000)
  local result = child.lua_get([[ProbeCursor]])
  if result.error then
    error(result.error)
  end
  return result
end

T["Ctrl-E then wait then Ctrl-U versus one send"] = function()
  local sequential, together = {}, {}
  for i = 1, 10 do
    if i % 2 == 0 then
      sequential[#sequential + 1] = measure(false)
      together[#together + 1] = measure(true)
    else
      together[#together + 1] = measure(true)
      sequential[#sequential + 1] = measure(false)
    end
  end
  local sequential_ms, together_ms = median(sequential), median(together)
  local delta_ms = sequential_ms - together_ms
  print(
    string.format(
      "probe clear median (10 runs): sequential %.2f ms, together %.2f ms, delta %.2f ms, %.2fx",
      sequential_ms,
      together_ms,
      delta_ms,
      sequential_ms / together_ms
    )
  )
end

T["combined send exposes command-end cursor to CursorMoved"] = function()
  local autocmd_captured, on_lines_captured, poll_captured = 0, 0, 0
  local autocmd_observed, on_lines_observed, poll_observed = {}, {}, {}
  for _ = 1, 20 do
    local result = capture_combined_cursor()
    if vim.tbl_contains(result.autocmd_positions, 16) then
      autocmd_captured = autocmd_captured + 1
    end
    if vim.tbl_contains(result.on_lines_positions, 16) then
      on_lines_captured = on_lines_captured + 1
    end
    if vim.tbl_contains(result.poll_positions, 16) then
      poll_captured = poll_captured + 1
    end
    autocmd_observed[#autocmd_observed + 1] = table.concat(result.autocmd_positions, ",")
    on_lines_observed[#on_lines_observed + 1] = table.concat(result.on_lines_positions, ",")
    poll_observed[#poll_observed + 1] = table.concat(result.poll_positions, ",")
  end
  print(
    string.format(
      "combined command-end capture: CursorMoved %d/20 [%s], on_lines %d/20 [%s], poll %d/20 [%s]",
      autocmd_captured,
      table.concat(autocmd_observed, " | "),
      on_lines_captured,
      table.concat(on_lines_observed, " | "),
      poll_captured,
      table.concat(poll_observed, " | ")
    )
  )
end

return T
