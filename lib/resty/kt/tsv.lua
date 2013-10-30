-- Copyright (C) 2013  Jiale Zhi (calio), Cloudflare Inc.

local string_byte = string.byte
local string_sub  = string.sub

local CR          = string_byte("\r")
local LF          = string_byte("\n")
local HTAB        = string_byte("\t")


local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 10)


function _M.parse(tsv_text)
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
            ngx.log(ngx.NOTICE, string_sub(tsv_text, i, j))
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

        res[row_idx] = line
    end
    return res
end

function _M.generate(source)
end

return _M
