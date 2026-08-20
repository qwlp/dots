vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.loaded_nvim_dir_plugin = 1
vim.opt.scrolljump = -50

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.softtabstop = 4
vim.opt.autoindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true
vim.opt.signcolumn = "yes"
vim.opt.updatetime = 50
vim.opt.colorcolumn = "80"

vim.api.nvim_create_autocmd("FileType", {
    pattern = {"typst", "markdown", "text"},
    callback = function()
        vim.opt_local.textwidth = 80
    end,
})
