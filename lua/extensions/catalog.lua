local Config = require("extensions.config")
local Status = require("extensions.status")

local M = {}

---@class ExtensionsCatalogItem
---@field repo string `user/repo` (as used by lazy.nvim)
---@field name string display name
---@field description string
---@field category string
---@field tags string[]

---@type ExtensionsCatalogItem[]
M.builtin = {
  {
    repo = "nvim-telescope/telescope.nvim",
    name = "telescope.nvim",
    description = "Fuzzy finder over files, buffers, LSP symbols and more.",
    category = "search",
    tags = { "finder", "fuzzy", "picker" },
  },
  {
    repo = "nvim-treesitter/nvim-treesitter",
    name = "nvim-treesitter",
    description = "Better syntax highlighting and code understanding via Treesitter.",
    category = "editor",
    tags = { "syntax", "highlight", "parser" },
  },
  {
    repo = "neovim/nvim-lspconfig",
    name = "nvim-lspconfig",
    description = "Quickstart configs for the Neovim LSP client.",
    category = "lsp",
    tags = { "lsp", "language-server" },
  },
  {
    repo = "hrsh7th/nvim-cmp",
    name = "nvim-cmp",
    description = "Completion engine with support for LSP, snippets, buffer and path sources.",
    category = "completion",
    tags = { "completion", "autocomplete" },
  },
  {
    repo = "L3MON4D3/LuaSnip",
    name = "LuaSnip",
    description = "Snippet engine written in Lua.",
    category = "completion",
    tags = { "snippets" },
  },
  {
    repo = "lewis6991/gitsigns.nvim",
    name = "gitsigns.nvim",
    description = "Git decorations in the sign column, hunk actions and blame.",
    category = "git",
    tags = { "git", "signs", "blame" },
  },
  {
    repo = "tpope/vim-fugitive",
    name = "vim-fugitive",
    description = "The classic Git command wrapper for Vim/Neovim.",
    category = "git",
    tags = { "git" },
  },
  {
    repo = "nvim-tree/nvim-tree.lua",
    name = "nvim-tree.lua",
    description = "File explorer tree sidebar.",
    category = "ui",
    tags = { "explorer", "file-tree" },
  },
  {
    repo = "nvim-neo-tree/neo-tree.nvim",
    name = "neo-tree.nvim",
    description = "File explorer that supports multiple sources: files, buffers, git.",
    category = "ui",
    tags = { "explorer", "file-tree" },
  },
  {
    repo = "nvim-lualine/lualine.nvim",
    name = "lualine.nvim",
    description = "Fast and configurable statusline.",
    category = "ui",
    tags = { "statusline" },
  },
  {
    repo = "akinsho/bufferline.nvim",
    name = "bufferline.nvim",
    description = "Snazzy buffer/tab line with grouping and diagnostics.",
    category = "ui",
    tags = { "tabline", "bufferline" },
  },
  {
    repo = "folke/tokyonight.nvim",
    name = "tokyonight.nvim",
    description = "Clean, dark Neovim colorscheme with multiple variants.",
    category = "colorscheme",
    tags = { "theme", "colorscheme" },
  },
  {
    repo = "catppuccin/nvim",
    name = "catppuccin",
    description = "Soothing pastel colorscheme with many integrations.",
    category = "colorscheme",
    tags = { "theme", "colorscheme" },
  },
  {
    repo = "folke/which-key.nvim",
    name = "which-key.nvim",
    description = "Displays a popup with possible keybindings as you type.",
    category = "editor",
    tags = { "keymaps", "help" },
  },
  {
    repo = "folke/trouble.nvim",
    name = "trouble.nvim",
    description = "Pretty list for diagnostics, references, quickfix and more.",
    category = "lsp",
    tags = { "diagnostics", "list" },
  },
  {
    repo = "folke/todo-comments.nvim",
    name = "todo-comments.nvim",
    description = "Highlight and search TODO/FIXME/NOTE comments.",
    category = "editor",
    tags = { "todo", "comments" },
  },
  {
    repo = "folke/noice.nvim",
    name = "noice.nvim",
    description = "Replaces the UI for messages, cmdline and popupmenu.",
    category = "ui",
    tags = { "ui", "cmdline", "messages" },
  },
  {
    repo = "folke/flash.nvim",
    name = "flash.nvim",
    description = "Fast, label-based motion for jumping anywhere in the buffer.",
    category = "editor",
    tags = { "motion", "jump" },
  },
  {
    repo = "numToStr/Comment.nvim",
    name = "Comment.nvim",
    description = "Smart and powerful comment toggling.",
    category = "editing",
    tags = { "comment" },
  },
  {
    repo = "windwp/nvim-autopairs",
    name = "nvim-autopairs",
    description = "Automatically close brackets, quotes and pairs as you type.",
    category = "editing",
    tags = { "autopairs", "brackets" },
  },
  {
    repo = "lukas-reineke/indent-blankline.nvim",
    name = "indent-blankline.nvim",
    description = "Indentation guides for every line.",
    category = "ui",
    tags = { "indent", "guides" },
  },
  {
    repo = "kylechui/nvim-surround",
    name = "nvim-surround",
    description = "Add, delete and change surrounding pairs (quotes, brackets, tags).",
    category = "editing",
    tags = { "surround" },
  },
  {
    repo = "williamboman/mason.nvim",
    name = "mason.nvim",
    description = "Portable package manager for LSP servers, DAP servers, linters and formatters.",
    category = "lsp",
    tags = { "lsp", "installer", "mason" },
  },
  {
    repo = "williamboman/mason-lspconfig.nvim",
    name = "mason-lspconfig.nvim",
    description = "Bridges mason.nvim with nvim-lspconfig.",
    category = "lsp",
    tags = { "lsp", "mason" },
  },
  {
    repo = "stevearc/conform.nvim",
    name = "conform.nvim",
    description = "Lightweight yet powerful formatter plugin.",
    category = "lsp",
    tags = { "format", "formatter" },
  },
  {
    repo = "mfussenegger/nvim-lint",
    name = "nvim-lint",
    description = "Asynchronous linter plugin.",
    category = "lsp",
    tags = { "lint", "linter" },
  },
  {
    repo = "mfussenegger/nvim-dap",
    name = "nvim-dap",
    description = "Debug Adapter Protocol client for Neovim.",
    category = "debug",
    tags = { "debug", "dap" },
  },
  {
    repo = "rcarriga/nvim-dap-ui",
    name = "nvim-dap-ui",
    description = "UI for nvim-dap.",
    category = "debug",
    tags = { "debug", "dap", "ui" },
  },
  {
    repo = "j-hui/fidget.nvim",
    name = "fidget.nvim",
    description = "Standalone UI for LSP progress notifications.",
    category = "ui",
    tags = { "lsp", "progress", "notify" },
  },
  {
    repo = "nvim-neotest/neotest",
    name = "neotest",
    description = "Extensible framework for running and displaying test results.",
    category = "testing",
    tags = { "test", "testing" },
  },
  {
    repo = "echasnovski/mini.nvim",
    name = "mini.nvim",
    description = "Library of independent, well-designed small modules for Neovim.",
    category = "editing",
    tags = { "mini", "library" },
  },
}

---@type ExtensionsCatalogItem[]
M.items = M.builtin

--- (Re)loads the catalog, applying a custom catalog_path override if configured.
function M.load()
  M.items = M.builtin

  local path = Config.options.catalog_path
  if not path then
    return
  end

  if vim.fn.filereadable(path) == 0 then
    vim.notify("[extensions.nvim] catalog_path not readable: " .. path, vim.log.levels.WARN)
    return
  end

  local ok, custom = pcall(dofile, path)
  if ok and type(custom) == "table" then
    M.items = custom
  else
    vim.notify("[extensions.nvim] failed to load catalog_path: " .. path, vim.log.levels.ERROR)
  end
end

---@class ExtensionsFilter
---@field query? string
---@field status? "all"|"installed"|"not_installed"

--- Returns catalog items matching the given filter.
---@param filter? ExtensionsFilter
---@return ExtensionsCatalogItem[]
function M.filter(filter)
  filter = filter or {}
  local query = (filter.query or ""):lower()
  local status = filter.status or "all"

  ---@type ExtensionsCatalogItem[]
  local result = {}
  for _, item in ipairs(M.items) do
    local matches_query = query == ""
      or item.name:lower():find(query, 1, true)
      or item.description:lower():find(query, 1, true)
      or vim.tbl_contains(item.tags or {}, query)

    local installed = Status.is_installed(item.repo)
    local matches_status = status == "all"
      or (status == "installed" and installed)
      or (status == "not_installed" and not installed)

    if matches_query and matches_status then
      table.insert(result, item)
    end
  end
  return result
end

return M
