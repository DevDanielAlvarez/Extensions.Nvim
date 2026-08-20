if vim.g.loaded_extensions_nvim then
  return
end
vim.g.loaded_extensions_nvim = true

if vim.fn.has("nvim-0.9.0") == 0 then
  vim.notify("extensions.nvim requires Neovim >= 0.9.0", vim.log.levels.ERROR)
  return
end

vim.api.nvim_create_user_command("Extensions", function()
  require("extensions").open()
end, { desc = "Browse, install and remove Neovim plugins" })
