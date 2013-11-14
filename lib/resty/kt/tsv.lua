-- Copyright (C) 2013  Jiale Zhi (calio), Cloudflare Inc.

local string_byte   = string.byte
local string_sub    = string.sub
local concat        = table.concat
local ipairs        = ipairs
local pairs         = pairs
local type          = type


local CR          = string_byte("\r")
local LF          = string_byte("\n")
local HTAB        = string_byte("\t")


local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 10)
_M._VERSION = '0.01'


function _M.decode_kv(tsv_text, decode_fun)
    local r, err = _M.decode(tsv_text)
    if not r then
        return nil, err
    end
    local res = {}
    for i, v in ipairs(r) do
        if decode_fun then
            res[decode_fun(v[1])] = decode_fun(v[2])
        else
            res[v[1]] = v[2]
        end
    end

    return res
end

function _M.decode(tsv_text)
    if (type(tsv_text) ~= "string") then
        return nil, "expect string but got " .. type(tsv_text)
    end

    local len = #tsv_text
    local i = 1
    local j = 1
    local col_idx = 1
    local row_idx = 1

    local res = {}
    local line = {}

    while j <= len do
        local ch = string_byte(tsv_text, j)
        if ch == HTAB then
            line[col_idx] = string_sub(tsv_text, i, j - 1)
            i = j + 1
            col_idx = col_idx + 1
        elseif ch == CR or ch == LF then
            line[col_idx] = string_sub(tsv_text, i, j - 1)
            if j < len then
                local ch1 = string_byte(tsv_text, j + 1)
                if ch1 == CR or ch1 == LF then
                    j = j + 1
                end
            end

            i = j + 1

            res[row_idx] = line
            col_idx = 1
            row_idx = row_idx + 1

            line = {}
        end
        j = j + 1
    end

    if i < len then
        line[col_idx] = string_sub(tsv_text, i)
        ngx.log(ngx.NOTICE, row_idx, " ", col_idx, " ", line[col_idx])

        res[row_idx] = line
    end
    return res
end

function _M.encode(source)
    if type(source) == "nil" then
        return ""
    end

    if type(source) ~= "table" then
        return nil, "tsv.encode expecting table but got "
                .. type(source)
    end

    local rows_idx = 1
    local rows = {}

    if #source > 0 then
        for i, row in ipairs(source) do
            rows[rows_idx] = concat(row, "\t")
            rows_idx = rows_idx + 1
        end
    else
        for k, v in pairs(source) do
            local val
            if type(v) == "table" then
                val = _M.encode(v)
            else
                val = v
            end
            rows[rows_idx] = k .. "\t" .. val
            rows_idx = rows_idx + 1
        end
    end

    return concat(rows, "\n")
end

return _M
