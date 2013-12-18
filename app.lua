local ngx = ngx
local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local unpack = unpack
local ngxctx = ngx.ctx

local router = require('mf.router')
local request = require('mf.request')
local response = require('mf.response')

local _APP = {}

local coreRacks = {
    router = router,
    request = request,
    response = response,
}

_APP.errHandler = function(app, err)
    ngx.say(err)

    self:die(1)
end

local addHooks = function(app, hks)
    if type(hks) ~= 'table' then
        return
    end

    for name, hk in pairs(hks) do
        app:hook(name, hk)
    end
end

local initConfig = function(app, config)
    if type(config) == 'table' then
        for key, val in pairs(config) do 
            app:config(key, val)
        end
    end
end

local _is_rack = function (rack)
    if type(rack) == 'table' 
       and type(rack.new) =='function' 
    then
        return true
    end

    return false
end

local setCoreRacks = function(app)
    if type(coreRacks) == 'table' then
        for name, rack in pairs(coreRacks) do 
            app:addRack(name, rack)
        end
    end
end

_APP.get = function(self, uri, act)
    self:getRack('router'):get(uri, act)
end

_APP.post = function(self, uri, act)
    self:getRack('router'):post(uri, act)
end

_APP.map = function(self, uri, methods, act)
    self:getRack('router'):some(uri, methods, act)
end

_APP.resource = function(self, path, mod)
    self:getRack('router'):resource(path, mod)
end

_APP.call = function(self, ctx)
    self:applyHook('before.route')

    local req = self:getRack('request')
    local route = self:getRack('router'):matchRoute(req)

    if not route then self:die(404) end


    self:applyHook('before.request')
    route:dispatch(req)
    self:applyHook('after.request')
    self:applyHook('after.route')
end

_APP.die = function(self, status)
    ngx.exit(status)
end

_APP.context = function(name)
    if type(ngxctx[name]) ~= 'table' then
        ngxctx[name] = {}
    end
    return ngxctx[name]
end


local new = function(config)
    local racks = {}
    local mud = {}
    local hooks = {}

    local getRack = function(app, name)
        return racks[name]
    end

    local printRacks = function(app)
        for name, val in pairs(racks) do
            ngx.say(name)
        end
    end

    local addRack = function(app, name, rack)
        --if rack.inited then
            --racks[name] = rack
        --else
        local rack = rack.init(app)
        if rack then
            racks[name] = rack
        end
        --end
    end

    local _meta_index = function(app, key)
        local rack = racks[key]
        if rack then
            return rack
        end

        local val = _APP[key]
        if val then
            app[key] = val
        end

        return val
    end

    local hook = function(app, name, func)
        if type(func) ~= 'function' then
            return
        end

        if type(hooks[name]) ~= 'table' then
            hooks[name] = {}
        end

        insert(hooks[name], func)
    end

    local applyHook = function(app, name)
        local hk = hooks[name]
        if type(hk) == 'table' then
            for hk in ipairs(hk) do
                local stat, err = pcall(hk, app)
                if not stat then
                    -- todo: to die or not to die, it's a question
                    app:errHandler(err)
                    break
                end
            end
        end
    end

    local finalize = function(app)
        --clean up & write output
        local resp = racks['response']
        local stat, headers, body = resp:finalize()
        --todo set headers, cookies & sessions
        ngx.say(body)
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
        if type(mw.call) ~= 'function'
            and type(mw) ~= 'table' then

            error('invalid mud')
        end

        mw.app = app
        addHooks(app, mw.hooks)
        insert(mud, 1, mw)
    end

    local getMud = function(app)
        return mud
    end

    local run = function(app)
        for _, m in ipairs(mud) do
            local stat, err = pcall(m.call, m)
            if not stat then
                racks['response']:write(err)
                break
            end
        end

        app:finalize()
    end

    local app = setmetatable({
        getRack  = getRack,
        addRack  = addRack,
        config   = config,
        register = register,
        getMud   = getMud,
        run      = run,
        applyHook= applyHook, 
        finalize = finalize,
        printRacks = printRacks,
    }, {__index = _meta_index})

    initConfig(app, config)
    setCoreRacks(app)

    app:register(app)
    
    return app
end


local _class_mt = {__newindex=function() error('unacceptable') end}

return setmetatable({new = new}, {__newindex = _class_mt})
