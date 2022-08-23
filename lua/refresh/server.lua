require 'refresh.command'

local script_dir = debug.getinfo(1).source:match '@?(.*/)'
local repo_root = vim.loop.fs_realpath(script_dir .. '/../../')
local exe = repo_root .. '/refresh.sh'
local fifo = vim.fn.stdpath 'data' .. '/fresh/fifo'

---@class Refresh.Server
local S = {}

function S.ensure_launch()
  vim.fn.jobstart(([[
    [ ! -p '%s' ] && rm -f '%s' && mkfifo '%s'
    pgrep -f '%s' || nohup '%s' &
  ]]):format(fifo, fifo, fifo, exe, exe))
end

---@param command Refresh.CommandBuilder
function S.send(command)
  local ok, payload = command:build()
  if ok then
    vim.fn.jobstart(
      ('echo "%s" > %s'):format(payload:gsub('"', '\\"'), fifo),
      { cwd = repo_root }
    )
  end
end

return S
