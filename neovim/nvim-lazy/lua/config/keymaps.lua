-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Guardar con w
vim.keymap.set("n", "w", ":w<CR>")

-- Cerrar con q
vim.keymap.set("n", "q", ":q<CR>")

-- Terminar la busqueda
vim.keymap.set("n", "<c-b>", ":nohlsearch<CR>")
