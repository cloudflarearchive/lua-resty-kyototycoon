# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 2 + 1);

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?.lua;;";
    lua_package_cpath "/usr/local/openresty-debug/lualib/?.so;/usr/local/openresty/lualib/?.so;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_KT_PORT} ||= 1978;

#no_long_string();

log_level('info');

run_tests();

__DATA__

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config
    lua_need_request_body on;
    client_body_buffer_size 50k;

    location /test {
        content_by_lua '
            ngx.print("Thanks for your " .. ngx.var.request_body)
        ';
    }

    location /t {
        content_by_lua '
            local http_module = require "resty.kt.http"
            local http = http_module:new()

            http:set_timeout(1000)

            local ok, err = http:connect({host = "127.0.0.1",
                    port = $TEST_NGINX_SERVER_PORT})
            if not ok then
                ngx.log(ngx.ERR, "failed to connect to 127.0.0.1:$TEST_NGINX_SERVER_PORT",
                        err)
                return
            end

            local res, err = http:post("/test", "cookies")
            if not res then
                ngx.log(ngx.ERR, "failed to send post request to /test: ", err)
                return
            end

            ngx.say(res.body)
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body
Thanks for your cookies



=== TEST 2: only header
--- http_config eval: $::HttpConfig
--- config
    lua_need_request_body on;
    client_body_buffer_size 50k;

    location /test {
        content_by_lua '
            ngx.exit(200)
        ';
    }

    location /t {
        content_by_lua '
            local http_module = require "resty.kt.http"
            local http = http_module:new()

            http:set_timeout(1000)

            local ok, err = http:connect({host = "127.0.0.1",
                    port = $TEST_NGINX_SERVER_PORT})
            if not ok then
                ngx.log(ngx.ERR, "failed to connect to 127.0.0.1:$TEST_NGINX_SERVER_PORT",
                        err)
                return
            end

            local res, err = http:post("/test", "cookies")
            if not res then
                ngx.log(ngx.ERR, "failed to send post request to /test: ", err)
                return
            end
            ngx.print(res.body)
        ';
    }
--- request
GET /t
--- no_error_log

--- response_body
