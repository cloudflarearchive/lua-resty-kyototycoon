# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * (blocks() * 2 + 1);

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

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local kyoto_tycoon = require "resty.kyoto_tycoon"
            local kt = kyoto_tycoon:new()

            kt:set_timeout(1000) -- 1 sec

            local ok, err = kt:connect("127.0.0.1", $TEST_NGINX_KT_PORT)
            if not ok then
                ngx.log(ngx.ERR, "failed to connect to kt: ", err)
                return
            end

            local res, err = kt:void()
            if err then
                ngx.log(ngx.ERR, "failed to call kt:void(): ", err)
                return
            end

            res, err = kt:set({
                key = "kyoto",
                value = "tycoon",
            })
            if not res then
                ngx.log(ngx.ERR, "failed to set: ", err)
                return
            end

            ngx.say("set kyoto ok")

            res, err = kt:get({ key = "kyoto" })
            if err then
                ngx.log(ngx.ERR, "failed to get kyoto: ", err)
                return
            end

            if not res then
                ngx.say("kyoto not found.")
                return
            end

            ngx.say("kyoto: ", res)

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

