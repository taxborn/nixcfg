vim.pack.add({'https://github.com/mikavilpas/yazi.nvim'})

require('yazi').setup({
    open_for_directories = true,
})

vim.keymap.set('n', '-', vim.cmd.Yazi, { desc = 'Open Yazi file manager' })

-- mark netrw as loaded so it's not loaded at all.
-- More details: https://github.com/mikavilpas/yazi.nvim/issues/802
vim.g.loaded_netrwPlugin = 1
vim.api.nvim_create_autocmd("UIEnter", {
  callback = function()
    require("yazi").setup({
      open_for_directories = true,
    })
  end,
})
