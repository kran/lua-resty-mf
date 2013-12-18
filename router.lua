local ngx          = require"ngx"
local setmetatable = setmetatable
local insert       = table.insert
local pairs        = pairs
local ipairs       = ipairs
local type         = type
local strlen       = string.len
local substr       = string.sub
local pp           = require'prettyprint'
local match        = string.match
local re           = ngx.re
local pcall        = pcall
local unpack       = unpack
local json         = require"cjson"
local ngxctx       = ngx.ctx
local concat       = table.concat
local error        = error

local _M = {}

local _routers = {}
local _methods = {'GET', 'POST', 'PUT', 'DELETE'}

local function throw(code, msg)
    ngx.log(ngx.NOTICE, msg)
    ngx.exit(code)
end

local function uniform_route(path)
    local patt = '^/?(.*?)?/*?$'
    local newpath, n, err = re.sub(path, patt, '/$1')
    if newpath then
        return newpath
    else
        throw(500, err)
    end
end

function _M.new(self, prefix, parent)
    local router = {
        parent = parent, 
        prefix = uniform_route(prefix), 
        routes = {},
    }

    router = setmetatable(router, {
        __index=_M, 
        __newindex=function()
            throw(500, 'not accept')
        end
    })

    insert(_routers, 1, router)

    return router
end

function _M.sub(self, prefix)
    prefix = self.prefix .. uniform_route(prefix)
    return self:new(prefix, self)
end

local function create_action_chain(act)
    local chain = {}
    local len = #act
    
    if len > 0 then
        for i=0, len do
            if type(act[i]) == 'function' then
                insert(chain, act[i])
            end
        end
    else
        throw(500, 'action invalid')
    end

    if type(act.final) == 'function' then
        chain.final = act.final
    end
    
    return function(env)
        env._chain = chain
        for i=0, len do
           local stat = chain[i](env) 
           if not stat then
               break
           end
        end

        if chain.final then
            chain.final(env)
        end
    end
end

local function parse_action(act)
    local action = nil
    local typ = type(act)
    if typ == 'function' then
        action = act
    elseif typ == 'table' then
        action = create_action_chain(act)
    end

    return action
end

function _M.route(self, uri)
    local method = ngx.req.get_method()

    local route = nil
    local params = {}
    local routes = self.routes[method]

    if type(routes) ~= 'table' then 
        throw(404, 'method not allowed')
    end

    if routes[uri] then
        route = routes[uri]
    else
        for patt, r in pairs(routes) do
            local m, err = re.match(uri, patt..'$')
            if m then 
                route = r
                params=m
            end
        end
    end

    if route then
        route({router=self, params=params})
    else
        throw(404, 'route not found')
    end
end

function _M.dispatch()
    local uri = uniform_route(ngx.var.uri)

    local router = nil
    for _, r in ipairs(_routers) do
        local m = match(uri, r.prefix)
        if m then 
            router = r
            break
        end
    end

    if not router then
        throw(404, 'router not found')
    end


    local path = substr(uri, strlen(router.prefix)+1)

    router:route(path)
end

function _M.add_route(self, methods, uri, action)
    action = parse_action(action)

    if not action then
        ngx.log(ngx.NOTICE, uri..' not an valid action')
        return 
    end

    if type(methods) == 'string' then
        methods = {methods}
    end

    for _, m in ipairs(methods) do
        if type(self.routes[m]) ~= 'table' then
            self.routes[m] = {}
        end
        self.routes[m][uniform_route(uri)] = action
    end
end

function _M.get(self, uri, action)
    self:add_route('GET', uri, action)
end

function _M.post(self, uri, action)
    self:add_route('POST', uri, action)
end

function _M.put(self, uri, action)
    self:add_route('PUT', uri, action)
end

function _M.delete(self, uri, action)
    self:add_route('DELETE', uri, action)
end

function _M.some(self, uri, mths, action)
    self:add_route(mths, uri, c)
end

function _M.any(self, uri, action)
    self:add_route(_methods, uri, action)
end

function _M.resource(self, base, mod)
    if type(mod) ~= 'table' then
        throw(500, 'resource should be a module')
    end
    
    local pre = 'action_'
    local len = strlen(pre)

    local router = self:sub(base)

    for name, action in pairs(mod) do
        if substr(name, 0, len) == pre then
            local uri = uniform_route(substr(name, len+1))..'/?(.*)'
            router:any(uri, action)
        end
    end
end

local _class_mt = {
    __newindex = function(self) error("not accept") end
}

return setmetatable(_M, _class_mt)
