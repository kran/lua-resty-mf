local _M = { }
local insert = table.insert

local init = function(app)
    local resp = {
        app = app,
        body = {}, 
        status = 200, 
        headers = {}, 
        cookies = {},
    }

    return setmetatable(resp, {__index, _M})
end


_M.write = function(self, body, replace)
    replace = replace or false
    
    if replace then
        self.body = body
    else
        insert(self.body, body)
    end

    return self.body
end

return {new = init}
