local _M = { }
local insert = table.insert
local concat = table.concat
local _key = 'response'

local init = function(app)
    local resp = {
        app = app,
        store = function(self)
            return app:context(_key)
        end,
    }

    return setmetatable(resp, {__index = _M})
end

_M.status = function(self)
    local ctx = self:store()

    if not ctx['status'] then return 200 end
    return ctx['status']
end

local _set_header = function()
    
end

_M.setHeader = function(self, headers)

end

_M.write = function(self, body, replace)
    replace = replace or false
    local store = self:store()

    ngx.say('body:', body)
    
    if replace then
        store.body = {body}
    else
        if type(store.body) == 'table' then
            insert(store.body, body)
        else
            insert({store.body}, body)
        end
    end

    return self.body
end

_M.finalize = function(self)
    local status = self:status()
    local body = self:store().body
    if type(body) == 'table' then
        body = concat(body)
    else
        body = ''
    end
    local headers = {}

    return status, headers, body
end


return {init = init}
