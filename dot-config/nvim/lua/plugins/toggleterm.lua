return {{
    "akinsho/toggleterm.nvim",
    version = "*",
    config = function()
        local toggleterm = require("toggleterm")

        toggleterm.setup({
            size = 20,
            shading_factor = 2,
            persist_size = true,
            close_on_exit = true
        })

        toggleterm.setup({
            size = function(term)
                if term.direction == "horizontal" then
                    return 15 -- height in lines for horizontal terminal
                elseif term.direction == "vertical" then
                    return 50 -- width in columns for vertical terminal
                elseif term.direction == "float" then
                    return 0.8 -- 80% of screen for float terminal
                end
            end,
            shading_factor = 2,
            persist_size = true,
            close_on_exit = true
        })

        -- Keymaps for different terminal types
        vim.api.nvim_set_keymap("n", "<leader>tf", ":ToggleTerm direction=float<CR>", {
            noremap = true,
            silent = true
        })
        vim.api.nvim_set_keymap("n", "<leader>th", ":ToggleTerm direction=horizontal<CR>", {
            noremap = true,
            silent = true
        })
        vim.api.nvim_set_keymap("n", "<leader>tv", ":ToggleTerm direction=vertical<CR>", {
            noremap = true,
            silent = true
        })

        -- Default toggle keymap
        vim.api.nvim_set_keymap("n", "<C-\\>", ":ToggleTerm<CR>", {
            noremap = true,
            silent = true
        })
        vim.api.nvim_set_keymap("t", "<C-\\>", "<C-\\><C-n>:ToggleTerm<CR>", {
            noremap = true,
            silent = true
        })
    end

}}
