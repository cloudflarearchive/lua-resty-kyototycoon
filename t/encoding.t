# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * (blocks() * 3);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_KT_PORT} ||= 1978;

#no_long_string();

log_level('notice');

run_tests();

__DATA__

=== TEST 1: value contains "\t"
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
                value = "\ttycoon",
            })
            if not ok then
                ngx.say("failed to set: ", err)
                return
            end

            ngx.say("set kyoto ok")

            res, err = kt:get({ key = "kyoto" })
            if err then
                ngx.say("failed to get kyoto ", err)
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
--- response_body eval
"set kyoto ok
kyoto: \ttycoon
"

