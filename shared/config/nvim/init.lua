-- Helpers {{{

local function augroup(name)
    return vim.api.nvim_create_augroup("Tsp" .. name, { clear = true })
end

local function map(mode, lhs, rhs, opts)
    vim.keymap.set(mode, lhs, rhs, opts or {})
end

if vim.nonnil then
    vim.F.if_nil = vim.nonnil
end

local loaded_packs = {}
local setup_once_state = {}

local function ensure_pack(name)
    if loaded_packs[name] then
        return
    end

    vim.cmd("packadd " .. name)
    loaded_packs[name] = true
end

local function ensure_packs(names)
    for _, name in ipairs(names) do
        ensure_pack(name)
    end
end

local function setup_once(name, callback)
    if setup_once_state[name] then
        return
    end

    callback()
    setup_once_state[name] = true
end

vim.api.nvim_create_autocmd("PackChanged", {
    callback = function(ev)
        local data = ev.data
        if data.spec.name ~= "tau.nvim" then
            return
        end
        if data.kind ~= "install" and data.kind ~= "update" then
            return
        end

        local result = vim.system({ "bun", "run", "build" }, {
            cwd = data.path .. "/cli",
            text = true,
        }):wait()

        if result.code ~= 0 then
            local output = vim.trim(
                (result.stderr and result.stderr ~= "") and result.stderr or (result.stdout or "")
            )
            if output == "" then
                output = ("bun run build exited with code %d"):format(result.code)
            end
            vim.notify(
                ("tau.nvim: failed to build cli/tau\n%s"):format(output),
                vim.log.levels.ERROR
            )
        end
    end,
})

vim.pack.add({ tau_spec }, {
    load = function() end,
})
-- }}}

-- Options {{{
vim.g.mapleader = " "
vim.g.maplocalleader = " "
vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1
vim.opt.guicursor = ""
vim.opt.scrolloff = 0
vim.opt.scrolljump = -50

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = -1
vim.opt.shiftwidth = 4
vim.opt.expandtab = true
vim.opt.autoindent = true

vim.opt.wrap = false

vim.opt.swapfile = false
vim.opt.backup = false
vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"
vim.opt.undofile = true

vim.opt.hlsearch = false
vim.opt.incsearch = true

vim.opt.termguicolors = true

-- vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")
vim.opt.updatetime = 50
vim.opt.colorcolumn = "80"

vim.opt.foldmethod = "marker"
vim.opt.foldmarker = "{{{,}}}"
vim.opt.foldenable = true
vim.opt.foldlevelstart = 0

vim.api.nvim_create_autocmd("FileType", {
    pattern = { "typst", "markdown", "text" },
    callback = function()
        vim.opt_local.textwidth = 80
    end,
})

-- }}}

-- Gruber Darker {{{
-- Vendored from qwlp/gruber-darker.nvim so the theme is not a plugin dependency.
package.preload["gruber-darker.color"] = function()
    ---@class Color
    ---@field private value integer|nil
    local Color = {}
    Color.__index = Color

    ---Create a new color
    ---@param value integer
    ---@return Color
    function Color.new(value)
        local color = setmetatable({
            value = value,
        }, Color)
        return color
    end

    ---Create the "NONE" color
    ---@return Color
    function Color.none()
        local color = setmetatable({
            value = nil,
        }, Color)
        return color
    end

    ---Get hexadecimal color value as a string
    ---@return string
    function Color:to_string()
        if self.value == nil then
            return "NONE"
        end

        -- special edge case for BLACK where
        -- "#0" is returned, which is invalid to Neovim
        if self.value == 0 then
            return "#000000"
        end

        return string.format("#%x", self.value)
    end

    return Color
end

package.preload["gruber-darker.config"] = function()
    ---@alias ItalicType
    ---|"strings"
    ---|"comments"
    ---|"operators"
    ---|"folds"

    ---@alias InvertType
    ---|"signs"
    ---|"tabline"
    ---|"visual"

    ---@class GruberDarkerOpts
    ---@field bold boolean
    ---@field invert table<InvertType, boolean>
    ---@field italic table<ItalicType, boolean>
    ---@field undercurl boolean
    ---@field underline boolean

    ---@type GruberDarkerOpts
    local DEFAULTS = {
        bold = true,
        invert = {
            signs = false,
            tabline = false,
            visual = false,
        },
        italic = {
            strings = true,
            comments = true,
            operators = false,
            folds = true,
        },
        undercurl = true,
        underline = true,
    }

    ---@class ConfigMgr
    ---@field private resolved_opts GruberDarkerOpts
    local ConfigMgr = {}
    ConfigMgr.__index = ConfigMgr

    ---@type ConfigMgr|nil
    local instance = nil

    ---Get GruberDarker user preferences
    ---@return GruberDarkerOpts
    ---@nodiscard
    function ConfigMgr.get_opts()
        if instance ~= nil then
            return instance.resolved_opts
        end

        return DEFAULTS
    end

    ---Set GruberDarker colorscheme options
    ---@param opts? GruberDarkerOpts
    function ConfigMgr.setup(opts)
        if instance ~= nil then
            return
        end

        instance = setmetatable({
            resolved_opts = vim.tbl_deep_extend("force", DEFAULTS, opts or {}),
        }, ConfigMgr)
    end

    return ConfigMgr
end

package.preload["gruber-darker.palette"] = function()
    local Color = require("gruber-darker.color")
    local M = {}

    ---@type table<string, Color>
    M = {
        none = Color.none(),
        fg = Color.new(0xe4e4e4),
        ["fg+1"] = Color.new(0xf4f4ff),
        ["fg+2"] = Color.new(0xf5f5f5),
        white = Color.new(0xffffff),
        black = Color.new(0x000000),
        ["bg-1"] = Color.new(0x101010),
        bg = Color.new(0x000000),
        -- bg = Color.new(0x181818),
        ["bg+1"] = Color.new(0x282828),
        ["bg+2"] = Color.new(0x453d41),
        ["bg+3"] = Color.new(0x484848),
        ["bg+4"] = Color.new(0x52494e),
        ["red-1"] = Color.new(0xc73c3f),
        red = Color.new(0xf43841),
        ["red+1"] = Color.new(0xff4f58),
        green = Color.new(0x73d936),
        yellow = Color.new(0xffdd33),
        brown = Color.new(0xcc8c3c),
        quartz = Color.new(0x95a99f),
        ["niagara-2"] = Color.new(0x303540),
        ["niagara-1"] = Color.new(0x565f73),
        niagara = Color.new(0x96a6c8),
        wisteria = Color.new(0x9e95c7),
        tspmatch = Color.new(0x2b293b),
    }

    return M
end

package.preload["gruber-darker.highlight"] = function()
    ---@class HighlightOpts
    ---@field fg Color foreground
    ---@field bg Color background
    ---@field sp Color special
    ---@field blend integer value between 0 and 100
    ---@field bold boolean
    ---@field standout boolean
    ---@field underline boolean
    ---@field undercurl boolean
    ---@field underdouble boolean
    ---@field underdotted boolean
    ---@field underdashed boolean
    ---@field strikethrough boolean
    ---@field italic boolean
    ---@field reverse boolean
    ---@field nocombine boolean
    ---@field link Highlight
    ---@field default any Don't override existing definition
    ---@field ctermfg any
    ---@field ctermbg any
    ---@field cterm any

    ---Get highlight definition map accepted by `nvim_set_hl`
    ---@param opts HighlightOpts
    ---@return table<string, any>
    local function get_hl_definition_map(opts)
        local hl = {}

        for key, value in pairs(opts) do
            if key == "fg" or key == "bg" or key == "sp" then
                hl[key] = value:to_string()
            elseif key == "link" then
                hl[key] = value.group
            else
                hl[key] = value
            end
        end

        return hl
    end

    ---@class Highlight
    ---@field private group string
    ---@field private opts HighlightOpts
    local Highlight = {}
    Highlight.__index = Highlight

    ---Create a new highlight
    ---@param group string
    ---@param opts HighlightOpts
    ---@return Highlight
    function Highlight.new(group, opts)
        local highlight = setmetatable({
            group = group,
            opts = opts,
        }, Highlight)
        return highlight
    end

    ---Set global highlight for the group this is associated with
    function Highlight:setup()
        -- print(self.group)
        vim.api.nvim_set_hl(0, self.group, get_hl_definition_map(self.opts))
    end

    return Highlight
end

package.preload["gruber-darker.highlights.colorscheme"] = function()
    local Highlight = require("gruber-darker.highlight")
    local c = require("gruber-darker.palette")
    local opts = require("gruber-darker.config").get_opts()

    ---@type HighlightsProvider
    local M = {
        highlights = {},
    }

    ---Set GruberDarker-specific highlights
    function M.setup()
        for _, value in pairs(M.highlights) do
            value:setup()
        end
    end

    -- Highlights inspired by
    -- https://github.com/ellisonleao/gruvbox.nvim/blob/main/lua/gruvbox/groups.lua#L43

    -- Colors

    M.highlights.fg0 = Highlight.new("GruberDarkerFg0", { fg = c.fg })
    M.highlights.fg1 = Highlight.new("GruberDarkerFg1", { fg = c["fg+1"] })
    M.highlights.fg2 = Highlight.new("GruberDarkerFg2", { fg = c["fg+2"] })

    M.highlights.bg_1 = Highlight.new("GruberDarkerBg_1", { fg = c["bg-1"] })
    M.highlights.bg0 = Highlight.new("GruberDarkerBg0", { fg = c.bg })
    M.highlights.bg1 = Highlight.new("GruberDarkerBg1", { fg = c["bg+1"] })
    M.highlights.bg2 = Highlight.new("GruberDarkerBg2", { fg = c["bg+2"] })
    M.highlights.bg3 = Highlight.new("GruberDarkerBg3", { fg = c["bg+3"] })
    M.highlights.bg4 = Highlight.new("GruberDarkerBg4", { fg = c["bg+4"] })

    M.highlights.dark_red = Highlight.new("GruberDarkerDarkRed", { fg = c["red-1"] })
    M.highlights.dark_red_bold = Highlight.new("GruberDarkerDarkRedBold", { fg = c["red-1"], bold = opts.bold })
    M.highlights.red = Highlight.new("GruberDarkerRed", { fg = c.red })
    M.highlights.red_bold = Highlight.new("GruberDarkerRedBold", { fg = c.red, bold = opts.bold })
    M.highlights.light_red = Highlight.new("GruberDarkerLightRed", { fg = c["red+1"] })
    M.highlights.light_red_bold = Highlight.new("GruberDarkerLightRedBold", { fg = c["red+1"], bold = opts.bold })

    M.highlights.green = Highlight.new("GruberDarkerGreen", { fg = c.green })
    M.highlights.green_bold = Highlight.new("GruberDarkerGreenBold", { fg = c.green, bold = opts.bold })

    M.highlights.yellow = Highlight.new("GruberDarkerYellow", { fg = c.yellow })
    M.highlights.yellow_bold = Highlight.new("GruberDarkerYellowBold", { fg = c.yellow, bold = opts.bold })

    M.highlights.brown = Highlight.new("GruberDarkerBrown", { fg = c.brown })
    M.highlights.brown_bold = Highlight.new("GruberDarkerBrownBold", { fg = c.brown, bold = opts.bold })

    M.highlights.quartz = Highlight.new("GruberDarkerQuartz", { fg = c.quartz })
    M.highlights.quartz_bold = Highlight.new("GruberDarkerQuartzBold", { fg = c.quartz, bold = opts.bold })

    M.highlights.darker_niagara = Highlight.new("GruberDarkerDarkestNiagara", { fg = c["niagara-2"] })
    M.highlights.darker_niagara_bold =
        Highlight.new("GruberDarkerDarkestNiagaraBold", { fg = c["niagara-2"], bold = opts.bold })
    M.highlights.dark_niagara = Highlight.new("GruberDarkerDarkNiagara", { fg = c["niagara-1"] })
    M.highlights.dark_niagara_bold = Highlight.new("GruberDarkerDarkNiagaraBold",
        { fg = c["niagara-1"], bold = opts.bold })
    M.highlights.niagara = Highlight.new("GruberDarkerNiagara", { fg = c.niagara })
    M.highlights.niagara_bold = Highlight.new("GruberDarkerNiagaraBold", { fg = c.niagara, bold = opts.bold })

    M.highlights.wisteria = Highlight.new("GruberDarkerWisteria", { fg = c.wisteria })
    M.highlights.wisteria_bold = Highlight.new("GruberDarkerWisteriaBold", { fg = c.wisteria, bold = opts.bold })

    -- Signs

    M.highlights.red_sign = Highlight.new("GruberDarkerRedSign", { fg = c.red, reverse = opts.invert.signs })
    M.highlights.yellow_sign = Highlight.new("GruberDarkerYellowSign", { fg = c.yellow, reverse = opts.invert.signs })
    M.highlights.green_sign = Highlight.new("GruberDarkerGreenSign", { fg = c.green, reverse = opts.invert.signs })
    M.highlights.quartz_sign = Highlight.new("GruberDarkerQuartzSign", { fg = c.quartz, reverse = opts.invert.signs })
    M.highlights.niagara_sign = Highlight.new("GruberDarkerNiagaraSign", { fg = c.niagara, reverse = opts.invert.signs })
    M.highlights.wisteria_sign = Highlight.new("GruberDarkerWisteriaSign",
        { fg = c.wisteria, reverse = opts.invert.signs })

    -- Underlines

    M.highlights.red_underline = Highlight.new("GruberDarkerRedUnderline", { sp = c.red, undercurl = opts.undercurl })
    M.highlights.yellow_underline =
        Highlight.new("GruberDarkerYellowUnderline", { sp = c.yellow, undercurl = opts.undercurl })
    M.highlights.green_underline = Highlight.new("GruberDarkerGreenUnderline",
        { sp = c.green, undercurl = opts.undercurl })
    M.highlights.quartz_underline =
        Highlight.new("GruberDarkerQuartzUnderline", { sp = c.quartz, undercurl = opts.undercurl })
    M.highlights.niagara_underline =
        Highlight.new("GruberDarkerNiagaraUnderline", { sp = c.niagara, undercurl = opts.undercurl })
    M.highlights.wisteria_underline =
        Highlight.new("GruberDarkerWisteriaUnderline", { sp = c.wisteria, undercurl = opts.undercurl })

    return M
end

package.preload["gruber-darker.highlights.vim"] = function()
    local Highlight = require("gruber-darker.highlight")
    local c = require("gruber-darker.palette")
    local opts = require("gruber-darker.config").get_opts()
    local gruber_hl = require("gruber-darker.highlights.colorscheme").highlights

    ---@type HighlightsProvider
    local M = {
        highlights = {},
    }

    ---Set standard Vim highlights
    function M.setup()
        for _, value in pairs(M.highlights) do
            value:setup()
        end
    end

    ---Any comment
    M.highlights.comment = Highlight.new("Comment", { fg = c.brown, italic = opts.italic.comments })
    ---Used for the columns set with 'colorcolumn'
    M.highlights.color_column = Highlight.new("ColorColumn", { bg = c["bg+2"] })
    ---Placeholder characters substituted for concealed text (see 'conceallevel')
    M.highlights.conceal = Highlight.new("Conceal", { fg = c.fg, bg = c.bg })
    ---Character under the cursor
    M.highlights.cursor = Highlight.new("Cursor", { bg = c.yellow })
    ---The character under the cursor when |language-mapping| is used (see 'guicursor')
    M.highlights.l_cursor = Highlight.new("lCursor", { fg = c.none, bg = c.yellow })
    ---Like Cursor, but used when in IME mode |CursorIM|
    M.highlights.cursor_im = Highlight.new("CursorIM", { fg = c.none, bg = c.yellow })
    ---Screen-column at the cursor, when 'cursorcolumn' is set.
    M.highlights.cursor_column = Highlight.new("CursorColumn", { bg = c["bg+2"] })
    ---Screen-line at the cursor, when 'cursorline' is set.  Low-priority if foreground (ctermfg OR guifg) is not set.
    M.highlights.cursor_line = Highlight.new("CursorLine", { bg = c["bg+1"] })
    ---Directory names (and other special names in listings)
    M.highlights.directory = Highlight.new("Directory", { link = gruber_hl.niagara_bold })

    ---Diff mode: Added line |diff.txt|
    M.highlights.diff_add = Highlight.new("DiffAdd", { fg = c.green, bg = c.none })
    ---Diff mode: Changed line |diff.txt|
    M.highlights.diff_change = Highlight.new("DiffChange", { fg = c.yellow, bg = c.none })
    ---Diff mode: Deleted line |diff.txt|
    M.highlights.diff_delete = Highlight.new("DiffDelete", { fg = c["red+1"], bg = c.none })
    ---Diff mode: Changed text within a changed line |diff.txt|
    M.highlights.diff_text = Highlight.new("DiffText", { fg = c.yellow, bg = c.none })

    ---Fugitive highlights; might need separate provider for git related plugins
    M.highlights.diff_added = Highlight.new("diffAdded", { link = M.highlights.diff_add })
    M.highlights.diff_removed = Highlight.new("diffRemoved", { link = M.highlights.diff_delete })
    M.highlights.diff_line = Highlight.new("diffLine", { link = M.highlights.diff_change })

    ---Gitsigns highlights
    M.highlights.git_signs_add = Highlight.new("GitSignsAdd", { link = M.highlights.diff_add })
    M.highlights.git_signs_change = Highlight.new("GitSignsChange", { link = M.highlights.diff_change })
    M.highlights.git_signs_delete = Highlight.new("GitSignsDelete", { link = M.highlights.diff_delete })

    ---Filler lines (~) after the end of the buffer.  By, this is highlighted like |hl-NonText|.
    M.highlights.end_of_buffer = Highlight.new("EndOfBuffer", { fg = c["bg+4"], bg = c.none })
    ---Cursor in a focused terminal
    M.highlights.term_cursor = Highlight.new("TermCursor", { bg = c.yellow })
    ---TermCursorNC= { }, ---cursor in an unfocused terminal

    ---Error messages on the command line
    M.highlights.error_msg = Highlight.new("ErrorMsg", { fg = c.white, bg = c.red })
    ---The column separating vertically split windows
    M.highlights.vert_split = Highlight.new("VertSplit", { fg = c["fg+2"], bg = c["bg+1"] })
    ---The column separating vertically split windows
    M.highlights.win_separator = Highlight.new("WinSeparator", { fg = c["bg+2"], bold = opts.bold })
    ---Line used for closed folds
    M.highlights.folded = Highlight.new("Folded", { fg = c.brown, bg = c["bg+2"], italic = opts.italic.folds })
    ---'foldcolumn'
    M.highlights.fold_column = Highlight.new("FoldColumn", { fg = c.brown, bg = c["bg+2"] })
    ---column where |signs| are displayed
    M.highlights.sign_column = Highlight.new("SignColumn", { fg = c["bg+2"], bg = c.none })
    ---SignColumnSB = Highlight.new("SignColumnSB", { bg = c.bg_sidebar, fg = c.fg_gutter }) ---column where |signs| are displayed
    ---Substitute = Highlight.new("Substitute", { bg = c.red, fg = c.black }) ---|:substitute| replacement text highlighting
    ---Line number for ":number" and ":#" commands, and when 'number' or 'relativenumber' option is set.
    M.highlights.line_number = Highlight.new("LineNr", { fg = c["bg+4"] })
    ---Like LineNr when 'cursorline' or 'relativenumber' is set for the cursor line.
    M.highlights.cursor_line_number = Highlight.new("CursorLineNr", { fg = c.yellow })
    ---The character under the cursor or just before it, if it is a paired bracket, and its match. |pi_paren.txt|
    M.highlights.match_paren = Highlight.new("MatchParen", { fg = c.fg, bg = c.tspmatch })
    ---'showmode' message (e.g., "---INSERT ---")
    M.highlights.mode_msg = Highlight.new("ModeMsg", { link = gruber_hl.fg2 })
    ---Area for messages and cmdline
    -- M.highlights.msg_area = Highlight.new("MsgArea", { fg = c.fg_dark })
    ---Separator for scrolled messages, `msgsep` flag of 'display'
    -- M.highlights.msg_separator = Highlight.new("MsgSeparator", { }),
    ---|more-prompt|
    M.highlights.more_msg = Highlight.new("MoreMsg", { fg = c["fg+2"] })
    ---'@' at the end of the window, characters from 'showbreak' and other characters that do not really exist in the text (e.g., ">" displayed when a double-wide character doesn't fit at the end of the line). See also |hl-EndOfBuffer|.
    M.highlights.non_text = Highlight.new("NonText", { link = M.highlights.end_of_buffer })
    ---Normal text
    M.highlights.normal = Highlight.new("Normal", { fg = c.fg, bg = c.bg })
    ---Normal text in non-current windows
    M.highlights.normal_non_current = Highlight.new("NormalNC", { fg = c.fg, bg = c.bg })
    ---Normal text in sidebar
    M.highlights.normal_sidebar = Highlight.new("NormalSB", { fg = c.fg, bg = c["bg-1"] })
    ---Normal text in floating windows.
    M.highlights.normal_float = Highlight.new("NormalFloat", { fg = c.fg, bg = c["bg+1"] })
    M.highlights.float_border = Highlight.new("FloatBorder", { fg = c["bg+4"], bg = c.none })

    -- Popup

    ---Popup menu: normal item.
    M.highlights.popup_menu = Highlight.new("Pmenu", { fg = c.fg, bg = c["bg+1"] })
    ---Popup menu: selected item.
    M.highlights.popup_menu_sel = Highlight.new("PmenuSel", { fg = c.fg, bg = c["bg+2"] })
    ---Popup menu: scrollbar.
    M.highlights.popup_menu_sidebar = Highlight.new("PmenuSbar", { bg = c.bg })
    ---Popup menu: Thumb of the scrollbar.
    M.highlights.popup_menu_thumb = Highlight.new("PmenuThumb", { bg = c.bg })

    ---|hit-enter| prompt and yes/no questions
    M.highlights.question = Highlight.new("Question", { fg = c.niagara })
    ---Current |quickfix| item in the quickfix window. Combined with |hl-CursorLine| when the cursor is there.
    M.highlights.quick_fix_line = Highlight.new("QuickFixLine", { bg = c["bg+2"], bold = opts.bold })

    -- Search

    ---Last search pattern highlighting (see 'hlsearch').  Also used for similar items that need to stand out.
    M.highlights.search = Highlight.new("Search", { fg = c["niagara-1"], bg = c["fg+1"] })
    ---'incsearch' highlighting; also used for the text replaced with ":s///c"
    M.highlights.incremental_search = Highlight.new("IncSearch", { fg = c.black, bg = c["fg+2"] })
    M.highlights.current_search = Highlight.new("CurSearch", { link = M.highlights.incremental_search })

    ---Unprintable characters: text displayed differently from what it really is.  But not 'listchars' whitespace. |hl-Whitespace|
    M.highlights.special_key = Highlight.new("SpecialKey", { fg = c["fg+2"] })

    -- Spell

    ---Word that is not recognized by the spellchecker. |spell| Combined with the highlighting used otherwise.
    M.highlights.spell_bad = Highlight.new("SpellBad", { link = gruber_hl.red_underline })
    ---Word that should start with a capital. |spell| Combined with the highlighting used otherwise.
    M.highlights.spell_cap = Highlight.new("SpellCap", { undercurl = opts.undercurl })
    ---Word that is recognized by the spellchecker as one that is used in another region. |spell| Combined with the highlighting used otherwise.
    M.highlights.spell_local = Highlight.new("SpellLocal", { undercurl = opts.undercurl })
    ---Word that is recognized by the spellchecker as one that is hardly ever used.  |spell| Combined with the highlighting used otherwise.
    M.highlights.spell_rare = Highlight.new("SpellRare", { undercurl = opts.undercurl })

    -- Statusline

    ---Status line of current window
    M.highlights.status_line = Highlight.new("StatusLine", { fg = c.white, bg = c["bg+1"] })
    ---Status lines of not-current windows Note: if this is equal to "StatusLine" Vim will use "^^^" in the status line of the current window.
    M.highlights.status_line_non_current = Highlight.new("StatusLineNC", { fg = c.quartz, bg = c["bg+1"] })

    -- Tabline

    ---Tab pages line, not active tab page label
    M.highlights.tab_line = Highlight.new("TabLine", { bg = c.none })
    ---Tab pages line, where there are no labels
    M.highlights.tab_line_fill = Highlight.new("TabLineFill", { fg = c["bg+4"], bg = c["bg+1"] })
    ---Tab pages line, active tab page label
    M.highlights.tab_line_sel = Highlight.new("TabLineSel", { fg = c.yellow, bg = c.none, bold = opts.bold })

    ---Titles for output from ":set all", ":autocmd" etc.
    M.highlights.title = Highlight.new("Title", { link = gruber_hl.quartz })
    ---Visual mode selection
    M.highlights.visual = Highlight.new("Visual", { bg = c["bg+2"], reverse = opts.invert.visual })
    ---Visual mode selection when vim is "Not Owning the Selection".
    M.highlights.visual_nos = Highlight.new("VisualNOS", { link = gruber_hl.red })
    ---Warning messages
    M.highlights.warning_msg = Highlight.new("WarningMsg", { link = gruber_hl.red })
    ---"nbsp", "space", "tab" and "trail" in 'listchars'
    M.highlights.whitespace = Highlight.new("Whitespace", { fg = c["bg+4"], bg = c.none })
    ---Current match in 'wildmenu' completion
    M.highlights.wild_menu = Highlight.new("WildMenu", { fg = c.black, bg = c.yellow })
    ---These groups are not listed as vim groups,
    ---but they are defacto standard group names for syntax highlighting.
    ---commented out groups should chain up to their "preferred" group by
    --,
    ---Uncomment and edit if you want more specific syntax highlighting.

    ---(preferred) any constant
    M.highlights.constant = Highlight.new("Constant", { link = gruber_hl.quartz })
    ---A string constant: "this is a string"
    M.highlights.string = Highlight.new("String", { fg = c.green, italic = opts.italic.strings })
    ---A character constant: 'c', '\n'
    M.highlights.character = Highlight.new("Character", { fg = c.green, italic = opts.italic.strings })
    ---A number constant: 234, 0xff
    M.highlights.number = Highlight.new("Number", { link = gruber_hl.wisteria })
    ---A boolean constant: TRUE, false
    M.highlights.boolean = Highlight.new("Boolean", { link = gruber_hl.yellow_bold })
    ---A floating point constant: 2.3e10
    M.highlights.float = Highlight.new("Float", { link = gruber_hl.wisteria })
    ---(preferred) any variable name
    M.highlights.identifier = Highlight.new("Identifier", { link = gruber_hl.fg1 })
    ---Function name (also: methods for classes)
    M.highlights.func = Highlight.new("Function", { link = gruber_hl.niagara })
    ---(preferred) any statement
    M.highlights.statement = Highlight.new("Statement", { fg = c.yellow })
    ---If, then, else, endif, switch, etc.
    M.highlights.conditional = Highlight.new("Conditional", { link = gruber_hl.yellow_bold })
    ---For, do, while, etc.
    M.highlights.repeats = Highlight.new("Repeat", { link = gruber_hl.yellow_bold })
    ---Case,, etc.
    M.highlights.label = Highlight.new("Label", { link = gruber_hl.yellow_bold })
    ---"sizeof", "+", "*", etc.
    M.highlights.operator = Highlight.new("Operator", { fg = c.fg, italic = opts.italic.operators })
    ---Any other keyword
    M.highlights.keyword = Highlight.new("Keyword", { link = gruber_hl.yellow_bold })
    ---Try, catch, throw
    M.highlights.exception = Highlight.new("Exception", { link = gruber_hl.yellow_bold })
    ---(preferred) generic Preprocessor
    M.highlights.pre_proc = Highlight.new("PreProc", { link = gruber_hl.quartz })
    ---Preprocessor #include
    M.highlights.include = Highlight.new("Include", { link = gruber_hl.quartz })
    ---Preprocessor #define
    M.highlights.define = Highlight.new("Define", { link = gruber_hl.quartz })
    ---Same as Define
    M.highlights.macro = Highlight.new("Macro", { link = gruber_hl.quartz })
    ---Preprocessor #if, #else, #endif, etc.
    M.highlights.pre_condit = Highlight.new("PreCondit", { link = gruber_hl.quartz })
    ---(preferred) int, long, char, etc.
    M.highlights.type = Highlight.new("Type", { link = gruber_hl.quartz })
    ---Static, register, volatile, etc.
    M.highlights.storage_class = Highlight.new("StorageClass", { link = gruber_hl.yellow_bold })
    ---Struct, union, enum, etc.
    M.highlights.structure = Highlight.new("Structure", { link = gruber_hl.yellow_bold })
    ---A typedef
    M.highlights.typedef = Highlight.new("Typedef", { link = gruber_hl.yellow_bold })
    ---(preferred) any special symbol
    M.highlights.special = Highlight.new("Special", { link = gruber_hl.yellow })
    --- special character in a constant
    M.highlights.special_char = Highlight.new("SpecialChar", { link = gruber_hl.yellow })
    ---You can use CTRL-] on this
    M.highlights.tag = Highlight.new("Tag", { link = gruber_hl.yellow })
    ---Character that needs attention
    M.highlights.delimiter = Highlight.new("Delimiter", { link = gruber_hl.fg0 })
    ---Special things inside a comment
    M.highlights.special_comment = Highlight.new("SpecialComment", { link = gruber_hl.wisteria_bold })
    ---Debugging statements
    M.highlights.debug = Highlight.new("Debug", { link = gruber_hl.fg2 })

    ---(preferred) text that stands out, HTML links
    M.highlights.underlined = Highlight.new("Underlined", { fg = c.wisteria, underline = opts.underline })
    M.highlights.bold = Highlight.new("Bold", { bold = opts.bold })
    M.highlights.italic = Highlight.new("Italic", { italic = true })
    ---("Ignore", below, may be invisible...)
    ---Ignore = Highlight.new("Ignore", { }) ---(preferred) left blank, hidden  |hl-Ignore|

    ---Error = Highlight.new("Error", { fg = c.error }) ---(preferred) any erroneous construct

    ---(preferred) anything that needs extra attention; mostly the keywords TODO FIXME and XXX
    M.highlights.todo = Highlight.new("Todo", { fg = c.bg, bg = c.yellow })

    -- Markdown

    M.highlights.md_heading_delim = Highlight.new("markdownHeadingDelimiter", { fg = c.niagara, bold = opts.bold })
    M.highlights.md_code = Highlight.new("markdownCode", { fg = c.green })
    M.highlights.md_code_block = Highlight.new("markdownCodeBlock", { fg = c.green })
    ---markdownH1 = Highlight.new("markdownH1", { fg = c.magenta, bold = true })
    ---markdownH2 = Highlight.new("markdownH2", { fg = c.blue, bold = true })
    ---markdownLinkText = Highlight.new("markdownLinkText", { fg = c.blue, underline = true })
    M.highlights.md_italic = Highlight.new("markdownItalic", { fg = c.wisteria, italic = true })
    M.highlights.md_bold = Highlight.new("markdownBold", { link = gruber_hl.yellow_bold })
    M.highlights.md_code_delim = Highlight.new("markdownCodeDelimiter", { fg = c.brown, italic = true })
    M.highlights.md_error = Highlight.new("markdownError", { fg = c.fg, bg = c["bg+1"] })

    return M
end

package.preload["gruber-darker.highlights.treesitter"] = function()
    local c = require("gruber-darker.palette")
    local opts = require("gruber-darker.config").get_opts()
    local vim_hl = require("gruber-darker.highlights.vim").highlights
    local gruber_hl = require("gruber-darker.highlights.colorscheme").highlights
    local Highlight = require("gruber-darker.highlight")

    ---@type HighlightsProvider
    local M = {
        highlights = {},
    }

    ---Set `nvim-treesitter` plugin highlights
    function M.setup()
        for _, value in pairs(M.highlights) do
            value:setup()
        end
    end

    -- Neovim tree-sitter highlights sourced from
    -- https://github.com/nvim-treesitter/nvim-treesitter/blob/master/CONTRIBUTING.md#highlights

    -- Misc

    ---Line and block comments
    M.highlights.comment = Highlight.new("@comment", { link = vim_hl.comment })
    ---Comments documenting code
    M.highlights.comment_documentation = Highlight.new("@comment.documentation",
        { link = gruber_hl.green, italic = opts.italic.comments })
    M.highlights.comment_luadoc = Highlight.new("@comment.luadoc", { link = M.highlights.comment_documentation })
    ---Syntax/parser errors
    M.highlights.error = Highlight.new("@error", {})
    ---Completely disable the highlight
    M.highlights.none = Highlight.new("@none", { fg = c.none, bg = c.none })
    ---Various preprocessor directives & shebangs
    M.highlights.pre_proc = Highlight.new("@preproc", { link = vim_hl.pre_proc })
    ---Preprocessor definition directives
    M.highlights.define = Highlight.new("@define", { link = vim_hl.define })
    ---Symbolic operators (e.g. `+` / `*`)
    M.highlights.operator = Highlight.new("@operator", { link = vim_hl.operator })

    -- Punctuation

    ---Delimiters (e.g. `;` / `.` / `,`)
    M.highlights.punctuation_delimiter = Highlight.new("@punctuation.delimiter", { link = vim_hl.delimiter })
    ---Brackets (e.g. `()` / `{}` / `[]`)
    M.highlights.punctuation_bracket = Highlight.new("@punctuation.bracket", { link = gruber_hl.wisteria })
    ---Special symbols (e.g. `{}` in string interpolation)
    M.highlights.punctuation_special = Highlight.new("@punctuation.special", { link = gruber_hl.brown })

    -- Literals

    ---String literals
    M.highlights.string = Highlight.new("@string", { link = vim_hl.string })
    ---String documenting code (e.g. Python docstrings)
    M.highlights.string_documentation = Highlight.new("@string.documentation", { link = vim_hl.string })
    ---Regular expressions
    M.highlights.string_regex = Highlight.new("@string.regex", { link = vim_hl.constant })
    ---Escape sequences
    M.highlights.string_escape = Highlight.new("@string.escape", { link = vim_hl.constant })
    ---Other special strings (e.g dates)
    M.highlights.string_special = Highlight.new("@string.special", { link = vim_hl.constant })

    ---Character literals
    M.highlights.character = Highlight.new("@character", { link = vim_hl.character })
    ---Special characters (e.g. wildcards)
    M.highlights.character_special = Highlight.new("@character.special", { link = vim_hl.constant })

    ---Boolean literals
    M.highlights.boolean = Highlight.new("@boolean", { link = vim_hl.boolean })
    ---Numeric literals
    M.highlights.number = Highlight.new("@number", { link = vim_hl.number })
    ---Floating-point number literals
    M.highlights.float = Highlight.new("@float", { link = vim_hl.float })

    -- Functions

    ---Function definitions
    M.highlights.func = Highlight.new("@function", { link = vim_hl.func })
    ---Built-in functions
    M.highlights.func_builtin = Highlight.new("@function.builtin", { link = gruber_hl.yellow })
    ---Function calls
    -- M.highlights.func_call = Highlight.new("@function.call", {})
    ---Preprocessor macros
    M.highlights.func_macro = Highlight.new("@function.macro", { link = vim_hl.macro })

    ---Method definitions
    M.highlights.method = Highlight.new("@method", { link = vim_hl.func })
    ---Method calls
    -- M.highlights.method_call = Highlight.new("@method.call", {})

    ---constructor calls and definitions
    M.highlights.constructor = Highlight.new("@constructor", { link = vim_hl.func })
    ---parameters of a function
    M.highlights.parameter = Highlight.new("@parameter", { link = vim_hl.identifier })

    -- Keywords

    ---various keywords
    M.highlights.keyword = Highlight.new("@keyword", { link = vim_hl.keyword })
    ---keywords related to coroutines (e.g. `go` in Go, `async/await` in Python)
    -- M.highlights.keyword_coroutine = Highlight.new("@keyword.coroutine", {})
    ---keywords that define a function (e.g. `func` in Go, `def` in Python)
    -- M.highlights.keyword_function = Highlight.new("@keyword.function", {})
    ---operators that are English words (e.g. `and` / `or`)
    -- M.highlights.keyword_operator = Highlight.new("@keyword.operator", {})
    ---keywords like `return` and `yield`
    -- M.highlights.keyword_return = Highlight.new("@keyword.return", {})

    ---keywords related to conditionals (e.g. `if` / `else`)
    M.highlights.conditional = Highlight.new("@conditional", { fg = c.yellow })
    ---ternary operator (e.g. `?` / `:`)
    M.highlights.conditional_ternary = Highlight.new("@conditional.ternary", {})

    ---keywords related to loops (e.g. `for` / `while`)
    M.highlights.repeats = Highlight.new("@repeat", { link = vim_hl.repeats })
    ---keywords related to debugging
    M.highlights.debug = Highlight.new("@debug", { link = vim_hl.debug })
    ---GOTO and other labels (e.g. `label:` in C)
    M.highlights.label = Highlight.new("@label", { link = vim_hl.label })
    ---keywords for including modules (e.g. `import` / `from` in Python)
    -- M.highlights.include = Highlight.new("@include", {})
    ---keywords related to exceptions (e.g. `throw` / `catch`)
    -- M.highlights.exception = Highlight.new("@exception", {})

    -- Types

    ---type or class definitions and annotations
    M.highlights.type = Highlight.new("@type", { link = vim_hl.type })
    ---built-in types
    M.highlights.type_builtin = Highlight.new("@type.builtin", { link = gruber_hl.yellow })
    ---type definitions (e.g. `typedef` in C)
    M.highlights.type_definition = Highlight.new("@type.definition", { link = vim_hl.typedef })
    ---type qualifiers (e.g. `const`)
    -- M.highlights.type_qualifier = Highlight.new("@type.qualifier", {})

    ---modifiers that affect storage in memory or life-time
    M.highlights.storage_class = Highlight.new("@storageclass", { link = vim_hl.storage_class })
    ---attribute annotations (e.g. Python decorators)
    -- I don't think this is supported anymore...
    -- M.highlights.attribute = Highlight.new("@attribute", { link = gruber_hl.brown })
    ---object and struct fields
    M.highlights.field = Highlight.new("@field", { link = gruber_hl.niagara })
    ---similar to `@field`
    M.highlights.property = Highlight.new("@property", { link = gruber_hl.dark_niagara })

    -- Identifiers

    ---various variable names
    M.highlights.variable = Highlight.new("@variable", { link = vim_hl.identifier })
    ---built-in variable names (e.g. `this`)
    M.highlights.variable_builtin = Highlight.new("@variable.builtin", { link = gruber_hl.yellow })

    ---constant identifiers
    M.highlights.constant = Highlight.new("@constant", { link = vim_hl.constant })
    ---built-in constant values
    M.highlights.constant_builtin = Highlight.new("@constant.builtin", { link = gruber_hl.yellow })
    ---constants defined by the preprocessor
    M.highlights.constant_macro = Highlight.new("@constant.macro", { link = vim_hl.define })

    ---modules or namespaces
    -- M.highlights.namespace = Highlight.new("@namespace", {})
    ---symbols or atoms
    -- M.highlights.symbol = Highlight.new("@symbol", {})

    -- Text (mainly for markup languages)

    ---non-structured text
    M.highlights.text = Highlight.new("@text", { link = vim_hl.normal })
    ---bold text
    M.highlights.text_strong = Highlight.new("@text.strong", { link = vim_hl.bold })
    ---text with emphasis
    M.highlights.text_emphasis = Highlight.new("@text.emphasis", { link = vim_hl.italic })
    ---underlined text
    M.highlights.text_underline = Highlight.new("@text.underline", { link = vim_hl.underlined })
    ---strikethrough text
    M.highlights.text_strike = Highlight.new("@text.strike", { strikethrough = true })
    ---text that is part of a title
    M.highlights.text_title = Highlight.new("@text.title", { link = vim_hl.title })
    ---literal or verbatim text (e.g., inline code)
    M.highlights.text_literal = Highlight.new("@text.literal", { link = vim_hl.constant })
    ---text quotations
    -- M.highlights.text_quote = Highlight.new("@text.quote", {})
    ---URIs (e.g. hyperlinks)
    M.highlights.text_uri = Highlight.new("@text.uri", { fg = c.niagara, underline = opts.underline })
    ---math environments (e.g. `$ ... $` in LaTeX)
    -- M.highlights.text_math = Highlight.new("@text.math", { link = vim_hl.special })
    ---text environments of markup languages
    -- M.highlights.text_environment = Highlight.new("@text.environment", {})
    ---text indicating the type of an environment
    -- M.highlights.text_environment_name = Highlight.new("@text.environment.name", {})
    ---text references, footnotes, citations, etc.
    M.highlights.text_reference = Highlight.new("@text.reference", { link = gruber_hl.yellow_bold })

    ---todo notes
    M.highlights.text_todo = Highlight.new("@text.todo", { link = vim_hl.todo })
    ---info notes
    M.highlights.text_note = Highlight.new("@text.note", { link = vim_hl.comment })
    ---warning notes
    M.highlights.text_warning = Highlight.new("@text.warning", { link = vim_hl.warning_msg })
    ---danger/error notes
    M.highlights.text_danger = Highlight.new("@text.danger", { link = vim_hl.error_msg })

    ---added text (for diff files)
    M.highlights.text_diff_add = Highlight.new("@text.diff.add", { link = vim_hl.diff_add })
    ---deleted text (for diff files)
    M.highlights.text_diff_delete = Highlight.new("@text.diff.delete", { link = vim_hl.diff_delete })
    M.highlights.text_diff_change = Highlight.new("@text.diff.change", { link = vim_hl.diff_change })

    -- Tags (used for XML-like tags)

    ---XML tag names
    M.highlights.tag = Highlight.new("@tag", { link = vim_hl.tag })
    ---XML tag attributes
    M.highlights.tag_attribute = Highlight.new("@tag.attribute", { link = M.highlights.field })
    ---XML tag delimiters
    M.highlights.tag_delimiter = Highlight.new("@tag.delimiter", { link = vim_hl.delimiter })

    return M
end

package.preload["gruber-darker.highlights.lsp"] = function()
    local Highlight = require("gruber-darker.highlight")
    local vim_hl = require("gruber-darker.highlights.vim").highlights
    local gruber_hl = require("gruber-darker.highlights.colorscheme").highlights

    ---@type HighlightsProvider
    local M = {
        highlights = {},
    }

    function M.setup()
        for _, value in pairs(M.highlights) do
            value:setup()
        end
    end

    M.highlights.diagnostic_error = Highlight.new("DiagnosticError", { link = gruber_hl.red_bold })
    M.highlights.diagnostic_sign_error = Highlight.new("DiagnosticSignError", { link = gruber_hl.red_sign })
    M.highlights.diagnostic_underline_error = Highlight.new("DiagnosticUnderlineError",
        { link = gruber_hl.red_underline })

    M.highlights.diagnostic_warn = Highlight.new("DiagnosticWarn", { link = gruber_hl.yellow_bold })
    M.highlights.diagnostic_sign_warn = Highlight.new("DiagnosticSignWarn", { link = gruber_hl.yellow_sign })
    M.highlights.diagnostic_underline_warn = Highlight.new("DiagnosticUnderlineWarn",
        { link = gruber_hl.yellow_underline })

    M.highlights.diagnostic_info = Highlight.new("DiagnosticInfo", { link = gruber_hl.green_bold })
    M.highlights.diagnostic_sign_info = Highlight.new("DiagnosticSignInfo", { link = gruber_hl.green_sign })
    M.highlights.diagnostic_underline_info = Highlight.new("DiagnosticUnderlineInfo",
        { link = gruber_hl.green_underline })

    M.highlights.diagnostic_hint = Highlight.new("DiagnosticHint", { link = gruber_hl.wisteria })
    M.highlights.diagnostic_sign_hint = Highlight.new("DiagnosticSignHint", { link = gruber_hl.wisteria_sign })
    M.highlights.diagnostic_underline_hint =
        Highlight.new("DiagnosticUnderlineHint", { link = gruber_hl.wisteria_underline })

    M.highlights.diagnostic_unnecessary = Highlight.new("DiagnosticUnnecessary",
        { link = M.highlights.diagnostic_underline_hint })

    ---LspSaga floating windows
    M.highlights.saga_normal = Highlight.new("SagaNormal", { link = vim_hl.normal_float })
    M.highlights.saga_border = Highlight.new("SagaBorder", { link = vim_hl.float_border })

    ---Used for highlighting "text" references
    -- M.highlights.lsp_reference_text = Highlight.new("LspReferenceText", {})
    ---Used for highlighting "read" references
    -- M.highlights.lsp_reference_read = Highlight.new("LspReferenceRead", {})
    ---Used for highlighting "write" references
    -- M.highlights.lsp_reference_write = Highlight.new("LspReferenceWrite", {})
    ---Used to color the virtual text of the codelens.
    -- M.highlights.lsp_code_lens = Highlight.new("LspCodeLens", {})
    ---Used to color the separator between two or more code lenses.
    -- M.highlights.lsp_code_lens_separator = Highlight.new("LspCodeLensSeparator", {})
    ---Used to highlight the active parameter in the signature help.
    -- M.highlights.lsp_signature_active_parameter = Highlight.new("LspSignatureActiveParameter", {})

    -- M.highlights.lsp_type_class = Highlight.new("@lsp.type.class", {})
    -- M.highlights.lsp_type_decorator = Highlight.new("@lsp.type.decorator", {})
    -- M.highlights.lsp_type_enum = Highlight.new("@lsp.type.enum", {})
    -- M.highlights.lsp_type_enum_member = Highlight.new("@lsp.type.enumMember", {})
    -- M.highlights.lsp_type_function = Highlight.new("@lsp.type.function", {})
    -- M.highlights.lsp_type_interface = Highlight.new("@lsp.type.interface", {})
    -- M.highlights.lsp_type_macro = Highlight.new("@lsp.type.macro", {})
    -- M.highlights.lsp_type_method = Highlight.new("@lsp.type.method", {})
    -- M.highlights.lsp_type_namespace = Highlight.new("@lsp.type.namespace", {})
    -- M.highlights.lsp_type_parameter = Highlight.new("@lsp.type.parameter", {})
    -- M.highlights.lsp_type_property = Highlight.new("@lsp.type.property", {})
    -- M.highlights.lsp_type_struct = Highlight.new("@lsp.type.struct", {})
    -- M.highlights.lsp_type_type = Highlight.new("@lsp.type.type", {})
    -- M.highlights.lsp_type_type_parameter = Highlight.new("@lsp.type.typeParameter", {})
    -- M.highlights.lsp_type_variable = Highlight.new("@lsp.type.variable", {})

    return M
end

package.preload["gruber-darker.highlights.terminal"] = function()
    local c = require("gruber-darker.palette")

    ---@type HighlightsProvider
    local M = {}

    ---Set Neovim terminal colors
    function M.setup()
        -- terminal colors adapted from
        -- https://github.com/drsooch/gruber-darker-vim/blob/master/colors/GruberDarker.vim#L202
        vim.g.terminal_color_0 = c["bg+1"]:to_string()
        vim.g.terminal_color_8 = c["bg+1"]:to_string()

        vim.g.terminal_color_1 = c["red+1"]:to_string()
        vim.g.terminal_color_9 = c["red+1"]:to_string()

        vim.g.terminal_color_2 = c.green:to_string()
        vim.g.terminal_color_10 = c.green:to_string()

        vim.g.terminal_color_3 = c.yellow:to_string()
        vim.g.terminal_color_11 = c.yellow:to_string()

        vim.g.terminal_color_4 = c.niagara:to_string()
        vim.g.terminal_color_12 = c.niagara:to_string()

        vim.g.terminal_color_5 = c.wisteria:to_string()
        vim.g.terminal_color_13 = c.wisteria:to_string()

        vim.g.terminal_color_6 = c.niagara:to_string()
        vim.g.terminal_color_14 = c.niagara:to_string()

        vim.g.terminal_color_7 = c.fg:to_string()
        vim.g.terminal_color_15 = c.fg:to_string()

        vim.g.terminal_color_background = c["bg+1"]:to_string()
        vim.g.terminal_color_foreground = c.white:to_string()
    end

    return M
end

package.preload["gruber-darker.highlights.cmp"] = function()
    local Highlight = require("gruber-darker.highlight")
    local c = require("gruber-darker.palette")
    local vim_hl = require("gruber-darker.highlights.vim").highlights
    local gruber_hl = require("gruber-darker.highlights.colorscheme").highlights

    ---@type HighlightsProvider
    local M = {
        highlights = {},
    }

    function M.setup()
        for _, value in pairs(M.highlights) do
            value:setup()
        end
    end

    M.highlights.cmp_item_kind = Highlight.new("CmpItemKind", { fg = c.white })
    M.highlights.cmp_item_menu = Highlight.new("CmpItemMenu", { fg = c.white })
    M.highlights.cmp_item_deprecated = Highlight.new("CmpItemAbbrDeprecated", { link = gruber_hl.darkest_niagara })
    M.highlights.cmp_item_abbr = Highlight.new("CmpItemAbbr", { fg = c.white })
    M.highlights.cmp_item_abbr_match = Highlight.new("CmpItemAbbrMatch", { link = gruber_hl.yellow_bold })
    M.highlights.cmp_item_abbr_match_fuzzy = Highlight.new("CmpItemAbbrMatchFuzzy", { link = gruber_hl.brown_bold })
    M.highlights.cmp_item_kind_text = Highlight.new("CmpItemKindText", { fg = c["fg+2"] })
    M.highlights.cmp_item_kind_method = Highlight.new("CmpItemKindMethod", { link = vim_hl.func })
    M.highlights.cmp_item_kind_function = Highlight.new("CmpItemKindFunction", { link = vim_hl.func })
    M.highlights.cmp_item_kind_constructor =
        Highlight.new("CmpItemKindConstructor", { link = vim_hl.func })
    M.highlights.cmp_item_kind_field = Highlight.new("CmpItemKindField", { link = gruber_hl.niagara })
    M.highlights.cmp_item_kind_variable = Highlight.new("CmpItemKindVariable", { link = vim_hl.identifier })
    M.highlights.cmp_item_kind_class = Highlight.new("CmpitemKindClass", { link = vim_hl.type })
    M.highlights.cmp_item_kind_interface = Highlight.new("CmpItemKindInterface", { link = vim_hl.type })
    M.highlights.cmp_item_kind_module = Highlight.new("CmpItemKindModule", { link = vim_hl.define })
    M.highlights.cmp_item_kind_property = Highlight.new("CmpItemKindProperty", { link = gruber_hl.dark_niagara })
    M.highlights.cmp_item_kind_unit = Highlight.new("CmpItemKindUnit", { link = gruber_hl.dark_niagara })
    M.highlights.cmp_item_kind_value = Highlight.new("CmpItemKindValue", { link = vim_hl.type })
    M.highlights.cmp_item_kind_enum = Highlight.new("CmpItemKindEnum", { link = vim_hl.type })
    M.highlights.cmp_item_kind_keywork = Highlight.new("CmpItemKindKeyword", { link = vim_hl.keyword })
    M.highlights.cmp_item_kind_snippet = Highlight.new("CmpItemKindSnippet", { link = gruber_hl.dark_niagara })
    M.highlights.cmp_item_kind_color = Highlight.new("CmpItemKindColor", { fg = c.yellow })
    M.highlights.cmp_item_kind_file = Highlight.new("CmpItemKindFile", { fg = c.wisteria })
    M.highlights.cmp_item_kind_reference = Highlight.new("CmpItemKindReference", { fg = c.wisteria })
    M.highlights.cmp_item_kind_folder = Highlight.new("CmpItemKindFolder", { fg = c.wisteria })
    M.highlights.cmp_item_kind_enum_member =
        Highlight.new("CmpItemKindEnumMember", { link = vim_hl.type })
    M.highlights.cmp_item_kind_constant = Highlight.new("CmpItemKindConstant", { link = vim_hl.constant })
    M.highlights.cmp_item_kind_struct = Highlight.new("CmpItemKindStruct", { link = gruber_hl.niagara })
    M.highlights.cmp_item_kind_event = Highlight.new("CmpItemKindEvent", { fg = c.brown })
    M.highlights.cmp_item_kind_operator = Highlight.new("CmpItemKindOperator", { link = vim_hl.operator })
    M.highlights.cmp_item_kind_type_parameter =
        Highlight.new("CmpItemKindTypeParameter", { link = vim_hl.identifier })

    return M
end

package.preload["gruber-darker.highlights.telescope"] = function()
    local Highlight = require("gruber-darker.highlight")
    local c = require("gruber-darker.palette")
    local vim_hl = require("gruber-darker.highlights.vim").highlights
    local gruber_hl = require("gruber-darker.highlights.colorscheme").highlights

    ---@type HighlightsProvider
    local M = {
        highlights = {},
    }

    function M.setup()
        for _, value in pairs(M.highlights) do
            value:setup()
        end
    end

    M.highlights.telescope_normal = Highlight.new("TelescopeNormal", { link = gruber_hl.fg })
    M.highlights.telescope_matching = Highlight.new("TelescopeMatching", { link = gruber_hl.yellow_bold })
    M.highlights.telescope_border = Highlight.new("TelescopeBorder", { link = vim_hl.float_border })
    M.highlights.telescope_prompt_prefix = Highlight.new("TelescopePromptPrefix", { link = gruber_hl.niagara })
    M.highlights.telescope_title = Highlight.new("TelescopeTitle", { fg = c.white })
    M.highlights.telescope_selection = Highlight.new("TelescopeSelection", { fg = c["fg+2"], bg = c["bg+1"] })
    M.highlights.telescope_multi_selection = Highlight.new("TelescopeMultiSelection", { link = vim_hl.cursor_line })
    M.highlights.telescope_selection_caret = Highlight.new("TelescopeSelectionCaret", { link = gruber_hl.yellow })

    return M
end

package.preload["gruber-darker.highlights.rainbow"] = function()
    local Highlight = require("gruber-darker.highlight")
    local c = require("gruber-darker.palette")

    ---@type HighlightsProvider
    local M = {
        highlights = {},
    }

    ---Set standard Vim highlights
    function M.setup()
        for _, value in pairs(M.highlights) do
            value:setup()
        end
    end

    M.highlights.rainbow_delimiter_red = Highlight.new("RainbowDelimiterRed", { fg = c["red+1"] })
    M.highlights.rainbow_delimiter_orange = Highlight.new("RainbowDelimiterOrange", { fg = c.brown })
    M.highlights.rainbow_delimiter_yellow = Highlight.new("RainbowDelimiterYellow", { fg = c.yellow })
    M.highlights.rainbow_delimiter_green = Highlight.new("RainbowDelimiterGreen", { fg = c.green })
    M.highlights.rainbow_delimiter_blue = Highlight.new("RainbowDelimiterBlue", { fg = c.niagara })
    M.highlights.rainbow_delimiter_violet = Highlight.new("RainbowDelimiterViolet", { fg = c.wisteria })
    M.highlights.rainbow_delimiter_cyan = Highlight.new("RainbowDelimiterCyan", { fg = c.quartz })

    return M
end

package.preload["gruber-darker.highlights"] = function()
    local M = {}

    ---@class HighlightsProvider
    ---@field highlights table<string, Highlight>
    ---@field setup fun() Set highlights

    ---@type HighlightsProvider[]
    local providers = {
        require("gruber-darker.highlights.colorscheme"),
        require("gruber-darker.highlights.lsp"),
        require("gruber-darker.highlights.vim"),
        require("gruber-darker.highlights.terminal"),
        require("gruber-darker.highlights.treesitter"),
        require("gruber-darker.highlights.cmp"),
        require("gruber-darker.highlights.telescope"),
        require("gruber-darker.highlights.rainbow"),
    }

    ---Set highlights for configured providers
    function M.setup()
        for _, provider in ipairs(providers) do
            provider:setup()
        end
        vim.opt.guicursor:append("a:Cursor/lCursor")
    end

    return M
end

package.preload["gruber-darker"] = function()
    local config = require("gruber-darker.config")

    local M = {}

    ---Delete GruberDarker autocmds when the
    ---theme changes to something else
    ---@package
    function M.on_colorscheme()
        vim.cmd([[autocmd! GruberDarker]])
        vim.cmd([[augroup! GruberDarker]])
    end

    local function create_autocmds()
        local gruber_darker_group = vim.api.nvim_create_augroup("GruberDarker", { clear = true })
        vim.api.nvim_create_autocmd("ColorSchemePre", {
            group = gruber_darker_group,
            pattern = "*",
            callback = function()
                require("gruber-darker").on_colorscheme()
            end,
        })

        vim.api.nvim_create_autocmd("FileType", {
            group = gruber_darker_group,
            pattern = "qf,help",
            callback = function()
                vim.cmd.setlocal("winhighlight=Normal:NormalSB,SignColumn:SignColumnSB")
            end,
        })

        -- This is a mitigation for new Nvim v0.9.0 lsp semantic highlights
        -- overriding treesitter highlights.
        -- TODO: link these to relevant treesitter groups in the future.
        -- See :h lsp-semantic-highlight
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = gruber_darker_group,
            pattern = "*",
            callback = function()
                -- Hide all semantic highlights
                for _, group in ipairs(vim.fn.getcompletion("@lsp", "highlight")) do
                    vim.api.nvim_set_hl(0, group, {})
                end
            end,
        })
    end

    ---Clear current highlights and set Neovim global `colors_name`
    function M.load()
        local highlights = require("gruber-darker.highlights")

        if vim.g.colors_name then
            vim.cmd.hi("clear")
        end

        vim.opt.termguicolors = true
        vim.g.colors_name = "gruber-darker"

        highlights.setup()

        create_autocmds()
    end

    ---Change colorscheme to GruberDarker
    function M.colorscheme() end

    ---GruberDarker configuration bootstrapper
    ---@param opts? GruberDarkerOpts
    function M.setup(opts)
        config.setup(opts)
    end

    return M
end

-- }}}

-- Naysayer {{{
-- Vendored from RostislavArts/naysayer.nvim so the theme is not a plugin dependency.
package.preload["colors.naysayer"] = function()
    -- naysayer.nvim - a Neovim colorscheme inspired by Emacs naysayer-theme
    -- Author: made by Rostislav Sobolevskiy based on Nick Aversano's Emacs theme

    local colors = {
        yellow = "#E6DB74",
        orange = "#FD971F",
        red = "#F92672",
        magenta = "#FD5FF0",
        blue = "#66D9EF",
        green = "#A6E22E",
        cyan = "#A1EFE4",
        violet = "#AE81FF",

        background = "#062329",
        gutter = "#062329",
        selection = "#1a4040",
        text = "#d0b892",
        comment = "#53d549",
        punctuation = "#8cde94",
        keyword = "#ffffff",
        variable = "#d0b892",
        function_ = "#d0b892",
        string = "#3ad0b5",
        constant = "#87ffde",
        macro = "#8cde94",
        number = "#87ffde",
        white = "#ffffff",
        error = "#ff0000",
        warning = "#ffaa00",
        highlight = "#0b3335",
        line_fg = "#126367",
        lualine_fg = "#12251b",
        lualine_bg = "#d3b58e",

        dimmed_keyword = "#b0b0b0",
        dimmed_function = "#cccccc",
        dimmed_variable = "#a0b8c8",
        dimmed_string = "#2fa89e",
        dimmed_type = "#79c4a6",
    }

    vim.cmd("highlight clear")
    vim.o.background = "dark"
    vim.g.colors_name = "naysayer"

    local set = vim.api.nvim_set_hl

    set(0, "Normal", { fg = colors.text, bg = colors.background })
    set(0, "Cursor", { bg = colors.white })
    set(0, "Visual", { bg = colors.selection })
    set(0, "LineNr", { fg = colors.line_fg, bg = colors.background })
    set(0, "CursorLineNr", { fg = colors.white, bg = colors.background })
    set(0, "CursorLine", { bg = colors.highlight })
    set(0, "ColorColumn", { bg = colors.highlight })
    set(0, "VertSplit", { fg = colors.line_fg })
    set(0, "MatchParen", { bg = colors.selection })

    set(0, "Comment", { fg = colors.comment })
    set(0, "String", { fg = colors.string })
    set(0, "Number", { fg = colors.number })
    set(0, "Boolean", { fg = colors.constant })
    set(0, "Constant", { fg = colors.constant })
    set(0, "Identifier", { fg = colors.variable })
    set(0, "Function", { fg = colors.function_ })
    set(0, "Statement", { fg = colors.keyword })
    set(0, "Keyword", { fg = colors.keyword })
    set(0, "Type", { fg = colors.punctuation })
    set(0, "PreProc", { fg = colors.macro })
    set(0, "Special", { fg = colors.orange })
    set(0, "WarningMsg", { fg = colors.warning })
    set(0, "Error", { fg = colors.error })

    set(0, "DiagnosticError", { fg = colors.red })
    set(0, "DiagnosticWarn", { fg = colors.warning })
    set(0, "DiagnosticInfo", { fg = colors.blue })
    set(0, "DiagnosticHint", { fg = colors.cyan })

    set(0, "rainbowcol1", { fg = colors.violet })
    set(0, "rainbowcol2", { fg = colors.blue })
    set(0, "rainbowcol3", { fg = colors.green })
    set(0, "rainbowcol4", { fg = colors.yellow })
    set(0, "rainbowcol5", { fg = colors.orange })
    set(0, "rainbowcol6", { fg = colors.red })

    set(0, "StatusLine", { fg = colors.lualine_fg, bg = colors.lualine_bg })
    set(0, "StatusLineNC", { fg = colors.line_fg, bg = colors.gutter })

    set(0, "@comment", { link = "Comment" })
    set(0, "@string", { link = "String" })
    set(0, "@number", { link = "Number" })
    set(0, "@boolean", { link = "Boolean" })
    set(0, "@constant", { link = "Constant" })
    set(0, "@function", { link = "Function" })
    set(0, "@function.builtin", { link = "Function" })
    set(0, "@variable", { link = "Identifier" })
    set(0, "@type", { link = "Type" })
    set(0, "@keyword", { link = "Keyword" })
    set(0, "@keyword.function", { link = "Keyword" })
    set(0, "@field", { link = "Identifier" })
    set(0, "@property", { link = "Identifier" })
    set(0, "@parameter", { link = "Identifier" })

    return colors
end

-- }}}
-- Diagnostics {{{
vim.diagnostic.config({
    virtual_text = {
        enabled = true,
        prefix = "●",
    },
    signs = true,
    float = {
        focusable = false,
        style = "minimal",
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
    },
})
-- }}}

-- Keymaps {{{
local has_compiled = false

local function compile_or_recompile()
    if vim.bo.filetype == "typst" then
        setup_once("typst-preview.nvim", function()
            ensure_pack("typst-preview.nvim")
            require("typst-preview").setup({
                invert_colors = "auto",
            })
        end)
        vim.cmd("TypstPreview")
        return
    end

    ensure_packs({ "plenary.nvim", "baleia.nvim", "compile-mode.nvim" })

    if has_compiled then
        vim.cmd.Recompile()
        return
    end

    vim.cmd.Compile()
    has_compiled = true
end

local function multiple_cursors(command)
    setup_once("multiple-cursors.nvim", function()
        ensure_pack("multiple-cursors.nvim")
        require("multiple-cursors").setup()
    end)

    vim.cmd(command)
end

local kitty_config = {
    config_path = vim.fn.expand("~/.config/kitty/kitty.conf"),
    theme_path = vim.fn.expand("~/.config/kitty/theme.conf"),
    fallback_transparency_enabled = false,
    fallback_theme = "solarized_dark",
}

local read_kitty_config

local function apply_theme_overrides(config)
    if not config.transparency_enabled then
        return
    end

    vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
    vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
    vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
    vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
    vim.api.nvim_set_hl(0, "StatusLine", { bg = "NONE" })
end

local function load_gruber_darker_theme()
    require("gruber-darker").load()
end

local function load_naysayer_theme()
    package.loaded["colors.naysayer"] = nil
    require("colors.naysayer")
end

read_kitty_config = function()
    local config = {
        transparency_enabled = kitty_config.fallback_transparency_enabled,
        theme = kitty_config.fallback_theme,
    }

    local ok, lines = pcall(vim.fn.readfile, kitty_config.theme_path)
    if not ok then
        ok, lines = pcall(vim.fn.readfile, kitty_config.config_path)
    end
    if not ok then
        return config
    end

    for _, line in ipairs(lines) do
        local transparency_enabled = line:match("^%s*#%s*tsp_transparency%s+([^%s#]+)")
        if transparency_enabled then
            config.transparency_enabled = transparency_enabled == "true"
                or transparency_enabled == "1"
                or transparency_enabled == "yes"
        end

        local theme = line:match("^%s*#%s*tsp_theme%s+([^%s#]+)")
        if theme then
            config.theme = theme
        end
    end

    return config
end

local function load_preferred_theme()
    local config = read_kitty_config()

    if config.theme == "solarized_dark" then
        load_naysayer_theme()
        apply_theme_overrides(config)
        return
    end

    load_gruber_darker_theme()
    apply_theme_overrides(config)
end

vim.api.nvim_create_user_command("TspReloadTheme", load_preferred_theme, {})
if vim.v.servername == "" then
    pcall(vim.fn.serverstart)
end

do
    local theme_watcher = vim.uv.new_fs_event()
    if theme_watcher then
        local theme_dir = vim.fs.dirname(kitty_config.theme_path)
        theme_watcher:start(theme_dir, {}, function(_, filename)
            if filename ~= vim.fs.basename(kitty_config.theme_path) then
                return
            end

            vim.schedule(load_preferred_theme)
        end)
        _G.TspThemeWatcher = theme_watcher
    end
end

map("v", "<LeftRelease>", [["+ygv]], { silent = true, desc = "[P]Mouse select -> yank to system clipboard" })
map(
    "v",
    "<2-LeftRelease>",
    [["+ygv]],
    { silent = true, desc = "[P]Mouse select (double) -> yank to system clipboard" }
)

map("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selected lines down" })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selected lines up" })

map("n", "J", "mzJ`z", { desc = "Join lines and keep cursor centered" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half-page up centered" })
map("n", "n", "nzzzv", { desc = "Next search result centered" })
map("n", "N", "Nzzzv", { desc = "Previous search result centered" })
map("n", "=ap", "ma=ap'a", { desc = "Reindent paragraph" })
map('i', '<M-d>', '<BS>', { desc = 'Delete character to the left' })

map("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit window" })
map("n", "<leader>w", "<cmd>w<cr><esc>", { desc = "Write buffer" })
map("n", "<leader><leader>", "<cmd>source $MYVIMRC<cr>", { desc = "Reload config" })

map("n", "<leader>r", compile_or_recompile, { desc = "Compile current buffer" })
map("n", "<leader>im", "odef main(args: Array[String]) =<cr><tab>", { desc = "Insert Scala main method" })
map("n", "<leader>zig", "<cmd>LspRestart<cr>", { desc = "Restart LSP clients" })

map("x", "<leader>p", [["_dP]], { desc = "Paste without yanking replaced text" })
map({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
map("n", "<leader>Y", [["+Y]], { desc = "Yank line to system clipboard" })
map({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

map("i", "<C-c>", "<Esc>", { desc = "Escape insert mode" })
map("n", "Q", "<nop>", { desc = "Disable Ex mode" })

map("n", "<C-f>", "<cmd>silent !tmux neww tmux-sessionizer<cr>", { desc = "Open tmux sessionizer" })
map("n", "<leader>sh", "<cmd>silent !tmux-sessionizer -s 0 --vsplit<cr>", { desc = "Open tmux sessionizer split" })
map("n", "<M-H>", "<cmd>silent !tmux neww tmux-sessionizer -s 0<cr>", { desc = "Open tmux sessionizer window" })

map("n", "<leader>k", "<cmd>lnext<cr>zz", { desc = "Next location list item" })
map("n", "<leader>j", "<cmd>lprev<cr>zz", { desc = "Previous location list item" })

map("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Substitute word under cursor" })
map("n", "<leader>x", "<cmd>!chmod +x %<cr>", { silent = true, desc = "Make current file executable" })
map("n", "<M-t>", "<cmd>vnew | terminal<cr>", { desc = "Open vertical terminal" })
map("n", "<M-;>", "<cmd>split<cr>", { desc = "Horizonal split" })

map({ "n", "x" }, "<C-M-Down>", function()
    multiple_cursors("MultipleCursorsAddDown")
end, { desc = "Multiple cursors: add cursor below" })
map({ "n", "x" }, "<C-M-Up>", function()
    multiple_cursors("MultipleCursorsAddUp")
end, { desc = "Multiple cursors: add cursor above" })
map("n", "<C-Space>", function()
    multiple_cursors("MultipleCursorsAddDelete")
end, { desc = "Multiple cursors: add/delete cursor" })
map({ "n", "i" }, "<M-LeftMouse>", function()
    multiple_cursors("MultipleCursorsMouseAddDelete")
end, { desc = "Multiple cursors: add/delete cursor with mouse" })
map("x", "<M-I>", function()
    multiple_cursors("MultipleCursorsAddVisualArea")
end, { desc = "Multiple cursors: add cursors to line ends" })
map({ "n", "x" }, "<C-S-l>", function()
    multiple_cursors("MultipleCursorsAddMatches")
end, { desc = "Multiple cursors: select all occurrences" })
map({ "n", "x" }, "<leader>mW", function()
    multiple_cursors("MultipleCursorsAddMatchesV")
end, { desc = "Multiple cursors: add matches in previous area" })
map({ "n", "x" }, "<M-d>", function()
    multiple_cursors("MultipleCursorsAddJumpNextMatch")
end, { desc = "Multiple cursors: add next occurrence" })
map({ "n", "x" }, "<leader>mN", function()
    multiple_cursors("MultipleCursorsJumpNextMatch")
end, { desc = "Multiple cursors: jump next" })
map({ "n", "x" }, "<leader>mp", function()
    multiple_cursors("MultipleCursorsAddJumpPrevMatch")
end, { desc = "Multiple cursors: add and jump previous" })
map({ "n", "x" }, "<leader>mP", function()
    multiple_cursors("MultipleCursorsJumpPrevMatch")
end, { desc = "Multiple cursors: jump previous" })
map({ "n", "x" }, "<leader>ml", function()
    multiple_cursors("MultipleCursorsLock")
end, { desc = "Multiple cursors: toggle lock" })

map({ "n", "t" }, "<M-h>", [[<C-\><C-n><C-w>h]], { desc = "Go to left window" })
map({ "n", "t" }, "<M-j>", [[<C-\><C-n><C-w>j]], { desc = "Go to lower window" })
map({ "n", "t" }, "<M-k>", [[<C-\><C-n><C-w>k]], { desc = "Go to upper window" })
map({ "n", "t" }, "<M-l>", [[<C-\><C-n><C-w>l]], { desc = "Go to right window" })
map({ "n", "t" }, "<M-.>", [[<C-\><C-n><C-w>2>]], { desc = "Increase pane size" })
map({ "n", "t" }, "<M-,>", [[<C-\><C-n><C-w>2<]], { desc = "Decrease pane size" })
map({ "n", "t" }, "<M-i>", [[<C-\><C-n><C-w>2+]], { desc = "Increase pane height" })
map({ "n", "t" }, "<M-o>", [[<C-\><C-n><C-w>2-]], { desc = "Decrease pane height" })
-- }}}

-- Autocmds {{{
local tsp_group = augroup("Core")
local yank_group = augroup("HighlightYank")

vim.filetype.add({
    extension = {
        templ = "templ",
    },
})

vim.api.nvim_create_autocmd("TextYankPost", {
    group = yank_group,
    callback = function()
        vim.hl.hl_op({
            higroup = "IncSearch",
            timeout = 40,
        })
    end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
    group = tsp_group,
    pattern = "*",
    command = [[%s/\s\+$//e]],
})

vim.api.nvim_create_autocmd("FileType", {
    group = tsp_group,
    pattern = { "javascript", "typescript", "javascriptreact", "typescriptreact", "typst", "tex" },
    callback = function()
        vim.opt_local.tabstop = 2
        vim.opt_local.softtabstop = -1
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab = true

        if vim.bo.filetype == "typst" then
            vim.opt_local.indentkeys:remove({ "O", "o" })
        end
    end,
})

local function close_mini_files()
    local ok, minifiles = pcall(require, "mini.files")
    if not ok or type(minifiles.close) ~= "function" then
        return nil
    end

    local close_ok, did_close = pcall(minifiles.close)
    if not close_ok then
        vim.notify("mini.files close failed: " .. tostring(did_close), vim.log.levels.WARN)
        return false
    end

    return did_close
end

local skip_mini_files_startup_quit = false

local function with_mini_files_closed(callback)
    if vim.bo.filetype == "minifiles" then
        skip_mini_files_startup_quit = true
    end

    local did_close = close_mini_files()
    if did_close == true then
        vim.schedule(function()
            callback()
            skip_mini_files_startup_quit = false
        end)
        return
    end

    if did_close == false then
        skip_mini_files_startup_quit = false
        return
    end

    skip_mini_files_startup_quit = false
    callback()
end

vim.api.nvim_create_autocmd("FileType", {
    group = tsp_group,
    pattern = {
        "fff",
        "TelescopePrompt",
        "fzf",
        "snacks_picker_input",
    },
    callback = function()
        vim.schedule(close_mini_files)
    end,
})

vim.api.nvim_create_autocmd("TermOpen", {
    group = tsp_group,
    callback = function()
        vim.schedule(close_mini_files)
    end,
})
-- }}}

-- Plugin Specs {{{
local plugin_specs = {
    -- UI
    { src = "https://github.com/laytan/cloak.nvim",                           name = "cloak.nvim" },
    { src = "https://github.com/nvim-mini/mini.icons",                        name = "mini.icons" },
    { src = "https://github.com/lukas-reineke/indent-blankline.nvim",         name = "indent-blankline.nvim" },
    { src = "https://github.com/3rd/image.nvim",                              name = "image.nvim" },


    -- Editing
    { src = "https://github.com/windwp/nvim-autopairs",                       name = "nvim-autopairs" },
    { src = "https://github.com/nvim-mini/mini.ai",                           name = "mini.ai" },
    { src = "https://github.com/nvim-mini/mini.surround",                     name = "mini.surround" },
    { src = "https://github.com/catgoose/nvim-colorizer.lua",                 name = "nvim-colorizer.lua" },
    { src = "https://github.com/brenton-leighton/multiple-cursors.nvim",      name = "multiple-cursors.nvim" },
    { src = "https://github.com/mbbill/undotree",                             name = "undotree" },
    { src = "https://github.com/MeanderingProgrammer/render-markdown.nvim",   name = "render-markdown.nvim" },


    -- Navigation
    { src = "https://github.com/nvim-mini/mini.files",                        name = "mini.files" },
    { src = "https://github.com/dmtrKovalenko/fff.nvim",                      name = "fff.nvim" },
    { src = "https://github.com/ThePrimeagen/harpoon",                        name = "harpoon" },
    { src = "https://github.com/nvim-mini/mini.jump2d",                       name = "mini.jump2d" },
    { src = "https://github.com/folke/trouble.nvim",                          name = "trouble.nvim" },
    { src = "https://github.com/folke/flash.nvim",                            name = "flash.nvim" },

    -- LSP and completion
    { src = "https://github.com/ray-x/lsp_signature.nvim",                    name = "lsp_signature.nvim" },
    { src = "https://github.com/stevearc/conform.nvim",                       name = "conform.nvim" },
    { src = "https://github.com/neovim/nvim-lspconfig",                       name = "nvim-lspconfig" },
    { src = "https://github.com/williamboman/mason.nvim",                     name = "mason.nvim" },
    { src = "https://github.com/williamboman/mason-lspconfig.nvim",           name = "mason-lspconfig.nvim" },
    { src = "https://github.com/Saghen/blink.cmp",                            name = "blink.cmp" },
    { src = "https://github.com/Saghen/blink.compat",                         name = "blink.compat" },
    { src = "https://github.com/L3MON4D3/LuaSnip",                            name = "LuaSnip" },
    { src = "https://github.com/j-hui/fidget.nvim",                           name = "fidget.nvim" },

    -- Treesitter
    { src = "https://github.com/nvim-treesitter/nvim-treesitter",             name = "nvim-treesitter" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-textobjects", name = "nvim-treesitter-textobjects" },
    { src = "https://github.com/nvim-treesitter/nvim-treesitter-context",     name = "nvim-treesitter-context" },

    -- Git
    { src = "https://github.com/nvim-lua/plenary.nvim",                       name = "plenary.nvim" },
    { src = "https://github.com/kdheepak/lazygit.nvim",                       name = "lazygit.nvim" },

    -- Extras
    { src = "https://github.com/HakonHarnes/img-clip.nvim",                   name = "img-clip.nvim" },
    { src = "https://github.com/thePrimeagen/vim-be-good",                    name = "vim-be-good" },
    { src = "https://github.com/qwlp/tau.nvim",                               name = "tau.nvim" },

    -- Testing
    { src = "https://github.com/ej-shafran/compile-mode.nvim",                name = "compile-mode.nvim" },
    { src = "https://github.com/m00qek/baleia.nvim",                          name = "baleia.nvim" },
    { src = "https://github.com/nvim-neotest/neotest",                        name = "neotest" },
    { src = "https://github.com/nvim-neotest/nvim-nio",                       name = "nvim-nio" },
    { src = "https://github.com/antoinemadec/FixCursorHold.nvim",             name = "FixCursorHold.nvim" },
    { src = "https://github.com/fredrikaverpil/neotest-golang",               name = "neotest-golang" },
    { src = "https://github.com/leoluz/nvim-dap-go",                          name = "nvim-dap-go" },

    -- Debugging
    { src = "https://github.com/mfussenegger/nvim-dap",                       name = "nvim-dap" },
    { src = "https://github.com/rcarriga/nvim-dap-ui",                        name = "nvim-dap-ui" },
    { src = "https://github.com/jay-babu/mason-nvim-dap.nvim",                name = "mason-nvim-dap.nvim" },

    { src = "https://github.com/chomosuke/typst-preview.nvim",                name = "typst-preview.nvim" },
}

local function plugin_names(arg_lead)
    local matches = {}
    local pattern = "^" .. vim.pesc(arg_lead)

    for _, spec in ipairs(plugin_specs) do
        if spec.name:match(pattern) then
            matches[#matches + 1] = spec.name
        end
    end

    return matches
end

local function parse_plugin_names(args)
    if args == "" then
        return nil
    end

    return vim.split(args, "%s+", { trimempty = true })
end

local function register_pack_commands()
    vim.api.nvim_create_user_command("PackUpdate", function(opts)
        vim.pack.update(parse_plugin_names(opts.args), {
            force = opts.bang,
        })
    end, {
        nargs = "*",
        bang = true,
        complete = plugin_names,
        desc = "Update vim.pack plugins (! skips confirmation)",
    })

    vim.api.nvim_create_user_command("PackSync", function(opts)
        vim.pack.update(parse_plugin_names(opts.args), {
            force = opts.bang,
            offline = true,
            target = "lockfile",
        })
    end, {
        nargs = "*",
        bang = true,
        complete = plugin_names,
        desc = "Sync vim.pack plugins to lockfile revisions",
    })
end

local function register_pack_hooks()
    vim.api.nvim_create_autocmd("PackChanged", {
        group = augroup("PackHooks"),
        callback = function(ev)
            if ev.data.spec.name ~= "nvim-treesitter" then
                return
            end
            if ev.data.kind ~= "install" and ev.data.kind ~= "update" then
                return
            end

            vim.schedule(function()
                pcall(vim.cmd, "packadd nvim-treesitter")
                pcall(vim.cmd, "TSUpdate")
            end)
        end,
    })
end

local function install_plugins()
    vim.pack.add(plugin_specs, {
        confirm = false,
        load = function() end,
    })
end
-- }}}

-- LSP Signature {{{
local signature = {}

signature.capabilities = {
    dynamicRegistration = false,
    signatureInformation = {
        documentationFormat = { "markdown", "plaintext" },
        parameterInformation = {
            labelOffsetSupport = true,
        },
    },
}

-- }}}

-- LSP Common {{{
local lsp_common = {}

function lsp_common.on_attach(_, bufnr)
    local function lsp_map(mode, lhs, rhs, desc)
        vim.keymap.set(mode, lhs, rhs, { buffer = bufnr, desc = desc })
    end

    lsp_map("n", "gd", vim.lsp.buf.definition, "LSP definition")
    lsp_map("n", "K", vim.lsp.buf.hover, "LSP hover")
    lsp_map("n", "<leader>vws", vim.lsp.buf.workspace_symbol, "LSP workspace symbols")
    lsp_map("n", "<leader>vd", vim.diagnostic.open_float, "Line diagnostics")
    lsp_map("n", "<leader>vc", vim.lsp.buf.code_action, "Code action")
    lsp_map("n", "<leader>vrr", vim.lsp.buf.references, "References")
    lsp_map("n", "<leader>vrn", vim.lsp.buf.rename, "Rename symbol")
    lsp_map("n", "[d", function()
        vim.diagnostic.jump({ count = -1 })
    end, "Previous diagnostic")

    lsp_map("n", "]d", function()
        vim.diagnostic.jump({ count = 1 })
    end, "Next diagnostic")

    lsp_map({ "i", "n" }, "<C-h>", vim.lsp.buf.signature_help, "LSP signature help")
end

function lsp_common.build_capabilities()
    return require("blink.cmp").get_lsp_capabilities({
        textDocument = {
            completion = {
                completionItem = {
                    snippetSupport = true,
                },
            },
            signatureHelp = signature.capabilities,
        },
    })
end

-- }}}

-- Snippets {{{
local function add_typst_snippets(luasnip)
    local s = luasnip.snippet
    local t = luasnip.text_node
    local i = luasnip.insert_node

    luasnip.add_snippets("typst", {
        s("dm", {
            t("$$ "),
            i(1, ""),
            t(" $$"),
        }),
    }, { key = "tsp_typst" })

    luasnip.add_snippets("typst", {
        s("b", {
            t("*"),
            i(1, ""),
            t("*"),
        }),
    }, { key = "tsp_typst" })
end
-- }}}

-- Plugin Setup {{{
-- UI {{{
local function setup_image()
    setup_once("image.nvim", function()
        ensure_pack("image.nvim")
        require("image").setup({
            backend = "sixel",
            integrations = {
                markdown = {
                    only_render_image_at_cursor = true,         -- defaults to false
                    only_render_image_at_cursor_mode = "popup", -- "popup" or "inline", defaults to "popup"
                },
                typst = {
                    only_render_image_at_cursor = true,         -- defaults to false
                    only_render_image_at_cursor_mode = "popup", -- "popup" or "inline", defaults to "popup"
                }

            }
        })
    end)
end

local function setup_ui()
    load_preferred_theme()

    ensure_packs({ "cloak.nvim", "mini.icons", "indent-blankline.nvim" })

    require("cloak").setup({
        enabled = true,
        cloak_character = "*",
        highlight_group = "Comment",
        patterns = {
            {
                file_pattern = {
                    ".env*",
                    "wrangler.toml",
                    ".dev.vars",
                },
                cloak_pattern = "=.+",
            },
        },
    })

    require("mini.icons").setup({})
    require("ibl").setup({})

    vim.api.nvim_create_autocmd("FileType", {
        group = augroup("Image"),
        pattern = { "markdown", "typst" },
        callback = setup_image,
    })
end
-- }}}

-- Editor {{{
local function setup_render_markdown()
    setup_once("render-markdown.nvim", function()
        ensure_pack("render-markdown.nvim")
        require("render-markdown").setup({})
    end)
end

local function setup_editor()
    ensure_packs({
        "nvim-autopairs",
        "mini.ai",
        "mini.surround",
        "nvim-colorizer.lua",
    })

    require("nvim-autopairs").setup({})
    require("mini.ai").setup({})
    require("mini.surround").setup({
        mappings = {
            add = 'Sa',        -- Add surrounding in Normal and Visual modes
            delete = 'Sd',     -- Delete surrounding
            find = 'Sf',       -- Find surrounding (to the right)
            find_left = 'SF',  -- Find surrounding (to the left)
            highlight = 'Sh',  -- Highlight surrounding
            replace = 'Sr',    -- Replace surrounding

            suffix_last = 'l', -- Suffix to search with "prev" method
            suffix_next = 'n', -- Suffix to search with "next" method
        },

    })

    require("colorizer").setup({
        user_default_options = {
            names = true,
            RGB = true,
            RRGGBB = true,
            css = false,
            mode = "background",
            tailwind = false,
            suppress_deprecation = true,
        },
    })

    vim.keymap.set("n", "<leader>u", function()
        ensure_pack("undotree")
        vim.cmd.UndotreeToggle()
    end, { desc = "Toggle undo tree" })

    vim.api.nvim_create_autocmd("FileType", {
        group = augroup("RenderMarkdown"),
        pattern = { "markdown", "typst" },
        callback = setup_render_markdown,
    })
end
-- }}}

-- Navigation {{{
local function setup_navigation()
    local function current_cwd()
        return vim.uv.cwd()
    end

    vim.g.fff = {
        lazy_sync = true,
        prompt = " > ",
        preview = {
            enabled = true,
            line_numbers = true,
        },
        layout = {
            height = 0.9,
            width = 0.9,
            prompt_position = 'top',    -- or 'top'
            preview_position = 'right', -- 'left' | 'right' | 'top' | 'bottom'
            preview_size = 0.5,
            flex = { size = 130, wrap = 'top' },
            show_scrollbar = false,
            path_shorten_strategy = 'middle_number', -- 'middle_number' | 'middle' | 'end'
            anchor = 'center',
        },
        debug = {
            enabled = false,
            show_scores = true,
        },
    }

    local function setup_mini_files()
        setup_once("mini.files", function()
            ensure_pack("mini.files")
            require("mini.files").setup({
                mappings = {
                    close       = 'q',
                    go_in       = '<CR>',
                    go_in_plus  = 'L',
                    go_out      = '-',
                    go_out_plus = 'H',
                    mark_goto   = "'",
                    mark_set    = 'm',
                    reset       = '<BS>',
                    reveal_cwd  = '@',
                    show_help   = 'g?',
                    synchronize = '=',
                    trim_left   = '<',
                    trim_right  = '>',
                },
            })

            vim.api.nvim_create_autocmd("User", {
                group = augroup("MiniFilesEnter"),
                pattern = "MiniFilesBufferCreate",
                callback = function(args)
                    local function open_pdf_in_tdf(path)
                        if vim.fn.executable("tdf") ~= 1 then
                            vim.notify("tdf is not executable", vim.log.levels.WARN)
                            vim.ui.open(path)
                            return
                        end

                        if vim.env.TMUX ~= nil and vim.fn.executable("tmux") == 1 then
                            vim.fn.jobstart({ "tmux", "split-window", "-h", "tdf", path }, { detach = true })
                            return
                        end

                        if (vim.env.KITTY_LISTEN_ON ~= nil or vim.env.TERM == "xterm-kitty")
                            and vim.fn.executable("kitty") == 1
                        then
                            vim.fn.jobstart({ "kitty", "@", "launch", "--location=vsplit", "tdf", path }, { detach = true })
                            return
                        end

                        vim.fn.jobstart({ "tdf", path }, { detach = true })
                    end

                    local function mini_files_ui_open()
                        local path = (MiniFiles.get_fs_entry() or {}).path
                        if path == nil then
                            vim.notify("Cursor is not on a valid file system entry", vim.log.levels.WARN)
                            return
                        end
                        if vim.fn.fnamemodify(path, ":e"):lower() == "pdf" then
                            open_pdf_in_tdf(path)
                        else
                            vim.ui.open(path)
                        end
                    end

                    local function mini_files_open_pdf_in_sioyek()
                        local path = (MiniFiles.get_fs_entry() or {}).path
                        if path == nil then
                            vim.notify("Cursor is not on a valid file system entry", vim.log.levels.WARN)
                            return
                        end
                        if path:find(".pdf", 1, true) then
                            print(path)
                            vim.fn.jobstart("sioyek \"" .. path .. "\"")
                        else
                            vim.ui.open(path)
                        end
                    end

                    vim.keymap.set("n", "<CR>", function()
                        MiniFiles.go_in({ close_on_file = true })
                    end, { buffer = args.data.buf_id, desc = "Go in entry and close on file" })
                    vim.keymap.set("n", "gx", mini_files_ui_open,
                        { buffer = args.data.buf_id, desc = "Open entry with system handler" })
                    vim.keymap.set("n", "zx", mini_files_open_pdf_in_sioyek,
                        { buffer = args.data.buf_id, desc = "Open entry with sioyek" })
                    vim.keymap.set("n", "<leader>w", function()
                        MiniFiles.synchronize()
                    end, { buffer = args.data.buf_id, desc = "Open entry with system handler" })
                end,
            })
        end)
    end

    local function setup_fff()
        setup_once("fff.nvim", function()
            ensure_pack("fff.nvim")

            vim.schedule(function()
                local download = require("fff.download")
                download.ensure_downloaded({}, function(success, err)
                    if success then
                        return
                    end

                    vim.schedule(function()
                        vim.notify("fff.nvim binary is unavailable: " .. tostring(err), vim.log.levels.WARN)
                    end)
                end)
            end)
        end)

        return require("fff")
    end

    vim.api.nvim_create_autocmd("PackChanged", {
        group = augroup("Fff"),
        callback = function(ev)
            local name = ev.data.spec.name
            local kind = ev.data.kind

            if name ~= "fff.nvim" or (kind ~= "install" and kind ~= "update") then
                return
            end

            if not ev.data.active then
                vim.cmd("packadd fff.nvim")
            end

            require("fff.download").download_or_build_binary()
        end,
    })

    local function live_grep_query(query, title)
        with_mini_files_closed(function()
            setup_fff().live_grep({
                cwd = current_cwd(),
                query = query,
                title = title,
            })
        end)
    end

    vim.keymap.set("n", "<leader>e", function()
        setup_mini_files()

        local path = vim.api.nvim_buf_get_name(0)
        if path == "" then
            MiniFiles.open()
            return
        end

        MiniFiles.open(path)
    end, { desc = "Open file explorer" })

    vim.api.nvim_create_autocmd("VimEnter", {
        group = augroup("MiniFilesStartup"),
        callback = function()
            if vim.fn.argc() ~= 1 then
                return
            end

            local path = vim.fn.argv(0)
            if vim.fn.isdirectory(path) == 0 then
                return
            end

            path = vim.fn.fnamemodify(path, ":p")
            vim.cmd.cd(vim.fn.fnameescape(path))

            local current_buf = vim.api.nvim_get_current_buf()
            setup_mini_files()
            vim.b[current_buf].mini_files_startup_target = true
            MiniFiles.open(path, false)

            local startup_close_group = augroup("MiniFilesStartupClose")
            local function quit_if_only_startup_target_remains()
                vim.schedule(function()
                    if skip_mini_files_startup_quit then
                        skip_mini_files_startup_quit = false
                        return
                    end

                    for _, win_id in ipairs(vim.api.nvim_list_wins()) do
                        local bufnr = vim.api.nvim_win_get_buf(win_id)
                        if vim.bo[bufnr].filetype == "minifiles" then
                            return
                        end
                    end

                    pcall(function()
                        if not vim.api.nvim_buf_is_valid(current_buf) then
                            return
                        end

                        local listed_bufs = vim.tbl_filter(function(bufnr)
                            return vim.bo[bufnr].buflisted
                        end, vim.api.nvim_list_bufs())

                        if #listed_bufs == 1 and listed_bufs[1] == current_buf then
                            vim.cmd.quit()
                        end
                    end)
                end)
            end

            vim.api.nvim_create_autocmd("User", {
                group = startup_close_group,
                pattern = "MiniFilesExplorerClose",
                once = true,
                callback = quit_if_only_startup_target_remains,
            })

            vim.api.nvim_create_autocmd("WinClosed", {
                group = startup_close_group,
                callback = quit_if_only_startup_target_remains,
            })
        end,
    })

    vim.keymap.set("n", "<leader>pf", function()
        with_mini_files_closed(function()
            setup_fff().find_files({
                cwd = current_cwd(),
                title = "Files",
            })
        end)
    end, { desc = "Find files" })

    vim.keymap.set("n", "<leader>g", function()
        with_mini_files_closed(function()
            setup_fff().find_files({
                cwd = current_cwd(),
                title = "Files (hidden)",
            })
        end)
    end, { desc = "Find files not ignored by Git" })

    vim.keymap.set("n", "<leader>pws", function()
        live_grep_query(vim.fn.expand("<cword>"), "Grep word under cursor")
    end, { desc = "Grep word under cursor" })

    vim.keymap.set("n", "<leader>pWs", function()
        live_grep_query(vim.fn.expand("<cWORD>"), "Grep WORD under cursor")
    end, { desc = "Grep WORD under cursor" })

    vim.keymap.set("n", "<leader>ps", function()
        local query = vim.fn.input("Grep > ")
        if query == "" then
            return
        end

        live_grep_query(query, "Prompted grep")
    end, { desc = "Prompted grep" })

    vim.keymap.set("n", "<leader>vh", function()
        local subject = vim.fn.input("Help > ")
        if subject == "" then
            return
        end

        vim.cmd.help(subject)
    end, { desc = "Help tags" })

    local function get_harpoon()
        setup_once("harpoon", function()
            ensure_packs({ "plenary.nvim", "harpoon" })
            require("harpoon"):setup()
        end)

        return require("harpoon")
    end

    vim.keymap.set("n", "<leader>A", function()
        local harpoon = get_harpoon()
        harpoon:list():prepend()
    end, { desc = "Harpoon prepend file" })

    vim.keymap.set("n", "<leader>a", function()
        local harpoon = get_harpoon()
        harpoon:list():add()
    end, { desc = "Harpoon add file" })

    vim.keymap.set("n", "<C-e>", function()
        local harpoon = get_harpoon()
        harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = "Harpoon quick menu" })

    vim.keymap.set("n", "<C-j>", function()
        local harpoon = get_harpoon()
        harpoon:list():select(1)
    end, { desc = "Harpoon file 1" })

    vim.keymap.set("n", "<C-k>", function()
        local harpoon = get_harpoon()
        harpoon:list():select(2)
    end, { desc = "Harpoon file 2" })

    vim.keymap.set("n", "<C-l>", function()
        local harpoon = get_harpoon()
        harpoon:list():select(3)
    end, { desc = "Harpoon file 3" })

    vim.keymap.set("n", "<C-;>", function()
        local harpoon = get_harpoon()
        harpoon:list():select(4)
    end, { desc = "Harpoon file 4" })

    vim.keymap.set("n", "<leader><C-j>", function()
        local harpoon = get_harpoon()
        harpoon:list():replace_at(1)
    end, { desc = "Harpoon replace file 1" })

    vim.keymap.set("n", "<leader><C-k>", function()
        local harpoon = get_harpoon()
        harpoon:list():replace_at(2)
    end, { desc = "Harpoon replace file 2" })

    vim.keymap.set("n", "<leader><C-l>", function()
        local harpoon = get_harpoon()
        harpoon:list():replace_at(3)
    end, { desc = "Harpoon replace file 3" })

    vim.keymap.set("n", "<leader><C-;>", function()
        local harpoon = get_harpoon()
        harpoon:list():replace_at(4)
    end, { desc = "Harpoon replace file 4" })

    local function get_trouble()
        setup_once("trouble.nvim", function()
            ensure_pack("trouble.nvim")
            require("trouble").setup({
                icons = false,
            })
        end)

        return require("trouble")
    end

    vim.keymap.set("n", "<leader>tt", function()
        get_trouble().toggle()
    end, { desc = "Toggle trouble" })

    vim.keymap.set("n", "[t", function()
        get_trouble().next({ skip_groups = true, jump = true })
    end, { desc = "Next trouble item" })

    vim.keymap.set("n", "]t", function()
        get_trouble().previous({ skip_groups = true, jump = true })
    end, { desc = "Previous trouble item" })

    local function flash_jump()
        setup_once("flash.nvim", function()
            ensure_pack("flash.nvim")
            require("flash").setup({})
        end)

        require("flash").jump()
    end

    vim.keymap.set({ "n", "x", "o" }, "s", flash_jump, { desc = "Flash" })
end

-- }}}

-- LSP Setup {{{
local function setup_lsp()
    ensure_packs({
        "conform.nvim",
        "nvim-lspconfig",
        "mason.nvim",
        "mason-lspconfig.nvim",
        "blink.cmp",
        "blink.compat",
        "LuaSnip",
        "fidget.nvim",
    })

    local lsp_util = require("lspconfig.util")
    local mason_lspconfig = require("mason-lspconfig")
    local blink = require("blink.cmp")
    local luasnip = require("luasnip")
    local capabilities = lsp_common.build_capabilities()
    local prettier_formatters = { "prettierd", "prettier", stop_after_first = true }

    local function root_pattern(...)
        local matcher = lsp_util.root_pattern(...)

        return function(bufnr, on_dir)
            local filename = vim.api.nvim_buf_get_name(bufnr)
            local root_dir = matcher(filename)

            if root_dir then
                on_dir(root_dir)
            end
        end
    end

    require("conform").setup({
        format_on_save = {
            timeout_ms = 1500,
            lsp_format = "fallback",
        },
        formatters_by_ft = {
            c = { "clang-format" },
            cpp = { "clang-format" },
            lua = { "stylua" },
            go = { "gofmt" },
            javascript = prettier_formatters,
            javascriptreact = prettier_formatters,
            typescript = prettier_formatters,
            typescriptreact = prettier_formatters,
            css = prettier_formatters,
            elixir = { "mix" },
            python = { "ruff_format" },
            typst = { "typstyle" },
            tex = { "tex-fmt" },
        },
        formatters = {
            ["clang-format"] = {
                prepend_args = { "-style=file", "-fallback-style=LLVM" },
            },
            ["typstyle"] = {
                args = { "--line-width", "80", "--wrap-text" },
            },
        },
    })

    vim.keymap.set("n", "<leader>f", function()
        require("conform").format({ bufnr = 0 })
    end, { desc = "Format buffer" })

    vim.keymap.set("i", "<C-;>", function()
        require("conform").format({ bufnr = 0 })
    end, { desc = "Format buffer" })

    require("fidget").setup({})

    require("mason").setup()

    require("blink.compat").setup({})

    luasnip.setup({
        history = true,
        region_check_events = "InsertEnter",
        delete_check_events = "InsertLeave",
    })

    add_typst_snippets(luasnip)

    blink.setup({
        enabled = function()
            return vim.bo.ft ~= "sql"
        end,
        snippets = {
            preset = "luasnip",
        },
        keymap = {
            preset = "none",
            ["<C-p>"] = { "select_prev", "fallback_to_mappings" },
            ["<C-n>"] = { "select_next", "fallback_to_mappings" },
            ["<C-y>"] = { "select_and_accept", "fallback" },
            ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
        },
        completion = {
            list = {
                selection = {
                    preselect = true,
                    auto_insert = false,
                },
            },
            accept = {
                auto_brackets = {
                    enabled = false,
                },
            },
        },
        sources = {
            default = { "lsp", "snippets", "buffer" },
        },
        cmdline = {
            keymap = {
                preset = "cmdline",
            },
            sources = function()
                local cmdtype = vim.fn.getcmdtype()
                if cmdtype == "/" or cmdtype == "?" then
                    return { "buffer" }
                end

                if cmdtype == ":" then
                    return { "path", "cmdline" }
                end

                return {}
            end,
        },
    })

    local servers = {
        clangd = {},
        gopls = {},
        lua_ls = {
            settings = {
                Lua = {
                    format = {
                        enable = true,
                        defaultConfig = {
                            indent_style = "space",
                            indent_size = "2",
                        },
                    },
                },
            },
        },
        pyright = {
            before_init = function(_, config)
                local root_dir = config.root_dir
                if not root_dir then
                    return
                end

                local venv_python = lsp_util.path.join(root_dir, ".venv", "bin", "python")
                if vim.uv.fs_stat(venv_python) then
                    config.settings = config.settings or {}
                    config.settings.python = config.settings.python or {}
                    config.settings.python.pythonPath = venv_python
                end
            end,
            settings = {
                python = {
                    analysis = {
                        autoSearchPaths = true,
                        useLibraryCodeForTypes = true,
                        diagnosticMode = "workspace",
                    },
                },
            },
        },
        rust_analyzer = {},
        tailwindcss = {
            filetypes = { "html", "css", "scss", "javascript", "javascriptreact", "typescript", "typescriptreact", "vue", "svelte", "heex" },
            root_dir = root_pattern(
                "tailwind.config.js",
                "tailwind.config.cjs",
                "tailwind.config.mjs",
                "tailwind.config.ts",
                "postcss.config.js",
                "postcss.config.cjs",
                "postcss.config.mjs",
                "postcss.config.ts"
            ),
        },
        texlab = {},
        vtsls = {
            root_dir = root_pattern("tsconfig.json", "jsconfig.json", "package.json", ".git"),
            single_file_support = false,
            settings = {
                typescript = {
                    preferences = {
                        importModuleSpecifier = "non-relative",
                    },
                },
                javascript = {
                    preferences = {
                        importModuleSpecifier = "non-relative",
                    },
                },
            },
        },
        zls = {
            root_dir = lsp_util.root_pattern(".git", "build.zig", "zls.json"),
            settings = {
                zls = {
                    enable_inlay_hints = true,
                    enable_snippets = true,
                    warn_style = true,
                },
            },
        },
        gleam = {},
        harper_ls = {
            filetypes = { "typst", "tex", "markdown" },
            settings = {
                ["harper-ls"] =
                {
                    userDictPath = "",
                    workspaceDictPath = "",
                    fileDictPath = "",
                    linters = {
                        SpellCheck = true,
                        SpelledNumbers = false,
                        AnA = true,
                        SentenceCapitalization = true,
                        -- UnclosedQuotes = true,
                        WrongQuotes = false,
                        PossessiveNoun = true,
                        WrongApostrophe = false,
                        LongSentences = true,
                        RepeatedWords = true,
                        Spaces = true,
                        Matcher = true,
                        CorrectNumberSuffix = true
                    },
                    codeActions = {
                        ForceStable = false
                    },
                    markdown = {
                        IgnoreLinkTitle = false
                    },
                    diagnosticSeverity = "hint",
                    isolateEnglish = false,
                    dialect = "American",
                    maxFileLength = 120000,
                    ignoredLintsPath = "",
                    excludePatterns = {}
                }
            },
        },
        tinymist = {},
    }

    mason_lspconfig.setup({
        ensure_installed = {
            "clangd",
            "gopls",
            "lua_ls",
            "pyright",
            "rust_analyzer",
            "tailwindcss",
            "texlab",
            "vtsls",
            "zls",
            "harper_ls",
            "tinymist",
        },
        automatic_enable = false,
    })

    for server_name, server in pairs(servers) do
        server.capabilities = vim.tbl_deep_extend("force", capabilities, server.capabilities or {})
        server.on_attach = server.on_attach or lsp_common.on_attach
        vim.lsp.config(server_name, server)
        vim.lsp.enable(server_name)
    end

    vim.g.zig_fmt_parse_errors = 0
    vim.g.zig_fmt_autosave = 0
end
-- }}}

-- Treesitter {{{
local function setup_treesitter()
    ensure_packs({
        "nvim-treesitter",
        "nvim-treesitter-textobjects",
        "nvim-treesitter-context",
    })

    require("nvim-treesitter.configs").setup({
        ensure_installed = {
            "vim",
            "vimdoc",
            "lua",
            "bash",
            "javascript",
            "typescript",
            "tsx",
            "json",
            "jsonc",
            "html",
            "css",
            "go",
            "gomod",
            "gowork",
            "python",
            "rust",
            "c",
            "cpp",
            "zig",
            "scala",
            "markdown",
            "markdown_inline",
            "typst",
            "query",
        },
        sync_install = false,
        auto_install = false,
        indent = {
            enable = true,
        },
        highlight = {
            enable = true,
            disable = { "html" },
            additional_vim_regex_highlighting = { "markdown" },
        },
    })

    -- Neovim nightly updated markdown injections away from the older
    -- `#set-lang-from-info-string!` directive shipped by our pinned
    -- nvim-treesitter version. Override the query so markdown buffers
    -- do not crash when injected languages are parsed.
    vim.treesitter.query.set("markdown", "injections", [[
(fenced_code_block
  (info_string
    (language) @injection.language)
  (code_fence_content) @injection.content)

((html_block) @injection.content
  (#set! injection.language "html")
  (#set! injection.combined)
  (#set! injection.include-children))

((minus_metadata) @injection.content
  (#set! injection.language "yaml")
  (#offset! @injection.content 1 0 -1 0)
  (#set! injection.include-children))

((plus_metadata) @injection.content
  (#set! injection.language "toml")
  (#offset! @injection.content 1 0 -1 0)
  (#set! injection.include-children))

([
  (inline)
  (pipe_table_cell)
] @injection.content
  (#set! injection.language "markdown_inline"))
    ]])

    local parser_config = require("nvim-treesitter.parsers").get_parser_configs()

    parser_config.templ = {
        install_info = {
            url = "https://github.com/vrischmann/tree-sitter-templ.git",
            files = { "src/parser.c", "src/scanner.c" },
            branch = "master",
        },
    }

    parser_config.typst = {
        install_info = {
            url = "https://github.com/uben0/tree-sitter-typst.git",
            files = { "src/parser.c", "src/scanner.c" },
            branch = "master",
        },
    }

    vim.treesitter.language.register("templ", "templ")
    vim.treesitter.language.register("typst", "typst")

    require("treesitter-context").setup({
        enable = true,
        multiwindow = false,
        max_lines = 0,
        min_window_height = 0,
        line_numbers = true,
        multiline_threshold = 20,
        trim_scope = "outer",
        mode = "cursor",
        separator = nil,
        zindex = 20,
    })
end
-- }}}

-- Git {{{
local function setup_git()
    vim.keymap.set("n", "<leader>lg", function()
        ensure_packs({ "plenary.nvim", "lazygit.nvim" })
        vim.cmd.LazyGit()
    end, { desc = "Open LazyGit" })
end
-- }}}

-- Extras {{{
local function setup_extras()
    local function setup_img_clip()
        setup_once("img-clip.nvim", function()
            ensure_pack("img-clip.nvim")
            require("img-clip").setup({})
        end)
    end

    local function setup_tau()
        setup_once("tau.nvim", function()
            ensure_pack("tau.nvim")
            require("tau").setup({
                connector = "opencode",

                -- optional
                opencode_model = "openai/gpt-5.4-mini",
                opencode_agent = "build",
                opencode_args = {
                    "--thinking",
                },
            })
        end)
    end

    vim.keymap.set("n", "<leader>ip", function()
        setup_img_clip()
        vim.cmd.PasteImage()
    end, { desc = "Paste image from clipboard" })

    -- require("tau").setup({
    --     api_url = "https://openrouter.ai/api/v1",
    --     api_key = vim.env.OPENROUTER_API_KEY,
    --     model = "google/gemini-3.1-flash-lite-preview",
    -- })
    vim.keymap.set("v", "<leader>t", function()
        setup_tau()
        vim.cmd("'<,'>Tau")
    end, { desc = "Tau: edit selection" })
    vim.keymap.set("v", "<leader>a", function()
        setup_tau()
        vim.cmd("'<,'>TauAsk")
    end, { desc = "Tau: ask" })
    vim.keymap.set("n", "<leader>vt", function()
        setup_tau()
        vim.cmd.TauVibe()
    end, { desc = "Tau: vibe" })
    vim.keymap.set("v", "<leader>vt", function()
        setup_tau()
        vim.cmd("'<,'>TauVibe")
    end, { desc = "Tau: vibe" })
    vim.keymap.set("n", "<C-t>", function()
        setup_tau()
        vim.cmd.TauContext()
    end, { desc = "Tau: context files" })
    vim.keymap.set("n", "<leader>T", function()
        setup_tau()
        vim.cmd.TauCancel()
    end, { desc = "Tau: cancel request" })
end
-- }}}

-- Testing {{{
local function setup_testing()
    vim.g.compile_mode = {
        baleia_setup = true,
        bang_expansion = true,
        default_command = function()
            local filetype = vim.bo.filetype
            if filetype == "python" then
                return "python %"
            elseif filetype == "tex" then
                return "tectonic %"
            elseif filetype == "typst" then
                return "TypstPreview"
            elseif filetype == "scala" then
                return "scala %"
            elseif filetype == "cpp" then
                return "g++ % -o %:r && ./%:r"
            elseif filetype == "gleam" then
                return "gleam run -m %:t:r"
            end
            return "make -k "
        end,
        focus_compilation_buffer = true,
    }

    local function setup_neotest()
        setup_once("neotest", function()
            ensure_packs({
                "plenary.nvim",
                "nvim-nio",
                "FixCursorHold.nvim",
                "neotest",
                "neotest-golang",
            })

            require("neotest").setup({
                adapters = {
                    require("neotest-golang")({
                        dap = { justMyCode = false },
                    }),
                },
            })
        end)

        return require("neotest")
    end

    vim.keymap.set("n", "<leader>tn", function()
        setup_neotest().run.run({
            suite = false,
            testify = true,
        })
    end, { desc = "Run nearest test" })

    vim.keymap.set("n", "<leader>te", function()
        setup_neotest().summary.toggle()
    end, { desc = "Toggle test summary" })

    vim.keymap.set("n", "<leader>ts", function()
        setup_neotest().run.run({
            suite = true,
            testify = true,
        })
    end, { desc = "Run test suite" })

    vim.keymap.set("n", "<leader>td", function()
        setup_neotest().run.run({
            suite = false,
            testify = true,
            strategy = "dap",
        })
    end, { desc = "Debug nearest test" })

    vim.keymap.set("n", "<leader>to", function()
        setup_neotest().output.open()
    end, { desc = "Open test output" })

    vim.keymap.set("n", "<leader>ta", function()
        setup_neotest().run.run(vim.fn.getcwd())
    end, { desc = "Run all tests in cwd" })
end
-- }}}

-- DAP {{{
local function setup_dap()
    local toggle_debug_ui

    local function setup_dap_runtime()
        setup_once("dap", function()
            ensure_packs({
                "nvim-dap",
                "nvim-nio",
                "nvim-dap-ui",
                "mason.nvim",
                "mason-nvim-dap.nvim",
                "nvim-dap-go",
            })

            local dap_group = augroup("Dap")

            local function focus_matching_buffer(args)
                local target_buf = args.buf

                vim.schedule(function()
                    for _, win_id in ipairs(vim.api.nvim_list_wins()) do
                        if vim.api.nvim_win_is_valid(win_id) and vim.api.nvim_win_get_buf(win_id) == target_buf then
                            vim.api.nvim_set_current_win(win_id)
                            return
                        end
                    end
                end)
            end

            local dap = require("dap")
            local dapui = require("dapui")

            dap.set_log_level("DEBUG")

            local function layout(name)
                return {
                    elements = {
                        { id = name },
                    },
                    enter = true,
                    size = 40,
                    position = "right",
                }
            end

            local name_to_layout = {
                repl = { layout = layout("repl"), index = 0 },
                stacks = { layout = layout("stacks"), index = 0 },
                scopes = { layout = layout("scopes"), index = 0 },
                console = { layout = layout("console"), index = 0 },
                watches = { layout = layout("watches"), index = 0 },
                breakpoints = { layout = layout("breakpoints"), index = 0 },
            }

            local layouts = {}
            for name, config in pairs(name_to_layout) do
                table.insert(layouts, config.layout)
                name_to_layout[name].index = #layouts
            end

            toggle_debug_ui = function(name)
                dapui.close()
                local layout_config = name_to_layout[name]
                if not layout_config then
                    error("Unknown DAP layout: " .. name)
                end

                local ui = vim.api.nvim_list_uis()[1]
                if ui then
                    layout_config.layout.size = ui.width
                end

                pcall(dapui.toggle, layout_config.index)
            end

            vim.api.nvim_create_autocmd("BufEnter", {
                group = dap_group,
                pattern = "*dap-repl*",
                callback = function()
                    vim.wo.wrap = true
                end,
            })

            vim.api.nvim_create_autocmd("BufWinEnter", {
                group = dap_group,
                pattern = { "*dap-repl*", "*DAP Watches*" },
                callback = focus_matching_buffer,
            })

            dapui.setup({
                layouts = layouts,
                enter = true,
            })

            dap.listeners.before.event_terminated.tsp_dapui = function()
                dapui.close()
            end

            dap.listeners.before.event_exited.tsp_dapui = function()
                dapui.close()
            end

            require("mason-nvim-dap").setup({
                ensure_installed = {
                    "delve",
                },
                automatic_installation = true,
                handlers = {
                    function(config)
                        require("mason-nvim-dap").default_setup(config)
                    end,
                    delve = function(config)
                        table.insert(config.configurations, 1, {
                            args = function()
                                return vim.split(vim.fn.input("args> "), " ")
                            end,
                            type = "delve",
                            name = "file",
                            request = "launch",
                            program = "${file}",
                            outputMode = "remote",
                        })

                        table.insert(config.configurations, 1, {
                            args = function()
                                return vim.split(vim.fn.input("args> "), " ")
                            end,
                            type = "delve",
                            name = "file args",
                            request = "launch",
                            program = "${file}",
                            outputMode = "remote",
                        })

                        require("mason-nvim-dap").default_setup(config)
                    end,
                },
            })

            require("dap-go").setup()
        end)

        return require("dap")
    end

    vim.keymap.set("n", "<F8>", function()
        setup_dap_runtime().continue()
    end, { desc = "Debug continue" })
    vim.keymap.set("n", "<F10>", function()
        setup_dap_runtime().step_over()
    end, { desc = "Debug step over" })
    vim.keymap.set("n", "<F11>", function()
        setup_dap_runtime().step_into()
    end, { desc = "Debug step into" })
    vim.keymap.set("n", "<F12>", function()
        setup_dap_runtime().step_out()
    end, { desc = "Debug step out" })
    vim.keymap.set("n", "<leader>b", function()
        setup_dap_runtime().toggle_breakpoint()
    end, { desc = "Toggle breakpoint" })
    vim.keymap.set("n", "<leader>B", function()
        setup_dap_runtime().set_breakpoint(vim.fn.input("Breakpoint condition: "))
    end, { desc = "Set conditional breakpoint" })

    local function open_debug_ui(name)
        setup_dap_runtime()
        toggle_debug_ui(name)
    end

    vim.keymap.set("n", "<leader>dr", function()
        open_debug_ui("repl")
    end, { desc = "Toggle DAP REPL" })
    vim.keymap.set("n", "<leader>ds", function()
        open_debug_ui("stacks")
    end, { desc = "Toggle DAP stacks" })
    vim.keymap.set("n", "<leader>dw", function()
        open_debug_ui("watches")
    end, { desc = "Toggle DAP watches" })
    vim.keymap.set("n", "<leader>db", function()
        open_debug_ui("breakpoints")
    end, { desc = "Toggle DAP breakpoints" })
    vim.keymap.set("n", "<leader>dS", function()
        open_debug_ui("scopes")
    end, { desc = "Toggle DAP scopes" })
    vim.keymap.set("n", "<leader>dc", function()
        open_debug_ui("console")
    end, { desc = "Toggle DAP console" })
end
-- }}}

-- Languages {{{
local function setup_languages()
    vim.api.nvim_create_autocmd("FileType", {
        group = augroup("TypstPreview"),
        pattern = "typst",
        callback = function()
            setup_once("typst-preview.nvim", function()
                ensure_pack("typst-preview.nvim")
                require("typst-preview").setup({
                    invert_colors = "auto",
                })
            end)
        end,
    })
end
-- }}}
-- }}}

-- Bootstrap {{{
register_pack_commands()
register_pack_hooks()
install_plugins()

setup_ui()
setup_editor()
setup_navigation()
setup_lsp()
setup_treesitter()
setup_git()
setup_extras()
setup_testing()
setup_dap()
setup_languages()
-- }}}
