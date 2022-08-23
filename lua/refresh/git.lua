local Job = require 'plenary.job'
local util = require 'refresh.util'

local G = {}

---@param dir string
---@param branch string
---@return boolean
local function validate_branch(dir, branch)
  if not branch then return true end
  local current = Job:new({
    command = 'git',
    args = { 'rev-parse', '--abbrev-ref', 'HEAD' },
    cwd = dir,
  }):sync()[1]
  if branch == current then return true end
  util.err('branch should be %s, but current one is %s.', branch, current)
  return false
end

---@param dir string
---@return boolean
local function validate_upstream(dir)
  local _, code = Job:new({
    command = 'git',
    args = { 'name-rev', '@{u}' },
    cwd = dir,
  }):sync()
  if code == 0 then return true end
  util.err 'please set upstream branch manually.'
  return false
end

---@param cmd 'pull'
---@param silent boolean
---@param on_success nil|fun(): nil
local function _on_event(cmd, silent, on_success)
  local output = {}
  return function(_, data, e)
    if e == 'exit' then
      if data == 0 then
        if not silent then util.msg 'done.' end
        if type(on_success) == 'function' then on_success() end
      else
        local header = string.format('something went wrong during %s:\n', cmd)
        table.insert(output, 1, { header, 'ErrorMsg' })
        util.echo(output)
      end
      return
    end
    data = table.concat(data, '\n')
    if data ~= '' then
      table.insert(output, { data, e == 'stdout' and 'None' or 'ErrorMsg' })
    end
  end
end

---@param bufnr number
---@param dir string
---@param branch string
---@param silent boolean
function G.pull(bufnr, dir, branch, silent)
  if not validate_branch(dir, branch) or not validate_upstream(dir) then
    return false
  end

  local on_event = _on_event('pull', silent, function()
    vim.api.nvim_buf_call(bufnr, function() pcall(vim.cmd, 'e') end)
  end)

  if not silent then util.msg 'Checking upstream...' end

  vim.fn.jobstart('git pull --ff-only', {
    on_stdout = on_event,
    on_stderr = on_event,
    on_exit = on_event,
    cwd = dir,
  })
end

return G
