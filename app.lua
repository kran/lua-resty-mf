local ngx = require('ngx')
local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local unpack = unpack
local ngxctx = ngx.ctx

local router = require('mf.racks.router')
local request = require('mf.racks.request')
local response = require('mf.racks.response')

local _M = {}

local _core_racks = {
    router = router,
    request = request,
    response = response,
}

local _add_hooks = function(app, hks)
    if type(hks) ~= 'table' then
        return
    end

    for name, hk in pairs(hks) do
        app:hook(name, hk)
    end
end

local _init_config = function(app, config)
    if type(config) == 'table' then
        for key, val in pairs(config) do 
            app:config(key, val)
        end
    end
end

local _is_rack = function (rack)
    if type(rack) == 'table' 
       and type(rack.init) =='function' 
    then
        return true
    end

    return false
end

local _set_core_racks = function(app)
    if type(_core_racks) == 'table' then
        for name, rack in pairs(_core_racks) do 
            app:add(name, rack)
        end
    end
end

_M.handleErr = function(app, err)
    ngx.say(err)
    self:die(500)
end

_M.get = function(self, uri, act)
    self:get('router'):get(uri, act)
end

_M.post = function(self, uri, act)
    self:get('router'):post(uri, act)
end

_M.map = function(self, uri, methods, act)
    self:get('router'):some(uri, methods, act)
end

_M.resource = function(self, path, mod)
    self:get('router'):resource(path, mod)
end

_M.call = function(self, ctx)

    local req = self:get('request')
    local route = self:get('router'):matchRoute(req)

    if not route then self:die(404, 'router not found') end

    self:apply('before.request')
    route:dispatch(req)
    self:apply('after.request')
end

_M.die = function(self, status, msg)
    --ngx.say(msg)
    ngx.exit(status)
end

_M.context = function(self, name)
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

    local addRack = function(app, name, rack)
        if not _is_rack(rack) then error('invalid rack') end

        local rack = rack.init(app)
        if rack then
            racks[name] = rack
        end
    end

    local _meta_index = function(app, key)
        local rack = racks[key]
        if rack then
            return rack
        end

        local val = _M[key]
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
        local hks = hooks[name]
        if type(hks) == 'table' then
            for _, hk in ipairs(hks) do
                local stat, err = pcall(hk, app)
                if not stat then
                    app:handleErr(err)
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
        if type(mw) ~= 'table' and type(mw.call) ~= 'function' then
            error('invalid mud')
        end

        mw.app = app
        _add_hooks(app, mw.hooks)
        insert(mud, 1, mw)
    end

    local getMud = function(app)
        return mud
    end

    local run = function(app)
        for _, m in ipairs(mud) do
            local stat, err = pcall(m.call, m)
            if not stat then
                app:handleErr(err)
                break
            end
        end

        app:finalize()
    end

    local app = setmetatable({
        get = getRack, 
        add  = addRack, 
        config   = config,  
        register = register, 
        run      = run,   
        apply = applyHook, 
        hook = hook,  
        finalize = finalize,
    }, {__index = _meta_index})

    _init_config(app, config)
    _set_core_racks(app)

    app:register(app)
    
    return app
end


local _class_mt = {__newindex=function() error('unacceptable') end}

return setmetatable({new = new}, {__newindex = _class_mt})
