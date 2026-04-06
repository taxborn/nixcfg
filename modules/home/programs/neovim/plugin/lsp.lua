-- LSP Configuration
vim.pack.add({ 'https://github.com/neovim/nvim-lspconfig' })
vim.pack.add({ 'https://github.com/j-hui/fidget.nvim' })

require('fidget').setup({})

vim.api.nvim_create_autocmd('LspAttach', {
    group = vim.api.nvim_create_augroup('lsp-attach', { clear = true }),
    callback = function(event)
        local map = function(keys, func, desc, mode)
            mode = mode or 'n'
            vim.keymap.set(mode, keys, func, { buffer = event.buf, desc = 'LSP: ' .. desc })
        end

        map('<leader>F', vim.lsp.buf.format, '[F]ormat')
        map('grn', vim.lsp.buf.rename, '[R]e[n]ame')
        map('gra', vim.lsp.buf.code_action, '[G]oto Code [A]ction', { 'n', 'x' })
        map('grD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        local client = vim.lsp.get_client_by_id(event.data.client_id)

        if client and client:supports_method('textDocument/documentHighlight', event.buf) then
            local highlight_augroup = vim.api.nvim_create_augroup('lsp-highlight', { clear = false })

            vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
                buffer = event.buf,
                group = highlight_augroup,
                callback = vim.lsp.buf.document_highlight,
            })

            vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
                buffer = event.buf,
                group = highlight_augroup,
                callback = vim.lsp.buf.clear_references,
            })

            vim.api.nvim_create_autocmd('LspDetach', {
                group = vim.api.nvim_create_augroup('lsp-detach', { clear = true }),
                callback = function(event2)
                    vim.lsp.buf.clear_references()
                    vim.api.nvim_clear_autocmds({ group = 'lsp-highlight', buffer = event2.buf })
                end,
            })
        end

        if client and client:supports_method('textDocument/inlayHint', event.buf) then
            map('<leader>th', function()
                vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
            end, '[T]oggle Inlay [H]ints')
        end
    end,
})

local servers = {
    rust_analyzer = {},
    zls = {},
    ts_ls = {},
    tailwindcss = {},
    astro = {
        init_options = {
            typescript = {
                tsdk = (function()
                    local tsc = vim.fn.exepath('tsc')
                    if tsc ~= '' then
                        -- /nix/store/xxx-typescript/bin/tsc -> /nix/store/xxx-typescript/lib/node_modules/typescript/lib
                        return tsc:gsub('/bin/tsc$', '/lib/node_modules/typescript/lib')
                    end
                    return ''
                end)(),
            },
        },
    },
    lua_ls = {
        on_init = function(client)
            if client.workspace_folders then
                local path = client.workspace_folders[1].name
                if
                    path ~= vim.fn.stdpath('config')
                    and (vim.uv.fs_stat(path .. '/.luarc.json') or vim.uv.fs_stat(path .. '/.luarc.jsonc'))
                then
                    return
                end
            end

            client.config.settings.Lua = vim.tbl_deep_extend('force', client.config.settings.Lua, {
                runtime = {
                    version = 'LuaJIT',
                    path = { 'lua/?.lua', 'lua/?/init.lua' },
                },
                workspace = {
                    checkThirdParty = false,
                    library = vim.tbl_extend('force', vim.api.nvim_get_runtime_file('', true), {
                        '${3rd}/luv/library',
                        '${3rd}/busted/library',
                    }),
                },
            })
        end,
        settings = {
            Lua = {},
        },
    },
}

local is_nixos = vim.uv.fs_stat('/etc/NIXOS') ~= nil

if not is_nixos then
    vim.pack.add({
        'https://github.com/mason-org/mason.nvim',
        'https://github.com/mason-org/mason-lspconfig.nvim',
    })
    require('mason').setup()
    require('mason-lspconfig').setup({
        ensure_installed = vim.tbl_keys(servers),
    })
end

for name, server in pairs(servers) do
    vim.lsp.config(name, server)
    vim.lsp.enable(name)
end
