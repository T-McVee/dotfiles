-- Desert Oasis Night theme
vim.cmd("hi clear")
if vim.fn.exists("syntax_on") then
  vim.cmd("syntax reset")
end

vim.g.colors_name = "desert-oasis-night"

-- Color palette
local colors = {
  -- Base colors
  bg = "#142735",
  fg = "#F5E8D8", -- Brighter from #E8D5B7

  -- UI colors
  bg_highlight = "#1F3A4F",
  bg_visual = "#2A4A5F",
  border = "#2D4A5E",

  -- Text colors
  comment = "#7D99B5", -- Brighter from #6B8299
  sand = "#E8C48A", -- Brighter from #D4A574
  clay = "#A38B6F", -- Brighter from #8B7355

  -- Accent colors
  oasis = "#5CB5A5", -- Brighter from #4A9B8E
  coral = "#D99B8B", -- Brighter from #C17767
  copper = "#B5856B", -- Brighter from #9B6B4F
  teal = "#7BC3C3", -- Brighter from #5BA3A3

  -- Semantic colors
  error = "#E89B7D", -- Brighter from #D97757
  warning = "#F0C878", -- Brighter from #E8B563
  success = "#7DC39B", -- Brighter from #6BA383
  info = "#8BB3D9", -- Brighter from #6B9BC3

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
hi("Comment", { fg = colors.comment, gui = "italic" })
hi("Constant", { fg = colors.coral })
hi("String", { fg = colors.teal })
hi("Character", { fg = colors.bright_teal })
hi("Number", { fg = colors.coral })
hi("Boolean", { fg = colors.coral })
hi("Float", { fg = colors.coral })
hi("Identifier", { fg = colors.sand })
hi("Function", { fg = colors.info })
hi("Statement", { fg = colors.oasis })
hi("Conditional", { fg = colors.oasis })
hi("Repeat", { fg = colors.oasis })
hi("Label", { fg = colors.oasis })
hi("Operator", { fg = colors.copper })
hi("Keyword", { fg = colors.oasis })
hi("Exception", { fg = colors.error })
hi("PreProc", { fg = colors.bright_yellow })
hi("Include", { fg = colors.oasis })
hi("Define", { fg = colors.oasis })
hi("Macro", { fg = colors.bright_yellow })
hi("PreCondit", { fg = colors.oasis })
hi("Type", { fg = colors.warning })
hi("StorageClass", { fg = colors.oasis })
hi("Structure", { fg = colors.warning })
hi("Typedef", { fg = colors.warning })
hi("Special", { fg = colors.bright_coral })
hi("SpecialChar", { fg = colors.bright_coral })
hi("Tag", { fg = colors.info })
hi("Delimiter", { fg = colors.fg })
hi("SpecialComment", { fg = colors.comment, gui = "italic" })
hi("Debug", { fg = colors.error })
hi("Underlined", { gui = "underline" })
hi("Ignore", { fg = colors.comment })
hi("Error", { fg = colors.error })
hi("Todo", { fg = colors.warning, gui = "bold" })

-- Treesitter
hi("@variable", { fg = colors.fg })
hi("@variable.builtin", { fg = colors.coral })
hi("@variable.parameter", { fg = colors.sand })
hi("@variable.member", { fg = colors.sand })
hi("@constant", { fg = colors.coral })
hi("@constant.builtin", { fg = colors.coral })
hi("@module", { fg = colors.info })
hi("@label", { fg = colors.oasis })
hi("@string", { fg = colors.teal })
hi("@string.escape", { fg = colors.bright_teal })
hi("@string.regexp", { fg = colors.bright_teal })
hi("@character", { fg = colors.bright_teal })
hi("@number", { fg = colors.coral })
hi("@boolean", { fg = colors.coral })
hi("@float", { fg = colors.coral })
hi("@function", { fg = colors.info })
hi("@function.builtin", { fg = colors.bright_blue })
hi("@function.macro", { fg = colors.bright_yellow })
hi("@function.method", { fg = colors.info })
hi("@constructor", { fg = colors.warning })
hi("@keyword", { fg = colors.oasis })
hi("@keyword.function", { fg = colors.oasis })
hi("@keyword.operator", { fg = colors.oasis })
hi("@keyword.return", { fg = colors.oasis })
hi("@operator", { fg = colors.copper })
hi("@punctuation.bracket", { fg = colors.fg })
hi("@punctuation.delimiter", { fg = colors.fg })
hi("@type", { fg = colors.warning })
hi("@type.builtin", { fg = colors.warning })
hi("@attribute", { fg = colors.bright_yellow })
hi("@property", { fg = colors.sand })
hi("@tag", { fg = colors.info })
hi("@tag.attribute", { fg = colors.sand })
hi("@tag.delimiter", { fg = colors.fg })

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
hi("NeoTreeGitAdded", { fg = colors.bright_green }) -- Changed from colors.success
hi("NeoTreeGitModified", { fg = colors.warning })
hi("NeoTreeGitDeleted", { fg = colors.error })
hi("NeoTreeGitUntracked", { fg = colors.bright_green }) -- Added for untracked files
hi("NeoTreeGitIgnored", { fg = colors.comment }) -- Added for ignored files
hi("NeoTreeGitConflict", { fg = colors.bright_coral }) -- Added for conflicts
hi("NeoTreeGitUnstaged", { fg = colors.warning }) -- Added for unstaged changes
hi("NeoTreeGitStaged", { fg = colors.bright_green }) -- Added for staged files
-- hi("NeoTreeNormal", { fg = colors.fg, bg = colors.bg })
-- hi("NeoTreeNormalNC", { fg = colors.fg, bg = colors.bg })
-- hi("NeoTreeDirectoryIcon", { fg = colors.info })
-- hi("NeoTreeDirectoryName", { fg = colors.info })
-- hi("NeoTreeFileName", { fg = colors.fg })
-- hi("NeoTreeFileNameOpened", { fg = colors.sand })
-- hi("NeoTreeGitAdded", { fg = colors.success })
-- hi("NeoTreeGitModified", { fg = colors.warning })
-- hi("NeoTreeGitDeleted", { fg = colors.error })

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
