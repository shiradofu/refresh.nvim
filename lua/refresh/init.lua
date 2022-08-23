local command = require 'refresh.command'
local server = require 'refresh.server'
local util = require 'refresh.util'
local git = require 'refresh.git'

local R = {}
R._registered = {}

local function iso8601utc() return os.date '!%Y-%m-%dT%TZ' end

---@class Refresh.RegisterConfigPull
---@field silent boolean

---@class Refresh.RegisterConfigDeleteEmpty
---@field files string[]|'SESSION'

---@class Refresh.RegisterConfigPush
---@field files string[]|'SESSION'
---@field commit_msg fun(): string

---@class Refresh.RegisterConfig
---@field pull Refresh.RegisterConfigPull
---@field delete_empty Refresh.RegisterConfigDeleteEmpty
---@field push Refresh.RegisterConfigPush
---@field branch string

---@param dir string
---@param config Refresh.RegisterConfig
function R.register(dir, config)
  dir = vim.endswith(dir, '/') and dir:sub(1, -2) or dir
  if vim.fn.isdirectory(dir) == 0 then
    util.err("'%s' is not a directory.", dir)
    return false
  end
  if vim.fn.isdirectory(dir .. '/.git') == 0 then
    util.err("'%s' msut be a git repository.", dir)
    return false
  end
  local session_delete_empty = false
  if config.delete_empty then
    if not config.delete_empty.files then
      util.err 'config.delete_empty.files required.'
      return false
    end
    if config.delete_empty.files == 'SESSION' then
      config.delete_empty.files = {}
      session_delete_empty = true
    end
  end
  local session_push = false
  if config.push then
    if not config.push.files then
      util.err 'config.push.files required.'
      return false
    end
    if config.push.files == 'SESSION' then
      config.push.files = {}
      session_push = true
    end
    if not config.push.commit_msg then config.push.commit_msg = iso8601utc end
  end

  local augroup = vim.api.nvim_create_augroup('Refresh:' .. dir, {})
  local dir_pattern = dir .. '/*'

  if config.pull then
    vim.api.nvim_create_autocmd('BufWinEnter', {
      group = augroup,
      pattern = dir_pattern,
      callback = function(a) git.pull(a.buf, dir, config.branch, config.pull.silent) end,
      once = true,
    })
  end

  if config.push or config.delete_empty then
    server.ensure_launch()
    vim.api.nvim_create_autocmd('ExitPre', {
      group = augroup,
      pattern = '*',
      callback = function()
        local builder = command()
        builder.dir = dir
        builder.branch = config.branch or ''
        if config.delete_empty then
          table.insert(builder.tasks, {
            name = 'delete_empty',
            args = config.delete_empty.files,
          })
        end
        if config.push then
          table.insert(builder.tasks, {
            name = 'push',
            args = { config.push.commit_msg(), unpack(config.push.files) },
          })
        end
        server.send(builder)
      end,
    })
  end

  if session_delete_empty then
    vim.api.nvim_create_autocmd('BufWinEnter', {
      group = augroup,
      pattern = dir_pattern,
      callback = function(e)
        if not vim.tbl_contains(config.delete_empty.files, e.file) then
          table.insert(config.delete_empty.files, e.file)
        end
      end,
    })
  end

  if session_push then
    vim.api.nvim_create_autocmd('BufWinEnter', {
      group = augroup,
      pattern = dir_pattern,
      callback = function(e)
        if not vim.tbl_contains(config.push.files, e.file) then
          table.insert(config.push.files, e.file)
        end
      end,
    })
  end

  R._registered[dir] = config
  return true
end

---@param dir string|nil
function R.status(dir)
  if dir then
    dir = vim.endswith(dir, '/') and dir:sub(1, -2) or dir
    vim.pretty_print(R._registered[dir])
  else
    vim.pretty_print(R._registered)
  end
end

return R
