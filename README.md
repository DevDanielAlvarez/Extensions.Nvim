# extensions.nvim

A VSCode-like "Extensions" panel for Neovim: browse a catalog of plugins,
search/filter it, view details, and install or remove plugins with a
keypress — backed by [lazy.nvim](https://github.com/folke/lazy.nvim) and
built with [nui.nvim](https://github.com/MunifTanjim/nui.nvim).

> **Status: MVP.** Static bundled catalog, single backend (`lazy.nvim`), no
> remote plugin data yet. See [Roadmap](#roadmap).

## Requirements

- Neovim >= 0.9.0
- [lazy.nvim](https://github.com/folke/lazy.nvim)
- [nui.nvim](https://github.com/MunifTanjim/nui.nvim)

## Installation

```lua
-- lua/plugins/extensions.lua
return {
  "DevDanielAlvarez/Extensions.Nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  cmd = "Extensions",
  opts = {},
}
```

## Usage

Run `:Extensions` to open the panel: a centered floating window with a
search bar and plugin list on the top-left, a live details preview on the
top-right that updates as you move the cursor, and a keymap reference panel
docked along the bottom — all visible from the moment it opens.

| Key         | Action                                                |
| ----------- | ------------------------------------------------------ |
| `i`         | Install the plugin under the cursor                     |
| `x`         | Remove the plugin under the cursor                      |
| `/`         | Focus the search bar and filter live as you type         |
| `<Tab>`     | Cycle status filter: All / Installed / Not installed     |
| `r`         | Reload the catalog                                       |
| `q`/`<Esc>` | Close                                                    |

## How installs work

extensions.nvim never edits your own config files. It owns a single spec
file, `lua/plugins/extensions-nvim.lua`, which `lazy.nvim` imports like any
other plugin module. Installing adds an entry there and asks `lazy.nvim` to
install it; removing deletes the entry and runs the equivalent of
`:Lazy clean`. Whether a catalog plugin shows as "installed" is read
directly from `lazy.nvim`'s own registry, so plugins you installed some
other way are recognized too.

## Configuration

```lua
require("extensions").setup({
  catalog_path = nil, -- path to a Lua file returning a custom catalog list
})
```

See `:help extensions.nvim` for the full catalog item shape and all options.

## Roadmap

- [ ] Dynamic/remote catalog (GitHub search API or similar), with caching
- [ ] Render each plugin's README in the detail panel
- [ ] Enable/disable toggle distinct from install/remove
- [ ] "Update available" indicator
- [ ] Support additional backends (`mini.deps`, `vim.pack`)
- [ ] Category/tag filter UI

## Prior art

[store.nvim](https://github.com/alex-popov-tech/store.nvim) already solves
plugin discovery/install very well with a large, hourly-updated database.
extensions.nvim is a smaller, VSCode-UX-focused take on the same idea.

## License

MIT
