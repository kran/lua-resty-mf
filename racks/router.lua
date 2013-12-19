local ngx          = require("ngx")
local setmetatable = setmetatable
local insert       = table.insert
local pairs        = pairs
local ipairs       = ipairs
local type         = type
local strlen       = string.len
local substr       = string.sub
--local pp           = require'prettyprint'
local re           = ngx.re
local match        = re.match
local pcall        = pcall
local unpack       = unpack
local ngxctx       = ngx.ctx
local concat       = table.concat
local error        = error
local upcase       = string.upper

local _M = {}

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
        error(err)
    end
end


function init(self)
    local router = {
        routes = {},
    }

    router = setmetatable(router, {
        __index=_M, 
        __newindex=function()
            error('not accept')
        end
    })

    --insert(_routers, 1, router)

    return router
end

local function createChain(act)
    local chain = {}
    local len = #act
    
    if len > 0 then
        for i=0, len do
            if type(act[i]) == 'function' then
                insert(chain, act[i])
            end
        end
    else
        error('action invalid')
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
        action = createChain(act)
    end

    return action
end

function _M.matchRoute(self, req)
    local method = upcase(req.method())
    local uri = req.pathinfo()

    local params = {}
    local route = nil
    local patt = nil

    local routes = self.routes[method]
    if not routes then return nil end

    for patt, r in pairs(routes) do
        local m = re.match(uri, patt..'$')
        if m then 
            route = r
            params = m
            break
        end
    end

    if not route then
        return nil
    end

    local dispatch = function()
        route{
            params = params,
            route = route,
        }
    end

    return { dispatch = dispatch }
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

function _M.resource(self, path, mod)
    if type(mod) ~= 'table' then
        error('resource should be a module')
    end
    
    local pre = 'action_'
    local len = strlen(pre)

    for name, action in pairs(mod) do
        if substr(name, 0, len) == pre then
            local p = {path, '/', substr(name, len+1)}
            local uri = uniform_route(p)..'/?(.*)'
            self:any(uri, action)
        end
    end
end

local _class_mt = {
    __newindex = function(self) error("not accept") end
}

return {init = init}
