vim.g.mapleader = " "
vim.g.maplocalleader = " "

require('keymaps')
require('options')

-- Highlight when yanking (copying) text
vim.api.nvim_create_autocmd("TextYankPost", {
    desc = "Highlight when yanking (copying) text",
    group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
    callback = function()
        vim.hl.on_yank()
    end,
})

vim.pack.add({
    'https://github.com/christoomey/vim-tmux-navigator',
    'https://github.com/nvim-tree/nvim-web-devicons'
})
