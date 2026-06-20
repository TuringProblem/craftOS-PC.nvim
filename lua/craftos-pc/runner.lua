-- lua/craftos-pc/runner.lua
-- Builds the craftos command and opens a terminal (float or split).
local M = {}

-- Platform binary detection. Returns path string or nil.
M.detect_binary = function()
  local sysname = vim.loop.os_uname().sysname

  if sysname == "Darwin" then
    -- Prefer the real binary so ROM resolution works without a wrapper script.
    local mac_bin = "/Applications/CraftOS-PC.app/Contents/MacOS/craftos"
    if vim.fn.executable(mac_bin) == 1 then
      return mac_bin
    end
  end

  -- Linux AppImage / distro package / wrapper on PATH
  if vim.fn.executable("craftos") == 1 then
    return "craftos"
  end

  return nil
end

-- Pure: build the argv list for a given run.
-- opts: { binary: string, file: string, renderer: string, mount: string }
-- Returns: string[]
-- Append the renderer flag to a command list (mutates cmd).
local with_renderer = function(cmd, renderer)
  if renderer == "cli" then
    table.insert(cmd, "--cli")
  elseif renderer == "headless" then
    table.insert(cmd, "--headless")
  end
  return cmd
end

-- SCRIPT mode: run a single file before the shell starts.
-- --script takes a HOST path, not the CC mount path. The mount still matters so
-- require()/fs can reach sibling files at opts.mount — but package.path is NOT
-- set up, so relative require("foo.bar") will NOT resolve. Use program mode for that.
-- opts: { binary, file, renderer, mount }
local build_script_cmd = function(opts)
  local cmd = { opts.binary }
  local dir = vim.fn.fnamemodify(opts.file, ":h")
  table.insert(cmd, "--mount-rw")
  table.insert(cmd, opts.mount .. "=" .. dir)
  table.insert(cmd, "--script")
  table.insert(cmd, opts.file)
  return with_renderer(cmd, opts.renderer)
end

-- PROGRAM mode: mount the project root and launch the file THROUGH the shell.
-- shell.setDir + shell.run sets package.path to the program's dir, so relative
-- require("CCZombies.game") resolves — the way real CC programs are run.
-- opts: { binary, root, entry, renderer, mount } where:
--   root  = host dir mounted at opts.mount (the program root)
--   entry = the entry file's path RELATIVE to root (CC-side)
local build_program_cmd = function(opts)
  local cmd = { opts.binary }
  table.insert(cmd, "--mount-rw")
  table.insert(cmd, opts.mount .. "=" .. opts.root)

  -- Build the CC-side lua: cd into the mount, run the entry by relative name.
  -- Single-quote the entry; CC paths never contain single quotes in practice.
  local cc_entry = opts.mount .. "/" .. opts.entry
  local lua = string.format("shell.setDir('%s'); shell.run('%s')", opts.mount, cc_entry)
  table.insert(cmd, "--exec")
  table.insert(cmd, lua)

  return with_renderer(cmd, opts.renderer)
end

-- Imperative shell: open a floating terminal window.
-- cmd: string[], float_opts: { width: number, height: number }
local open_float = function(cmd, float_opts)
  local width  = math.floor(vim.o.columns * float_opts.width)
  local height = math.floor(vim.o.lines   * float_opts.height)
  local row    = math.floor((vim.o.lines   - height) / 2)
  local col    = math.floor((vim.o.columns - width)  / 2)

  local buf = vim.api.nvim_create_buf(false, true)

  local win_opts = {
    relative = "editor",
    width    = width,
    height   = height,
    row      = row,
    col      = col,
    style    = "minimal",
    border   = "rounded",
  }

  -- title support added in Neovim 0.9
  if vim.fn.has("nvim-0.9.0") == 1 then
    win_opts.title     = " CraftOS-PC "
    win_opts.title_pos = "center"
  end

  local win = vim.api.nvim_open_win(buf, true, win_opts)

  vim.fn.termopen(cmd, {
    on_exit = function()
      vim.schedule(function()
        if vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end)
    end,
  })

  vim.cmd("startinsert")
end

-- Imperative shell: open a bottom-split terminal.
local open_split = function(cmd)
  vim.cmd("botright split")
  vim.fn.termopen(cmd, {
    on_exit = function()
      vim.schedule(function()
        local buf = vim.api.nvim_get_current_buf()
        if vim.api.nvim_buf_is_valid(buf) then
          vim.api.nvim_buf_delete(buf, { force = true })
        end
      end)
    end,
  })
  vim.cmd("startinsert")
end

-- Resolve the binary or notify + return nil.
local resolve_binary = function(config)
  local binary = config.binary or M.detect_binary()
  if not binary then
    vim.notify(
      "[craftos-pc] CraftOS-PC binary not found. Install it or set config.binary in setup().\n"
        .. "Run :checkhealth craftos-pc for details.",
      vim.log.levels.ERROR
    )
  end
  return binary
end

-- Open the built command in the configured terminal presentation.
local launch = function(cmd, config)
  if config.terminal == "float" then
    open_float(cmd, config.float)
  else
    open_split(cmd)
  end
end

-- SCRIPT mode: run the current buffer's file as a single startup script.
-- Fast for self-contained files; relative require() will NOT resolve (use run_program).
-- renderer_override: "cli" | "headless" | nil (uses config default)
M.run = function(renderer_override)
  local config = require("craftos-pc").config
  local binary = resolve_binary(config)
  if not binary then return end

  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("[craftos-pc] Buffer has no file path. Save the file first.", vim.log.levels.ERROR)
    return
  end

  launch(build_script_cmd({
    binary   = binary,
    file     = file,
    renderer = renderer_override or config.renderer,
    mount    = config.mount,
  }), config)
end

-- PROGRAM mode: mount a project root and launch the entry file through the shell,
-- so relative require()s resolve like a real CC program. The root defaults to the
-- current file's parent directory; override with config.project_root (a function
-- (file) -> dir, or a string path).
-- renderer_override: "cli" | "headless" | nil
M.run_program = function(renderer_override)
  local config = require("craftos-pc").config
  local binary = resolve_binary(config)
  if not binary then return end

  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("[craftos-pc] Buffer has no file path. Save the file first.", vim.log.levels.ERROR)
    return
  end

  -- Determine the program root.
  local root
  local pr = config.project_root
  if type(pr) == "function" then
    root = pr(file)
  elseif type(pr) == "string" then
    root = pr
  else
    root = vim.fn.fnamemodify(file, ":h")
  end
  root = vim.fn.fnamemodify(root, ":p"):gsub("/$", "")

  -- Entry path relative to root (forward slashes for CC).
  local entry = vim.fn.fnamemodify(file, ":p"):sub(#root + 2)
  if entry == "" then
    vim.notify("[craftos-pc] Current file is not under the project root.", vim.log.levels.ERROR)
    return
  end

  launch(build_program_cmd({
    binary   = binary,
    root     = root,
    entry    = entry,
    renderer = renderer_override or config.renderer,
    mount    = config.mount,
  }), config)
end

-- Open a bare CraftOS-PC shell (no file loaded).
M.shell = function()
  local config = require("craftos-pc").config
  local binary = resolve_binary(config)
  if not binary then return end
  launch({ binary, "--cli" }, config)
end

return M
