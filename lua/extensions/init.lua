local Config = require("extensions.config")
local Catalog = require("extensions.catalog")

local M = {}

local did_setup = false

---@param opts? ExtensionsOptions
function M.setup(opts)
  Config.setup(opts)
  Catalog.load()
  did_setup = true
end

--- Opens the extensions UI. Lazily applies default setup() if the user
--- never called it explicitly (e.g. plain `cmd = "Extensions"` lazy spec).
function M.open()
  if not did_setup then
    M.setup({})
  end
  require("extensions.ui").open()
end

return M
