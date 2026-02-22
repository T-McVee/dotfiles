return {
  {
    "desert-oasis-night",
    dir = vim.fn.stdpath("config") .. "/colors",
    lazy = false,
    priority = 1000,
    config = function()
      vim.cmd([[colorscheme desert-oasis-night]])
    end,
  },
}
