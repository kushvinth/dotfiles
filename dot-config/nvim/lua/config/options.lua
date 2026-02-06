-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options hereo

-- lua/config/options.lua
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.autoindent = true
vim.opt.mouse = "a"
vim.opt.cursorline = true
vim.cmd("highlight CursorLine cterm=NONE ctermbg=darkgray guibg=#2e2e2e")
vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.errorbells = false
vim.opt.visualbell = true
vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = vim.fn.expand("~/.vim/undodir")
vim.opt.undofile = true
vim.opt.clipboard = "unnamed"
