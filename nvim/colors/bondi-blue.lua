-- Bondi Blue theme (Dark+ inspired, boho Australian coastal palette)
vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "bondi-blue"

-- Color palette — boho coastal
local colors = {
  -- Base colors
  bg = "#11161D",            -- Warm charcoal night
  fg = "#E5D8C8",            -- Raw linen

  -- UI colors
  bg_highlight = "#1C2330",  -- Rattan shadow
  bg_visual = "#272E3C",     -- Woven basket dark
  border = "#333A48",        -- Driftwood grey

  -- Coastal tones
  comment = "#7A8595",       -- Weathered timber
  driftwood = "#C9A96E",     -- Sun-bleached driftwood
  sandstone = "#8D7E6A",     -- Worn sandstone
  shell = "#D4B896",         -- Cowrie shell

  -- Water colors (muted, seen through linen curtains)
  sage = "#7DB89A",          -- Coastal sage bush
  dusty_teal = "#6AACA5",   -- Sea glass
  soft_blue = "#8AABC2",    -- Faded indigo linen
  washed_cyan = "#7BBFB8",  -- Tide-washed turquoise

  -- Warm accents
  terracotta = "#CC7B5E",    -- Terracotta pot
  bright_terra = "#DDA088",  -- Sunlit terracotta
  dusty_rose = "#C0849A",   -- Dried native flowers
  ochre = "#B87D4A",        -- Aboriginal ochre

  -- Sky colors
  golden_hour = "#DDB96A",  -- Late afternoon through pandanus

  -- Semantic colors
  error = "#C97060",         -- Muted terracotta red
  warning = "#DDB96A",       -- Golden hour
  success = "#7DB89A",       -- Sage
  info = "#8AABC2",          -- Soft blue

  -- Bright variants
  bright_coral = "#E0A890",
  bright_green = "#96CCAE",
  bright_yellow = "#EDD48A",
  bright_blue = "#A8C4D8",
  bright_teal = "#90D0C8",
  bright_fg = "#F0E5D8",
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
hi("Cursor", { fg = colors.bg, bg = colors.driftwood })
hi("CursorLine", { bg = colors.bg_highlight })
hi("CursorLineNr", { fg = colors.driftwood })
hi("LineNr", { fg = colors.comment })
hi("SignColumn", { fg = colors.comment, bg = colors.bg })
hi("StatusLine", { fg = colors.fg, bg = colors.bg_highlight })
hi("StatusLineNC", { fg = colors.comment, bg = colors.bg_highlight })
hi("TabLine", { fg = colors.comment, bg = colors.bg_highlight })
hi("TabLineFill", { bg = colors.bg_highlight })
hi("TabLineSel", { fg = colors.fg, bg = colors.bg })
hi("VertSplit", { fg = colors.border })
hi("Visual", { bg = colors.bg_visual })
hi("Search", { fg = colors.bg, bg = colors.golden_hour })
hi("IncSearch", { fg = colors.bg, bg = colors.driftwood })
hi("Pmenu", { fg = colors.fg, bg = colors.bg_highlight })
hi("PmenuSel", { fg = colors.bg, bg = colors.driftwood })
hi("PmenuSbar", { bg = colors.bg_highlight })
hi("PmenuThumb", { bg = colors.border })

-- Syntax highlighting (Dark+ structure, boho warmth)
hi("Comment", { fg = colors.comment, gui = "italic" })
hi("Constant", { fg = colors.terracotta })
hi("String", { fg = colors.terracotta })             -- Terracotta strings (Dark+ orange)
hi("Character", { fg = colors.bright_terra })
hi("Number", { fg = colors.sage })                   -- Coastal sage (Dark+ green)
hi("Boolean", { fg = colors.soft_blue })             -- Faded indigo (Dark+ blue)
hi("Float", { fg = colors.sage })
hi("Identifier", { fg = colors.bright_blue })
hi("Function", { fg = colors.driftwood })            -- Sun-bleached driftwood (Dark+ yellow)
hi("Statement", { fg = colors.dusty_rose })
hi("Conditional", { fg = colors.dusty_rose })        -- Dried flowers (Dark+ purple)
hi("Repeat", { fg = colors.dusty_rose })
hi("Label", { fg = colors.dusty_rose })
hi("Operator", { fg = colors.fg })
hi("Keyword", { fg = colors.soft_blue })             -- Faded indigo (Dark+ blue keywords)
hi("Exception", { fg = colors.dusty_rose })
hi("PreProc", { fg = colors.bright_yellow })
hi("Include", { fg = colors.dusty_rose })
hi("Define", { fg = colors.dusty_rose })
hi("Macro", { fg = colors.bright_yellow })
hi("PreCondit", { fg = colors.dusty_rose })
hi("Type", { fg = colors.dusty_teal })              -- Sea glass (Dark+ teal types)
hi("StorageClass", { fg = colors.soft_blue })
hi("Structure", { fg = colors.dusty_teal })
hi("Typedef", { fg = colors.dusty_teal })
hi("Special", { fg = colors.bright_coral })
hi("SpecialChar", { fg = colors.bright_coral })
hi("Tag", { fg = colors.soft_blue })
hi("Delimiter", { fg = colors.sandstone })
hi("SpecialComment", { fg = colors.comment, gui = "italic" })
hi("Debug", { fg = colors.error })
hi("Underlined", { gui = "underline" })
hi("Ignore", { fg = colors.comment })
hi("Error", { fg = colors.error })
hi("Todo", { fg = colors.golden_hour, gui = "bold" })

-- Treesitter
hi("@variable", { fg = colors.bright_blue })        -- Washed blue variables
hi("@variable.builtin", { fg = colors.soft_blue })   -- Faded indigo for this/self
hi("@variable.parameter", { fg = colors.bright_blue })
hi("@variable.member", { fg = colors.bright_blue })
hi("@constant", { fg = colors.soft_blue })
hi("@constant.builtin", { fg = colors.soft_blue })
hi("@module", { fg = colors.bright_blue })
hi("@label", { fg = colors.dusty_rose })
hi("@string", { fg = colors.terracotta })            -- Terracotta strings
hi("@string.escape", { fg = colors.bright_terra })
hi("@string.regexp", { fg = colors.bright_terra })
hi("@character", { fg = colors.bright_terra })
hi("@number", { fg = colors.sage })                  -- Sage green numbers
hi("@boolean", { fg = colors.soft_blue })            -- Faded indigo booleans
hi("@float", { fg = colors.sage })
hi("@function", { fg = colors.driftwood })           -- Driftwood gold functions
hi("@function.builtin", { fg = colors.driftwood })
hi("@function.macro", { fg = colors.bright_yellow })
hi("@function.method", { fg = colors.driftwood })
hi("@constructor", { fg = colors.driftwood })
hi("@keyword", { fg = colors.soft_blue })            -- Faded indigo keywords
hi("@keyword.function", { fg = colors.soft_blue })
hi("@keyword.operator", { fg = colors.soft_blue })
hi("@keyword.return", { fg = colors.dusty_rose })    -- Dried flowers for return
hi("@keyword.import", { fg = colors.dusty_rose })    -- Dried flowers for import/export
hi("@operator", { fg = colors.fg })
hi("@punctuation.bracket", { fg = colors.sandstone })
hi("@punctuation.delimiter", { fg = colors.sandstone })
hi("@type", { fg = colors.dusty_teal })              -- Sea glass types
hi("@type.builtin", { fg = colors.dusty_teal })
hi("@attribute", { fg = colors.dusty_teal })
hi("@property", { fg = colors.bright_blue })         -- Washed blue properties
hi("@tag", { fg = colors.soft_blue })                -- Faded indigo tags
hi("@tag.attribute", { fg = colors.bright_blue })    -- Washed blue tag attributes
hi("@tag.delimiter", { fg = colors.comment })        -- Weathered timber angle brackets

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
hi("TelescopeSelectionCaret", { fg = colors.driftwood })
hi("TelescopeMatching", { fg = colors.driftwood, gui = "bold" })

-- Neo-tree
hi("NeoTreeNormal", { fg = colors.fg, bg = colors.bg })
hi("NeoTreeNormalNC", { fg = colors.fg, bg = colors.bg })
hi("NeoTreeDirectoryIcon", { fg = colors.soft_blue })
hi("NeoTreeDirectoryName", { fg = colors.soft_blue })
hi("NeoTreeFileName", { fg = colors.fg })
hi("NeoTreeFileNameOpened", { fg = colors.driftwood })
hi("NeoTreeGitAdded", { fg = colors.bright_green })
hi("NeoTreeGitModified", { fg = colors.warning })
hi("NeoTreeGitDeleted", { fg = colors.error })
hi("NeoTreeGitUntracked", { fg = colors.bright_green })
hi("NeoTreeGitIgnored", { fg = colors.comment })
hi("NeoTreeGitConflict", { fg = colors.bright_coral })
hi("NeoTreeGitUnstaged", { fg = colors.warning })
hi("NeoTreeGitStaged", { fg = colors.bright_green })

-- Snacks Explorer
hi("SnacksPickerPathHidden", { fg = colors.ochre })
hi("SnacksPickerPathIgnored", { fg = colors.ochre })
hi("SnacksPickerGitStatusUntracked", { fg = colors.bright_green })
hi("SnacksPickerGitStatusAdded", { fg = colors.bright_green })
hi("SnacksPickerGitStatusModified", { fg = colors.warning })
hi("SnacksPickerGitStatusDeleted", { fg = colors.error })
hi("SnacksPickerGitStatusStaged", { fg = colors.bright_green })

-- Which-key
hi("WhichKey", { fg = colors.driftwood })
hi("WhichKeyGroup", { fg = colors.soft_blue })
hi("WhichKeyDesc", { fg = colors.fg })
hi("WhichKeySeparator", { fg = colors.comment })

-- Dashboard
hi("DashboardHeader", { fg = colors.driftwood })
hi("DashboardCenter", { fg = colors.soft_blue })
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
hi("RainbowDelimiterRed", { fg = colors.terracotta })
hi("RainbowDelimiterYellow", { fg = colors.driftwood })
hi("RainbowDelimiterBlue", { fg = colors.soft_blue })
hi("RainbowDelimiterOrange", { fg = colors.ochre })
hi("RainbowDelimiterGreen", { fg = colors.dusty_teal })
hi("RainbowDelimiterViolet", { fg = colors.dusty_rose })
hi("RainbowDelimiterCyan", { fg = colors.washed_cyan })
