-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- VSCode-like Ctrl+` to toggle terminal
vim.keymap.set("n", "<C-`>", "<cmd>ToggleTerm<CR>", { desc = "Toggle terminal" })
vim.keymap.set("t", "<C-`>", "<C-\\><C-n><cmd>ToggleTerm<CR>", { desc = "Toggle terminal" })

-- Open file under cursor in OS default viewer (workaround for no inline images in Neovide)
vim.keymap.set("n", "<leader>o", function()
  local file = vim.fn.expand("<cfile>")
  if file ~= "" then
    local cmd
    if vim.fn.has("mac") == 1 then
      cmd = { "open", file }
    elseif vim.fn.has("unix") == 1 then
      cmd = { "xdg-open", file }
    elseif vim.fn.has("win32") == 1 then
      cmd = { "cmd.exe", "/c", "start", "", file }
    end
    if cmd then
      vim.fn.jobstart(cmd, { detach = true })
    end
  end
end, { desc = "Open file under cursor in external viewer" })
