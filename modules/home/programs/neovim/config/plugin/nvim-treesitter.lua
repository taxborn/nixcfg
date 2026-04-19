vim.pack.add({'https://github.com/nvim-treesitter/nvim-treesitter'})

-- runs :TSUpdate when treesitter is updated
vim.api.nvim_create_autocmd('PackChanged', { callback = function(ev)
    local name, kind = ev.data.spec.name, ev.data.kind
    if name == 'nvim-treesitter' and kind == 'update' then
        if not ev.data.active then vim.cmd.packadd('nvim-treesitter') end
        vim.cmd('TSUpdate')
    end
end })

require('nvim-treesitter').install {
    "astro",
    "bash",
    "c",
    "diff",
    "html",
    "java",
    "javascript",
    "lua",
    "luadoc",
    "markdown",
    "markdown_inline",
    "nix",
    "python",
    "query",
    "rust",
    "typescript",
    "vim",
    "vimdoc",
    "zig",
}

vim.api.nvim_create_autocmd("FileType", {
    callback = function(args)
        local buf, filetype = args.buf, args.match

        local language = vim.treesitter.language.get_lang(filetype)
        if not language then
            return
        end

        if not vim.treesitter.language.add(language) then
            return
        end
        vim.treesitter.start(buf, language)
        vim.wo.foldexpr = "v:lua.vim.treesitter.foldexpr()"
        vim.wo.foldmethod = "expr"
        vim.wo.foldlevel = 99
        -- enables treesitter based indentation
        vim.bo.indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end,
})

