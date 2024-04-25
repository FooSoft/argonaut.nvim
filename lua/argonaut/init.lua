local config = require('argonaut.config')
local types = require('argonaut.types')

local function setup(opts, filetypes)
    config.set(opts, filetypes)
end

return {
    reflow = types.reflow,
    setup = setup,
}
