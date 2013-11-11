-- Copyright (C) 2013  Jiale Zhi (calio), Cloudflare Inc.

local httpmod       = require "resty.kt.http"
local tsv           = require "resty.kt.tsv"

local pairs         = pairs
local concat        = table.concat
local debug         = ngx.config.debug
local log           = ngx.log
local format        = string.format

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
    void                = {},
    --echo              = {},            -- check the protocol detail later
    report              = {},
    --play_script         = { "name" },
    --tune_replication    = {},
    status              = {},
    clear               = {},
    --synchronize         = {},
    set                 = { "key", "value" },
    add                 = { "key", "value" },
----------------------- NOT TESTED --------------------------
    replace             = { "key", "value" },
    append              = { "key", "value" },
    increment           = { "key", "num" },
    increment_double    = { "key", "num" },
    cas                 = { "key" },
    remove              = { "key" },
    get                 = { "key" },
    check               = { "key" },
    seize               = { "key" },
    set_bulk            = {},
    remove_bulk         = {},
    get_bulk            = {},
    vacuum              = {},
    match_prefix        = { "prefix" },
    match_regex         = { "regex" },
    match_similar       = { "origin" },
    cur_jump            = { "CUR" },
    cur_jump_back       = { "CUR" },
    cur_step            = { "CUR" },
    cur_step_back       = { "CUR" },
    cur_set_value       = { "CUR", "value" },
    cur_remove          = { "CUR" },
    cur_get_key         = { "CUR" },
    cur_get_value       = { "CUR" },
    cur_get             = { "CUR" },
    cur_seize           = { "CUR" },
    cur_delete          = { "CUR" },
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
            missing[idx] = v
            idx = idx + 1
        end
    end

    if idx > 1 then
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
        if not body then
            return nil, err
        end
    elseif type(args) == "string" then
        body = args
    elseif type(args) == "nil" then
        body = ""
    else
        return nil, "bad argument, expecting table or string but got "
                .. type(args)
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

    local body = tsv.decode_kv(res.body)
    if (res.header.status ~= 200) then
        return nil, format("%d: %s", res.header.status, body.ERROR)
    end

    return body
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
