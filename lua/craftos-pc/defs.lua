-- lua/craftos-pc/defs.lua
-- Manages the CC:Tweaked LuaLS definitions and .luarc.json injection.
local M = {}

local DEFS_REPO = "https://github.com/nvim-computercraft/lua-ls-cc-tweaked"

-- All CC globals the LSP should know about.
local CC_GLOBALS = {
  "turtle", "redstone", "peripheral", "fs", "http", "os",
  "term", "io", "textutils", "colors", "colours", "keys",
  "vector", "paintutils", "window", "multishell", "shell",
  "help", "parallel", "settings", "gps", "pocket", "disk",
  "print", "write", "sleep", "read",
}

-- Return the defs directory (config override or default under stdpath data).
M.defs_path = function()
  local config = require("craftos-pc").config
  if config.defs_path then
    return config.defs_path
  end
  return vim.fn.stdpath("data") .. "/craftos-pc/defs"
end

-- Ensure defs are present on disk, cloning if needed.
-- callback(defs_path) called when ready.
M.ensure_defs = function(callback)
  local path = M.defs_path()

  if vim.fn.isdirectory(path) == 1 then
    callback(path)
    return
  end

  vim.notify("[craftos-pc] Cloning CC:Tweaked LuaLS defs (first run)…", vim.log.levels.INFO)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")

  vim.fn.jobstart({ "git", "clone", "--depth=1", DEFS_REPO, path }, {
    on_exit = function(_, code)
      vim.schedule(function()
        if code == 0 then
          vim.notify("[craftos-pc] Defs ready at " .. path, vim.log.levels.INFO)
          callback(path)
        else
          vim.notify(
            "[craftos-pc] Failed to clone defs. Check network and git installation.",
            vim.log.levels.ERROR
          )
        end
      end)
    end,
  })
end

-- Build the .luarc.json fragment we need to inject.
local make_luarc_fragment = function(defs_path)
  return {
    runtime     = { version = "Lua 5.3" },
    workspace   = {
      library        = { defs_path .. "/library" },
      checkThirdParty = false,
    },
    diagnostics = { globals = CC_GLOBALS },
  }
end

-- Union-merge a list (array table) with a value, returning a new list.
local list_union = function(existing, new_items)
  local seen = {}
  local result = {}
  for _, v in ipairs(existing) do
    if not seen[v] then
      seen[v] = true
      table.insert(result, v)
    end
  end
  for _, v in ipairs(new_items) do
    if not seen[v] then
      seen[v] = true
      table.insert(result, v)
    end
  end
  return result
end

-- Write or merge .luarc.json at `root`.
-- If one already exists, unions workspace.library and diagnostics.globals.
M.inject_luarc = function(root)
  M.ensure_defs(function(defs_path)
    local luarc_path = root .. "/.luarc.json"
    local fragment   = make_luarc_fragment(defs_path)
    local final      = fragment

    if vim.fn.filereadable(luarc_path) == 1 then
      local raw = table.concat(vim.fn.readfile(luarc_path), "\n")
      local ok, existing = pcall(vim.json.decode, raw)

      if ok and type(existing) == "table" then
        -- Union-merge: preserve everything the user has, add our entries.
        existing.runtime = vim.tbl_deep_extend("force", existing.runtime or {}, fragment.runtime)

        existing.workspace          = existing.workspace or {}
        existing.workspace.library  = list_union(
          existing.workspace.library or {},
          fragment.workspace.library
        )
        if existing.workspace.checkThirdParty == nil then
          existing.workspace.checkThirdParty = false
        end

        existing.diagnostics         = existing.diagnostics or {}
        existing.diagnostics.globals = list_union(
          existing.diagnostics.globals or {},
          fragment.diagnostics.globals
        )

        final = existing
      else
        vim.notify(
          "[craftos-pc] Existing .luarc.json could not be parsed — overwriting.",
          vim.log.levels.WARN
        )
      end
    end

    local encoded = vim.json.encode(final)
    vim.fn.writefile({ encoded }, luarc_path)
    vim.notify("[craftos-pc] .luarc.json updated at " .. luarc_path, vim.log.levels.INFO)
  end)
end

return M
