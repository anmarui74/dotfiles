-- Aliases

local map = vim.api.nvim_set_keymap
local default_ops = { noremap = true, silent = true }
local cmd = vim.cmd

-- Mappings

-- Definir espacio como tecla líder
vim.g.mapleader = " "

-- Guardar con w
vim.keymap.set("n", "w", ":w<CR>")

-- Cerrar con q
vim.keymap.set("n", "q", ":q<CR>")

-- Abrir el archivo init.vim con <líder> +e
vim.keymap.set("n", "<leader>e", ":e $MYVIMRC<CR>")

-- Redimensionar ventanas
vim.keymap.set("n", "<leader><right>", ":vertical resize +5<CR>")
vim.keymap.set("n", "<leader><left>", ":vertical resize -5<CR>")
vim.keymap.set("n", "<leader><up>", ":resize +5<CR>")
vim.keymap.set("n", "<leader><down>", ":resize -5<CR>")

-- Terminar la busqueda
vim.keymap.set("n", "<leader>b", ":nohlsearch<CR>")

-- Moverse al buffer siguiente con <líder> + k
vim.keymap.set("n", "<leader>k ", ":bnext<CR>")

-- Moverse al buffer anterior con <líder> + j
vim.keymap.set("n", "<leader>j", ":bprevious<CR>")

-- Cerrar el buffer actual con <líder> + q
vim.keymap.set("n", "<leader>q", ":bdelete<CR>")

-- Crear una ventana nueva con <líder> + t
vim.keymap.set("n", "<leader>t", ":tabe<CR>")

-- Hacer un split vertical con <líder> + vs
vim.keymap.set("n", "<leader>vs", ":vsp<CR>")

-- Hacer un split horizontal con <líder> + sp
vim.keymap.set("n", "<leader>sp", ":sp<CR>")

-- Copia al portapapeles.
vim.keymap.set({ "n", "x" }, "gy", '"+y')

-- Pegar desde el portapapeles.
vim.keymap.set({ "n", "x" }, "gp", '"+p')

-- Cortar al porta papeles con <líder> + d
vim.keymap.set({ "n", "x" }, "gp", '"+d')

-- Abrir NERDTree <líder> + n
vim.keymap.set("n", "<leader>n", ":NERDTreeToggle<CR>")

-- Split de terminal <c-t>
vim.keymap.set("n", "<c-t>", ":split<CR>:ter<CR>:resize 15<CR>")
