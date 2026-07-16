local M = {}

M.defaults = {
  editor = {
    type = "integrated",
    filetype = "bash",
    terminal_name_pattern = [[\v(:| )(/[^ ]*/)?(zsh|bash|fish)( |$)]],
    open = "<Esc>",
    is_disabled = function()
      return false
    end,
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
        border = nil,
        window = nil,
        winhighlight = nil,
      },
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
      pass_through_insert_keys = { "<Up>", "<Tab>" },
      pass_through_normal_keys = { "}", "<C-d>", "<C-b>", "G", "L", "/", "?", "n", "N" },
    },
  },
  debug = false,
}

---Store resolved plugin options and return them.
---@param options? table
---@return table
function M.setup(options)
  M.options = vim.deepcopy(vim.tbl_deep_extend("keep", options or {}, M.defaults))
  return M.options
end

return M
