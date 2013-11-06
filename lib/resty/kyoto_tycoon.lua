-- Copyright (C) 2013  Jiale Zhi (calio), Cloudflare Inc.

local cjson         = require "cjson"
local httpmod       = require "resty.kt.http"
local tsv           = require "resty.kt.tsv"

local pairs         = pairs
local debug         = ngx.config.debug
local log           = ngx.log

local DEBUG         = ngx.DEBUG
local ERR           = ngx.ERR


local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 10)

_M._VERSION = '0.01'


local mt = { __index = _M }

local commands = {
    "void",     "echo",         "report",       "play_script",
    "tune_replication",         "status",       "clear",        "synchronize",
    "set",      "add",          "replace",      "append",       "increment",
    "increment_double",         "cas",          "remove",       "get",
    "check",    "seize",        "set_bulk",     "remove_bulk",  "get_bulk",
    "vacuum",   "match_prefix",                 "match_regex",  "match_similar",
    "cur_jump", "cur_jump_back",                "cur_step",     "cur_step_back",
    "cur_set_value",            "cur_remove",   "cur_get_key",  "cur_get_value",
    "cur_get",  "cur_seize",    "cur_delete",
}

local command_args = {
    void        = {},
    get         = { "key" },
    set         = { "key", "value" },
    clear       = {},
    report      = {},
    --echo = {},                -- check the protocol detail later
}


local function _check_args(cmd, args)
    local checklist = command_args[cmd]
    if not checklist then
        return nil, "command_args[cmd] not implemented for cmd: " .. cmd
    end

    local missing = {}
    local idx = 1
    for i, v in pairs(checklist) do
        if not args[v] then
            table.insert(missing, v)
        end
    end

    if #missing > 0 then
        return nil, "argument " .. table.concat(missing, ",")
                .. " is missing for cmd: " .. cmd
    end

    return true
end

local function _do_req(http, cmd, args)

    -- check args
    local ok, err = _check_args(cmd, args)
    if not ok then
        return nil, err
    end
    -- get uri and header
    local uri = "/rpc/" .. cmd
    -- get body
    local body, err
    if type(args) == "table" then
        body, err = tsv.encode(args)
    elseif type(args) == "string" then
        body = args
    elseif type(args) == "nil" then
        body = ""
    else
        return nil, "bad argument, expecting table or string but got "
                .. type(args)
    end
    if not body then
        return nil, err
    end

    return http:post(uri, body)
end

-- kt:get("hello")
local function _do_command(self, cmd, args)
    local res, err = _do_req(self.http, cmd, args)
    if not res then
        return nil, err
    end

    if #res.body == 0 then
        return ""
    end

    if (res.header.content_type ~= "text/tab-separated-values") then
        return res.body
    end

    local t = tsv.decode_kv(res.body)
print("tsv result:" .. cjson.encode(t))
    return t
end

function _M.new(self)
    local http, err = httpmod:new()
    if not http then
        return nil, err
    end

    return setmetatable({ http = http, tsv = tsv }, mt)
end


function _M.connect(self, ...)
    local args = {...}
    local host = args[1]
    local port = args[2]

    return self.http:connect({ host = host, port = port })
end

for i, cmd in pairs(commands) do
    _M[cmd] = function(self, args) return _do_command(self, cmd, args) end
end

function _M.set_timeout(self, ...)
    self.http:set_timeout(...)
end

function _M.close(self)
    self.http:close()
end

return _M
