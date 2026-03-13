return {
  "HiPhish/rainbow-delimiters.nvim",
  event = "VeryLazy",
  config = function()
    local rainbow = require("rainbow-delimiters")
    vim.g.rainbow_delimiters = {
      strategy = {
        [""] = rainbow.strategy["global"],
      },
      query = {
        [""] = "rainbow-delimiters",
        -- Use parentheses-only query for markup languages
        html = "rainbow-parens",
        tsx = "rainbow-parens",
        jsx = "rainbow-parens",
        xml = "rainbow-parens",
      },
    }
  end,
}
