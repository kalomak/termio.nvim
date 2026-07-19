local M = {}

local namespace = vim.api.nvim_create_namespace("termio-debug-osc-markers")
local marker_highlights = {
  -- Blue (#5f5faf): emitted before the shell renders a prompt.
  ["133;A"] = { "TermioDebugOscPromptStart", "#5f5faf" },
  -- Cyan (#008787): emitted after the prompt, where editable input starts.
  ["133;B"] = { "TermioDebugOscPromptEnd", "#008787" },
  -- Yellow (#af8700): emitted after command submission, before its output.
  ["133;C"] = { "TermioDebugOscOutputStart", "#af8700" },
  -- Green (#5f875f): emitted after command output, with the exit status.
  ["133;D"] = { "TermioDebugOscOutputEnd", "#5f875f" },
  -- Purple (#875f87): response to Termio requesting the current editable command state.
  -- It is not emitted on every redraw; the payload contains cursor and command text.
  ["633;E"] = { "TermioDebugOscCommandState", "#875f87" },
  -- Orange (#af5f00): emitted immediately before the shell opens completion UI.
  ["633;CL"] = { "TermioDebugOscCompletion", "#af5f00" },
  -- Indigo (#5f5f87): emitted when the injected shell integration announces itself.
  ["633;I"] = { "TermioDebugOscIntegration", "#5f5f87" },
}
-- Gray (#666666): any other OSC request, including terminal title changes.
local other_highlight = { "TermioDebugOscOther", "#666666" }

local function marker_highlight(sequence)
  local marker = sequence:match("^\027%](133;[ABCD])") or sequence:match("^\027%](633;[%u]+)")
  return (marker_highlights[marker] or other_highlight)[1]
end

local function mark_event(args)
  local cursor = args.data.cursor or {}
  local row, col = cursor[1], cursor[2]
  if not row or row <= 0 or col == nil then
    return
  end
  local line = vim.api.nvim_buf_get_lines(args.buf, row - 1, row, false)[1] or ""
  if #line == 0 then
    return
  end
  local marker_col = math.min(col, #line - 1)
  vim.api.nvim_buf_set_extmark(args.buf, namespace, row - 1, marker_col, {
    end_col = marker_col + 1,
    hl_group = marker_highlight(args.data.sequence),
    right_gravity = false,
  })
end

function M.setup()
  for _, highlight in pairs(marker_highlights) do
    vim.api.nvim_set_hl(0, highlight[1], { bg = highlight[2] })
  end
  vim.api.nvim_set_hl(0, other_highlight[1], { bg = other_highlight[2] })
  local group = vim.api.nvim_create_augroup("termio-debug-osc-markers", { clear = true })
  vim.api.nvim_create_autocmd("TermRequest", { group = group, callback = mark_event })
  vim.api.nvim_create_autocmd({ "BufDelete", "TermClose" }, {
    group = group,
    callback = function(args)
      if vim.api.nvim_buf_is_valid(args.buf) then
        vim.api.nvim_buf_clear_namespace(args.buf, namespace, 0, -1)
      end
    end,
  })
end

return M
