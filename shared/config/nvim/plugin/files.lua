vim.pack.add({ 'https://github.com/nvim-mini/mini.files' })
vim.pack.add({ 'https://github.com/stevearc/oil.nvim' })
vim.pack.add({ 'https://github.com/nvim-mini/mini.icons' })

require('mini.icons').setup()

require('mini.files').setup({
    -- Customization of shown content
    content = {
        -- Predicate for which file system entries to show
        filter = nil,
        -- Highlight group to use for a file system entry
        highlight = nil,
        -- Prefix text and highlight to show to the left of file system entry
        prefix = nil,
        -- Order in which to show file system entries
        sort = nil,
    },

    -- Module mappings created only inside explorer.
    -- Use `''` (empty string) to not create one.
    mappings = {
        close       = 'q',
        go_in       = '<CR>',
        go_in_plus  = '<CR>',
        go_out      = '-',
        go_out_plus = '-',
        mark_goto   = "'",
        mark_set    = 'm',
        reset       = '<BS>',
        reveal_cwd  = '@',
        show_help   = 'g?',
        synchronize = '<leader>w',
        trim_left   = '<',
        trim_right  = '>',
    },

    -- General options
    options = {
        -- Whether to delete permanently or move into module-specific trash
        permanent_delete = true,
        -- Whether to use for editing directories
        use_as_default_explorer = true,
        -- Timeout for synchronous LSP integration requests
        lsp_timeout = 1000,
    },

    -- Customization of explorer windows
    windows = {
        -- Maximum number of windows to show side by side
        max_number = math.huge,
        -- Whether to show preview of file/directory under cursor
        preview = false,
        -- Width of focused window
        width_focus = 50,
        -- Width of non-focused window
        width_nofocus = 15,
        -- Width of preview window
        width_preview = 25,
    },
})

vim.keymap.set("n", "<leader>e", function()
    MiniFiles.open()
end)

-- require("oil").setup({
--     -- Oil will take over directory buffers (e.g. `vim .` or `:e src/`)
--     -- Set to false if you want some other plugin (e.g. netrw) to open when you edit directories.
--     default_file_explorer = true,
--     -- Id is automatically added at the beginning, and name at the end
--     -- See :help oil-columns
--     columns = {
--         "icon",
--         "permissions",
--         "size",
--         "mtime",
--     },
--     -- Buffer-local options to use for oil buffers
--     buf_options = {
--         buflisted = false,
--         bufhidden = "hide",
--     },
--     -- Window-local options to use for oil buffers
--     win_options = {
--         wrap = false,
--         signcolumn = "no",
--         cursorcolumn = false,
--         foldcolumn = "0",
--         spell = false,
--         list = false,
--         conceallevel = 3,
--         concealcursor = "nvic",
--     },
--     delete_to_trash = false,
--     skip_confirm_for_simple_edits = false,
--     prompt_save_on_select_new_entry = true,
--     cleanup_delay_ms = 2000,
--     lsp_file_methods = {
--         enabled = true,
--         timeout_ms = 1000,
--         autosave_changes = false,
--     },
--     constrain_cursor = "editable",
--     watch_for_changes = false,
--     keymaps = {
--         ["g?"] = { "actions.show_help", mode = "n" },
--         ["<CR>"] = "actions.select",
--         ["<C-s>"] = { "actions.select", opts = { vertical = true } },
--         ["<C-h>"] = { "actions.select", opts = { horizontal = true } },
--         ["<C-t>"] = { "actions.select", opts = { tab = true } },
--         ["<C-p>"] = "actions.preview",
--         ["<C-c>"] = { "actions.close", mode = "n" },
--         ["<C-l>"] = "actions.refresh",
--         ["-"] = { "actions.parent", mode = "n" },
--         ["_"] = { "actions.open_cwd", mode = "n" },
--         ["`"] = { "actions.cd", mode = "n" },
--         ["g~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
--         ["gs"] = { "actions.change_sort", mode = "n" },
--         ["gx"] = "actions.open_external",
--         ["g."] = { "actions.toggle_hidden", mode = "n" },
--         ["g\\"] = { "actions.toggle_trash", mode = "n" },
--     },
--     use_default_keymaps = true,
--     view_options = {
--         show_hidden = false,
--         is_hidden_file = function(name, bufnr) local m = name:match("^%.")
--             return m ~= nil
--         end,
--         is_always_hidden = function(name, bufnr)
--             return false
--         end,
--         natural_order = "fast",
--         case_insensitive = false,
--         sort = {
--             { "type", "asc" },
--             { "name", "asc" },
--         },
--         highlight_filename = function(entry, is_hidden, is_link_target, is_link_orphan)
--             return nil
--         end,
--     },
--     extra_scp_args = {},
--     extra_s3_args = {},
--     git = {
--         add = function(path)
--             return false
--         end,
--         mv = function(src_path, dest_path)
--             return false
--         end,
--         rm = function(path)
--             return false
--         end,
--     },
--     -- Configuration for the floating window in oil.open_float
--     float = {
--         -- Padding around the floating window
--         padding = 2,
--         -- max_width and max_height can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
--         max_width = 0,
--         max_height = 0,
--         border = nil,
--         win_options = {
--             winblend = 0,
--         },
--         -- optionally override the oil buffers window title with custom function: fun(winid: integer): string
--         get_win_title = nil,
--         -- preview_split: Split direction: "auto", "left", "right", "above", "below".
--         preview_split = "auto",
--         -- This is the config that will be passed to nvim_open_win.
--         -- Change values here to customize the layout
--         override = function(conf)
--             return conf
--         end,
--     },
--     -- Configuration for the file preview window
--     preview_win = {
--         -- Whether the preview window is automatically updated when the cursor is moved
--         update_on_cursor_moved = true,
--         -- How to open the preview window "load"|"scratch"|"fast_scratch"
--         preview_method = "fast_scratch",
--         -- A function that returns true to disable preview on a file e.g. to avoid lag
--         disable_preview = function(filename)
--             return false
--         end,
--         -- Window-local options to use for preview window buffers
--         win_options = {},
--     },
--     -- Configuration for the floating action confirmation window
--     confirmation = {
--         -- Width dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
--         -- min_width and max_width can be a single value or a list of mixed integer/float types.
--         -- max_width = {100, 0.8} means "the lesser of 100 columns or 80% of total"
--         max_width = 0.9,
--         -- min_width = {40, 0.4} means "the greater of 40 columns or 40% of total"
--         min_width = { 40, 0.4 },
--         -- optionally define an integer/float for the exact width of the preview window
--         width = nil,
--         -- Height dimensions can be integers or a float between 0 and 1 (e.g. 0.4 for 40%)
--         -- min_height and max_height can be a single value or a list of mixed integer/float types.
--         -- max_height = {80, 0.9} means "the lesser of 80 columns or 90% of total"
--         max_height = 0.9,
--         -- min_height = {5, 0.1} means "the greater of 5 columns or 10% of total"
--         min_height = { 5, 0.1 },
--         -- optionally define an integer/float for the exact height of the preview window
--         height = nil,
--         border = nil,
--         win_options = {
--             winblend = 0,
--         },
--     },
--     -- Configuration for the floating progress window
--     progress = {
--         max_width = 0.9,
--         min_width = { 40, 0.4 },
--         width = nil,
--         max_height = { 10, 0.9 },
--         min_height = { 5, 0.1 },
--         height = nil,
--         border = nil,
--         minimized_border = "none",
--         win_options = { },
--     },
--     -- Configuration for the floating SSH window
--     ssh = {
--         border = nil,
--     },
--     -- Configuration for the floating keymaps help window
--     keymaps_help = {
--         border = nil,
--     },
-- })
--
-- vim.keymap.set("n", "<leader>e", "<CMD>Oil<CR>")
