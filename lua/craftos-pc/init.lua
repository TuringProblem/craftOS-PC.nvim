-- lua/craftos-pc/init.lua
-- Public API. Config is initialized to defaults so the plugin works even without setup().
local M = {}

local defaults = {
  -- Path to craftos binary. Auto-detected if nil.
  binary = nil,
  -- "cli" (ncurses, interactive) or "headless" (plain stdout, for scripting)
  renderer = "cli",
  -- Terminal presentation: "float" or "split"
  terminal = "float",
  -- Mount point inside CraftOS for the current file's directory
  mount = "/src",
  -- Path to CC:Tweaked LuaLS defs. Auto-managed (cloned to stdpath data) if nil.
  defs_path = nil,
  -- Float window dimensions as fraction of editor
  float = {
    width = 0.8,
    height = 0.8,
  },
}

-- Always initialized to defaults — commands work even without an explicit setup() call.
M.config = vim.tbl_deep_extend("force", defaults, {})

--- Configure the plugin. Call once from your Neovim config (optional).
---@param opts table?
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
  -- Resolve binary once at setup time so runtime calls are fast.
  if not M.config.binary then
    M.config.binary = require("craftos-pc.runner").detect_binary()
  end
end

return M
