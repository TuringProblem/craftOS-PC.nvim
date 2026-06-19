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
local build_cmd = function(opts)
  local cmd = { opts.binary }

  -- Mount the file's parent directory read-write at the CC mount point.
  local dir = vim.fn.fnamemodify(opts.file, ":h")
  table.insert(cmd, "--mount-rw")
  table.insert(cmd, opts.mount .. "=" .. dir)

  -- Run the file as a startup script.
  local filename = vim.fn.fnamemodify(opts.file, ":t")
  table.insert(cmd, "--script")
  table.insert(cmd, opts.mount .. "/" .. filename)

  if opts.renderer == "cli" then
    table.insert(cmd, "--cli")
  elseif opts.renderer == "headless" then
    table.insert(cmd, "--headless")
  end

  return cmd
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

-- Run the current buffer's file in CraftOS-PC.
-- renderer_override: "cli" | "headless" | nil (uses config default)
M.run = function(renderer_override)
  local config = require("craftos-pc").config

  local binary = config.binary or M.detect_binary()
  if not binary then
    vim.notify(
      "[craftos-pc] CraftOS-PC binary not found. Install it or set config.binary in setup().\n"
        .. "Run :checkhealth craftos-pc for details.",
      vim.log.levels.ERROR
    )
    return
  end

  local file = vim.api.nvim_buf_get_name(0)
  if file == "" then
    vim.notify("[craftos-pc] Buffer has no file path. Save the file first.", vim.log.levels.ERROR)
    return
  end

  local renderer = renderer_override or config.renderer
  local cmd = build_cmd({
    binary   = binary,
    file     = file,
    renderer = renderer,
    mount    = config.mount,
  })

  if config.terminal == "float" then
    open_float(cmd, config.float)
  else
    open_split(cmd)
  end
end

-- Open a bare CraftOS-PC shell (no file loaded).
M.shell = function()
  local config = require("craftos-pc").config

  local binary = config.binary or M.detect_binary()
  if not binary then
    vim.notify(
      "[craftos-pc] CraftOS-PC binary not found. Run :checkhealth craftos-pc for details.",
      vim.log.levels.ERROR
    )
    return
  end

  local cmd = { binary, "--cli" }

  if config.terminal == "float" then
    open_float(cmd, config.float)
  else
    open_split(cmd)
  end
end

return M
