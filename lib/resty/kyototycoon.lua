-- Copyright (C) 2013  Jiale Zhi (calio), Cloudflare Inc.

local httpmod       = require "resty.kt.http"
local tsv           = require "resty.kt.tsv"

local pairs         = pairs
local concat        = table.concat
local debug         = ngx.config.debug
local log           = ngx.log
local format        = string.format
local sub           = string.sub
local match         = string.match

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
    "check",    "seize",      --"set_bulk",     "remove_bulk",  "get_bulk",
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
    replace             = { "key", "value" },
    append              = { "key", "value" },
    get                 = { "key" },
    get_bulk            = {},
    set_bulk            = {},
    remove_bulk         = {},
    match_prefix        = { "prefix" },
    match_regex         = { "regex" },
    match_similar       = { "origin" },
----------------------- NOT TESTED --------------------------
    increment           = { "key", "num" }, -- failed
    increment_double    = { "key", "num" },
    cas                 = { "key" },
    remove              = { "key" },
    check               = { "key" },
    seize               = { "key" },
    vacuum              = {},
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
        body, err = tsv.encode(args, ngx.encode_base64)
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

local function _strip_underscored_result(res)
    local num = res.num

    if not num then
        return nil, "bad response from Kyoto Tycoon server, \"num\" not found"
    end

    res.num = nil

    local new_res = new_tab(0, num)
    for k, v in pairs(res) do
        new_res[sub(k, 2)] = v
    end

    return new_res
end

local function _get_encoding(content_type)
    if (sub(content_type, 1, 25) ~= "text/tab-separated-values") then
        return false
    end

    local enc = match(content_type, "colenc%=(%w)")
    return true, enc
end

local function _decode_quoted_printable(str)
    return sub(str, 2, -2)
end

local function _do_command(self, cmd, args)
    local res, err = _do_req(self.http, cmd, args)
    if not res then
        return nil, err
    end

    if #res.body == 0 then
        return ""
    end

    local is_tsv, encoding = _get_encoding(res.header.content_type)
    if not is_tsv then
        return res.body
    end
    local decode_fun

    if encoding == "B" then
        decode_fun = ngx.decode_base64
    elseif encoding == "Q" then
        decode_fun = _decode_quoted_printable
    elseif encoding == "U" then
        decode_fun = ngx.unescape_uri
    end

    local body = tsv.decode_kv(res.body, decode_fun)
    if (res.header.status ~= 200) then
        return nil, format("%d: %s", res.header.status, body.ERROR)
    end

    return body
end

local function _do_command_strip_result(self, cmd, args)
    local res, err = _do_command(self, cmd, args)
    if err then
        return nil, err
    end

    return _strip_underscored_result(res)
end

local function _bulk_cmd(self, cmd, records, args)
    local db, atomic

    if args then
        db = args.db
        atomic = args.atomic
    end

    if atomic then
        atomic = ""
    end

    local new_args = { db = db, atomic = atomic }
    if #records > 0 then
        -- key tables
        for i, v in ipairs(records) do
            new_args["_" .. v] = ""
        end
    else
        -- key/value pairs
        for k, v in pairs(records) do
            new_args["_" .. k] = v
        end
    end

    local res, err = _do_command(self, cmd, new_args)
    if err then
        return nil, err
    end

    return _strip_underscored_result(res)
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
    if sub(cmd, 1, 6) == "match_" then
        _M[cmd] = function(self, args)
                        return _do_command_strip_result(self, cmd, args)
                  end
    else
        _M[cmd] = function(self, args)
                        return _do_command(self, cmd, args)
                  end
    end
end

function _M.set_keepalive(self, ...)
    self.http:set_keepalive(self, ...)
end

function _M.set_timeout(self, ...)
    self.http:set_timeout(...)
end

function _M.close(self)
    self.http:close()
end

function _M.set_bulk(self, records, args)
    return _bulk_cmd(self, "set_bulk", records, args)
end

function _M.get_bulk(self, keys, args)
    return _bulk_cmd(self, "get_bulk", keys, args)
end

function _M.remove_bulk(self, keys, args)
    return _bulk_cmd(self, "remove_bulk", keys, args)
end

return _M
