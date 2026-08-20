vim.keymap.set("v", "<LeftRelease>", [["+ygv]], { silent = true, desc = "[P]Mouse select -> yank to system clipboard" })
vim.keymap.set(
    "v",
    "<2-LeftRelease>",
    [["+ygv]],
    { silent = true, desc = "[P]Mouse select (double) -> yank to system clipboard" }
)
vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv", { silent = true, desc = "Move selected lines down" })
vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv", { silent = true, desc = "Move selected lines up" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines and keep cursor centered" })
vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Half-page down centered" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Half-page up centered" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result centered" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Previous search result centered" })
vim.keymap.set("n", "=ap", "ma=ap'a", { desc = "Reindent paragraph" })
vim.keymap.set('i', '<M-d>', '<BS>', { desc = 'Delete character to the left' })

vim.keymap.set("n", "<leader>q", "<cmd>q<cr>", { desc = "Quit window" })
vim.keymap.set("n", "<leader>w", "<cmd>w<cr><esc>", { desc = "Write buffer" })
vim.keymap.set("n", "<leader><leader>", "<cmd>source $MYVIMRC<cr>", { desc = "Reload config" })

-- vim.keymap.set("n", "<leader>r", compile_or_recompile, { desc = "Compile current buffer" })
vim.keymap.set("n", "<leader>pr", "<cmd>restart<cr>", { desc = "Restart nvim"})

vim.keymap.set("x", "<leader>p", [["_dP]], { desc = "Paste without yanking replaced text" })
vim.keymap.set({ "n", "v" }, "<leader>y", [["+y]], { desc = "Yank to system clipboard" })
vim.keymap.set("n", "<leader>Y", [["+Y]], { desc = "Yank line to system clipboard" })
vim.keymap.set({ "n", "v" }, "<leader>d", [["_d]], { desc = "Delete without yanking" })

vim.keymap.set("n", "<leader>k", "<cmd>lnext<cr>zz", { desc = "Next location list item" })
vim.keymap.set("n", "<leader>j", "<cmd>lprev<cr>zz", { desc = "Previous location list item" })

vim.keymap.set("n", "<leader>s", [[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]], { desc = "Substitute word under cursor" })
vim.keymap.set("n", "<leader>x", "<cmd>!chmod +x %<cr>", { silent = true, desc = "Make current file executable" })
vim.keymap.set("n", "<M-t>", "<cmd>vnew | terminal<cr>", { desc = "Open vertical terminal" })
vim.keymap.set("n", "<M-;>", "<cmd>split<cr>", { desc = "Horizonal split" })

vim.keymap.set({ "n", "t" }, "<M-h>", [[<C-\><C-n><C-w>h]], { desc = "Go to left window" })
vim.keymap.set({ "n", "t" }, "<M-j>", [[<C-\><C-n><C-w>j]], { desc = "Go to lower window" })
vim.keymap.set({ "n", "t" }, "<M-k>", [[<C-\><C-n><C-w>k]], { desc = "Go to upper window" })
vim.keymap.set({ "n", "t" }, "<M-l>", [[<C-\><C-n><C-w>l]], { desc = "Go to right window" })
vim.keymap.set({ "n", "t" }, "<M-.>", [[<C-\><C-n><C-w>2>]], { desc = "Increase pane size" })
vim.keymap.set({ "n", "t" }, "<M-,>", [[<C-\><C-n><C-w>2<]], { desc = "Decrease pane size" })
vim.keymap.set({ "n", "t" }, "<M-i>", [[<C-\><C-n><C-w>2+]], { desc = "Increase pane height" })
vim.keymap.set({ "n", "t" }, "<M-o>", [[<C-\><C-n><C-w>2-]], { desc = "Decrease pane height" })
