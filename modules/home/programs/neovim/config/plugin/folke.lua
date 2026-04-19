vim.pack.add({
    'https://github.com/folke/which-key.nvim',
    'https://github.com/folke/todo-comments.nvim'
})

require('which-key').setup({
    -- delay between pressing a key and opening which-key (milliseconds)
    delay = 0,
    icons = { mappings = true },

    -- Document existing key chains
    spec = {
        { "<leader>f", group = "[F]ind", mode = { "n", "v" } },
        { "gr", group = "LSP Actions", mode = { "n" } },
    },
})

require('todo-comments').setup({
    signs = false
})
