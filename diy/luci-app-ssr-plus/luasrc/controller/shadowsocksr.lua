-- Copyright (C) 2017 yushi studio <ywb94@qq.com>
-- Licensed to the public under the GNU General Public License v3.
module("luci.controller.shadowsocksr", package.seeall)

function index()
	if not nixio.fs.access("/etc/config/shadowsocksr") then
		call("act_reset")
	end
	local page
	page = entry({"admin", "services", "shadowsocksr"}, alias("admin", "services", "shadowsocksr", "client"), _("ShadowSocksR Plus+"), 10)
	page.dependent = true
	page.acl_depends = { "luci-app-ssr-plus" }
	entry({"admin", "services", "shadowsocksr", "client"}, cbi("shadowsocksr/client"), _("SSR Client"), 10).leaf = true
	entry({"admin", "services", "shadowsocksr", "servers"}, arcombine(cbi("shadowsocksr/servers", {autoapply = true}), cbi("shadowsocksr/client-config")), _("Severs Nodes"), 20).leaf = true
        entry({"admin", "services", "shadowsocksr", "subscription"},cbi("shadowsocksr/subscription"),_("Subscribe"),25).leaf=true	
	entry({"admin", "services", "shadowsocksr", "control"}, cbi("shadowsocksr/control"), _("Access Control"), 30).leaf = true
        entry({"admin", "services", "shadowsocksr", "node_list"},arcombine(cbi("shadowsocksr/node_list", {autoapply = true}), cbi("shadowsocksr/client-config")),_("Auto Switch"), 40).leaf = true
    --  entry({"admin", "services", "shadowsocksr", "advanced"}, cbi("shadowsocksr/advanced"), _("Advanced Settings"), 50).leaf = true
	entry({"admin", "services", "shadowsocksr", "server"}, arcombine(cbi("shadowsocksr/server"), cbi("shadowsocksr/server-config")), _("Server-Side"), 60).leaf = true
	entry({"admin", "services", "shadowsocksr", "status"}, form("shadowsocksr/status"), _("Status"), 70).leaf = true
	entry({"admin", "services", "shadowsocksr", "check"}, call("check_status"))
	entry({"admin", "services", "shadowsocksr", "refresh"}, call("refresh_data"))
    --  entry({"admin", "services", "shadowsocksr", "subscribe"}, call("subscribe"))
        entry({"admin", "services", "shadowsocksr", "subscribe"}, call("get_subscribe"))
	entry({"admin", "services", "shadowsocksr", "checkport"}, call("check_port"))
        entry({"admin", "services", "shadowsocksr", "checkports"}, call("check_ports"))
        entry({"admin", "services", "shadowsocksr", "switch"}, call("switch"))
        entry({"admin", "services", "shadowsocksr", "flag"}, call("get_flag"))
        entry({"admin", "services", "shadowsocksr", "ip"}, call("check_ip"))
	entry({"admin", "services", "shadowsocksr", "log"}, form("shadowsocksr/log"), _("Watch Logs"), 80).leaf = true
          entry({"admin", "services", "shadowsocksr", "get_log"}, call("get_log")).leaf = true
         entry({"admin", "services", "shadowsocksr", "clear_log"}, call("clear_log")).leaf = true
	entry({"admin", "services", "shadowsocksr", "run"}, call("act_status"))
        entry({"admin", "services", "shadowsocksr", "change"}, call("change_node"))
        entry({"admin", "services", "shadowsocksr", "allserver"}, call("get_servers"))
	entry({"admin", "services", "shadowsocksr", "ping"}, call("act_ping"))
	entry({"admin", "services", "shadowsocksr", "reset"}, call("act_reset"))
	entry({"admin", "services", "shadowsocksr", "restart"}, call("act_restart"))
	entry({"admin", "services", "shadowsocksr", "delete"}, call("act_delete"))
	entry({"admin", "services", "shadowsocksr", "cache"}, call("act_cache"))
end


function subscribe()
	luci.sys.call("/usr/bin/lua /usr/share/shadowsocksr/subscribe.lua >>/var/log/ssrplus.log")
	luci.http.prepare_content("application/json")
	luci.http.write_json({ret = 1})
end

function get_subscribe()
    local cjson = require "cjson"
    local e = {}
    local uci = luci.model.uci.cursor()
    local auto_update = luci.http.formvalue("auto_update")
    local auto_update_time = luci.http.formvalue("auto_update_time")
    local proxy = luci.http.formvalue("proxy")
    local subscribe_url = luci.http.formvalue("subscribe_url")
    if subscribe_url ~= "[]" then
        local cmd1 = 'uci set shadowsocksr.@server_subscribe[0].auto_update="' ..
                         auto_update .. '"'
        local cmd2 = 'uci set shadowsocksr.@server_subscribe[0].auto_update_time="' ..
                         auto_update_time .. '"'
        local cmd3 = 'uci set shadowsocksr.@server_subscribe[0].proxy="' .. proxy .. '"'
        luci.sys.call('uci delete shadowsocksr.@server_subscribe[0].subscribe_url ')
        luci.sys.call(cmd1)
        luci.sys.call(cmd2)
        luci.sys.call(cmd3)
        for k, v in ipairs(cjson.decode(subscribe_url)) do
            luci.sys.call(
                'uci add_list shadowsocksr.@server_subscribe[0].subscribe_url="' .. v ..
                    '"')
        end
        luci.sys.call('uci commit shadowsocksr')
        luci.sys.call(
              "nohup /usr/bin/lua /usr/share/shadowsocksr/subscribe.lua >/www/check_update.htm 2>/dev/null &")
        
        e.error = 0
    else
        e.error = 1
    end

    luci.http.prepare_content("application/json")
    luci.http.write_json(e)
end

function get_servers()
                local uci = luci.model.uci.cursor()
                local server_table = {}
                uci:foreach("shadowsocksr", "servers", function(s)
                local e = {}
                e["name"] = s[".name"]
                local t1 = luci.sys.exec(
                       "ping -c 1 -W 1 %q 2>&1 | grep -o 'time=[0-9]*.[0-9]' | awk -F '=' '{print$2}'" %
                           s["server"])
                e["t1"] = t1
                table.insert(server_table, e)
    end)
                luci.http.prepare_content("application/json")
                luci.http.write_json(server_table)
end

function change_node()
                local e = {}
                local uci = luci.model.uci.cursor()
                local sid = luci.http.formvalue("set")
                local name = ""
                uci:foreach("shadowsocksr", "global", function(s) name = s[".name"] end)
                e.status = false
                e.sid = sid
                if sid ~= "" then
                uci:set("shadowsocksr", name, "global_server", sid)
                uci:commit("shadowsocksr")
                luci.sys.call("/etc/init.d/shadowsocksr restart")
                e.status = true
    end
                luci.http.prepare_content("application/json")
                luci.http.write_json(e)
end

function switch()
               local e = {}
               local uci = luci.model.uci.cursor()
               local sid = luci.http.formvalue("node")
               local isSwitch = uci:get("shadowsocksr", sid, "switch_enable")
               if isSwitch == "1" then
               uci:set("shadowsocksr", sid, "switch_enable","0")
               e.switch = false
               else
               uci:set("shadowsocksr", sid, "switch_enable","1")
               e.switch = true
  end
               uci:commit("shadowsocksr")
               e.status = true
               luci.http.prepare_content("application/json")
               luci.http.write_json(e)
  end

function act_status()
	local e = {}
	e.running = luci.sys.call("busybox ps -w | grep ssr-retcp | grep -v grep >/dev/null") == 0
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function act_ping()
	local e = {}
	local domain = luci.http.formvalue("domain")
	local port = luci.http.formvalue("port")
	local transport = luci.http.formvalue("transport")
	local wsPath = luci.http.formvalue("wsPath")
	local tls = luci.http.formvalue("tls")
	e.index = luci.http.formvalue("index")
	local iret = luci.sys.call("ipset add ss_spec_wan_ac " .. domain .. " 2>/dev/null")
	if transport == "ws" then
		local prefix = tls=='1' and "https://" or "http://"
		local address = prefix..domain..':'..port..wsPath
		local result = luci.sys.exec("curl --http1.1 -m 2 -ksN -o /dev/null -w 'time_connect=%{time_connect}\nhttp_code=%{http_code}' -H 'Connection: Upgrade' -H 'Upgrade: websocket' -H 'Sec-WebSocket-Key: SGVsbG8sIHdvcmxkIQ==' -H 'Sec-WebSocket-Version: 13' "..address)
		e.socket = string.match(result,"http_code=(%d+)")=="101"
		e.ping = tonumber(string.match(result, "time_connect=(%d+.%d%d%d)"))*1000
	else
		local socket = nixio.socket("inet", "stream")
		socket:setopt("socket", "rcvtimeo", 3)
		socket:setopt("socket", "sndtimeo", 3)
		e.socket = socket:connect(domain, port)
		socket:close()
		-- 	e.ping = luci.sys.exec("ping -c 1 -W 1 %q 2>&1 | grep -o 'time=[0-9]*.[0-9]' | awk -F '=' '{print$2}'" % domain)
		-- 	if (e.ping == "") then
		e.ping = luci.sys.exec(string.format("echo -n $(tcping -q -c 1 -i 1 -t 2 -p %s %s 2>&1 | grep -o 'time=[0-9]*' | awk -F '=' '{print $2}') 2>/dev/null", port, domain))
		-- 	end
	end
	if (iret == 0) then
		luci.sys.call(" ipset del ss_spec_wan_ac " .. domain)
	end
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function check_status()
	local e = {}
	e.ret = luci.sys.call("/usr/bin/ssr-check www." .. luci.http.formvalue("set") .. ".com 80 3 1")
	luci.http.prepare_content("application/json")
	luci.http.write_json(e)
end

function refresh_data()
	local set = luci.http.formvalue("set")
	local retstring = loadstring("return " .. luci.sys.exec("/usr/bin/lua /usr/share/shadowsocksr/update.lua " .. set))()
	luci.http.prepare_content("application/json")
	luci.http.write_json(retstring)
end

function check_ports()
	local retstring = "<br /><br />"
	local s
	local server_name = ""
	local uci = luci.model.uci.cursor()
	local iret = 1
	uci:foreach("shadowsocksr", "servers", function(s)
		if s.alias then
			server_name = s.alias
		elseif s.server and s.server_port then
			server_name = "%s:%s" % {s.server, s.server_port}
		end
		iret = luci.sys.call("ipset add ss_spec_wan_ac " .. s.server .. " 2>/dev/null")
		socket = nixio.socket("inet", "stream")
		socket:setopt("socket", "rcvtimeo", 3)
		socket:setopt("socket", "sndtimeo", 3)
		ret = socket:connect(s.server, s.server_port)
		if tostring(ret) == "true" then
			socket:close()
			retstring = retstring .. "<font color = 'green'>[" .. server_name .. "] OK.</font><br />"
		else
			retstring = retstring .. "<font color = 'red'>[" .. server_name .. "] Error.</font><br />"
		end
		if iret == 0 then
			luci.sys.call("ipset del ss_spec_wan_ac " .. s.server)
		end
	end)
	luci.http.prepare_content("application/json")
	luci.http.write_json({ret = retstring})
end

function check_port()
    local sockets = require 'socket'
    local shadowsocksr = require 'ssr'
    local set = luci.http.formvalue('host')
    local port = luci.http.formvalue('port')
    local retstring = ''
    local t0 = sockets.gettime()
    ret = shadowsocksr.check_site(set, port)
    local t1 = sockets.gettime()
    retstring = tostring(ret) == 'true' and '1' or '0'
    local tt = t1 - t0
    luci.http.prepare_content('application/json')
    luci.http.write_json({ret = retstring, used = math.floor(tt * 1000 + 0.5)})

end


function get_iso(ip)
    local mm = require 'maxminddb'
    local db = mm.open('/usr/share/shadowsocksr/GeoLite2-Country.mmdb')
    local res = db:lookup(ip)
    return string.lower(res:get('country', 'iso_code'))
end

function get_cname(ip)
    local mm = require 'maxminddb'
    local db = mm.open('/usr/share/shadowsocksr/GeoLite2-Country.mmdb')
    local res = db:lookup(ip)
    return string.lower(res:get('country', 'names', 'zh-CN'))
end


-- 检测 当前节点ip 和 网站访问情况
function check_ip()
-- 获取当前的ip和国家
     local e = {}
    local d = {}
    local shadowsocksr = require 'ssr'
    local port = 80
    local ip = shadowsocksr.wget('http://api.ipify.org/')
    d.flag = 'un'
    d.country = 'Unknown'
    if (ip ~= '') then
        local status, code = pcall(get_iso, ip)
        if (status) then
            d.flag = code
        end
        local status1, country = pcall(get_cname, ip)
        if (status1) then
            d.country = country
        end
    end
    e.outboard = ip
    e.outboardip = d
    e.baidu = shadowsocksr.check_site('www.baidu.com', port)
    e.taobao = shadowsocksr.check_site('www.taobao.com', port)
    e.github = shadowsocksr.check_site('www.github.com', port)
    e.google = shadowsocksr.check_site('www.google.com', port)
    e.netflix = shadowsocksr.check_site('www.netflix.com', port)
    e.youtube = shadowsocksr.check_site('www.youtube.com', port)
    
    luci.http.prepare_content('application/json')
    luci.http.write_json(e)
end

-- 获取节点国旗 iso code
function get_flag()
    local e = {}
    local shadowsocksr = require 'ssr'
    local host = luci.http.formvalue('host')
    local remark = luci.http.formvalue('remark')
    e.host = host
    e.flag = shadowsocksr.get_flag(remark, host)
    luci.http.prepare_content('application/json')
    luci.http.write_json(e)
end

function get_log()
	luci.http.write(luci.sys.exec(
		"[ -f '/var/log/ssrplus.log' ] && cat /var/log/ssrplus.log"))
end

function clear_log()
	luci.sys.call("echo '' > /var/log/ssrplus.log")
end

function act_reset()
	luci.sys.call("/etc/init.d/shadowsocksr reset &")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "shadowsocksr"))
end

function act_restart()
	luci.sys.call("/etc/init.d/shadowsocksr restart &")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "shadowsocksr"))
end

function act_delete()
	luci.sys.call("/etc/init.d/shadowsocksr restart &")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "shadowsocksr", "servers"))
end
