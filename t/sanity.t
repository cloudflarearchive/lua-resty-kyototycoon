# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * (blocks() * 3 + 2);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_KT_PORT} ||= 1978;

no_long_string();

log_level('notice');

run_tests();

__DATA__

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            local res, err = kt:void()
            if err then
                ngx.say("failed to call kt:void(): ", err)
                return
            end

            ok, err = kt:set({
                key = "kyoto",
                value = "tycoon",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set kyoto ok")

            res, err = kt:get({ key = "kyoto" })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            if not res.value then
                ngx.say("kyoto not found.")
                return
            else
                ngx.say("kyoto: ", res.value)
            end

            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
set kyoto ok
kyoto: tycoon



=== TEST 2: sanity, more commands
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            local res, err = kt:report()
            if err then
                ngx.say("failed to call kt:report(): ", err)
                return
            end
            print(cjson.encode(res))

            local res, err = kt:status()
            if err then
                ngx.say("failed to call kt:report(): ", err)
                return
            end
            print(cjson.encode(res))

            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- error_log
ktcapcnt
conf_kc_version
--- response_body



=== TEST 3: clear
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            ok, err = kt:set({
                key = "kyoto",
                value = "tycoon",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set kyoto ok")

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            res, err = kt:get({ key = "kyoto" })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
set kyoto ok
failed to get kyoto: 450: DB: 7: no record: no record



=== TEST 4: set number
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:set({
                key = "count",
                value = 1,
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set count ok")

            res, err = kt:get({ key = "count" })
            if err then
                ngx.say("failed to get count ", err)
                return
            end

            if not res.value then
                ngx.say("count not found.")
                return
            else
                ngx.say("count: ", res.value)
            end

            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
set count ok
count: 1



=== TEST 5: add
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:add({
                key = "count",
                value = 1,
            })
            if err then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("add count ok")

            res, err = kt:get({ key = "count" })
            if err then
                ngx.say("failed to get count ", err)
                return
            end

            if not res.value then
                ngx.say("count not found.")
                return
            else
                ngx.say("count: ", res.value)
            end

            ok, err = kt:add({
                key = "count",
                value = 1,
            })
            if err then
                ngx.say("failed to set: ", err)
                return
            end

            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
add count ok
count: 1
failed to set: 450: DB: 6: record duplication: record duplication



=== TEST 6: replace
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:replace({
                key = "count",
                value = 1,
            })
            if err then
                ngx.say("failed to replace ", err)
            else
                ngx.say("replace count ok")
            end

            res, err = kt:set({ key = "count", value = 2 })
            if err then
                ngx.say("failed to set count ", err)
                return
            end

            ok, err = kt:replace({
                key = "count",
                value = 1,
            })
            if err then
                ngx.say("failed to replace ", err)
            else
                ngx.say("replace count ok")
            end

            res, err = kt:get({ key = "count" })
            if err then
                ngx.say("failed to get count ", err)
            else
                ngx.say("get count: ", res.value)
            end

            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
failed to replace 450: DB: 7: no record: no record
replace count ok
get count: 1



=== TEST 7: append
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:append({
                key = "kyoto",
                value = "tycoon",
            })
            if not ok then
                ngx.say("failed to append ", err)
                return
            end

            ngx.say("append kyoto ok")

            res, err = kt:get({ key = "kyoto" })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            if not res.value then
                ngx.say("kyoto not found.")
                return
            else
                ngx.say("kyoto: ", res.value)
            end

            ok, err = kt:append({
                key = "kyoto",
                value = "+tycoon",
            })
            if not ok then
                ngx.say("failed to append ", err)
                return
            end

            ngx.say("append kyoto ok")

            res, err = kt:get({ key = "kyoto" })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            if not res.value then
                ngx.say("kyoto not found.")
                return
            else
                ngx.say("kyoto: ", res.value)
            end

            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
append kyoto ok
kyoto: tycoon
append kyoto ok
kyoto: tycoon+tycoon



=== TEST 8: increment # need to know more about KT's implementation
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            local ok, err = kt:set({ key = "abc", value = 1000 })
            if err then
                ngx.say("failed to set: ", err)
            end

            local res, err = kt:increment({ key = "abc", num = 1 })
            if err then
                ngx.say("failed to increment: ", err)
            else
                ngx.say("increment ok: ", res.value)
            end

            local res, err = kt:increment({ key = "xyz", num = 1000 })
            if err then
                ngx.say("failed to increment: ", err)
            else
                ngx.say("increment ok: ", res.num)
            end

            local res, err = kt:increment({ key = "abc", num = 1, orig = "set" })
            if err then
                ngx.say("failed to increment: ", err)
            else
                ngx.say("increment ok: ", res.num)
            end

            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
failed to increment: 450: DB: 8: logical inconsistency: logical inconsistency
increment ok: 1000
increment ok: 1001
--- SKIP



=== TEST 9: get_bulk
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:set({
                key = "kyoto",
                value = "tycoon",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ok, err = kt:set({
                key = "tokyo",
                value = "cabinet",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set kyoto, tokyo ok")

            res, err = kt:get_bulk({ "kyoto", "tokyo" }, { atomic = true })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            for k, v in pairs(res) do
                ngx.say(k, ": ", v)
            end
            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
set kyoto, tokyo ok
tokyo: cabinet
kyoto: tycoon



=== TEST 10: sanity
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:set({
                key = "kyoto",
                value = "tycoon",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set kyoto ok")

            res, err = kt:get_bulk({ "kyoto", "tokyo" }, { atomic = true })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            for k, v in pairs(res) do
                ngx.say(k, ": ", v)
            end
            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
set kyoto ok
kyoto: tycoon



=== TEST 11: match_prefix
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:set({
                key = "abcd",
                value = "kyoto",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ok, err = kt:set({
                key = "abcdefg",
                value = "tycoon",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set ok")

            res, err = kt:match_prefix({ prefix = "abc", max = 10 })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            for k, v in pairs(res) do
                ngx.say(k, ": ", v)
            end
            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
set ok
abcd: 0
abcdefg: 1



=== TEST 12: match_regex
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:set({
                key = "abcd",
                value = "kyoto",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ok, err = kt:set({
                key = "abcdefg",
                value = "tycoon",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set ok")

            res, err = kt:match_regex({ regex = [[^abc\\w*$]], max = 10 })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            for k, v in pairs(res) do
                ngx.say(k, ": ", v)
            end
            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
set ok
abcd: 0
abcdefg: 1



=== TEST 13: match_similar
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:set({
                key = "abcd",
                value = "kyoto",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ok, err = kt:set({
                key = "abcdefg",
                value = "tycoon",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set ok")

            res, err = kt:match_similar({
                    origin = "abcde",
                    range = 2,
                    max = 10,
            })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            for k, v in pairs(res) do
                ngx.say(k, ": ", v)
            end
            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
set ok
abcd: 0
abcdefg: 1



=== TEST 14: set_bulk
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyototycoon = require "resty.kyototycoon"
            local kt = kyototycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.say("failed to connect to kt: ", err)
                return
            end

            local res, err = kt:clear()
            if err then
                ngx.say("failed to call kt:clear(): ", err)
                return
            end

            ok, err = kt:set_bulk({
                kyoto = "tycoon",
                tokyo = "cabinet",
            }, { atom = true })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set kyoto, tokyo ok")

            res, err = kt:get_bulk({ "kyoto", "tokyo" }, { atomic = true })
            if err then
                ngx.say("failed to get kyoto: ", err)
                return
            end

            for k, v in pairs(res) do
                ngx.say(k, ": ", v)
            end
            kt:close()
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
set kyoto, tokyo ok
tokyo: cabinet
kyoto: tycoon
