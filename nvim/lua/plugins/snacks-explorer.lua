return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          hidden = false,
          ignored = false,
        },
      },
      win = {
        input = {
          keys = {
            ["<c-x>"] = { "toggle_hidden", mode = { "i", "n" } },
            ["<a-x>"] = { "toggle_ignored", mode = { "i", "n" } },
          },
        },
      },
    },
  },
}
