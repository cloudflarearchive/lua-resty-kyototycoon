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
    location /t {
        content_by_lua '
            local cjson = require "cjson"
            local tsv = require "resty.kt.tsv"

            local res, err tsv.parse(ngx.var.request_body)
            if not res then
                ngx.log(ngx.ERR, "failed to parse tsv")
            end

            ngx.say(cjson.encode(res))
        ';
    }
--- request eval
"POST /t\r\nBach\tMozart\tBeethoven\r\nPagnini\tHeifetz"
--- no_error_log
[error]
--- response

