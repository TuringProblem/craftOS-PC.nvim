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
  -- Keymaps. Set any value to false to disable that mapping.
  -- Mapped buffer-local on Lua files only (see ft_scope).
  keymaps = {
    run   = "<leader>cr", -- :CraftOSRun
    shell = "<leader>co", -- :CraftOS
  },
  -- If true, keymaps apply only in `lua` buffers via a FileType autocmd.
  -- If false, they're set globally at setup() time.
  ft_scope = true,
}

-- Always initialized to defaults — commands work even without an explicit setup() call.
M.config = vim.tbl_deep_extend("force", defaults, {})

-- Bind the configured keymaps. buf is an optional buffer handle for ft-scoped maps.
---@param config table resolved config
---@param buf integer? buffer handle, or nil for global maps
local set_maps = function(config, buf)
  local km = config.keymaps or {}
  local opts = { silent = true, buffer = buf }

  if km.run then
    vim.keymap.set("n", km.run, function()
      require("craftos-pc.runner").run()
    end, vim.tbl_extend("force", opts, { desc = "CraftOS: run current file" }))
  end

  if km.shell then
    vim.keymap.set("n", km.shell, function()
      require("craftos-pc.runner").shell()
    end, vim.tbl_extend("force", opts, { desc = "CraftOS: open shell" }))
  end
end

-- Register keymaps either globally or scoped to lua buffers (via FileType autocmd).
local register_keymaps = function(config)
  if config.ft_scope then
    local group = vim.api.nvim_create_augroup("CraftosPcKeymaps", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group   = group,
      pattern = "lua",
      callback = function(args)
        set_maps(config, args.buf)
      end,
    })
    -- Retro-apply to lua buffers already open when setup() ran (lazy loading).
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_loaded(buf)
        and vim.bo[buf].filetype == "lua" then
        set_maps(config, buf)
      end
    end
  else
    set_maps(config, nil)
  end
end

--- Configure the plugin. Call once from your Neovim config (optional).
---@param opts table?
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", defaults, opts or {})
  -- Resolve binary once at setup time so runtime calls are fast.
  if not M.config.binary then
    M.config.binary = require("craftos-pc.runner").detect_binary()
  end
  register_keymaps(M.config)
end

return M
