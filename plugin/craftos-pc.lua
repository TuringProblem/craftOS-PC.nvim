-- plugin/craftos-pc.lua
-- Loaded automatically from runtimepath. Registers user commands.
-- Intentionally thin — all logic lives in lua/craftos-pc/*.

if vim.g.loaded_craftos_pc then
  return
end
vim.g.loaded_craftos_pc = 1

if vim.fn.has("nvim-0.8.0") ~= 1 then
  vim.api.nvim_err_writeln("[craftos-pc] requires Neovim 0.8.0+")
  return
end

--- :CraftOS — open a bare CraftOS-PC shell
vim.api.nvim_create_user_command("CraftOS", function()
  require("craftos-pc.runner").shell()
end, { desc = "Open CraftOS-PC shell" })

--- :CraftOSRun [cli|headless] — run current file in CraftOS-PC
vim.api.nvim_create_user_command("CraftOSRun", function(opts)
  local renderer = opts.args ~= "" and opts.args or nil
  require("craftos-pc.runner").run(renderer)
end, {
  nargs    = "?",
  complete = function() return { "cli", "headless" } end,
  desc     = "Run current file in CraftOS-PC",
})

--- :CraftOSRunProgram [cli|headless] — run current file as a CC program (through
--- the shell, so relative require()s resolve). Mounts the project root.
vim.api.nvim_create_user_command("CraftOSRunProgram", function(opts)
  local renderer = opts.args ~= "" and opts.args or nil
  require("craftos-pc.runner").run_program(renderer)
end, {
  nargs    = "?",
  complete = function() return { "cli", "headless" } end,
  desc     = "Run current file as a CC program (resolves requires)",
})

--- :CraftOSSetupDefs — clone defs + write .luarc.json for current project
vim.api.nvim_create_user_command("CraftOSSetupDefs", function()
  require("craftos-pc.defs").inject_luarc(vim.fn.getcwd())
end, { desc = "Setup CC:Tweaked LuaLS defs for current project" })
