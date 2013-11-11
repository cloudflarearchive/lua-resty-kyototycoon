-- Copyright (C) 2013  Jiale Zhi (calio), Cloudflare Inc.

local tcp       = ngx.socket.tcp
local type      = type
local match     = string.match
local format    = string.format
local tostring  = tostring
local tonumber  = tonumber


local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 10)
_M._VERSION = '0.01'

local mt = { __index = _M }

function _M.new(self, args)
    local sock, err = tcp()
    if not sock then
        return nil, err
    end

    return setmetatable({ sock = sock }, mt)
end

function _M.connect(self, args)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    if args.host and args.port then
        self.host = args.host
        self.port = args.port
        return sock:connect(args.host, args.port)
    else
        return nil, "no host/port argument"
    end
end

function _M.set_timeout(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:settimeout(...)
end

function _M.set_keepalive(self, ...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:setkeepalive(...)
end

function _M.read_reply(self)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    sock = self.sock

    local reader = sock:receiveuntil("\r\n\r\n")
    local header, err = reader()

    if not header then
        return nil, "receive header failed: " .. err
    end

    local header_table = {}

    local status = match(header, "HTTP/1%.%d (%d+)")
    if not status then
        return nil, "illegal response, no \"HTTP status\": " .. tostring(header)
    end
    header_table.status = tonumber(status)

    local content_length = match(header, "Content%-Length: (%d+)")
    if not content_length then
        return nil, "illegal response, no \"Content-Length\" header: " ..
                tostring(header)
    end
    header_table.content_length = tonumber(content_length)

    local content_type = match(header, "Content%-Type: ([%w_/-]+)")
    if content_type then
        header_table.content_type = content_type
    end


    local body, err = sock:receive(content_length)
    if not body then
        return nil, "receive http body failed: " .. err
    end

    print("http response:\n" .. header .. "\r\n\r\n" .. body)
    return { header = header_table, raw_header = header, body = body }
end

function _M.post(self, ...)
    local args = {...}
    local uri = args[1]
    local body = args[2]

    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    sock = self.sock

    if type(uri) ~= "string" or #uri == 0 then
        return nil, "bad uri argument, expect \"string\" but got: "
                .. type(uri)
    end

    if type(body) ~= "string" then
        return nil, "bad body argument, expect \"string\" but got: "
                .. type(body)
    end

    local req = format("POST %s HTTP/1.0\r\n"
            .. "Host: %s:%d\r\n"
            .. "Content-Length: %d\r\n"
            .. "Content-Type: text/tab-separated-values\r\n"
            .. "Connection: Keep-Alive\r\n\r\n"
            .. "%s", uri, self.host, self.port, #body, body)

    print("http request:\n" .. req)
    local bytes, err = sock:send(req)
    if not bytes then
        return nil, "sock:send failed: " .. err
    end

    return _M.read_reply(self)
end

function _M.close(self)
    return self.sock:close()
end
return _M
