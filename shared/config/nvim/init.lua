-- Helpers {{{

local function augroup(name)
    return vim.api.nvim_create_augroup("Tsp" .. name, { clear = true })
end

local function map(mode, lhs, rhs, opts)
    vim.keymap.set(mode, lhs, rhs, opts or {})
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

vim.pack.add({ tau_spec })
-- }}}

-- Options {{{
vim.g.mapleader = " "
vim.g.maplocalleader = " "

vim.opt.nu = true
vim.opt.relativenumber = true

vim.opt.tabstop = 4
vim.opt.softtabstop = 0
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

vim.opt.scrolloff = 8
vim.opt.signcolumn = "yes"
vim.opt.isfname:append("@-@")
vim.opt.updatetime = 50
vim.opt.colorcolumn = "80"

vim.opt.foldmethod = "marker"
vim.opt.foldmarker = "{{{,}}}"
vim.opt.foldenable = true
vim.opt.foldlevelstart = 0
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
        vim.cmd("TypstPreview")
        return
    end

    if has_compiled then
        vim.cmd.Recompile()
        return
    end

    vim.cmd.Compile()
    has_compiled = true
end

map("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selected lines down" })
map("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selected lines up" })

map("n", "J", "mzJ`z", { desc = "Join lines and keep cursor centered" })
map("n", "<C-d>", "<C-d>zz", { desc = "Half-page down centered" })
map("n", "<C-u>", "<C-u>zz", { desc = "Half-page up centered" })
map("n", "n", "nzzzv", { desc = "Next search result centered" })
map("n", "N", "Nzzzv", { desc = "Previous search result centered" })
map("n", "=ap", "ma=ap'a", { desc = "Reindent paragraph" })

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
        vim.hl.on_yank({
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
        vim.opt_local.shiftwidth = 2
        vim.opt_local.expandtab = true
        vim.opt_local.autoindent = true
    end,
})
-- }}}

-- Plugin Specs {{{
local plugin_specs = {
    -- UI
    { src = "https://github.com/qwlp/gruber-darker.nvim",                     name = "gruber-darker.nvim" },
    { src = "https://github.com/laytan/cloak.nvim",                           name = "cloak.nvim" },
    { src = "https://github.com/nvim-mini/mini.icons",                        name = "mini.icons" },

    -- Editing
    { src = "https://github.com/windwp/nvim-autopairs",                       name = "nvim-autopairs" },
    { src = "https://github.com/nvim-mini/mini.ai",                           name = "mini.ai" },
    { src = "https://github.com/nvim-mini/mini.surround",                     name = "mini.surround" },
    { src = "https://github.com/catgoose/nvim-colorizer.lua",                 name = "nvim-colorizer.lua" },
    { src = "https://github.com/mbbill/undotree",                             name = "undotree" },
    { src = "https://github.com/OXY2DEV/markview.nvim",                       name = "markview.nvim" },


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
    { src = "https://github.com/timothyckl/tau.nvim",                         name = "tau.nvim" },

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

    -- Languages
    { src = "https://github.com/scalameta/nvim-metals",                       name = "nvim-metals" },
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
        load = false,
    })
end

local function load_plugins()
    for _, spec in ipairs(plugin_specs) do
        vim.cmd("packadd " .. spec.name)
    end
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

signature.opts = {
    bind = true,
    doc_lines = 10,
    floating_window = true,
    -- Keep the popup away from the command line when typing near the bottom.
    floating_window_above_cur_line = true,
    max_height = 8,
    handler_opts = {
        border = "rounded",
    },
    hint_enable = false,
    extra_trigger_chars = { "(", "," },
    always_trigger = false,
    close_timeout = nil,
    auto_close_after = nil,
    toggle_key = "<C-h>",
    toggle_key_flip_floatwin_setting = false,
    timer_interval = 80,
}

function signature.attach(bufnr)
    if vim.b[bufnr].tsp_signature_help_setup then
        return
    end

    vim.b[bufnr].tsp_signature_help_setup = true
    require("lsp_signature").on_attach(signature.opts, bufnr)
end

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

    signature.attach(bufnr)
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

-- Metals CodeLens {{{
local metals_codelens = {}

local STATUS_PREFIX = {
    passed = "✓ ",
    failed = "✗ ",
    running = "⟳ ",
}

local session_state = setmetatable({}, { __mode = "k" })
local pending_runs = {}
local lens_state = {}
local handler_patched = false
local dap_patched = false
local on_win_patched = false

local function strip_status(title)
    if type(title) ~= "string" then
        return ""
    end

    for _, prefix in pairs(STATUS_PREFIX) do
        if vim.startswith(title, prefix) then
            return title:sub(#prefix + 1)
        end
    end

    return title
end

local function is_test_lens(command)
    if type(command) ~= "table" then
        return false
    end

    local title = strip_status(command.title or ""):lower()
    if title:find("test", 1, true) then
        return true
    end

    local arguments = command.arguments
    return type(arguments) == "table"
        and (arguments.requestData ~= nil or tostring(arguments.runType or ""):find("^test") ~= nil)
end

local function lens_key(row, command)
    return table.concat({
        tostring(row),
        command.command or "",
        strip_status(command.title or ""),
    }, "\31")
end

local function get_provider()
    for i = 1, 10 do
        local name, value = debug.getupvalue(vim.lsp.codelens.get, i)
        if name == "Provider" then
            return value
        end
    end
end

local function set_lens_status(bufnr, client_id, lens, status)
    if not (bufnr and client_id and lens and lens.command and status) then
        return
    end

    lens_state[bufnr] = lens_state[bufnr] or {}
    lens_state[bufnr][client_id] = lens_state[bufnr][client_id] or {}
    lens_state[bufnr][client_id][lens_key(lens.range.start.line, lens.command)] = status
end

local function clear_lens_status(bufnr, client_id, lens)
    local state = lens_state[bufnr] and lens_state[bufnr][client_id]
    if not (state and lens and lens.command) then
        return
    end

    state[lens_key(lens.range.start.line, lens.command)] = nil
end

local function apply_statuses(bufnr, client_id, row_lenses)
    local state = lens_state[bufnr] and lens_state[bufnr][client_id]
    if not state then
        return
    end

    for _, lenses in pairs(row_lenses) do
        for _, lens in ipairs(lenses) do
            if lens.command then
                lens.command.title = strip_status(lens.command.title or "")
            end
        end
    end
end

local function lens_status(bufnr, client_id, lens)
    local state = lens_state[bufnr] and lens_state[bufnr][client_id]
    if not (state and lens and lens.command) then
        return nil
    end

    return state[lens_key(lens.range.start.line, lens.command)]
end

local function status_highlight(status)
    if status == "passed" then
        return "TspMetalsCodelensPassed"
    elseif status == "failed" then
        return "TspMetalsCodelensFailed"
    elseif status == "running" then
        return "TspMetalsCodelensRunning"
    end
end

local function setup_codelens_highlights()
    vim.api.nvim_set_hl(0, "TspMetalsCodelensPassed", { link = "DiagnosticOk", default = true })
    vim.api.nvim_set_hl(0, "TspMetalsCodelensFailed", { link = "DiagnosticError", default = true })
    vim.api.nvim_set_hl(0, "TspMetalsCodelensRunning", { link = "DiagnosticWarn", default = true })
end

local function invalidate_row(bufnr, client_id, row)
    local provider = get_provider()
    local active = provider and provider.active and provider.active[bufnr]
    local state = active and active.client_state and active.client_state[client_id]
    if not (active and state) then
        return
    end

    active.row_version[row] = nil
    vim.api.nvim_buf_clear_namespace(bufnr, state.namespace, row, row + 1)
    vim.api.nvim__redraw({ buf = bufnr, valid = true, flush = false })
end

local function current_test_lens(client, bufnr, command)
    local row = vim.api.nvim_win_get_cursor(0)[1] - 1

    for _, item in ipairs(vim.lsp.codelens.get({ bufnr = bufnr, client_id = client.id })) do
        local lens = item.lens
        if lens.range.start.line == row and lens.command and lens.command.command == command.command and is_test_lens(lens.command) then
            return lens
        end
    end
end

local function finalize_session(session, status)
    local run = session_state[session]
    if not run then
        return
    end

    session_state[session] = nil
    set_lens_status(run.bufnr, run.client_id, run.lens, status)
    invalidate_row(run.bufnr, run.client_id, run.lens.range.start.line)
end

local failure_patterns = {
    "%f[%a]failures?[%f[%A]]",
    "%f[%a]failed[%f[%A]]",
    "test failed",
    "assertionerror",
    "comparisonfailure",
    "exception",
    "%*%*%* failed %*%*%*",
}

local function output_indicates_failure(output)
    if type(output) ~= "string" then
        return false
    end

    local text = output:lower()
    for _, pattern in ipairs(failure_patterns) do
        if text:find(pattern) then
            return true
        end
    end

    return false
end

local function install_dap_listeners()
    if dap_patched then
        return
    end

    local ok, dap = pcall(require, "dap")
    if not ok then
        return
    end

    local key = "tsp_metals_codelens"

    dap.listeners.after.event_initialized[key] = function(session)
        if not (session and session.config and session.config.type == "scala") then
            return
        end

        local run = table.remove(pending_runs, 1)
        if run then
            run.saw_failure = false
            session_state[session] = run
        end
    end

    dap.listeners.before.event_output[key] = function(session, body)
        local run = session_state[session]
        if not run then
            return
        end

        if output_indicates_failure(body and body.output) then
            run.saw_failure = true
        end
    end

    dap.listeners.before.event_stopped[key] = function(session, body)
        local run = session_state[session]
        if not run then
            return
        end

        local reason = body and body.reason
        if reason == "exception" then
            run.saw_failure = true
        end
    end

    dap.listeners.before.event_exited[key] = function(session, body)
        local run = session_state[session]
        if not run then
            return
        end

        local exit_code = body and body.exitCode
        if run.saw_failure then
            finalize_session(session, "failed")
        else
            finalize_session(session, exit_code == 0 and "passed" or "failed")
        end
    end

    dap.listeners.before.event_terminated[key] = function(session)
        local run = session_state[session]
        if not run then
            return
        end

        if run.saw_failure then
            finalize_session(session, "failed")
        else
            finalize_session(session, "passed")
        end
    end

    dap_patched = true
end

local function patch_codelens_handler()
    if handler_patched then
        return
    end

    local provider = get_provider()
    if not provider or not provider.handler then
        return
    end

    local original = provider.handler
    provider.handler = function(self, err, result, ctx)
        original(self, err, result, ctx)
        if not err then
            local state = self.client_state and self.client_state[ctx.client_id]
            if state then
                apply_statuses(self.bufnr, ctx.client_id, state.row_lenses)
            end
        end
    end

    handler_patched = true
end

local function patch_codelens_on_win()
    if on_win_patched then
        return
    end

    local provider = get_provider()
    if not provider or not provider.on_win then
        return
    end

    provider.on_win = function(self, toprow, botrow)
        local api = vim.api

        for row = toprow, botrow do
            if self.row_version[row] ~= self.version then
                for client_id, state in pairs(self.client_state) do
                    local bufnr = self.bufnr
                    local namespace = state.namespace

                    api.nvim_buf_clear_namespace(bufnr, namespace, row, row + 1)

                    local lenses = state.row_lenses[row]
                    if lenses then
                        table.sort(lenses, function(a, b)
                            return a.range.start.character < b.range.start.character
                        end)

                        local indent = api.nvim_buf_call(bufnr, function()
                            return vim.fn.indent(row + 1)
                        end)

                        local virt_lines = { { { string.rep(" ", indent), "LspCodeLensSeparator" } } }
                        local virt_text = virt_lines[1]
                        for _, lens in ipairs(lenses) do
                            if not lens.command then
                                local client = assert(vim.lsp.get_client_by_id(client_id))
                                self:resolve(client, lens)
                            else
                                local status = lens_status(bufnr, client_id, lens)
                                local prefix = STATUS_PREFIX[status]
                                local prefix_hl = status_highlight(status)
                                if prefix and prefix_hl then
                                    virt_text[#virt_text + 1] = { prefix, prefix_hl }
                                end
                                virt_text[#virt_text + 1] = { strip_status(lens.command.title), "LspCodeLens" }
                                virt_text[#virt_text + 1] = { " | ", "LspCodeLensSeparator" }
                            end
                        end

                        if #virt_text > 1 then
                            virt_text[#virt_text] = nil
                        else
                            virt_text[#virt_text + 1] = { "...", "LspCodeLens" }
                        end

                        api.nvim_buf_set_extmark(bufnr, namespace, row, 0, {
                            virt_lines = virt_lines,
                            virt_lines_above = true,
                            virt_lines_overflow = "scroll",
                            hl_mode = "combine",
                        })
                    end
                    self.row_version[row] = self.version
                end
            end
        end

        if botrow == api.nvim_buf_line_count(self.bufnr) - 1 then
            for _, state in pairs(self.client_state) do
                api.nvim_buf_clear_namespace(self.bufnr, state.namespace, botrow, -1)
            end
        end
    end

    on_win_patched = true
end

function metals_codelens.attach(client, bufnr)
    if client._tsp_metals_codelens_attached then
        return
    end

    setup_codelens_highlights()
    patch_codelens_handler()
    patch_codelens_on_win()
    install_dap_listeners()

    local run_command = client.commands["metals-run-session-start"]
    local debug_command = client.commands["metals-debug-session-start"]

    local function wrap(original)
        return function(command, context)
            if is_test_lens(command) then
                local lens = current_test_lens(client, bufnr, command)
                if lens then
                    clear_lens_status(bufnr, client.id, lens)
                    set_lens_status(bufnr, client.id, lens, "running")
                    invalidate_row(bufnr, client.id, lens.range.start.line)
                    for i = #pending_runs, 1, -1 do
                        pending_runs[i] = nil
                    end
                    table.insert(pending_runs, {
                        bufnr = bufnr,
                        client_id = client.id,
                        lens = lens,
                    })
                end
            end

            return original(command, context)
        end
    end

    if run_command then
        client.commands["metals-run-session-start"] = wrap(run_command)
    end

    if debug_command then
        client.commands["metals-debug-session-start"] = wrap(debug_command)
    end

    client._tsp_metals_codelens_attached = true
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
local function setup_ui()
    local function apply_theme_overrides()
        vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
        vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
        vim.api.nvim_set_hl(0, "NormalNC", { bg = "none" })
        vim.api.nvim_set_hl(0, "FloatBorder", { bg = "none" })
        vim.api.nvim_set_hl(0, "Pmenu", { bg = "none" })
        vim.api.nvim_set_hl(0, "StatusLine", { bg = "NONE" })
    end

    vim.cmd.colorscheme("gruber-darker")
    apply_theme_overrides()

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
end
-- }}}

-- Editor {{{
local function setup_editor()
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

    vim.keymap.set("n", "<leader>u", "<cmd>UndotreeToggle<cr>", { desc = "Toggle undo tree" })

    require("markview").setup({
        typst = { enable = false }
    })
end
-- }}}

-- Navigation {{{
local function setup_navigation()
    local fff = require("fff")

    local function current_cwd()
        return vim.uv.cwd()
    end

    local function live_grep_query(query, title)
        fff.live_grep({
            cwd = current_cwd(),
            query = query,
            title = title,
        })
    end

    require("mini.files").setup({
        mappings = {
            go_in = "l",
            go_in_plus = "L",
        },
    })

    vim.api.nvim_create_autocmd("User", {
        group = augroup("MiniFilesEnter"),
        pattern = "MiniFilesBufferCreate",
        callback = function(args)
            local function mini_files_ui_open()
                local path = (MiniFiles.get_fs_entry() or {}).path
                if path == nil then
                    vim.notify("Cursor is not on a valid file system entry", vim.log.levels.WARN)
                    return
                end
                if path:find(".pdf", 1, true) then
                    print(path)
                    vim.fn.system("kitty @ launch --location=vsplit tdf \"" .. path .. "\"")
                else
                    vim.ui.open(path)
                end
            end

            vim.keymap.set("n", "<CR>", function()
                MiniFiles.go_in({ close_on_file = true })
            end, { buffer = args.data.buf_id, desc = "Go in entry and close on file" })
            vim.keymap.set("n", "gx", mini_files_ui_open,
                { buffer = args.data.buf_id, desc = "Open entry with system handler" })
            vim.keymap.set("n", "<leader>w", function()
                MiniFiles.synchronize()
            end, { buffer = args.data.buf_id, desc = "Open entry with system handler" })
        end,
    })

    vim.keymap.set("n", "<leader>e", function()
        local path = vim.api.nvim_buf_get_name(0)
        if path == "" then
            MiniFiles.open()
            return
        end

        MiniFiles.open(path)
    end, { desc = "Open file explorer" })

    vim.g.fff = {
        lazy_sync = true,
        debug = {
            enabled = true,
            show_scores = true,
        },
    }

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

    vim.keymap.set("n", "<leader>pf", function()
        fff.find_files({
            cwd = current_cwd(),
            title = "Files",
        })
    end, { desc = "Find files" })

    vim.keymap.set("n", "<leader>g", function()
        fff.find_files({
            cwd = current_cwd(),
            title = "Files (hidden)",
        })
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

    local harpoon = require("harpoon")
    harpoon:setup()

    vim.keymap.set("n", "<leader>A", function()
        harpoon:list():prepend()
    end, { desc = "Harpoon prepend file" })

    vim.keymap.set("n", "<leader>a", function()
        harpoon:list():add()
    end, { desc = "Harpoon add file" })

    vim.keymap.set("n", "<C-e>", function()
        harpoon.ui:toggle_quick_menu(harpoon:list())
    end, { desc = "Harpoon quick menu" })

    vim.keymap.set("n", "<C-j>", function()
        harpoon:list():select(1)
    end, { desc = "Harpoon file 1" })

    vim.keymap.set("n", "<C-k>", function()
        harpoon:list():select(2)
    end, { desc = "Harpoon file 2" })

    vim.keymap.set("n", "<C-l>", function()
        harpoon:list():select(3)
    end, { desc = "Harpoon file 3" })

    vim.keymap.set("n", "<C-;>", function()
        harpoon:list():select(4)
    end, { desc = "Harpoon file 4" })

    vim.keymap.set("n", "<leader><C-j>", function()
        harpoon:list():replace_at(1)
    end, { desc = "Harpoon replace file 1" })

    vim.keymap.set("n", "<leader><C-k>", function()
        harpoon:list():replace_at(2)
    end, { desc = "Harpoon replace file 2" })

    vim.keymap.set("n", "<leader><C-l>", function()
        harpoon:list():replace_at(3)
    end, { desc = "Harpoon replace file 3" })

    vim.keymap.set("n", "<leader><C-;>", function()
        harpoon:list():replace_at(4)
    end, { desc = "Harpoon replace file 4" })

    require("trouble").setup({
        icons = false,
    })

    vim.keymap.set("n", "<leader>tt", function()
        require("trouble").toggle()
    end, { desc = "Toggle trouble" })

    vim.keymap.set("n", "[t", function()
        require("trouble").next({ skip_groups = true, jump = true })
    end, { desc = "Next trouble item" })

    vim.keymap.set("n", "]t", function()
        require("trouble").previous({ skip_groups = true, jump = true })
    end, { desc = "Previous trouble item" })

    require("flash").setup({})

    local flash = require("flash")
    vim.keymap.set({ "n", "x", "o" }, "s", flash.jump, { desc = "Flash" })
end

-- }}}

-- LSP Setup {{{
local function setup_lsp()
    local lsp_util = require("lspconfig.util")
    local mason_lspconfig = require("mason-lspconfig")
    local blink = require("blink.cmp")
    local luasnip = require("luasnip")
    local capabilities = lsp_common.build_capabilities()

    require("lsp_signature").setup(signature.opts)

    require("conform").setup({
        format_on_save = {
            timeout_ms = 500,
            lsp_format = "fallback",
        },
        formatters_by_ft = {
            c = { "clang-format" },
            cpp = { "clang-format" },
            lua = { "stylua" },
            go = { "gofmt" },
            javascript = { "prettier" },
            javascriptreact = { "prettier" },
            typescript = { "prettier" },
            typescriptreact = { "prettier" },
            css = { "prettier" },
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

    require("fidget").setup({
        progress = {
            ignore = { "metals" },
        },
    })

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
        },
        texlab = {},
        ts_ls = {},
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
                ["harper-ls"] = {
                    linters = {
                        SpellCheck = true,
                        SentenceCapitalization = false,
                        UnclosedQuotes = true,
                        RepeatedWords = true,
                    },
                },
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
            "ts_ls",
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
    vim.keymap.set("n", "<leader>lg", "<cmd>LazyGit<cr>", { desc = "Open LazyGit" })
end
-- }}}

-- Extras {{{
local function setup_extras()
    local cwd = vim.uv.cwd()
    local basename = vim.fs.basename(cwd)

    require("img-clip").setup({})
    vim.keymap.set("n", "<leader>ip", "<cmd>PasteImage<cr>", { desc = "Paste image from clipboard" })
    require("tau").setup({
        api_url = "https://openrouter.ai/api/v1",
        api_key = vim.env.OPENROUTER_API_KEY,
        model = "openai/gpt-4o",
    })
    vim.keymap.set("v", "<leader>t", ":Tau<CR>", { desc = "Tau: edit selection" })
    vim.keymap.set("n", "<C-t>", ":TauContext<CR>", { desc = "Tau: context files" })
    vim.keymap.set("n", "<leader>T", ":TauCancel<CR>", { desc = "Tau: cancel request" })
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

    require("neotest").setup({
        adapters = {
            require("neotest-golang")({
                dap = { justMyCode = false },
            }),
        },
    })

    vim.keymap.set("n", "<leader>tr", function()
        require("neotest").run.run({
            suite = false,
            testify = true,
        })
    end, { desc = "Run nearest test" })

    vim.keymap.set("n", "<leader>tv", function()
        require("neotest").summary.toggle()
    end, { desc = "Toggle test summary" })

    vim.keymap.set("n", "<leader>ts", function()
        require("neotest").run.run({
            suite = true,
            testify = true,
        })
    end, { desc = "Run test suite" })

    vim.keymap.set("n", "<leader>td", function()
        require("neotest").run.run({
            suite = false,
            testify = true,
            strategy = "dap",
        })
    end, { desc = "Debug nearest test" })

    vim.keymap.set("n", "<leader>to", function()
        require("neotest").output.open()
    end, { desc = "Open test output" })

    vim.keymap.set("n", "<leader>ta", function()
        require("neotest").run.run(vim.fn.getcwd())
    end, { desc = "Run all tests in cwd" })
end
-- }}}

-- DAP {{{
local function setup_dap()
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

    require("dap").set_log_level("DEBUG")

    vim.keymap.set("n", "<F8>", function()
        require("dap").continue()
    end, { desc = "Debug continue" })
    vim.keymap.set("n", "<F10>", function()
        require("dap").step_over()
    end, { desc = "Debug step over" })
    vim.keymap.set("n", "<F11>", function()
        require("dap").step_into()
    end, { desc = "Debug step into" })
    vim.keymap.set("n", "<F12>", function()
        require("dap").step_out()
    end, { desc = "Debug step out" })
    vim.keymap.set("n", "<leader>b", function()
        require("dap").toggle_breakpoint()
    end, { desc = "Toggle breakpoint" })
    vim.keymap.set("n", "<leader>B", function()
        require("dap").set_breakpoint(vim.fn.input("Breakpoint condition: "))
    end, { desc = "Set conditional breakpoint" })

    local dap = require("dap")
    local dapui = require("dapui")

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

    local function toggle_debug_ui(name)
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

    vim.keymap.set("n", "<leader>dr", function()
        toggle_debug_ui("repl")
    end, { desc = "Toggle DAP REPL" })
    vim.keymap.set("n", "<leader>ds", function()
        toggle_debug_ui("stacks")
    end, { desc = "Toggle DAP stacks" })
    vim.keymap.set("n", "<leader>dw", function()
        toggle_debug_ui("watches")
    end, { desc = "Toggle DAP watches" })
    vim.keymap.set("n", "<leader>db", function()
        toggle_debug_ui("breakpoints")
    end, { desc = "Toggle DAP breakpoints" })
    vim.keymap.set("n", "<leader>dS", function()
        toggle_debug_ui("scopes")
    end, { desc = "Toggle DAP scopes" })
    vim.keymap.set("n", "<leader>dc", function()
        toggle_debug_ui("console")
    end, { desc = "Toggle DAP console" })

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
end
-- }}}

-- Languages {{{
local function setup_languages()
    local metals = require("metals")
    local group = augroup("Metals")
    local metals_config = metals.bare_config()

    metals_config.settings = {
        autoImportBuild = "all",
        verboseCompilation = false,
        serverProperties = { "-Xms256m", "-Xmx4g" },
    }
    metals_config.capabilities = lsp_common.build_capabilities()
    metals_config.init_options.statusBarProvider = "on"
    metals_config.on_attach = function(client, attached_bufnr)
        lsp_common.on_attach(client, attached_bufnr)
        local dap_ok, dap_err = pcall(metals.setup_dap)
        if not dap_ok then
            vim.notify("Metals DAP setup failed: " .. tostring(dap_err), vim.log.levels.WARN)
        end

        vim.lsp.codelens.enable(true, { bufnr = attached_bufnr })
        metals_codelens.attach(client, attached_bufnr)

        vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, {
            buffer = attached_bufnr,
            callback = function()
                if vim.api.nvim_buf_is_valid(attached_bufnr) then
                    vim.lsp.codelens.enable(true, { bufnr = attached_bufnr })
                end
            end,
        })

        vim.keymap.set("n", "<leader>cl", vim.lsp.codelens.run, {
            buffer = attached_bufnr,
            desc = "Run CodeLens",
        })
        vim.keymap.set("n", "<leader>mc", metals.commands, {
            buffer = attached_bufnr,
            desc = "Metals commands",
        })
    end

    local function attach_if_scala(bufnr)
        local filetype = vim.bo[bufnr].filetype
        if filetype ~= "scala" and filetype ~= "sbt" and filetype ~= "java" then
            return
        end

        vim.api.nvim_buf_call(bufnr, function()
            metals.initialize_or_attach(metals_config)
        end)
    end

    vim.api.nvim_create_autocmd("FileType", {
        group = group,
        pattern = { "scala", "sbt", "java" },
        callback = function(args)
            attach_if_scala(args.buf)
        end,
    })

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            attach_if_scala(bufnr)
        end
    end

    vim.api.nvim_create_autocmd("VimLeavePre", {
        group = group,
        callback = function()
            for _, client in ipairs(vim.lsp.get_clients()) do
                if client.name == "metals" then
                    client.stop()
                end
            end
        end,
    })

    require("typst-preview").setup({
        invert_colors = "auto",
    })
end
-- }}}
-- }}}

-- Bootstrap {{{
register_pack_commands()
register_pack_hooks()
install_plugins()
load_plugins()

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
