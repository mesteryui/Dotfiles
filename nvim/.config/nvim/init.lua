vim.cmd("set expandtab")
vim.cmd("set tabstop=2")
vim.cmd("set softtabstop=2")
vim.cmd("set shiftwidth=2")
vim.g.mapleader= ","
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)
local plugins = {
   { "catppuccin/nvim", lazy = false, name = "catppuccin", priority = 1000 },
   {
    'nvim-telescope/telescope.nvim', tag = '0.1.6',
-- or                              , branch = '0.1.x',
      dependencies = { 'nvim-lua/plenary.nvim' }
    },
    {'kaarmu/typst.vim'},
{"nvim-treesitter/nvim-treesitter", build = ":TSUpdate"},
{
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",}
}

}
local opts = {}
require("lazy").setup(plugins, opts)
local builtin = require("telescope.builtin")
vim.keymap.set('n', '<C-f>', builtin.find_files, {})
require("catppuccin").setup()
vim.cmd.colorscheme "catppuccin"
vim.keymap.set('n', '<leader>s', builtin.live_grep, {})
vim.keymap.set('n', '<leader>f', ':Neotree filesystem reveal left<CR>')
local config = require("nvim-treesitter.configs")
config.setup({
  ensure_installed = {"lua", "python", "typst", "org"},
  highlight = { enable = true },
  indent = { enable = true },
})
