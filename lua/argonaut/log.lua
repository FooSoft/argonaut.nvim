local Log = {}
Log.__index = Log

function Log.new()
    local log = { depth = 0 }
    return setmetatable(log, Log)
end

function Log:write(text, ...)
    local indent = string.rep(' ', self.depth * vim.opt.shiftwidth:get())
    print(indent .. string.format(text, ...))
end

function Log:indent()
    self.depth = self.depth + 1
end

function Log:unindent()
    self.depth = self.depth - 1
end

return Log
