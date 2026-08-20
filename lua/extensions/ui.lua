local Split = require("nui.split")
local Popup = require("nui.popup")
local Line = require("nui.line")
local Input = require("nui.input")

local Catalog = require("extensions.catalog")
local Status = require("extensions.status")
local Installer = require("extensions.installer")

local M = {}

local ns = vim.api.nvim_create_namespace("extensions_nvim")

local STATUS_LABELS = {
  all = "All",
  installed = "Installed",
  not_installed = "Not installed",
}
local STATUS_CYCLE = { "all", "installed", "not_installed" }

---@type table
local state = {
  split = nil,
  detail = nil,
  filter = { query = "", status = "all" },
  line_to_item = {},
}

local reload_autocmd_id = nil

--- Re-renders the list whenever an install/clean/sync finishes, so status
--- icons stay correct without the user having to press `r` manually.
local function ensure_reload_autocmd()
  if reload_autocmd_id then
    return
  end
  reload_autocmd_id = vim.api.nvim_create_autocmd("User", {
    pattern = { "LazyInstall", "LazyClean", "LazySync" },
    callback = function()
      if state.split then
        M.render_list()
      end
    end,
  })
end

---@return ExtensionsCatalogItem?
local function current_item()
  if not state.split or not state.split.winid then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(state.split.winid)[1]
  return state.line_to_item[row]
end

function M.render_list()
  if not state.split then
    return
  end
  local bufnr = state.split.bufnr

  local items = Catalog.filter(state.filter)
  state.line_to_item = {}

  vim.bo[bufnr].modifiable = true
  vim.bo[bufnr].readonly = false
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  if #items == 0 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "  (no plugins match the current filter)" })
  else
    for i, item in ipairs(items) do
      local installed = Status.is_installed(item.repo)
      local line = Line()
      line:append(installed and "[x] " or "[ ] ", installed and "DiagnosticOk" or "Comment")
      line:append(item.name .. " ", "Title")
      line:append(item.description, "Comment")
      line:render(bufnr, ns, i)
      state.line_to_item[i] = item
    end
  end

  vim.bo[bufnr].modifiable = false
  vim.bo[bufnr].readonly = true
  vim.wo[state.split.winid].winbar = string.format(
    "Extensions  [%s]  search: %s",
    STATUS_LABELS[state.filter.status],
    state.filter.query == "" and "<none>" or state.filter.query
  )
end

function M.close_detail()
  if state.detail then
    state.detail:unmount()
    state.detail = nil
  end
end

function M.show_detail()
  local item = current_item()
  if not item then
    return
  end

  M.close_detail()

  local installed = Status.is_installed(item.repo)
  local popup = Popup({
    relative = "editor",
    position = "50%",
    size = { width = 64, height = 10 },
    enter = true,
    focusable = true,
    zindex = 60,
    border = {
      style = "rounded",
      text = { top = " " .. item.name .. " ", top_align = "center" },
    },
    buf_options = { modifiable = false, readonly = true, filetype = "markdown" },
    win_options = { wrap = true },
  })
  popup:mount()
  state.detail = popup

  local lines = {
    "repo:        " .. item.repo,
    "category:    " .. item.category,
    "status:      " .. (installed and "installed" or "not installed"),
    "",
    item.description,
    "",
    "[i] install   [x] remove   [q] close",
  }
  vim.bo[popup.bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(popup.bufnr, 0, -1, false, lines)
  vim.bo[popup.bufnr].modifiable = false

  popup:map("n", "q", function()
    M.close_detail()
  end, { noremap = true })
  popup:map("n", "<Esc>", function()
    M.close_detail()
  end, { noremap = true })
  popup:map("n", "i", function()
    Installer.install(item.repo)
    M.close_detail()
  end, { noremap = true })
  popup:map("n", "x", function()
    Installer.remove(item.repo)
    M.close_detail()
  end, { noremap = true })
end

function M.install_selected()
  local item = current_item()
  if not item then
    return
  end
  Installer.install(item.repo)
end

function M.remove_selected()
  local item = current_item()
  if not item then
    return
  end
  Installer.remove(item.repo)
end

function M.prompt_search()
  local input = Input({
    relative = "editor",
    position = "50%",
    size = { width = 40 },
    border = { style = "rounded", text = { top = " Search ", top_align = "center" } },
    win_options = { winhighlight = "Normal:Normal" },
  }, {
    prompt = "> ",
    default_value = state.filter.query,
    on_submit = function(value)
      state.filter.query = value
      M.render_list()
    end,
  })
  input:mount()
  input:map("n", "<Esc>", function()
    input:unmount()
  end, { noremap = true })
end

function M.cycle_status_filter()
  local idx = 1
  for i, status in ipairs(STATUS_CYCLE) do
    if status == state.filter.status then
      idx = i
      break
    end
  end
  state.filter.status = STATUS_CYCLE[(idx % #STATUS_CYCLE) + 1]
  M.render_list()
end

function M.reload()
  Catalog.load()
  M.render_list()
end

function M.close()
  M.close_detail()
  if state.split then
    state.split:unmount()
    state.split = nil
  end
end

local function create_split()
  local split = Split({
    relative = "editor",
    position = "left",
    size = 50,
    buf_options = {
      modifiable = false,
      readonly = true,
      filetype = "extensions",
      buftype = "nofile",
      swapfile = false,
    },
    win_options = {
      number = false,
      relativenumber = false,
      wrap = false,
      cursorline = true,
      signcolumn = "no",
    },
  })
  split:mount()
  state.split = split

  split:map("n", "<CR>", M.show_detail, { noremap = true })
  split:map("n", "i", M.install_selected, { noremap = true })
  split:map("n", "x", M.remove_selected, { noremap = true })
  split:map("n", "/", M.prompt_search, { noremap = true })
  split:map("n", "<Tab>", M.cycle_status_filter, { noremap = true })
  split:map("n", "r", M.reload, { noremap = true })
  split:map("n", "q", M.close, { noremap = true })

  ensure_reload_autocmd()
  M.render_list()
end

function M.open()
  if state.split and state.split.winid and vim.api.nvim_win_is_valid(state.split.winid) then
    vim.api.nvim_set_current_win(state.split.winid)
    return
  end
  create_split()
end

return M
