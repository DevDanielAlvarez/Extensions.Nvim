local Installer = require("extensions.installer")

local M = {}

--- Whether a catalog plugin is currently installed, according to lazy.nvim's
--- own registry (`Config.plugins[name]._.installed`). This reflects plugins
--- installed by extensions.nvim as well as ones declared elsewhere by the
--- user, since it reads lazy.nvim's state directly rather than our own
--- managed file.
---@param repo string `user/repo`
---@return boolean
function M.is_installed(repo)
  local ok, Config = pcall(require, "lazy.core.config")
  if not ok then
    return false
  end

  local plugin = Config.plugins[Installer.short_name(repo)]
  return plugin ~= nil and plugin._ ~= nil and plugin._.installed == true
end

return M
