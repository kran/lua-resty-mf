local insert = table.insert
local ipairs = ipairs
local pairs = pairs

local _M = {}
local _APP = {}

local router = require('tatto.router')

local coreRacks = {
    router = router,
    session = session,
}

local defaultMiddleWares = {

}

--[[
middleware: start, call, halt, hooks
]]

local initConfig = function(app, config)
    if type(config) == 'table' then
        for key, val = pairs(config) do 
            app:config(key, val)
        end
    end
end

local _is_rack = function (rack)
    if type(rack) == 'table' 
       --and type(rack.call) == 'function' 
       and type(rack.new) =='function' 
    then
        return true
    end

    return false
end

local setCoreRacks = function(app)
    if type(coreRacks) == 'table' then
        for name, rack in pairs(coreRacks) do 
            app:setRack(name, rack)
        end
    end
end

_APP.hook = function(self, hook, callable)

end

_APP.call = function(self, ctx)
    -- dispatch routers
end

_M.new = function(config)
    local racks = {}
    local mud = {}
    local hooks = {}

    local getRack = function(app, name)
        return racks[name]
    end

    local setRack = function(app, name, rack)
        if rack._inited then
            racks[name] = rack
        else
            racks[name] = rack.new(app)
        end
    end

    local _meta_index = function(app, key)
        local rack = getRack(key)
        if racks then
            return rack
        end

        local val = _APP[key]
        if val then
            app[key] = val
        end

        return val
    end

    local config = function(app, key, val)
        if not val then
            return app[key]
        else
            app[key] = val
            return val
        end
    end

    local register = function(app, mw)
        insert(mud, 1, mw)
    end

    local getMud = function(app)
        return mud
    end

    local run = function(app)
        for m in ipairs(mud) do
            m:call()
        end
    end

    local app = setmetatable({
        getRack = getRack,
        setRack = setRack,
        config = config,
        register = register,
        getMud = getMud, 
        run = run, 
    }, {__index=_meta_index})

    initConfig(app, config)
    setCoreRacks(app)

    app:register(app)
    
    return app
end


local _class_mt = {__newindex=function() error('unacceptable') end}

return setmetatable(_M, _class_mt)
