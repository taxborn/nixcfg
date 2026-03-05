{
  lib,
  config,
  ...
}:
{
  options.myHome.taxborn.programs.neovim.enable = lib.mkEnableOption "enable neovim";

  config = lib.mkIf config.myHome.taxborn.programs.neovim.enable {
    programs.neovim = {
      enable = true;
      vimAlias = true;
      defaultEditor = true;

      initLua = ''
        -- line numbers
        vim.opt.number = true
        vim.opt.relativenumber = true

        -- indentation
        vim.opt.tabstop = 4
        vim.opt.shiftwidth = 4
        vim.opt.expandtab = true
        vim.opt.smartindent = true

        -- search
        vim.opt.ignorecase = true
        vim.opt.smartcase = true
        vim.opt.hlsearch = false
        vim.opt.incsearch = true

        -- appearance
        vim.opt.termguicolors = true
        vim.opt.signcolumn = "yes"
        vim.opt.scrolloff = 8
        vim.opt.wrap = false

        -- behavior
        vim.opt.splitbelow = true
        vim.opt.splitright = true
        vim.opt.undofile = true

        -- leader key
        vim.g.mapleader = " "
        vim.g.maplocalleader = " "

        -- keymaps
        vim.keymap.set("n", "<leader>pv", vim.cmd.Ex, { desc = "Open netrw" })
        vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
        vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
        vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result centered" })
        vim.keymap.set("n", "N", "Nzzzv", { desc = "Prev search result centered" })
        vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { desc = "Move selection down" })
        vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { desc = "Move selection up" })
      '';
    };
  };
}
