-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Neovide GUI settings
if vim.g.neovide then
  vim.g.neovide_window_blurred = true
  vim.g.neovide_floating_blur_amount_x = 2.0
  vim.g.neovide_floating_blur_amount_y = 2.0
  vim.g.neovide_remember_window_size = true
  vim.g.neovide_opacity = 0.92
  vim.g.neovide_cursor_vfx_mode = "railgun"
  vim.g.neovide_cursor_animation_length = 0.05
  vim.g.neovide_cursor_trail_length = 0.08
  vim.g.neovide_hide_mouse_when_typing = true
  vim.g.neovide_refresh_rate = 120
  vim.g.neovide_no_idle = true
  vim.g.neovide_theme = "auto"

  -- Cmd+C / Cmd+V copy & paste
  -- https://neovide.dev/faq.html#how-can-i-use-cmd-ccmd-v-to-copy-and-paste
  -- nvim_paste uses bracketed-paste handling, so pasted text isn't mangled by
  -- auto-indent, mappings or undo units (the old "+P / <C-R>+ approach causes that)
  local function save()
    vim.cmd.write()
  end
  local function copy()
    vim.cmd([[normal! "+y]])
  end
  local function paste()
    vim.api.nvim_paste(vim.fn.getreg("+"), true, -1)
  end

  vim.keymap.set({ "n", "i", "v" }, "<D-s>", save, { desc = "Save" })
  vim.keymap.set("v", "<D-c>", copy, { silent = true, desc = "Copy" })
  vim.keymap.set({ "n", "i", "v", "c", "t" }, "<D-v>", paste, { silent = true, desc = "Paste" })
end
