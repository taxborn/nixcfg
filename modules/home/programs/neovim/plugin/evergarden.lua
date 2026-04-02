vim.pack.add({{ src = 'https://codeberg.org/evergarden/nvim', name = 'evergarden' }})
require('evergarden').setup({
    theme = { variant = 'spring' }
})
vim.cmd.colorscheme('evergarden')

