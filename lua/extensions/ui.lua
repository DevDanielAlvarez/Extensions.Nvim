local Layout = require("nui.layout")
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

local HELP_TEXT = " [i] install  [x] remove  [/] search  [tab] filter  [r] reload  [q] quit "

---@type table
local state = {
  layout = nil,
  list = nil, ---@type NuiPopup?
  preview = nil, ---@type NuiPopup?
  filter = { query = "", status = "all" },
  line_to_item = {},
}

local reload_autocmd_id = nil

--- Re-renders whenever an install/clean/sync finishes, so status icons stay
--- correct without the user having to press `r` manually.
local function ensure_reload_autocmd()
  if reload_autocmd_id then
    return
  end
  reload_autocmd_id = vim.api.nvim_create_autocmd("User", {
    pattern = { "LazyInstall", "LazyClean", "LazySync" },
    callback = function()
      if state.list then
        M.render()
      end
    end,
  })
end

---@return ExtensionsCatalogItem?
local function current_item()
  if not state.list or not state.list.winid then
    return nil
  end
  local row = vim.api.nvim_win_get_cursor(state.list.winid)[1]
  return state.line_to_item[row]
end

local function render_preview()
  if not state.preview then
    return
  end
  local bufnr = state.preview.bufnr
  local item = current_item()

  vim.bo[bufnr].modifiable = true
  if not item then
    state.preview.border:set_text("top", " Details ", "center")
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "", "  Nothing selected." })
  else
    local installed = Status.is_installed(item.repo)
    state.preview.border:set_text("top", " " .. item.name .. " ", "center")
    local lines = {
      "",
      "  " .. (installed and "● installed" or "○ not installed"),
      "",
      "  repo       " .. item.repo,
      "  category   " .. item.category,
      "  tags       " .. table.concat(item.tags or {}, ", "),
      "",
      "  " .. item.description,
    }
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  end
  vim.bo[bufnr].modifiable = false
end

local function render_list()
  if not state.list then
    return
  end
  local bufnr = state.list.bufnr

  local items = Catalog.filter(state.filter)
  state.line_to_item = {}

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

  if #items == 0 then
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "", "  (no plugins match)" })
  else
    for i, item in ipairs(items) do
      local installed = Status.is_installed(item.repo)
      local line = Line()
      line:append(installed and " ● " or " ○ ", installed and "DiagnosticOk" or "Comment")
      line:append(item.name, "Title")
      line:render(bufnr, ns, i)
      state.line_to_item[i] = item
    end
  end

  vim.bo[bufnr].modifiable = false

  local status_line = string.format(
    " %d/%d plugins · %s%s ",
    #items,
    #Catalog.items,
    STATUS_LABELS[state.filter.status],
    state.filter.query == "" and "" or (" · “" .. state.filter.query .. "”")
  )
  state.list.border:set_text("bottom", status_line, "center")
end

function M.render()
  render_list()
  render_preview()
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
    zindex = 100,
    border = {
      style = "rounded",
      text = { top = " Search ", top_align = "center" },
    },
    win_options = { winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder" },
  }, {
    prompt = "  ",
    default_value = state.filter.query,
    on_submit = function(value)
      state.filter.query = value
      M.render()
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
  M.render()
end

function M.reload()
  Catalog.load()
  M.render()
end

function M.close()
  if state.layout then
    state.layout:unmount()
  end
  state.layout, state.list, state.preview = nil, nil, nil
end

local function create_layout()
  local list = Popup({
    focusable = true,
    enter = true,
    zindex = 50,
    border = {
      style = "rounded",
      text = { top = " 🧩 Extensions ", top_align = "center", bottom = HELP_TEXT, bottom_align = "center" },
    },
    buf_options = { modifiable = false, filetype = "extensions", buftype = "nofile", swapfile = false },
    win_options = {
      cursorline = true,
      winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder,CursorLine:PmenuSel",
    },
  })

  local preview = Popup({
    focusable = false,
    zindex = 50,
    border = {
      style = "rounded",
      text = { top = " Details ", top_align = "center" },
    },
    buf_options = { modifiable = false, filetype = "markdown", buftype = "nofile", swapfile = false },
    win_options = { wrap = true, winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder" },
  })

  local layout = Layout(
    {
      relative = "editor",
      position = "50%",
      size = { width = "84%", height = "76%" },
    },
    Layout.Box({
      Layout.Box(list, { size = "34%" }),
      Layout.Box(preview, { size = "66%" }),
    }, { dir = "row" })
  )

  layout:mount()

  state.layout = layout
  state.list = list
  state.preview = preview

  list:map("n", "i", M.install_selected, { noremap = true })
  list:map("n", "x", M.remove_selected, { noremap = true })
  list:map("n", "/", M.prompt_search, { noremap = true })
  list:map("n", "<Tab>", M.cycle_status_filter, { noremap = true })
  list:map("n", "r", M.reload, { noremap = true })
  list:map("n", "q", M.close, { noremap = true })
  list:map("n", "<Esc>", M.close, { noremap = true })

  list:on(require("nui.utils.autocmd").event.CursorMoved, render_preview)

  ensure_reload_autocmd()
  M.render()
end

function M.open()
  if state.list and state.list.winid and vim.api.nvim_win_is_valid(state.list.winid) then
    vim.api.nvim_set_current_win(state.list.winid)
    return
  end
  create_layout()
end

return M
