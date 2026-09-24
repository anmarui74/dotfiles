-----------------------------------------------------------
-- General
-----------------------------------------------------------
vim.g.mapleader = ' '             -- change leader to a comma
vim.opt.mouse = 'a'            	  -- enable mouse support
vim.opt.clipboard = 'unnamedplus' 	  -- copy/paste to system clipboard
vim.opt.swapfile = false          	  -- don't use swapfile


-----------------------------------------------------------
-- Neovim UI
-----------------------------------------------------------
vim.opt.number = true             -- show line number
vim.opt.relativenumber = true     -- show line number
vim.opt.showmatch = true          -- highlight matching parenthesis
vim.opt.foldmethod = 'expr'       -- enable folding (default 'foldmarker')
vim.opt.tw = 0
vim.opt.colorcolumn = ""    	  -- line lenght marker at 80 columns
vim.opt.splitright = true         -- vertical split to the right
vim.opt.splitbelow = true         -- orizontal split to the bottom
vim.opt.ignorecase = true         -- ignore case letters when search
vim.opt.smartcase = true          -- ignore lowercase for the whole pattern
vim.opt.linebreak = true          -- wrap on word boundary
vim.opt.foldlevel = 99            -- should open all folds
vim.opt.conceallevel = 0
vim.opt.termguicolors = true
vim.opt.guifont = "Droid Sans Mono Nerd Font"


-----------------------------------------------------------
-- Folding
-----------------------------------------------------------


-----------------------------------------------------------
-- Memory, CPU
-----------------------------------------------------------
vim.opt.hidden = true         -- enable background buffers
vim.opt.history = 100         -- remember n lines in history
-- vim.opt.lazyredraw = true     -- faster scrolling
vim.opt.synmaxcol = 1000      -- max column for syntax highlight


-----------------------------------------------------------
-- Tabs, indent
-----------------------------------------------------------
vim.opt.expandtab = true      -- use spaces instead of tabs
vim.opt.shiftwidth = 4        -- shift 4 spaces when tab
vim.opt.tabstop = 4           -- 1 tab == 4 spaces
vim.opt.smartindent = true    -- autoindent new lines

-- IndentLine
--vim.g.indentLine_setColors = 0  -- set indentLine color
vim.g.indentLine_char = '|'       -- set indentLine character

