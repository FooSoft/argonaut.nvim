local config = require('argonaut.config')
local types = require('argonaut.types')

local function reflow()
    local wrap_context = types.WrapContext.new(config.get())
    if wrap_context:parse() then
        wrap_context:toggle()
    end
end

return {
    reflow = reflow,
    setup = config.setup,
}
