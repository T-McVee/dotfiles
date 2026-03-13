-- Desert Oasis Dusk theme (Dark+ inspired variant)
vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "desert-oasis-dusk"

-- Color palette
local colors = {
  -- Base colors
  bg = "#0D1B26",
  fg = "#F5E8D8",

  -- UI colors
  bg_highlight = "#1F3A4F",
  bg_visual = "#2A4A5F",
  border = "#2D4A5E",

  -- Text colors
  comment = "#7D99B5",
  sand = "#E8C48A",
  clay = "#A38B6F",

  -- Accent colors
  oasis = "#5CB5A5",
  coral = "#D99B8B",
  copper = "#B5856B",
  teal = "#7BC3C3",

  -- Dark+ inspired additions
  mauve = "#C4879B",        -- Dusty rose for control flow (replaces Dark+'s purple)
  bright_mauve = "#D9A0B3", -- Brighter variant

  -- Semantic colors
  error = "#E89B7D",
  warning = "#F0C878",
  success = "#7DC39B",
  info = "#8BB3D9",

  -- Bright variants
  bright_coral = "#F0B099",
  bright_green = "#99D9B5",
  bright_yellow = "#FFD98F",
  bright_blue = "#A3C9E8",
  bright_teal = "#99D9D9",
  bright_fg = "#FFF5E8",
}

-- Helper function to set highlights
local function hi(group, opts)
  local cmd = "hi " .. group
  if opts.fg then
    cmd = cmd .. " guifg=" .. opts.fg
  end
  if opts.bg then
    cmd = cmd .. " guibg=" .. opts.bg
  end
  if opts.gui then
    cmd = cmd .. " gui=" .. opts.gui
  end
  if opts.sp then
    cmd = cmd .. " guisp=" .. opts.sp
  end
  vim.cmd(cmd)
end

-- Editor UI
hi("Normal", { fg = colors.fg, bg = colors.bg })
hi("NormalFloat", { fg = colors.fg, bg = colors.bg_highlight })
hi("FloatBorder", { fg = colors.border, bg = colors.bg_highlight })
hi("ColorColumn", { bg = colors.bg_highlight })
hi("Cursor", { fg = colors.bg, bg = colors.sand })
hi("CursorLine", { bg = colors.bg_highlight })
hi("CursorLineNr", { fg = colors.sand })
hi("LineNr", { fg = colors.comment })
hi("SignColumn", { fg = colors.comment, bg = colors.bg })
hi("StatusLine", { fg = colors.fg, bg = colors.bg_highlight })
hi("StatusLineNC", { fg = colors.comment, bg = colors.bg_highlight })
hi("TabLine", { fg = colors.comment, bg = colors.bg_highlight })
hi("TabLineFill", { bg = colors.bg_highlight })
hi("TabLineSel", { fg = colors.fg, bg = colors.bg })
hi("VertSplit", { fg = colors.border })
hi("Visual", { bg = colors.bg_visual })
hi("Search", { fg = colors.bg, bg = colors.warning })
hi("IncSearch", { fg = colors.bg, bg = colors.sand })
hi("Pmenu", { fg = colors.fg, bg = colors.bg_highlight })
hi("PmenuSel", { fg = colors.bg, bg = colors.sand })
hi("PmenuSbar", { bg = colors.bg_highlight })
hi("PmenuThumb", { bg = colors.border })

-- Syntax highlighting
-- Dark+ mapping: keywords=blue, control flow=purple, strings=orange, functions=yellow, types=teal
hi("Comment", { fg = colors.comment, gui = "italic" })
hi("Constant", { fg = colors.coral })
hi("String", { fg = colors.coral })               -- Dark+ uses orange for strings
hi("Character", { fg = colors.bright_coral })
hi("Number", { fg = colors.success })              -- Dark+ uses light green for numbers
hi("Boolean", { fg = colors.info })                -- Dark+ uses blue for booleans
hi("Float", { fg = colors.success })
hi("Identifier", { fg = colors.bright_blue })
hi("Function", { fg = colors.sand })               -- Dark+ uses yellow for functions
hi("Statement", { fg = colors.mauve })
hi("Conditional", { fg = colors.mauve })           -- Dark+ uses purple for control flow
hi("Repeat", { fg = colors.mauve })
hi("Label", { fg = colors.mauve })
hi("Operator", { fg = colors.fg })                 -- Dark+ uses white-ish for operators
hi("Keyword", { fg = colors.info })                -- Dark+ uses blue for keywords
hi("Exception", { fg = colors.mauve })
hi("PreProc", { fg = colors.bright_yellow })
hi("Include", { fg = colors.mauve })               -- Dark+ uses purple for import
hi("Define", { fg = colors.mauve })
hi("Macro", { fg = colors.bright_yellow })
hi("PreCondit", { fg = colors.mauve })
hi("Type", { fg = colors.oasis })                  -- Dark+ uses teal for types
hi("StorageClass", { fg = colors.info })
hi("Structure", { fg = colors.oasis })
hi("Typedef", { fg = colors.oasis })
hi("Special", { fg = colors.bright_coral })
hi("SpecialChar", { fg = colors.bright_coral })
hi("Tag", { fg = colors.info })
hi("Delimiter", { fg = colors.clay })
hi("SpecialComment", { fg = colors.comment, gui = "italic" })
hi("Debug", { fg = colors.error })
hi("Underlined", { gui = "underline" })
hi("Ignore", { fg = colors.comment })
hi("Error", { fg = colors.error })
hi("Todo", { fg = colors.warning, gui = "bold" })

-- Treesitter
hi("@variable", { fg = colors.bright_blue })       -- Dark+ light blue variables
hi("@variable.builtin", { fg = colors.info })       -- Dark+ blue for this/self
hi("@variable.parameter", { fg = colors.bright_blue }) -- Dark+ light blue for params
hi("@variable.member", { fg = colors.bright_blue }) -- Dark+ light blue for members
hi("@constant", { fg = colors.info })               -- Dark+ blue for constants
hi("@constant.builtin", { fg = colors.info })
hi("@module", { fg = colors.bright_blue })
hi("@label", { fg = colors.mauve })
hi("@string", { fg = colors.coral })               -- Dark+ orange strings
hi("@string.escape", { fg = colors.bright_coral })
hi("@string.regexp", { fg = colors.bright_coral })
hi("@character", { fg = colors.bright_coral })
hi("@number", { fg = colors.success })              -- Dark+ light green numbers
hi("@boolean", { fg = colors.info })                -- Dark+ blue booleans
hi("@float", { fg = colors.success })
hi("@function", { fg = colors.sand })               -- Dark+ yellow functions
hi("@function.builtin", { fg = colors.sand })
hi("@function.macro", { fg = colors.bright_yellow })
hi("@function.method", { fg = colors.sand })
hi("@constructor", { fg = colors.sand })
hi("@keyword", { fg = colors.info })                -- Dark+ blue keywords (const, let, class)
hi("@keyword.function", { fg = colors.info })       -- function, =>
hi("@keyword.operator", { fg = colors.info })       -- typeof, instanceof
hi("@keyword.return", { fg = colors.mauve })        -- Dark+ purple for return (control flow)
hi("@keyword.import", { fg = colors.mauve })        -- Dark+ purple for import/export
hi("@operator", { fg = colors.fg })                 -- Dark+ white-ish operators
hi("@punctuation.bracket", { fg = colors.clay })
hi("@punctuation.delimiter", { fg = colors.clay })
hi("@type", { fg = colors.oasis })                  -- Dark+ teal for types
hi("@type.builtin", { fg = colors.oasis })
hi("@attribute", { fg = colors.oasis })
hi("@property", { fg = colors.bright_blue })        -- Dark+ light blue for properties
hi("@tag", { fg = colors.info })                    -- Dark+ blue for HTML/JSX tags
hi("@tag.attribute", { fg = colors.bright_blue })   -- Dark+ light blue for attributes
hi("@tag.delimiter", { fg = colors.comment })       -- Gray angle brackets

-- LSP
hi("DiagnosticError", { fg = colors.error })
hi("DiagnosticWarn", { fg = colors.warning })
hi("DiagnosticInfo", { fg = colors.info })
hi("DiagnosticHint", { fg = colors.success })
hi("DiagnosticUnderlineError", { sp = colors.error, gui = "underline" })
hi("DiagnosticUnderlineWarn", { sp = colors.warning, gui = "underline" })
hi("DiagnosticUnderlineInfo", { sp = colors.info, gui = "underline" })
hi("DiagnosticUnderlineHint", { sp = colors.success, gui = "underline" })

-- Git signs
hi("GitSignsAdd", { fg = colors.success })
hi("GitSignsChange", { fg = colors.warning })
hi("GitSignsDelete", { fg = colors.error })

-- Telescope
hi("TelescopeBorder", { fg = colors.border })
hi("TelescopePromptBorder", { fg = colors.border })
hi("TelescopeResultsBorder", { fg = colors.border })
hi("TelescopePreviewBorder", { fg = colors.border })
hi("TelescopeSelection", { fg = colors.fg, bg = colors.bg_visual })
hi("TelescopeSelectionCaret", { fg = colors.sand })
hi("TelescopeMatching", { fg = colors.sand, gui = "bold" })

-- Neo-tree
hi("NeoTreeNormal", { fg = colors.fg, bg = colors.bg })
hi("NeoTreeNormalNC", { fg = colors.fg, bg = colors.bg })
hi("NeoTreeDirectoryIcon", { fg = colors.info })
hi("NeoTreeDirectoryName", { fg = colors.info })
hi("NeoTreeFileName", { fg = colors.fg })
hi("NeoTreeFileNameOpened", { fg = colors.sand })
hi("NeoTreeGitAdded", { fg = colors.bright_green })
hi("NeoTreeGitModified", { fg = colors.warning })
hi("NeoTreeGitDeleted", { fg = colors.error })
hi("NeoTreeGitUntracked", { fg = colors.bright_green })
hi("NeoTreeGitIgnored", { fg = colors.comment })
hi("NeoTreeGitConflict", { fg = colors.bright_coral })
hi("NeoTreeGitUnstaged", { fg = colors.warning })
hi("NeoTreeGitStaged", { fg = colors.bright_green })

-- Snacks Explorer
hi("SnacksPickerPathHidden", { fg = colors.copper })
hi("SnacksPickerPathIgnored", { fg = colors.copper })
hi("SnacksPickerGitStatusUntracked", { fg = colors.bright_green })
hi("SnacksPickerGitStatusAdded", { fg = colors.bright_green })
hi("SnacksPickerGitStatusModified", { fg = colors.warning })
hi("SnacksPickerGitStatusDeleted", { fg = colors.error })
hi("SnacksPickerGitStatusStaged", { fg = colors.bright_green })

-- Which-key
hi("WhichKey", { fg = colors.sand })
hi("WhichKeyGroup", { fg = colors.info })
hi("WhichKeyDesc", { fg = colors.fg })
hi("WhichKeySeparator", { fg = colors.comment })

-- Dashboard
hi("DashboardHeader", { fg = colors.sand })
hi("DashboardCenter", { fg = colors.info })
hi("DashboardFooter", { fg = colors.comment, gui = "italic" })

-- Notify
hi("NotifyERRORBorder", { fg = colors.error })
hi("NotifyWARNBorder", { fg = colors.warning })
hi("NotifyINFOBorder", { fg = colors.info })
hi("NotifyDEBUGBorder", { fg = colors.comment })
hi("NotifyTRACEBorder", { fg = colors.success })
hi("NotifyERRORTitle", { fg = colors.error })
hi("NotifyWARNTitle", { fg = colors.warning })
hi("NotifyINFOTitle", { fg = colors.info })
hi("NotifyDEBUGTitle", { fg = colors.comment })
hi("NotifyTRACETitle", { fg = colors.success })

-- Rainbow delimiters
hi("RainbowDelimiterRed", { fg = colors.coral })
hi("RainbowDelimiterYellow", { fg = colors.sand })
hi("RainbowDelimiterBlue", { fg = colors.info })
hi("RainbowDelimiterOrange", { fg = colors.copper })
hi("RainbowDelimiterGreen", { fg = colors.oasis })
hi("RainbowDelimiterViolet", { fg = colors.mauve })
hi("RainbowDelimiterCyan", { fg = colors.teal })
