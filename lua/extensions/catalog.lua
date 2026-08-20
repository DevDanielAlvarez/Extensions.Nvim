local Config = require("extensions.config")
local Status = require("extensions.status")

local M = {}

---@class ExtensionsConfigField
---@field key string option name written into the plugin's `opts` table
---@field input_type "toggle"|"int"|"string"
---@field input_name string label shown in the config popup
---@field default boolean|integer|string

---@class ExtensionsCatalogItem
---@field repo string `user/repo` (as used by lazy.nvim)
---@field name string display name
---@field description string
---@field category string
---@field tags string[]
---@field config? ExtensionsConfigField[] optional configurable options
---@field default_keymaps? string raw Lua source for a `keys = {...}` lazy.nvim spec block, spliced in verbatim when a "enabled_default_keymaps" toggle field is set to true

---@type ExtensionsCatalogItem[]
M.items = {}

--- Decodes a catalog JSON file (an array of ExtensionsCatalogItem) from disk.
---@param path string
---@return ExtensionsCatalogItem[]?
local function decode_file(path)
  local ok_read, lines = pcall(vim.fn.readfile, path)
  if not ok_read then
    vim.notify("[extensions.nvim] could not read " .. path, vim.log.levels.ERROR)
    return nil
  end

  local ok_decode, items = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not ok_decode or type(items) ~= "table" then
    vim.notify("[extensions.nvim] invalid catalog JSON: " .. path, vim.log.levels.ERROR)
    return nil
  end
  return items
end

--- (Re)loads the catalog: the bundled data/catalog.json, or a custom
--- catalog_path override (same JSON shape) when configured.
function M.load()
  local path = Config.options.catalog_path

  if not path then
    local found = vim.api.nvim_get_runtime_file("data/catalog.json", false)[1]
    if not found then
      vim.notify("[extensions.nvim] bundled data/catalog.json not found on runtimepath", vim.log.levels.ERROR)
      M.items = {}
      return
    end
    path = found
  elseif vim.fn.filereadable(path) == 0 then
    vim.notify("[extensions.nvim] catalog_path not readable: " .. path, vim.log.levels.WARN)
    return
  end

  local items = decode_file(path)
  if items then
    M.items = items
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
