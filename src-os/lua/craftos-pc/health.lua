-- lua/craftos-pc/health.lua
-- :checkhealth craftos-pc
local M = {}

-- Compat: vim.lsp.get_clients added in 0.10; get_active_clients is 0.8/0.9.
local lsp_clients = vim.lsp.get_clients or vim.lsp.get_active_clients

M.check = function()
  local h = vim.health

  h.start("craftos-pc")

  -- 1. Binary
  local runner = require("craftos-pc.runner")
  local config = require("craftos-pc").config
  local binary = config.binary or runner.detect_binary()

  if binary and vim.fn.executable(binary) == 1 then
    h.ok("CraftOS-PC binary: " .. binary)
  elseif binary then
    h.error(
      "Binary path set but not executable: " .. binary,
      { "Check file permissions or correct the path in setup({ binary = '...' })" }
    )
  else
    h.error(
      "CraftOS-PC binary not found",
      {
        "macOS: download the .dmg from https://github.com/MCJack123/craftos2/releases",
        "  After install: xattr -dr com.apple.quarantine /Applications/CraftOS-PC.app",
        "Linux: download the AppImage from the same releases page",
        "Override: require('craftos-pc').setup({ binary = '/path/to/craftos' })",
      }
    )
  end

  -- 2. ROM (macOS-specific — symlink breaks ROM resolution)
  if binary and vim.loop.os_uname().sysname == "Darwin" then
    local rom = "/Applications/CraftOS-PC.app/Contents/Resources/rom"
    if vim.fn.isdirectory(rom) == 1 then
      h.ok("ROM directory: " .. rom)
    else
      h.warn(
        "ROM not found at: " .. rom,
        {
          "If using a symlink or wrapper script, ensure it uses `exec` so argv[0] is the real binary.",
          "The plugin uses the direct .app binary path by default, which avoids this.",
        }
      )
    end
  end

  -- 3. git (needed for auto-clone of defs)
  if vim.fn.executable("git") == 1 then
    h.ok("git available")
  else
    h.error(
      "git not found",
      { "git is required to auto-clone the CC:Tweaked LuaLS defs on first use" }
    )
  end

  -- 4. CC:Tweaked LuaLS defs
  local defs = require("craftos-pc.defs")
  local defs_path = defs.defs_path()
  if vim.fn.isdirectory(defs_path) == 1 then
    h.ok("CC:Tweaked defs: " .. defs_path)
  else
    h.warn(
      "CC:Tweaked LuaLS defs not yet cloned",
      {
        "Run :CraftOSSetupDefs to clone them and wire .luarc.json in the current project.",
        "Or set config.defs_path to an existing install.",
      }
    )
  end

  -- 5. lua_ls
  local lua_ls_clients = lsp_clients({ name = "lua_ls" })
  if #lua_ls_clients > 0 then
    h.ok("lua_ls running")
  else
    h.warn(
      "lua_ls not running",
      { "Open a Lua file and ensure lua_ls is configured — autocomplete requires it" }
    )
  end
end

return M
