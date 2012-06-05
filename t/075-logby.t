# vim:set ft= ts=4 sw=4 et fdm=marker:

use lib 'lib';
use Test::Nginx::Socket;

#worker_connections(1014);
#master_on();
#workers(2);
log_level('debug');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 3 + 3);

#no_diff();
#no_long_string();
run_tests();

__DATA__

=== TEST 1: log_by_lua
--- config
    location /lua {
        echo hello;
        log_by_lua 'ngx.log(ngx.ERR, "Hello from log_by_lua: ", ngx.var.uri)';
    }
--- request
GET /lua
--- response_body
hello
--- error_log
Hello from log_by_lua: /lua



=== TEST 2: log_by_lua_file
--- config
    location /lua {
        echo hello;
        log_by_lua_file html/a.lua;
    }
--- user_files
>>> a.lua
ngx.log(ngx.ERR, "Hello from log_by_lua: ", ngx.var.uri)
--- request
GET /lua
--- response_body
hello
--- error_log
Hello from log_by_lua: /lua



=== TEST 3: log_by_lua_file & content_by_lua
--- config
    location /lua {
        set $counter 3;
        content_by_lua 'ngx.var.counter = ngx.var.counter + 1 ngx.say(ngx.var.counter)';
        log_by_lua_file html/a.lua;
    }
--- user_files
>>> a.lua
ngx.log(ngx.ERR, "Hello from log_by_lua: ", ngx.var.counter * 2)
--- request
GET /lua
--- response_body
4
--- error_log
Hello from log_by_lua: 8



=== TEST 4: ngx.ctx available in log_by_lua (already defined)
--- config
    location /lua {
        content_by_lua 'ngx.ctx.counter = 3 ngx.say(ngx.ctx.counter)';
        log_by_lua 'ngx.log(ngx.ERR, "ngx.ctx.counter: ", ngx.ctx.counter)';
    }
--- request
GET /lua
--- response_body
3
--- error_log
ngx.ctx.counter: 3
lua release ngx.ctx



=== TEST 5: ngx.ctx available in log_by_lua (not defined yet)
--- config
    location /lua {
        echo hello;
        log_by_lua '
            ngx.log(ngx.ERR, "ngx.ctx.counter: ", ngx.ctx.counter)
            ngx.ctx.counter = "hello world"
        ';
    }
--- request
GET /lua
--- response_body
hello
--- error_log
ngx.ctx.counter: nil
lua release ngx.ctx



=== TEST 6: log_by_lua + shared dict
--- http_config
    lua_shared_dict foo 100k;
--- config
    location /lua {
        echo hello;
        log_by_lua '
            local foo = ngx.shared.foo
            local key = ngx.var.uri .. ngx.status
            local newval, err = foo:incr(key, 1)
            if not newval then
                if err == "not found" then
                    foo:add(key, 0)
                    newval, err = foo:incr(key, 1)
                    if not newval then
                        ngx.log(ngx.ERR, "failed to incr ", key, ": ", err)
                        return
                    end
                else
                    ngx.log(ngx.ERR, "failed to incr ", key, ": ", err)
                    return
                end
            end
            print(key, ": ", foo:get(key))
        ';
    }
--- request
GET /lua
--- response_body
hello
--- error_log eval
qr{/lua200: [12]}
--- no_error_log
[error]

