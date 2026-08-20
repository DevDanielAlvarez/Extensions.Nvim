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

---@param value boolean|integer|number|string
---@return string
local function serialize_value(value)
  local t = type(value)
  if t == "string" then
    return string.format("%q", value)
  elseif t == "number" or t == "boolean" then
    return tostring(value)
  end
  error("[extensions.nvim] cannot serialize opt value of type " .. t)
end

--- Virtual config key (never a real plugin option): when true, the catalog
--- item's `default_keymaps` raw Lua source is spliced in as a `keys = {...}`
--- field on the spec entry, alongside (not inside) `opts`. Filtered out of
--- the serialized `opts` table itself so it never reaches the plugin's
--- `.setup(opts)` call.
local DEFAULT_KEYMAPS_OPT = "enabled_default_keymaps"

--- Looks up a catalog item's raw `default_keymaps` source by repo. Required
--- lazily (not at module load) to avoid a load-time circular require with
--- extensions.catalog, which itself requires extensions.status ->
--- extensions.installer.
---@param repo string
---@return string?
local function default_keymaps_source(repo)
  local ok, Catalog = pcall(require, "extensions.catalog")
  if not ok then
    return nil
  end
  for _, item in ipairs(Catalog.items) do
    if item.repo == repo then
      return item.default_keymaps
    end
  end
  return nil
end

---@param specs { [1]: string, opts?: table<string, boolean|integer|string> }[]
---@return boolean
function M.write_specs(specs)
  local path = M.managed_file()
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")

  local lines = {
    "-- File managed by extensions.nvim -- changes here may be overwritten.",
    "return {",
  }
  for _, spec in ipairs(specs) do
    local opts = spec.opts or {}
    local want_keys = opts[DEFAULT_KEYMAPS_OPT] == true

    local opt_parts = {}
    for key, value in pairs(opts) do
      if key ~= DEFAULT_KEYMAPS_OPT then
        table.insert(opt_parts, string.format("%s = %s", key, serialize_value(value)))
      end
    end
    table.sort(opt_parts) -- deterministic output regardless of pairs() order

    local entry_parts = {}
    if #opt_parts > 0 then
      table.insert(entry_parts, string.format("opts = { %s }", table.concat(opt_parts, ", ")))
    end
    if want_keys then
      local keys_src = default_keymaps_source(spec[1])
      if keys_src then
        table.insert(entry_parts, "keys = " .. keys_src)
      else
        vim.notify("[extensions.nvim] no default keymaps available for " .. spec[1], vim.log.levels.WARN)
      end
    end

    if #entry_parts > 0 then
      table.insert(lines, string.format("  { %q, %s },", spec[1], table.concat(entry_parts, ", ")))
    else
      table.insert(lines, string.format("  { %q },", spec[1]))
    end
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

--- Current configured `opts` for an installed plugin (empty table if none
--- set yet).
---@param repo string `user/repo`
---@return table<string, boolean|integer|string>
function M.get_opts(repo)
  local specs = M.read_specs()
  for _, spec in ipairs(specs) do
    if spec[1] == repo then
      return spec.opts or {}
    end
  end
  return {}
end

--- Sets a single option on an already-tracked plugin's spec entry and
--- rewrites the managed file. Requires the plugin to already be tracked
--- (i.e. installed through this plugin) -- configuring before installing
--- is refused rather than silently pre-staging an install.
---@param repo string `user/repo`
---@param key string
---@param value boolean|integer|string
function M.set_opt(repo, key, value)
  local specs = M.read_specs()
  local target = nil
  for _, spec in ipairs(specs) do
    if spec[1] == repo then
      target = spec
      break
    end
  end

  if not target then
    vim.notify("[extensions.nvim] " .. repo .. " is not installed yet -- install it before configuring.", vim.log.levels.WARN)
    return
  end

  target.opts = target.opts or {}
  target.opts[key] = value

  if not M.write_specs(specs) then
    return
  end

  reload_specs()
  vim.notify(
    "[extensions.nvim] saved. Most plugins only apply opts once at load time -- "
      .. "run `:Lazy reload "
      .. M.short_name(repo)
      .. "` or restart Neovim for it to take effect.",
    vim.log.levels.INFO
  )
end

return M
