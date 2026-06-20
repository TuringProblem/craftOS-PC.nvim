# craftos-pc.nvim

### ***Want to contribute?*** See [CONTRIBUTIONS.md](CONTRIBUTIONS.md). 

Run the [CraftOS-PC](https://github.com/MCJack123/craftos2) emulator inside Neovim, with full [CC:Tweaked](https://tweaked.cc) autocomplete wired in automatically.

Edit, run, and autocomplete ComputerCraft Lua without leaving your editor.

## What it does

- `:CraftOSRun` — runs the current file as a single startup script (fast; for self-contained files)
- `:CraftOSRunProgram` — runs the current file as a CC *program* through the shell, so relative `require()`s resolve (for multi-file projects)
- `:CraftOS` — opens a bare CraftOS-PC shell
- `:CraftOSSetupDefs` — clones the CC:Tweaked LuaLS definitions and writes `.luarc.json` into your project so `lua_ls` autocompletes the full CC API (`turtle`, `peripheral`, `redstone`, etc.)

## Requirements

- Neovim 0.8+
- **CraftOS-PC** installed (see below — not available via Homebrew)
- `git` (for auto-clone of LuaLS definitions)
- `lua_ls` (for autocomplete)

## Install CraftOS-PC

**macOS:**
```sh
# Download the .dmg from https://github.com/MCJack123/craftos2/releases
# Drag CraftOS-PC.app to /Applications, then:
xattr -dr com.apple.quarantine /Applications/CraftOS-PC.app
```

**Linux:**
```sh
# Download the AppImage from https://github.com/MCJack123/craftos2/releases
chmod +x CraftOS-PC-*.AppImage
mv CraftOS-PC-*.AppImage ~/.local/bin/craftos
```

## Install the plugin

**[lazy.nvim](https://github.com/folke/lazy.nvim) (recommended):**

```lua
{
  "TuringProblem/craftos-pc.nvim",
  config = function()
    require("craftos-pc").setup()
  end,
}
```

**With options:**

```lua
{
  "TuringProblem/craftos-pc.nvim",
  config = function()
    require("craftos-pc").setup({
      binary   = "/path/to/craftos",  -- auto-detected if omitted
      renderer = "cli",               -- "cli" (interactive) | "headless" (stdout)
      terminal = "float",             -- "float" | "split"
      mount    = "/src",              -- CC path for current file's directory
      float    = { width = 0.8, height = 0.8 },
      keymaps  = {
        run     = "<leader>cr",       -- :CraftOSRun         (single file; false to disable)
        program = "<leader>cp",       -- :CraftOSRunProgram  (resolves requires)
        shell   = "<leader>co",       -- :CraftOS
      },
      ft_scope = true,                -- keymaps only active in lua buffers
    })
  end,
}
```

### Without a plugin manager (native packages)

Neovim's built-in package system needs no dependencies. Clone (or symlink, for
local development) into a `pack/*/start/` directory:

```sh
git clone https://github.com/TuringProblem/craftos-pc.nvim \
  ~/.config/nvim/pack/plugins/start/craftos-pc.nvim
```

Then call setup from your `init.lua`:

```lua
require("craftos-pc").setup()
```

Anything under `pack/*/start/` loads at startup automatically. See `:help packages`.

> **Local development:** symlink your working copy instead of cloning, so edits
> are live on the next restart:
> ```sh
> ln -s ~/Documents/craftos-pc.nvim \
>   ~/.config/nvim/pack/plugins/start/craftos-pc.nvim
> ```

## Usage

1. Open a `.lua` file in your CC:Tweaked project
2. Run `:CraftOSSetupDefs` once — clones the CC LuaLS defs and writes `.luarc.json`
3. Restart `lua_ls` (or reopen Neovim) to pick up autocomplete
4. `:CraftOSRun` (single file) or `:CraftOSRunProgram` (multi-file), `:CraftOS` for a shell

Exit the CraftOS terminal: type `exit` inside the CC shell, or press `<C-\><C-n>` then `:q`.

### Single file vs. program

| Command | Mechanism | Use for |
| --- | --- | --- |
| `:CraftOSRun` | `--script <file>` (runs before the shell) | self-contained files; quick checks |
| `:CraftOSRunProgram` | mounts the project root, launches via the shell | multi-file projects with relative `require()` |

`:CraftOSRun` does **not** set up `package.path`, so `require("foo.bar")` won't resolve — that's what `:CraftOSRunProgram` is for. The program root defaults to the current file's parent directory; set `project_root` (a path or a `function(file) -> dir`) to point elsewhere.

> Programs with **external** dependencies (e.g. `Pine3D`, libraries not in the CraftOS ROM) still need those installed into the project — the plugin runs the emulator, it doesn't fetch third-party CC libraries.

## Health check

```
:checkhealth craftos-pc
```

Verifies the binary, ROM path, defs, and `lua_ls`.

## How it works

CraftOS-PC is launched as a subprocess inside Neovim's `:terminal`, with your file's directory mounted read-write at `/src` inside the CraftOS filesystem. The `--cli` renderer (ncurses) gives a clean interactive terminal experience.

Autocomplete uses [lua-ls-cc-tweaked](https://github.com/nvim-computercraft/lua-ls-cc-tweaked) — a set of LuaLS type definitions for the CC:Tweaked API. `:CraftOSSetupDefs` clones these once and injects the right `workspace.library` + `diagnostics.globals` entries into your project's `.luarc.json`.

## License

MIT
