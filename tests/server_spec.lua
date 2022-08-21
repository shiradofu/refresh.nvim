local command = require 'refresh.command'
local server = require 'refresh.server'
local _stub = require 'luassert.stub'
local match = require 'luassert.match'

local stubs = {}
local function stub(...)
  local s = _stub(...)
  table.insert(stubs, s)
  return s
end
local function revert_mocks()
  for _, fn in ipairs(stubs) do
    fn:revert()
  end
  stubs = {}
end

describe('refresh.server', function()
  it('should send correctly', function()
    local jobstart = stub(vim.fn, 'jobstart')

    local builder = command()
    builder.dir = '/some/dir'
    builder.branch = 'main'
    builder.tasks = {
      {
        name = 'push',
        args = { '"double quote should be escaped"', '*' },
      },
    }

    server.send(builder)

    assert.stub(jobstart).called_with([[echo "/some/dir
main
push
\"double quote should be escaped\"
*

" > ]] .. vim.fn.stdpath 'data' .. '/fresh/fifo', match._)
  end)
end)
