local M = {}

--- Path to the spec file extensions.nvim owns. It is imported by lazy.nvim
--- like any other module under `lua/plugins/`, so extensions.nvim never has
--- to touch files it doesn't own.
---@return string
function M.managed_file()
  return vim.fn.stdpath("config") .. "/lua/plugins/extensions-nvim.lua"
end

--- Derives the plugin name lazy.nvim uses as key in `Config.plugins`
--- (the same logic as `Spec.get_name` in lazy.nvim: strip a trailing
--- `.git`/`/`, then take the segment after the last `/`).
---@param repo string
---@return string
function M.short_name(repo)
  local name = repo:sub(-4) == ".git" and repo:sub(1, -5) or repo
  name = name:sub(-1) == "/" and name:sub(1, -2) or name
  return name:match("([^/]+)$") or name
end

---@return { [1]: string }[]
function M.read_specs()
  local path = M.managed_file()
  if vim.fn.filereadable(path) == 0 then
    return {}
  end

  local chunk, load_err = loadfile(path)
  if not chunk then
    vim.notify("[extensions.nvim] failed to parse " .. path .. ": " .. tostring(load_err), vim.log.levels.ERROR)
    return {}
  end

  local ok, specs = pcall(chunk)
  if not ok or type(specs) ~= "table" then
    vim.notify("[extensions.nvim] managed file did not return a table: " .. path, vim.log.levels.ERROR)
    return {}
  end
  return specs
end

---@param specs { [1]: string }[]
---@return boolean
function M.write_specs(specs)
  local path = M.managed_file()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")

  local lines = {
    "-- File managed by extensions.nvim -- changes here may be overwritten.",
    "return {",
  }
  for _, spec in ipairs(specs) do
    table.insert(lines, string.format("  { %q },", spec[1]))
  end
  table.insert(lines, "}")
  table.insert(lines, "")

  local file, open_err = io.open(path, "w")
  if not file then
    vim.notify("[extensions.nvim] could not write " .. path .. ": " .. tostring(open_err), vim.log.levels.ERROR)
    return false
  end
  file:write(table.concat(lines, "\n"))
  file:close()
  return true
end

--- Re-parses lazy.nvim's plugin specs from disk (same internal call lazy.nvim's
--- own file-watcher uses) so newly written/removed entries take effect
--- immediately, without requiring a restart.
local function reload_specs()
  local ok, Plugin = pcall(require, "lazy.core.plugin")
  if ok then
    Plugin.load()
  else
    vim.notify("[extensions.nvim] lazy.nvim not found", vim.log.levels.ERROR)
  end
end

---@param repo string `user/repo`
function M.install(repo)
  local specs = M.read_specs()
  for _, spec in ipairs(specs) do
    if spec[1] == repo then
      return -- already tracked
    end
  end

  table.insert(specs, { repo })
  if not M.write_specs(specs) then
    return
  end

  reload_specs()

  local name = M.short_name(repo)
  local ok, Config = pcall(require, "lazy.core.config")
  if not ok or not Config.plugins[name] then
    vim.notify(
      "[extensions.nvim] added "
        .. repo
        .. " to "
        .. M.managed_file()
        .. ", but lazy.nvim did not pick it up. Make sure your lazy.nvim spec "
        .. 'imports that directory, e.g. `{ import = "plugins" }`.',
      vim.log.levels.ERROR
    )
    return
  end

  require("lazy").install({ plugins = { name }, show = true })
end

---@param repo string `user/repo`
function M.remove(repo)
  local specs = M.read_specs()
  local kept = {}
  for _, spec in ipairs(specs) do
    if spec[1] ~= repo then
      table.insert(kept, spec)
    end
  end

  if not M.write_specs(kept) then
    return
  end

  reload_specs()
  require("lazy").clean({ show = true })
end

return M
