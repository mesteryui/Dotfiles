return {
	"nvimtools/none-ls.nvim",
	config = function()
		local null_ls = require("null-ls")
		null_ls.setup({
			sources = {
				null_ls.builtins.formatting.black, -- Formatting python
				null_ls.builtins.formatting.xmlformat, -- Formatting XML
				null_ls.builtins.diagnostics.mypy,
				null_ls.builtins.formatting.stylua,
				null_ls.builtins.completion.spell,
			},
		})
		vim.keymap.set("n", "<leader>f", vim.lsp.buf.format, {})
	end,
}
