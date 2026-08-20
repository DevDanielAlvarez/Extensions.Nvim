local M = {}

---@class ExtensionsOptions
---@field catalog_path? string path to a JSON file (same shape as data/catalog.json) with a custom catalog list

---@type ExtensionsOptions
M.defaults = {
  catalog_path = nil,
}

---@type ExtensionsOptions
M.options = vim.deepcopy(M.defaults)

---@param opts? ExtensionsOptions
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", {}, M.defaults, opts or {})
end

return M
