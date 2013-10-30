-- Copyright (C) 2013  Jiale Zhi (calio), Cloudflare Inc.

local ok, new_tab = pcall(require, "table.new")
if not ok then
    new_tab = function (narr, nrec) return {} end
end

local _M = new_tab(0, 10)


function _M.parse(tsv_text)
end

function _M.generate(source)
end

return _M
