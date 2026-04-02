vim.pack.add({
    { src = 'https://github.com/saghen/blink.cmp', version = vim.version.range('1.10.1') } ,
    'https://github.com/L3MON4D3/LuaSnip',
})

vim.api.nvim_create_autocmd('PackChanged', { callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == 'LuaSnip' and (kind == 'install' or kind == 'update') then
        if vim.fn.has('win32') == 0 and vim.fn.executable('make') == 1 then
            vim.system({ 'make', 'install_jsregexp' }, { cwd = ev.data.path })
        end
    end
end })

require('blink.cmp').setup({
    keymap = {
        preset = 'default',
    },
    appearance = {
        nerd_font_variant = 'mono',
    },
    completion = {
        documentation = { auto_show = false, auto_show_delay_ms = 500 },
    },
    sources = {
        default = { 'lsp', 'path', 'snippets' },
    },
    snippets = { preset = 'luasnip' },
    fuzzy = { implementation = 'prefer_rust' },
    signature = { enabled = true },
})
