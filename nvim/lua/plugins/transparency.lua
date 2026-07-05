-- Transparent background so Ghostty's background-opacity / background-blur
-- show through inside Neovim.
--
-- ROLLBACK: delete this file (or `git clean -f lua/plugins/transparency.lua`)
-- and restart Neovim.
--
-- This registers a ColorScheme autocmd at startup (top-level side effect when
-- lazy.nvim imports the plugin spec), so it fires whenever the colorscheme is
-- applied — including reloads — without redefining the colorscheme plugin spec.

local function make_transparent()
  for _, group in ipairs({
    "Normal",
    "NormalNC",
    "NormalFloat",
    "FloatBorder",
    "SignColumn",
    "EndOfBuffer",
    "MsgArea",
    -- File explorer (neo-tree) so the sidebar matches
    "NeoTreeNormal",
    "NeoTreeNormalNC",
    "NeoTreeEndOfBuffer",
  }) do
    vim.api.nvim_set_hl(0, group, { bg = "none" })
  end
end

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = make_transparent,
})

-- In case the colorscheme is already active by the time this loads.
make_transparent()

return {}
