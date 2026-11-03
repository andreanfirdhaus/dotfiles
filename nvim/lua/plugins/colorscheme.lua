local opts = { transparent = true }

local theme = vim.fn.expand "~/.config/nvim/theme.json"
if vim.fn.filereadable(theme) == 1 then
  local ok, palette = pcall(vim.json.decode, table.concat(vim.fn.readfile(theme), "\n"))
  if ok and type(palette) == "table" then
    opts.colors = palette
  end
end

require("vague").setup(opts)

vim.cmd.colorscheme "vague"
