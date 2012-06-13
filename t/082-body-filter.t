# vim:set ft= ts=4 sw=4 et fdm=marker:

use lib 'lib';
use Test::Nginx::Socket;

#worker_connections(1014);
#master_process_enabled(1);
#log_level('warn');

log_level('debug');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 + 5);

#no_diff();
#no_long_string();

run_tests();

__DATA__

=== TEST 1: read chunks (inline)
--- config
    location /read {
        echo -n hello world;
        echo -n hiya globe;

        body_filter_by_lua '
            local chunk, eof = ngx.arg[1], ngx.arg[2]
            print("chunk: [", chunk, "], eof: ", eof)
        ';
    }
--- request
GET /read
--- response_body chop
hello worldhiya globe
--- error_log
chunk: [hello world], eof: false
chunk: [hiya globe], eof: false
chunk: [], eof: true
--- no_error_log
[error]



=== TEST 2: read chunks (file)
--- config
    location /read {
        echo -n hello world;
        echo -n hiya globe;

        body_filter_by_lua_file html/a.lua;
    }
--- user_files
>>> a.lua
local chunk, eof = ngx.arg[1], ngx.arg[2]
print("chunk: [", chunk, "], eof: ", eof)
--- request
GET /read
--- response_body chop
hello worldhiya globe
--- error_log
chunk: [hello world], eof: false
chunk: [hiya globe], eof: false
chunk: [], eof: true
--- no_error_log
[error]



=== TEST 3: read chunks (user module)
--- http_config
    lua_package_path "$prefix/html/?.lua;;";
--- config
    location /read {
        echo -n hello world;
        echo -n hiya globe;

        body_filter_by_lua '
            local foo = require "foo"
            foo.go()
        ';
    }
--- user_files
>>> foo.lua
module("foo", package.seeall)

function go()
    -- ngx.say("Hello")
    local chunk, eof = ngx.arg[1], ngx.arg[2]
    print("chunk: [", chunk, "], eof: ", eof)
end
--- request
GET /read
--- response_body chop
hello worldhiya globe
--- error_log
chunk: [hello world], eof: false
chunk: [hiya globe], eof: false
chunk: [], eof: true
--- no_error_log
[error]



=== TEST 4: rewrite chunks (upper all)
--- config
    location /t {
        echo hello world;
        echo hiya globe;

        body_filter_by_lua '
            ngx.arg[1] = string.upper(ngx.arg[1])
        ';
    }
--- request
GET /t
--- response_body
HELLO WORLD
HIYA GLOBE
--- no_error_log
[error]



=== TEST 5: rewrite chunks (truncate data)
--- config
    location /t {
        echo hello world;
        echo hiya globe;

        body_filter_by_lua '
            local chunk = ngx.arg[1]
            if string.match(chunk, "hello") then
                ngx.arg[1] = string.upper(chunk)
                ngx.arg[2] = true
                return
            end

            ngx.arg[1] = nil
        ';
    }
--- request
GET /t
--- response_body
HELLO WORLD
--- no_error_log
[error]



=== TEST 6: set eof back and forth
--- config
    location /t {
        echo hello world;
        echo hiya globe;

        body_filter_by_lua '
            local chunk = ngx.arg[1]
            if string.match(chunk, "hello") then
                ngx.arg[1] = string.upper(chunk)
                ngx.arg[2] = true
                ngx.arg[2] = false
                ngx.arg[2] = true
                return
            end

            ngx.arg[1] = nil
            ngx.arg[2] = true
            ngx.arg[2] = false
        ';
    }
--- request
GET /t
--- response_body
HELLO WORLD
--- no_error_log
[error]



=== TEST 7: set eof to original
--- config
    location /t {
        echo hello world;
        echo hiya globe;

        body_filter_by_lua '
            local chunk, eof = ngx.arg[1], ngx.arg[2]
            ngx.arg[2] = eof
        ';
    }
--- request
GET /t
--- response_body
hello world
hiya globe
--- no_error_log
[error]



=== TEST 8: set eof to original
--- config
    location /t {
        echo hello world;
        echo hiya globe;

        body_filter_by_lua '
            local chunk, eof = ngx.arg[1], ngx.arg[2]
            ngx.arg[2] = eof
        ';
    }
--- request
GET /t
--- response_body
hello world
hiya globe
--- no_error_log
[error]



=== TEST 9: fully buffered output (string scalar)
--- config
    location /t {
        echo hello world;
        echo hiya globe;

        body_filter_by_lua '
            local chunk, eof = ngx.arg[1], ngx.arg[2]
            local buf = ngx.ctx.buf

            if eof then
                if buf then
                    ngx.arg[1] = "[" .. buf .. chunk .. "]"
                    return
                end

                return
            end

            if buf then
                ngx.ctx.buf = buf .. chunk
            else
                ngx.ctx.buf = chunk
            end

            ngx.arg[1] = nil
        ';
    }
--- request
GET /t
--- response_body chop
[hello world
hiya globe
]
--- no_error_log
[error]



=== TEST 10: fully buffered output (string table)
--- config
    location /t {
        echo hello world;
        echo hiya globe;

        body_filter_by_lua '
            local chunk, eof = ngx.arg[1], ngx.arg[2]
            local buf = ngx.ctx.buf

            if eof then
                if buf then
                    ngx.arg[1] = {"[", buf, chunk, "]"}
                    return
                end

                return
            end

            if buf then
                ngx.ctx.buf = {buf, chunk}
            else
                ngx.ctx.buf = chunk
            end

            ngx.arg[1] = nil
        ';
    }
--- request
GET /t
--- response_body chop
[hello world
hiya globe
]
--- no_error_log
[error]



=== TEST 11: abort via user error (string)
--- config
    location /t {
        echo hello world;
        echo_flush;
        echo hiya globe;

        body_filter_by_lua '
            local chunk, eof = ngx.arg[1], ngx.arg[2]
            if eof then
                error("something bad happened!")
            end
        ';
    }
--- request
GET /t
--- ignore_response
--- error_log
failed to run body_filter_by_lua*: [string "body_filter_by_lua"]:4: something bad happened!



=== TEST 12: abort via user error (nil)
--- config
    location /t {
        echo hello world;
        echo_flush;
        echo hiya globe;

        body_filter_by_lua '
            local chunk, eof = ngx.arg[1], ngx.arg[2]
            if eof then
                error(nil)
            end
        ';
    }
--- request
GET /t
--- ignore_response
--- error_log
failed to run body_filter_by_lua*: unknown reason



=== TEST 13: abort via return NGX_ERROR
--- config
    location /t {
        echo hello world;
        echo_flush;
        echo hiya globe;

        body_filter_by_lua '
            local chunk, eof = ngx.arg[1], ngx.arg[2]
            if eof then
                return ngx.ERROR
            end
        ';
    }
--- request
GET /t
--- ignore_response
--- no_error_log
[error]

