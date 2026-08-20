---
name: extensions-nvim
description: Standing architecture and plan for extensions.nvim, a Neovim plugin that recreates VSCode's "Extensions" tab (browse/search/install/remove Neovim plugins, plus a per-plugin config builder) built on nui.nvim and lazy.nvim. Load before planning, scaffolding, or implementing any part of this project so decisions stay consistent.
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
- **Catalog data source (MVP): static, local, bundled with the plugin**, as
  `data/catalog.json`. No network calls in the MVP. ~31 well-known plugins.
  Fields per entry: `name`, `repo` (`user/repo`), `description`, `category`,
  `tags`, optional `config` (see the configuration-builder section below).

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

## Implemented: per-plugin configuration builder

User request: press `c` on a plugin in the list to get a popup where they
can configure that plugin's options (toggle/int/string fields), driven by
a schema the catalog data carries per plugin — a "builder" that reads the
schema and renders the right input widget per field type. **Implemented
and headless-tested** (full cycle: install → open config → toggle a field
→ edit a string field → verify the managed file round-trips and
`loadfile()`s cleanly → remove). The design below matches what was built;
update this section first if the design changes rather than letting code
and plan drift apart.

### 1. Catalog moves from a Lua table to JSON

- New bundled file: `data/catalog.json` at the plugin root (a JSON array,
  order-preserving — see field-ordering note below). Replaces the inline
  `M.builtin` Lua table currently in `lua/extensions/catalog.lua`; that
  module keeps its role as the loader + `filter()` logic, it just changes
  *how* `M.items` gets populated (decode JSON instead of a literal table).
- Why JSON specifically: it's a neutral, dependency-free format any
  tool/script/contributor can generate or validate, which matters if the
  catalog ever grows beyond a hand-maintained Lua list (already on the
  roadmap as "dynamic/remote catalog"). Parsing needs no extra dependency —
  Neovim has `vim.json.decode`/`vim.json.encode` built in (0.6+).
- Locating the bundled file at runtime: `lazy.nvim` adds the whole plugin
  directory to `runtimepath` (not just `lua/`), so
  `vim.api.nvim_get_runtime_file("data/catalog.json", false)[1]` finds it
  correctly without hardcoding an absolute path.
- `config.catalog_path` (the existing user override option) keeps working,
  but its expected format changes from "a Lua file that `return`s a table"
  to "a JSON file with the same shape as `data/catalog.json`". Decide at
  implementation time whether to keep accepting `.lua` overrides too for
  backward compatibility (cheap: branch on file extension) or cut over
  cleanly to JSON-only, since the MVP shipped only a few days ago and has
  no external users yet — cutting over cleanly is probably fine.

### 2. New catalog field: `config` (per-plugin option schema)

Each catalog item gains an optional `config` field: an **array** (not a
JSON object) of field-spec objects, e.g.:

```json
{
  "repo": "windwp/nvim-autopairs",
  "name": "nvim-autopairs",
  "description": "...",
  "category": "editing",
  "tags": ["autopairs"],
  "config": [
    { "key": "check_ts", "input_type": "toggle", "input_name": "Treesitter-aware pairs", "default": true },
    { "key": "map_cr", "input_type": "toggle", "input_name": "Map <CR>", "default": true }
  ]
}
```

Why an array and not the object-keyed-by-field-name shape the user first
sketched (`config: { input_type: toggle, input_name: lazy }`): decoding a
JSON *object* into a Lua table loses key order (Lua maps are unordered),
so the config popup couldn't reliably show fields in the order the plugin
entry's author intended. A JSON array of `{ key, input_type, input_name,
default }` objects decodes to a sequence (`ipairs`-safe) and keeps order,
at the cost of `key` being explicit instead of implicit-as-object-key.

Field spec properties:
- `key` — the literal option name written into that plugin's `opts` table
  in the generated lazy.nvim spec (see §3).
- `input_type` — `"toggle"` (boolean) | `"int"` (integer) | `"string"`
  (free text) for the first version. Dispatch is a small lookup table in
  the UI builder (`INPUT_RENDERERS[input_type]`), so adding a type later
  (`"select"`/enum, `"float"`, ...) means adding one more entry, not
  restructuring the builder.
- `input_name` — human-readable label shown in the popup.
- `default` — pre-filled/fallback value when the user hasn't set one yet.

### 3. Where chosen values live: reuse the existing managed spec file

No new storage file. `installer.lua`'s per-plugin entry in
`lua/plugins/extensions-nvim.lua` grows from `{ repo }` to
`{ repo, opts = { key = value, ... } }` — `opts` is a first-class
`lazy.nvim` spec field lazy.nvim already knows how to apply
(`require(x).setup(opts)`), so no extra plumbing is needed to make chosen
values actually reach the plugin.
- `write_specs`'s serializer needs extending to also emit a nested `opts`
  table with typed Lua literals (strings via `%q`, numbers/booleans via
  `tostring`), not just the single repo string it handles today.
- New `installer.lua` functions: `M.get_opts(repo)` (read the current
  `opts` for a repo from the managed file, falling back to each field's
  `default` for keys not yet set) and `M.set_opt(repo, key, value)`
  (update one key in that plugin's `opts` table and rewrite the file).
- Known limitation to surface to the user in the UI (a notify, not a
  blocker): most plugins only call `.setup(opts)` once at load time, so
  changing `opts` after a plugin is already loaded this session typically
  needs `:Lazy reload <plugin>` or a Neovim restart to actually take
  effect — the config builder should say so after saving, not imply a
  live-apply it can't deliver.
- Removing a plugin (`x`) deletes its whole spec entry, `opts` included —
  no separate "remember old config" behavior planned.

### 4. UI: the config popup (`c` keymap)

- New keymap `c` on the list pane: opens a config popup for the plugin
  under the cursor. If that catalog item's `config` array is empty/absent,
  notify "No configurable options for this plugin" instead of opening
  anything.
- Popup: a **centered** floating `nui.Popup` (like the old on-demand help
  popup was, not docked into the permanent 3-pane layout — this is a
  per-plugin, occasional action, not always-relevant chrome). Title
  " Configure <plugin name> ", rounded border, styled consistently with
  the rest of the UI.
- One line per field, built by the `INPUT_RENDERERS[input_type]` builder:
  - `toggle` → renders as a checkbox-style line; `<CR>`/`<Space>` flips it
    and immediately calls `Installer.set_opt(repo, key, not current)`.
  - `int`/`string` → renders label + current value; `<CR>` opens a small
    `nui.Input` overlaid at that line's position (same in-place-edit trick
    used for the search bar), validates (`int` must `tonumber` cleanly),
    and calls `Installer.set_opt` on submit.
- Changes apply immediately per field (no separate "save" step), matching
  how install/remove/search already behave in this plugin — `q`/`<Esc>`
  just closes the popup.

### Resolved while implementing (decisions made, differ slightly from the
### original draft above)

- Example `config` schemas seeded on 3 catalog entries: `nvim-autopairs`
  (`check_ts`, `map_cr`, both toggle), `folke/todo-comments.nvim`
  (`sign_priority` int, `merge_keywords` toggle), `numToStr/Comment.nvim`
  (`padding`/`sticky` toggle, `ignore` string). Swapped
  `indent-blankline.nvim` out of the original candidate list — its
  meaningful options are nested (`scope.enabled`, `indent.char`, ...) and
  the `key` field only supports flat top-level `opts` keys in this first
  version; picked `Comment.nvim` instead, which has flat options that fit.
- `catalog_path` cut over to JSON-only, no `.lua` fallback kept (confirmed
  fine — the option had no external users yet).
- `M.open_config()` (the UI layer) refuses to open for an uninstalled
  plugin with a `vim.notify` WARN, *and* `Installer.set_opt()` (the data
  layer) independently refuses too — belt-and-suspenders, since `set_opt`
  is reachable from more than just this one UI path.
- "Reset to default" key was **not** added — still genuinely open if
  wanted later.

## Implemented: opt-in default keymaps block (`enabled_default_keymaps`)

User request: some catalog plugins (e.g. `folke/sidekick.nvim`) ship
documented default keymaps as a `keys = { ... }` lazy.nvim spec table full
of closures -- not representable as a JSON scalar, so the existing
`opts.<key> = <scalar>` config-field model (see above) can't carry it.
Wanted a one-toggle way to opt into shipping that exact block.

- New optional catalog item field `default_keymaps`: a **raw Lua source
  string** (e.g. `"{ { \"<tab>\", function() ... end, ... }, ... }"`) for
  the plugin's `keys` block, JSON-escaped like any string field.
- Convention: a `config` field spec with `key = "enabled_default_keymaps"`
  and `input_type = "toggle"` is treated as a **virtual** option -- it
  round-trips through the managed file's `opts` table exactly like any
  other toggle (`Installer.get_opts`/`set_opt` needed zero changes for
  this), but `installer.write_specs` special-cases that one key name at
  serialize time: it's filtered out of the emitted `opts = { ... }` block
  (it isn't a real plugin option) and, when `true`, the catalog item's
  `default_keymaps` source is looked up and spliced in verbatim as a
  sibling `keys = { ... }` field on that spec entry. Toggling back to
  `false` drops the block again on the next write.
- Lookup requires `extensions.catalog` from inside `installer.lua`, done
  with a **lazy `require` inside the function body**, not at module top --
  a top-level require would be a load-time circular dependency
  (`installer` -> `catalog` -> `status` -> `installer`). Deferred to call
  time it's safe: by the time any write happens, `extensions.catalog` is
  already fully loaded via `ui.lua`'s top-level require.
- Verified headless: toggling on produces a `keys` block that
  `loadfile()`s and executes cleanly with the right keymap count; toggling
  off leaves no trace of the flag in `opts`.
- Scoped to exactly this one key name, not a general "raw code block"
  field type -- no other catalog entry needs this yet, and a more generic
  mechanism can be designed later if a second use case shows up.

## Explicitly out of scope for MVP (backlog for v2+)

- Dynamic/remote catalog (GitHub search API, dotfyle.com API), with caching.
- README rendering in the detail panel (e.g. via markview.nvim).
- Enable/disable toggle as distinct from install/remove.
- "Update available" detection.
- Multi-backend support (`mini.deps`, `vim.pack`).
- Category/tag filter UI (the data fields exist, but no filter UI yet).

## File layout

```
plugin/extensions.lua        -- defines :Extensions command
lua/extensions/init.lua      -- setup(), public API
lua/extensions/ui.lua        -- nui.nvim layout, keymaps
lua/extensions/catalog.lua   -- catalog loader (JSON decode) + search/filter
lua/extensions/installer.lua -- managed spec file read/write, lazy.nvim calls
lua/extensions/status.lua    -- installed/not-installed detection
data/catalog.json            -- bundled catalog data (incl. `config` schemas),
                                 found at runtime via nvim_get_runtime_file
doc/extensions.txt           -- help docs
```

## Open questions not yet decided

- Whether to add a healthcheck (`:checkhealth extensions`) in MVP or v2.
- See "Open questions for this feature" under the config-builder section
  above for that feature's specific open questions.
