return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "scss", "css" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        cssls = {},
      },
    },
  },
}
