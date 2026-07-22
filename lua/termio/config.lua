local Termio = {}

--- Termio configuration with its default values.
---
---@type table
--- Default values:
---@eval return MiniDoc.afterlines_to_code(MiniDoc.current.eval_section)
Termio.defaults = {
  -- "auto" reads through shell integration, then falls back to terminal text.
  -- "buffer" always reads terminal text.
  backend = "auto",
  -- Vim regexes used to detect prompts in terminal text.
  prompt_patterns = { [[^>>> ]], [[^\.\.\. ]] },
  -- Ordered Lua pattern replacements applied after reading a command.
  read_replace_patterns = {},
  -- Ordered Lua pattern replacements applied before writing a command.
  write_replace_patterns = {},
  timeouts = {
    -- Polling deadline and interval for terminal rendering.
    render_command = { limit_ms = 50, interval_ms = 2 },
    -- Polling deadline and interval for shell integration responses.
    shell_query = { limit_ms = 50, interval_ms = 2 },
  },
  waits = {
    -- How long the integrated editor ignores redraw-triggered TextChanged after writing.
    integrated_write_guard_ms = 0,
  },
  editor = {
    -- Bundled editor: "integrated", "centered", or "overlay".
    type = "integrated",
    -- Delay before editor changes are synchronized to the shell; nil disables synchronization.
    sync_debounce_ms = 100,
    -- Filetype assigned to bundled editor buffers.
    filetype = "bash",
    -- Vim regex matched against terminal buffer names before enabling the editor.
    -- Set to nil to accept every terminal buffer.
    terminal_name_pattern = [[\v(:| )(/[^ ]*/)?(zsh|bash|fish)( |$)]],
    -- Terminal-mode key that opens centered and overlay editors.
    open = "<Esc>",
    -- Returning true prevents the editor from opening for the buffer.
    is_disabled = function()
      return false
    end,
    -- Editor action mappings by mode: t=terminal, n=normal.
    keys = {
      t = {
        ["<Esc>"] = "open",
        ["<CR>"] = "submit",
        ["<C-u>"] = "clear",
        ["<C-s>"] = "write",
        ["<M-t>"] = "toggle",
      },
      n = {
        ["<CR>"] = "submit",
        ["<C-u>"] = "clear",
        ["<C-s>"] = "write",
        ["<Esc>"] = "save_and_close",
        ["<M-t>"] = "toggle",
      },
    },
    popup = {
      style = {
        -- Floating-window border override.
        border = nil,
        -- Floating-window style passed to nvim_open_win().
        window = nil,
        -- Floating-window 'winhighlight' override.
        winhighlight = nil,
      },
      -- Reserved for opening the overlay when a prompt appears; not implemented.
      open_on_prompt = false,
      -- Experimental. For centered and overlay editors, open when the terminal-normal
      -- cursor crosses from outside into the detected prompt or current command.
      -- The popup does not reopen while the cursor remains in that area.
      open_on_focus = false,
      -- Terminal normal/visual keys that open the popup before replaying the key.
      open_then_keys = { n = { "p", "P" }, x = { "p", "P" } },
      -- Additional popup-buffer action mappings by mode.
      keys = {
        i = {
          ["<CR>"] = "submit",
          ["<C-u>"] = "clear",
          ["<C-s>"] = "write",
        },
        n = {
          ["q"] = "close",
          ["j"] = "down",
          ["k"] = "up",
        },
        x = {
          ["j"] = "down",
          ["k"] = "up",
        },
        o = {
          ["j"] = "down",
          ["k"] = "up",
        },
      },
      -- Popup insert-mode keys that write, close, then replay in terminal mode.
      pass_through_insert_keys = { "<Up>", "<Tab>" },
      -- Popup normal-mode keys that write, close, then replay in terminal normal mode.
      pass_through_normal_keys = { "}", "<C-d>", "<C-b>", "G", "L", "/", "?", "n", "N" },
      -- Normal-mode pass-through keys active only on the popup's first visual line.
      pass_through_normal_keys_first_line = { "{", "<C-u>", "gg", "H" },
    },
  },
  -- Minimum level recorded by the Termio logger.
  log_level = vim.log.levels.OFF,
}

---Store resolved plugin options and return them.
---@param options? table
---@return table
---@private
function Termio.setup(options)
  Termio.options = vim.deepcopy(vim.tbl_deep_extend("keep", options or {}, Termio.defaults))
  return Termio.options
end

return Termio
