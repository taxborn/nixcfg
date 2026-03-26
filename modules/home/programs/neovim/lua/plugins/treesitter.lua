return {
    "nvim-treesitter/nvim-treesitter",
    lazy = false,
    build = ":TSUpdate",
    branch = "main",
    config = function()
        local parsers = {
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
        require("nvim-treesitter").install(parsers)
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
    end,
}
