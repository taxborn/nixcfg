local opt = vim.opt

opt.number = true
opt.relativenumber = true
opt.cursorline = true
opt.wrap = false
opt.scrolloff = 10 -- keep 10 lines above/below the cursor
opt.sidescrolloff = 8 -- keep 8 columns to the left/right of cursor

-- indentation
opt.tabstop = 2 -- tab width
opt.shiftwidth = 2 -- indent width
opt.softtabstop = 2
opt.expandtab = true -- spaces instead of tabs
opt.smartindent = true -- autoindenting
opt.autoindent = true -- copy indent from previous line?

-- search settings
opt.ignorecase = true
opt.smartcase = true -- case sensitive if I use caps
opt.hlsearch = false
opt.incsearch = true

-- visual settings
opt.termguicolors = true -- 24-bit color
opt.signcolumn = "yes"
opt.showmatch = true
opt.matchtime = 2
opt.cmdheight = 1
opt.showmode = false
opt.pumheight = 10 -- popup menu height
opt.pumblend = 10 -- popup menu transparency
opt.winblend = 0 -- floating window transparency
opt.confirm = true
opt.ruler = false

-- file handling
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undofile = true
opt.undolevels = 10000
opt.undodir = vim.fn.expand("~/.config/nvim/undodir")
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
opt.path:append("**") -- include subdirs as part of search
opt.selection = "exclusive"
opt.mouse = "a" -- enable mouse
opt.clipboard = vim.env.SSH_TTY and "" or "unnamedplus"
opt.modifiable = true
opt.encoding = "UTF-8"

opt.smoothscroll = true
vim.wo.foldmethod = expr
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
local undodir = vim.fn.expand("~/.config/nvim/undodir")
if vim.fn.isdirectory(undodir) == 0 then
  vim.fn.mkdir(undodir, "p")
end

vim.g.autoformat = true
vim.g.trouble_lualine = true

opt.jumpoptions = "view"
opt.laststatus = 3 -- global statusline
opt.list = false
opt.linebreak = true -- Wrap lines at convenient points
opt.list = true -- Show some invisible characters (tabs...
opt.shiftround = true -- Round indent
opt.shiftwidth = 2 -- Size of an indent
opt.shortmess:append({ W = true, I = true, c = true, C = true })
