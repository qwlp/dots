-- 1. Install nvim-lspconfig (still needed for its community server registry commands/metadata)
vim.pack.add({
    { src = "https://github.com/neovim/nvim-lspconfig" },
    { src = "https://github.com/mason-org/mason-lspconfig.nvim" },
    { src = "https://github.com/williamboman/mason.nvim" },
})

-- 2. Initialize Mason
require("mason").setup()
require("mason-lspconfig").setup({
    ensure_installed = {
        "gopls", "lua_ls", "pyright", "tailwindcss",
        "vtsls", "zls", "harper_ls", "tinymist"
    }
})

-- 3. Neovim 0.11 Native LSP Configuration (Replaces lspconfig)
local lsp = vim.lsp

-- Default configs for servers that don't need changes
local simple_servers = { "gopls", "tinymist" }
for _, server in ipairs(simple_servers) do
    lsp.config(server, {})
end

-- Custom setups: Native 0.11 configuration format
lsp.config("lua_ls", {
    settings = {
        Lua = {
            format = {
                enable = true,
                defaultConfig = { indent_style = "space", indent_size = "2" },
            },
        },
    },
})

lsp.config("pyright", {
    before_init = function(_, config)
        if config.root_dir then
            local venv_python = vim.fs.joinpath(config.root_dir, ".venv", "bin", "python")
            if vim.uv.fs_stat(venv_python) then
                config.settings = config.settings or {}
                config.settings.python = config.settings.python or {}
                config.settings.python.pythonPath = venv_python
            end
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
})

lsp.config("tailwindcss", {
    -- Uses vim.fs.root for native root file searching
    root_dir = function(filename)
        return vim.fs.root(filename, {
            "tailwind.config.js", "tailwind.config.ts", "postcss.config.js"
        })
    end,
})

lsp.config("vtsls", {
    single_file_support = false,
    settings = {
        typescript = { preferences = { importModuleSpecifier = "non-relative" } },
        javascript = { preferences = { importModuleSpecifier = "non-relative" } },
    },
})

lsp.config("zls", {
    settings = {
        zls = { enable_inlay_hints = true, enable_snippets = true, warn_style = true },
    },
})

-- Restricting harper_ls using 0.11 configuration
lsp.config("harper_ls", {
    filetypes = { "typst", "tex", "markdown" },
    single_file_support = false,
})


-- 4. UI Customizations
vim.o.winborder = "rounded"

local orig_open_floating_preview = lsp.util.open_floating_preview
function lsp.util.open_floating_preview(contents, syntax, opts, ...)
    opts = opts or {}
    opts.border = opts.border or "rounded"
    opts.max_width = math.min(80, vim.o.columns - 10)
    opts.max_height = math.min(12, vim.o.lines - 10)
    return orig_open_floating_preview(contents, syntax, opts, ...)
end


-- 5. Keymaps
local map = vim.keymap.set
map("n", "gd", lsp.buf.definition, { desc = "LSP definition" })
map("n", "K", lsp.buf.hover, { desc = "LSP hover" })
map("n", "<leader>vws", lsp.buf.workspace_symbol, { desc = "LSP workspace symbols" })
map("n", "<leader>vd", vim.diagnostic.open_float, { desc = "Line diagnostics" })
map("n", "<leader>vc", lsp.buf.code_action, { desc = "Code action" })
map("n", "<leader>vrr", lsp.buf.references, { desc = "References" })
map("n", "<leader>vrn", lsp.buf.rename, { desc = "Rename symbol" })

map("n", "[d", function() vim.diagnostic.jump({ count = -1 }) end, { desc = "Previous diagnostic" })
map("n", "]d", function() vim.diagnostic.jump({ count = 1 }) end, { desc = "Next diagnostic" })
map({ "i", "n" }, "<C-h>", lsp.buf.signature_help, { desc = "LSP signature help" })
