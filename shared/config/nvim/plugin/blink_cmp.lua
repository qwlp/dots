vim.pack.add({ 'https://github.com/saghen/blink.lib', 'https://github.com/saghen/blink.cmp'})
local cmp = require('blink.cmp')
cmp.setup({
    completion = {
        menu = {
            border = "rounded",
        },
        documentation = {
            window = {
                border = "rounded",
            },
        },
    },
    signature = {
        window = {
            border = "rounded",
        },
    },
})
