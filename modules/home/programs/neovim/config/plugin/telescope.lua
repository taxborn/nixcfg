vim.pack.add({
    'https://github.com/nvim-telescope/telescope.nvim',
    'https://github.com/nvim-lua/plenary.nvim',
    'https://github.com/nvim-telescope/telescope-fzf-native.nvim',
    'https://github.com/nvim-telescope/telescope-ui-select.nvim',
    'https://github.com/nvim-tree/nvim-web-devicons'
})

vim.api.nvim_create_autocmd('PackChanged', { callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind

    if name == 'telescope-fzf-native' and (kind == 'install' or kind == 'update') then
        -- Append `:wait()` if you need synchronous execution
        vim.system({ 'make' }, { cwd = ev.data.path })
    end
end })

local builtin = require('telescope.builtin')

-- This runs on LSP attach per buffer (see main LSP attach function in 'neovim/nvim-lspconfig' config for more info,
-- it is better explained there). This allows easily switching between pickers if you prefer using something else!
vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("telescope-lsp-attach", { clear = true }),
    callback = function(event)
        local buf = event.buf

        -- Find references for the word under your cursor.
        vim.keymap.set("n", "grr", builtin.lsp_references, { buffer = buf, desc = "[G]oto [R]eferences" })

        -- Jump to the implementation of the word under your cursor.
        -- Useful when your language has ways of declaring types without an actual implementation.
        vim.keymap.set(
            "n",
            "gri",
            builtin.lsp_implementations,
            { buffer = buf, desc = "[G]oto [I]mplementation" }
        )

        -- Jump to the definition of the word under your cursor.
        -- This is where a variable was first declared, or where a function is defined, etc.
        -- To jump back, press <C-t>.
        vim.keymap.set("n", "grd", builtin.lsp_definitions, { buffer = buf, desc = "[G]oto [D]efinition" })

        -- Fuzzy find all the symbols in your current document.
        -- Symbols are things like variables, functions, types, etc.
        vim.keymap.set(
            "n",
            "gO",
            builtin.lsp_document_symbols,
            { buffer = buf, desc = "Open Document Symbols" }
        )

        -- Fuzzy find all the symbols in your current workspace.
        -- Similar to document symbols, except searches over your entire project.
        vim.keymap.set(
            "n",
            "gW",
            builtin.lsp_dynamic_workspace_symbols,
            { buffer = buf, desc = "Open Workspace Symbols" }
        )

        -- Jump to the type of the word under your cursor.
        -- Useful when you're not sure what type a variable is and you want to see
        -- the definition of its *type*, not where it was *defined*.
        vim.keymap.set(
            "n",
            "grt",
            builtin.lsp_type_definitions,
            { buffer = buf, desc = "[G]oto [T]ype Definition" }
        )
    end,
})


vim.keymap.set('n', '<leader>ff', builtin.find_files, { desc = 'Telescope find files' })
vim.keymap.set('n', '<leader>fg', builtin.live_grep, { desc = 'Telescope live grep' })
vim.keymap.set('n', '<leader>fb', builtin.buffers, { desc = 'Telescope buffers' })
vim.keymap.set('n', '<leader>fh', builtin.help_tags, { desc = 'Telescope help tags' })
