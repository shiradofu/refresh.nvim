local command = require 'refresh.command'
local server = require 'refresh.server'
local util = require 'refresh.util'

local R = {}
R._registered = {}

local function iso8601utc()
  return os.date '!%Y-%m-%dT%TZ'
end

---@class Refresh.RegisterConfigPull
---@field silent boolean

---@class Refresh.RegisterConfigDeleteEmpty
---@field files string[]

---@class Refresh.RegisterConfigPush
---@field files string[]
---@field commit_msg fun(): string

---@class Refresh.RegisterConfig
---@field pull Refresh.RegisterConfigPull
---@field delete_empty Refresh.RegisterConfigDeleteEmpty
---@field push Refresh.RegisterConfigPush
---@field branch string

---@param dir string
---@param config Refresh.RegisterConfig
function R.register(dir, config)
  if vim.fn.isdirectory(dir) == 0 then
    util.err("'%s' is not a directory.", dir)
    return false
  end
  if config.delete_empty and not config.delete_empty.files then
    util.err 'config.delete_empty.files required.'
    return false
  end
  if config.push then
    if not config.push.files then
      util.err 'config.push.files required.'
      return false
    end
    if not config.push.commit_msg then
      config.push.commit_msg = iso8601utc
    end
  end

  local augroup =
    vim.api.nvim_create_augroup('Refresh' .. dir:gsub('/', '_'), {})

  if config.pull then
    local pattern = (vim.endswith(dir, '/') and dir or dir .. '/') .. '*'
    vim.api.nvim_create_autocmd('BufWinEnter', {
      group = augroup,
      pattern = pattern,
      callback = function()
        R.pull(dir, config.branch, config.pull.silent)
      end,
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
        builder.branch = config.branch
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

  R._registered[dir] = config
  return true
end

---@param dir string|nil
function R.status(dir)
  if dir then
    vim.pretty_print(R._registered[dir])
  else
    vim.pretty_print(R._registered)
  end
end

return R
