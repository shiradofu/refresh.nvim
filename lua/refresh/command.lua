---@alias Refresh.Command string

---@class Refresh.CommandTask
---@field name 'delete_empty'|'push'
---@field args string[]

---@class Refresh.CommandBuilder
---@field dir string
---@field branch string
---@field tasks Refresh.CommandTask[]
---@field build fun(self: Refresh.CommandBuilder): Refresh.Command

---@return Refresh.CommandBuilder
return function()
  local c = {
    dir = '',
    branch = '',
    tasks = {},
    paylaod = '',
    _append = function(self, p) self.payload = self.payload .. p .. '\n' end,
    build = function(self)
      if not self.dir or self.dir == '' then return false, 'dir required' end
      if #self.tasks == 0 then return false, 'tasks is empty' end
      self.payload = ''
      self:_append(self.dir)
      self:_append(self.branch)
      for _, task in ipairs(self.tasks) do
        self:_append(task.name)
        self:_append(table.concat(task.args, '\n'))
        self:_append '' -- this indicates the end of arg list
      end
      return true, self.payload
    end,
  }
  return c
end
