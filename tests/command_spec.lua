local command = require 'refresh.command'

describe('command.build', function()
  it('should fail if dir is empty', function()
    local x = command()
    x.branch = 'main'
    x.tasks = { name = 'push', args = { '*' } }

    local ok, payload = x:build()

    assert.False(ok)
    assert.equals('dir required', payload)
  end)

  it('should success when branch is empty', function()
    local x = command()
    x.dir = '/some/dir'
    x.tasks = { { name = 'push', args = { '*' } } }
    assert.True(x:build())
  end)

  it('should succeess with single task', function()
    local x = command()
    x.dir = '/some/dir'
    x.branch = 'main'
    x.tasks = { { name = 'delete_empty', args = { 'file1', 'file2' } } }

    local ok, payload = x:build()

    assert.True(ok)
    assert.equals(
      [[/some/dir
main
delete_empty
file1
file2

]],
      payload
    )
  end)

  it('should succeess with multiple tasks', function()
    local x = command()
    x.dir = '/some/dir'
    x.branch = 'main'
    table.insert(x.tasks, {
      name = 'delete_empty',
      args = { '*' },
    })
    table.insert(x.tasks, {
      name = 'push',
      args = { 'file1', 'file2' },
    })

    local ok, payload = x:build()

    assert.True(ok)
    assert.equals(
      [[/some/dir
main
delete_empty
*

push
file1
file2

]],
      payload
    )
  end)
end)
