local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.wrap = false
opt.scrolloff = 10
opt.sidescrolloff = 8

-- indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.softtabstop = 2
opt.expandtab = true
opt.smartindent = true
opt.autoindent = true

-- search settings
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = false
opt.incsearch = true

-- visual settings
opt.termguicolors = true
opt.signcolumn = "yes"
opt.showmatch = true
opt.matchtime = 2
opt.cmdheight = 1
opt.showmode = false
opt.pumheight = 10
opt.pumblend = 10
opt.winblend = 0
opt.confirm = true
opt.ruler = false

-- file handling
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.undolevels = 10000
local undodir = vim.fn.expand("~/.config/nvim/undodir")
opt.undodir = undodir
opt.updatetime = 300
opt.timeoutlen = 300
opt.ttimeoutlen = 0
opt.autoread = true
opt.autowrite = true

-- behavior
opt.hidden = true
opt.errorbells = false
opt.backspace = "indent,eol,start"
opt.autochdir = false
opt.iskeyword:append("-") -- treat - as part of word
opt.path:append("**")
opt.selection = "exclusive"
opt.mouse = "a"
-- Over SSH the clipboard worth writing to is on the machine at the other end,
-- so leave the registers unhooked there. `"+y` still reaches it through
-- nvim's OSC 52 fallback, which `unnamedplus` would take out of the picture.
opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus"
opt.modifiable = true
opt.encoding = "UTF-8"

opt.smoothscroll = true
-- `expr` was unquoted here, so this assigned the value of an undefined
-- global rather than the string. Neovim ships a treesitter foldexpr, and
-- naming it is what makes `expr` mean anything; without one the method
-- falls back to a foldexpr of 0 and no file ever folds. Filetypes with no
-- parser installed get no folds, which is the graceful end of it.
--
-- `opt` rather than `vim.wo`: window-local only reaches the window that
-- exists while this file runs, so every split opened afterwards kept the
-- default.
opt.foldmethod = "expr"
opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
-- Open files unfolded. Folds are there to be asked for, not to greet you.
opt.foldlevel = 99
opt.formatoptions = "jcroqlnt"
opt.grepformat = "%f:%l:%c:%m"
opt.grepprg = "rg --vimgrep"

-- split behavior
opt.splitbelow = true
opt.splitright = true
opt.splitkeep = "screen"

-- command-line completion
opt.wildmenu = true
opt.wildmode = "longest:full,full"
opt.wildignore:append({"*.o"})

opt.diffopt:append("linematch:60")

opt.redrawtime = 10000
opt.maxmempattern = 20000

-- Create undo directory if it doesn't exist
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, "p")
end

opt.jumpoptions = "view"
opt.laststatus = 3 -- global statusline
opt.linebreak = true
opt.list = true
opt.shiftround = true
opt.shortmess:append({ W = true, I = true, c = true, C = true })
