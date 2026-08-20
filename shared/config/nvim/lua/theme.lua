local theme = {
    colors_path = vim.fn.expand("~/.config/tsp-theme/current/colors.toml"),
    name_path = vim.fn.expand("~/.local/state/tsp-theme/name"),
}

local function read_palette()
    local palette = {}
    local ok, lines = pcall(vim.fn.readfile, theme.colors_path)
    if not ok then
        return nil
    end

    for _, line in ipairs(lines) do
        local key, value = line:match('^%s*([%w_]+)%s*=%s*"(#[%x]+)"')
        if key then
            palette[key] = value
        end
    end

    if not palette.background or not palette.foreground then
        return nil
    end
    return palette
end

local function apply_theme()
    local colors = read_palette()
    if not colors then
        vim.notify("Could not read " .. theme.colors_path, vim.log.levels.ERROR)
        return
    end

    local ok, names = pcall(vim.fn.readfile, theme.name_path)
    local name = ok and vim.trim(names[1] or "") or "desktop"
    vim.cmd("highlight clear")
    vim.o.background = "dark"
    vim.g.colors_name = "tsp-" .. name

    local set = vim.api.nvim_set_hl
    local background = colors.background
    local foreground = colors.foreground
    local muted = colors.muted or colors.color8
    local border = { fg = muted, bg = background }

    set(0, "Normal", { fg = foreground, bg = background })
    set(0, "NormalNC", { fg = foreground, bg = background })
    set(0, "Cursor", { bg = colors.cursor or colors.color15 })
    set(0, "Visual", { fg = colors.selection_foreground, bg = colors.selection_background })
    set(0, "LineNr", { fg = muted, bg = background })
    set(0, "CursorLineNr", { fg = colors.accent, bg = background, bold = true })
    set(0, "CursorLine", { bg = colors.color0 })
    set(0, "ColorColumn", { bg = colors.color0 })
    set(0, "WinSeparator", border)
    set(0, "VertSplit", border)
    set(0, "MatchParen", { bg = colors.selection_background })

    set(0, "Comment", { fg = muted, italic = true })
    set(0, "String", { fg = colors.color2 })
    set(0, "Number", { fg = colors.color14 })
    set(0, "Boolean", { fg = colors.color14 })
    set(0, "Constant", { fg = colors.color14 })
    set(0, "Identifier", { fg = colors.color6 })
    set(0, "Function", { fg = colors.color4 })
    set(0, "Statement", { fg = colors.color5, bold = true })
    set(0, "Keyword", { fg = colors.color5, bold = true })
    set(0, "Type", { fg = colors.color3 })
    set(0, "PreProc", { fg = colors.color10 })
    set(0, "Special", { fg = colors.accent })
    set(0, "WarningMsg", { fg = colors.color3 })
    set(0, "Error", { fg = colors.color1 })
    set(0, "DiagnosticError", { fg = colors.color1 })
    set(0, "DiagnosticWarn", { fg = colors.color3 })
    set(0, "DiagnosticInfo", { fg = colors.color4 })
    set(0, "DiagnosticHint", { fg = colors.color6 })

    for group, link in pairs({
        ["@comment"] = "Comment",
        ["@string"] = "String",
        ["@number"] = "Number",
        ["@boolean"] = "Boolean",
        ["@constant"] = "Constant",
        ["@function"] = "Function",
        ["@function.builtin"] = "Function",
        ["@variable"] = "Identifier",
        ["@type"] = "Type",
        ["@keyword"] = "Keyword",
        ["@keyword.function"] = "Keyword",
        ["@field"] = "Identifier",
        ["@property"] = "Identifier",
        ["@parameter"] = "Identifier",
    }) do
        set(0, group, { link = link })
    end

    set(0, "StatusLine", { fg = background, bg = colors.accent, bold = true })
    set(0, "StatusLineNC", { fg = muted, bg = background })
    set(0, "NormalFloat", { fg = foreground, bg = background })
    set(0, "FloatBorder", border)
    set(0, "Pmenu", { fg = foreground, bg = colors.color0 })
    set(0, "PmenuSel", { fg = colors.selection_foreground, bg = colors.selection_background })

    set(0, "MiniFilesNormal", { fg = foreground, bg = background })
    set(0, "MiniFilesBorder", border)
    set(0, "MiniFilesCursorLine", { bg = colors.color0, force = true })
    set(0, "MiniFilesDirectory", { fg = colors.color4 })
    set(0, "MiniFilesFile", { fg = foreground })
    set(0, "MiniFilesTitle", { fg = muted, bg = background })
    set(0, "MiniFilesTitleFocused", { fg = colors.accent, bg = background, bold = true })
    set(0, "MiniPickHeader", { fg = colors.color2, bold = true })
    set(0, "MiniPickMatchCurrent", { bg = colors.selection_background, force = true })
    set(0, "MiniPickMatchMarked", { bg = colors.color0 })
    set(0, "MiniPickNormal", { fg = foreground, bg = background })
    set(0, "MiniPickBorder", border)
    set(0, "MiniPickPrompt", { fg = colors.accent, bg = background, bold = true })

    set(0, "BlinkCmpMenu", { fg = foreground, bg = background })
    set(0, "BlinkCmpMenuBorder", border)
    set(0, "BlinkCmpMenuSelection", { bg = colors.selection_background, bold = true })
    set(0, "BlinkCmpLabelMatch", { fg = colors.accent, bold = true })
    set(0, "BlinkCmpDoc", { fg = foreground, bg = background })
    set(0, "BlinkCmpDocBorder", border)
    set(0, "BlinkCmpKind", { fg = colors.accent, bg = background })

    vim.api.nvim_exec_autocmds("ColorScheme", { pattern = vim.g.colors_name })
end

vim.api.nvim_create_user_command("TspReloadTheme", apply_theme, {})

if vim.v.servername == "" then
    pcall(vim.fn.serverstart)
end

local watcher = vim.uv.new_fs_event()
if watcher then
    watcher:start(vim.fs.dirname(theme.name_path), {}, function(_, filename)
        if filename == vim.fs.basename(theme.name_path) then
            vim.schedule(apply_theme)
        end
    end)
    _G.TspThemeWatcher = watcher
end

apply_theme()
