local refresh = require 'refresh'
local server = require 'refresh.server'
local util = require 'refresh.util'
local Job = require 'plenary.job'
local _stub = require 'luassert.stub'
local _spy = require 'luassert.spy'
local match = require 'luassert.match'

local script_dir = debug.getinfo(1).source:match '@?(.*/)'
local testdir = vim.loop.fs_realpath(script_dir .. '/assets') .. '/testdir'
Job:new({ command = 'mkdir', args = { '-p', testdir } }):sync()
Job:new({ command = 'git', args = { 'init' }, cwd = testdir }):sync()

local augroup = 'Refresh:' .. testdir
local mocks = {}
local function mock(is_stub, ...)
  local s = is_stub and _stub(...) or _spy.on(...)
  table.insert(mocks, s)
  return s
end
local function revert_mocks()
  for _, fn in ipairs(mocks) do
    fn:revert()
  end
  mocks = {}
end
local function delete_all_buffers_and_wins()
  vim.cmd 'silent! %bdelete'
  local wins = vim.api.nvim_list_wins()
  for i, win in ipairs(wins) do
    if i == #wins then break end
    vim.api.nvim_win_close(win, true)
  end
end

describe('refresh.register', function()
  before_each(function()
    revert_mocks()
    delete_all_buffers_and_wins()
    pcall(vim.api.nvim_del_augroup_by_name, augroup)
  end)

  it('should fail if dir is not a directory', function()
    mock(true, util, 'err')
    assert.False(refresh.register('/invalid/dir', {}))
  end)

  it('should fail if dir is not git managed', function()
    mock(true, util, 'err')
    assert.False(refresh.register('/tmp', {}))
  end)

  it('should set pull autocmd when enabled', function()
    assert.True(refresh.register(testdir, { pull = {} }))
    assert.equals(
      1,
      #vim.api.nvim_get_autocmds { group = augroup, event = 'BufWinEnter' }
    )
  end)

  it('should cause an error if files is nil', function()
    mock(true, util, 'err')
    assert.False(refresh.register(testdir, { push = {} }))
  end)

  it('should handle commit_msg and files table correctly', function()
    local server_ensure = mock(true, server, 'ensure_launch')
    assert.True(refresh.register(testdir, {
      push = {
        files = { 'file1', 'file2' },
        commit_msg = function() return 'my_msg' end,
      },
    }))
    assert.equals(
      1,
      #vim.api.nvim_get_autocmds { group = augroup, event = 'ExitPre' }
    )
    assert.stub(server_ensure).called(1)

    local jobstart = mock(true, vim.fn, 'jobstart')
    vim.api.nvim_exec_autocmds('ExitPre', { group = augroup })
    assert
      .stub(jobstart)
      .called_with(match.has_match 'push\nmy_msg\nfile1\nfile2', match._)
  end)

  it('should handle files = "SESSION" correctly', function()
    local config = { push = { files = 'SESSION' } }
    assert.True(refresh.register(testdir, config))
    assert.equals(
      1,
      #vim.api.nvim_get_autocmds { group = augroup, event = 'ExitPre' }
    )
    assert.equals(0, #config.push.files)

    vim.cmd('e' .. testdir .. '/.gitkeep')
    assert.equals(testdir .. '/.gitkeep', config.push.files[1])
  end)
end)

Job:new({ command = 'rm', args = { '-rf', testdir } }):sync()
