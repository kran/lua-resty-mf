local ngx = ngx

local _M = {}

local _meta_call = function(self)
    return ngx.req
end

local init = function(app)
    local req = {
        app = app, 
    }

    return setmetatable(req, {
        __index = _M,
        __call = _meta_call
    })
end


_M.method = function(self)
    return ngx.req.get_method()
end

_M.pathinfo = function(self)
    return ngx.var.uri
end

return { init=init }
