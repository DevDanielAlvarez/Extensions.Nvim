---
name: extensions-nvim
description: Standing architecture and MVP plan for extensions.nvim, a Neovim plugin that recreates VSCode's "Extensions" tab (browse/search/install/remove Neovim plugins) built on nui.nvim and lazy.nvim. Load before planning, scaffolding, or implementing any part of this project so decisions stay consistent.
---

# extensions.nvim — project plan

This is the standing plan agreed on for this project. Treat it as the source of
truth for scope and architecture; update this file when a decision changes
instead of re-deciding from scratch in a fresh conversation.

## What it is

A Neovim plugin that recreates the UX of VSCode's "Extensions" sidebar tab,
but for browsing, installing, and removing **Neovim plugins** themselves
(not LSP servers/tools — that's mason.nvim's job).

## Prior art (checked before committing to build)

- **store.nvim** (`alex-popov-tech/store.nvim`, also at nvim.store) already
  does something very close: 6200+ plugin DB updated hourly, in-editor UI,
  live README preview via markview.nvim, one-key install for `lazy.nvim` and
  `vim.pack`. This is the closest direct competitor/reference.
- **mason.nvim** — same "open panel, search, install with one key" UX, but
  for LSP/DAP/linters/formatters, not editor plugins.
- **awesome-neovim**, **neovimcraft** — curated discovery lists, no install
  integration.
- Decision: build extensions.nvim anyway, as a personal/learning project,
  differentiated by closer VSCode-UX fidelity (explicit installed/enabled/
  disabled states, sidebar + detail panel feel) rather than trying to beat
  store.nvim's data pipeline.

## Name

**extensions.nvim** (renamed from the earlier "LazyShop" working name).

## Confirmed tech decisions

- **UI: `nui.nvim`** directly for MVP — split/popup/menu components. (Earlier
  plan considered starting with native buffer/floating-window API and adding
  nui.nvim later; user decided to commit to nui.nvim from the start instead.)
- **Plugin manager backend: `lazy.nvim` only** for MVP. Other backends
  (`mini.deps`, `vim.pack`) are explicitly deferred.
- **Install/remove strategy**: extensions.nvim owns a single managed spec
  file, e.g. `lua/plugins/extensions-nvim.lua`, which `lazy.nvim` imports
  like any normal plugin spec module. extensions.nvim never edits other
  arbitrary user config files.
  - Install → add spec entry to the managed file, call
    `require("lazy").install()`.
  - Remove → delete the entry, run `Lazy clean`.
  - Status detection (installed/not) → read `lazy.nvim`'s own registry via
    `require("lazy.core.config").plugins`, so plugins installed outside
    extensions.nvim are still correctly detected.
- **Catalog data source (MVP): static, local, bundled with the plugin.** No
  network calls in the MVP. Small curated list (~30–50 well-known plugins).
  Fields per entry: `name`, `repo` (`user/repo`), `description`, `category`,
  `tags`.

## MVP scope (in)

- `:Extensions` command opens the UI: a single centered floating `nui.nvim`
  Layout (not a left split — revised from the original plan) containing
  three Popups that all mount/unmount together as one unit:
  - top-left: plugin list (~34% width of the top row)
  - top-right: live details preview (~66% width) that updates on
    `CursorMoved` in the list
  - bottom: a keymap reference panel (fixed height = `#KEYMAPS + 2` rows,
    full width), docked below the list/preview row
  Structure: outer `Layout.Box({..}, {dir="col"})` with the list+preview
  row-group using `grow = 1` and the help panel using a fixed `size`, so
  nui's own layout engine positions the help panel directly under the
  other two without any manual pixel math. The help panel always opens
  together with the rest — there is no separate toggle for it (an earlier
  on-demand `?`-toggled popup was replaced by this docked panel per user
  request). Rounded borders throughout; title in the list's top border,
  live filter/count status in its bottom border (via `border:set_text`).
- List view with per-item status indicator (installed vs not).
- **Always-visible search bar**: row 1 of the list buffer itself is
  reserved for a search bar (placeholder "Search…" or the current query);
  catalog items start at row 2 (`state.line_to_item` keys start at 2 to
  match). It shows up the moment `:Extensions` opens — no keypress needed
  to reveal it, per user request. Pressing `/` overlays a real editable
  `nui.Input` at the exact same position/width (row 0, col 0 relative to
  the list window) so it reads as an in-place edit of that line, not a
  separate popup appearing elsewhere. Filters live on every keystroke via
  `on_change` (deferred with `vim.schedule` — firing the re-render
  synchronously from inside `on_lines` throws Neovim's E565 "can't change
  buffer during callback"). Initial cursor is placed on row 2 (first item)
  so `j`/`k` navigation works immediately without landing on the search row.
- Status filter: All / Installed / Not installed.
- Live preview pane on cursor movement: name, repo, description, status,
  category, tags. (Replaces the earlier plan of a separate on-demand detail
  popup triggered by `<CR>` — the preview pane is now always visible.)
- Actions: install (`i`), remove (`x`), both wired to the managed spec file
  + `lazy.nvim` API as described above.
- Keymaps (all on the list pane; `j`/`k` are native cursor motion, no remap
  needed): `i` install, `x` remove, `/` search, `<Tab>` cycle status filter,
  `r` reload catalog, `q`/`<Esc>` close. Documented in the always-visible
  docked help panel, built from a single `KEYMAPS` table in `ui.lua`.
- `require("extensions").setup({ catalog_path = ... })` — minimal config,
  only override currently planned is a custom catalog path.

## Explicitly out of scope for MVP (backlog for v2+)

- Dynamic/remote catalog (GitHub search API, dotfyle.com API), with caching.
- README rendering in the detail panel (e.g. via markview.nvim).
- Enable/disable toggle as distinct from install/remove.
- "Update available" detection.
- Multi-backend support (`mini.deps`, `vim.pack`).
- Category/tag filter UI (the data fields exist, but no filter UI yet).

## Suggested file layout (once scaffolding starts)

```
plugin/extensions.lua        -- defines :Extensions command
lua/extensions/init.lua      -- setup(), public API
lua/extensions/ui.lua        -- nui.nvim layout, keymaps
lua/extensions/catalog.lua   -- static plugin list + search/filter
lua/extensions/installer.lua -- managed spec file read/write, lazy.nvim calls
lua/extensions/status.lua    -- installed/not-installed detection
doc/extensions.txt           -- help docs
```

## Open questions not yet decided

- Exact initial curated catalog list (which ~30–50 plugins to seed).
- Whether to add a healthcheck (`:checkhealth extensions`) in MVP or v2.
