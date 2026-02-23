-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

local map = vim.keymap.set

-- VS Code-like save (Ctrl+S)
map("n", "<C-s>", "<cmd>w<cr>", { desc = "Save File" })
