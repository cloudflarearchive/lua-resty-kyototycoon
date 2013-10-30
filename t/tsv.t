# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3);

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

=== TEST 1: parsing
--- http_config eval: $::HttpConfig
--- config
    lua_need_request_body on;
    client_body_buffer_size 50k;
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local tsv = require "resty.kt.tsv"

            local res, err = tsv.decode(ngx.var.request_body)
            if not res then
                ngx.log(ngx.ERR, "failed to parse tsv: ", err)
            end

            ngx.say(cjson.encode(res))
        ';
    }
--- request eval
"POST /t\r\nBach\tMozart\tBeethoven\r\nPaganini\tHeifetz"
--- no_error_log
[error]
--- response_body
[["Bach","Mozart","Beethoven"],["Paganini","Heifetz"]]



=== TEST 2: parsing 2
--- http_config eval: $::HttpConfig
--- config
    lua_need_request_body on;
    client_body_buffer_size 50k;
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local tsv = require "resty.kt.tsv"

            ngx.log(ngx.NOTICE, ngx.var.request_body)
            local res, err = tsv.decode(ngx.var.request_body)
            if not res then
                ngx.log(ngx.ERR, "failed to parse tsv: ", err)
            end

            ngx.say(cjson.encode(res))
        ';
    }
--- request eval
[["POST /t\r\n", "Beethoven\n\tPaganini\nHeifetz"]]
--- no_error_log
[error]
--- response_body
[["Beethoven"],["","Paganini"],["Heifetz"]]



=== TEST 3: parsing 3
--- http_config eval: $::HttpConfig
--- config
    lua_need_request_body on;
    client_body_buffer_size 50k;
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local tsv = require "resty.kt.tsv"

            local res, err = tsv.decode(ngx.var.request_body)
            if not res then
                ngx.log(ngx.ERR, "failed to parse tsv: ", err)
            end

            ngx.say(cjson.encode(res))
        ';
    }
--- request eval
"POST /t\r\n\nBeethoven\tPaganini\nHeifetz"
--- no_error_log
[error]
--- response_body
[["Beethoven","Paganini"],["Heifetz"]]



=== TEST 4: encoding
--- http_config eval: $::HttpConfig
--- config
    lua_need_request_body on;
    client_body_buffer_size 50k;
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local tsv = require "resty.kt.tsv"

            local content = {
                {"Bach", "Tchaikovsky"},
                {"Mozart"},
            }
            local res, err = tsv.encode(content)
            if not res then
                ngx.log(ngx.ERR, "failed to decode tsv: ", err)
            end

            ngx.say(res)
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body eval
"Bach\tTchaikovsky\nMozart\n"



=== TEST 5: encoding
--- http_config eval: $::HttpConfig
--- config
    lua_need_request_body on;
    client_body_buffer_size 50k;
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local tsv = require "resty.kt.tsv"

            local content = {
            }
            local res, err = tsv.encode(content)
            if not res then
                ngx.log(ngx.ERR, "failed to decode tsv: ", err)
            end

            ngx.say(res)
        ';
    }
--- request
GET /t
--- no_error_log
[error]
--- response_body eval
"\n"
--- ONLY
