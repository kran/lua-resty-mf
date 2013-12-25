local _M = {}
local insert = table.insert
local concat = table.concat
local _key = 'response'

local initialize = function(app)
    if not app.context[_key] then
        app.context[_key] = setmetatable({ app = app }, {
            __index = _M, 
            __call = initialize,
        })
    end

    return app.context[_key]
end

_M.status = function(self)
    local ctx = self:store()

    if not ctx['status'] then return 200 end
    return ctx['status']
end

_M.setStatus = function(self, status)
    self:store()['status'] = status
end

local _set_header = function()
end

_M.setHeader = function(self, headers)
    if type(headers) == 'table' then
        local store = self:store()
        if not store.headers then store.headers = {} end

        for key, val in pairs(headers) do
            store.headers[key] = val
        end
    end
end

_M.header = function(self)
    if type(self:store().headers) == 'table' then
        return self:store().headers
    end
    return {}
end

_M.write = function(self, body, replace)
    replace = replace or false
    local store = self:store()
    
    if replace then
        store.body = {body}
    else
        if type(store.body) == 'table' then
            insert(store.body, body)
        else
            insert({store.body}, body)
        end
    end

    return store.body
end

_M.body = function(self)
    local body = self:store().body
    if type(body) == 'table' then
        body = concat(body)
    else
        body = ''
    end
    return body
end


_M.finalize = function(self)
    local status = self:status()
    local body = self:body()
    local headers = self:header()

    return status, headers, body
end

return initialize
