local command = require 'refresh.command'
local server = require 'refresh.server'

describe('refresh.server', function()
  it('should send', function()
    local orig_jobstart = vim.fn.jobstart
    local jobstart_cmd = nil
    vim.fn.jobstart = function(cmd, _) jobstart_cmd = cmd end

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

    assert.True(vim.startswith(
      jobstart_cmd,
      [[echo "/some/dir
main
push
\"double quote should be escaped\"
*

" >]]
    ))

    vim.fn.jobstart = orig_jobstart
  end)
end)
