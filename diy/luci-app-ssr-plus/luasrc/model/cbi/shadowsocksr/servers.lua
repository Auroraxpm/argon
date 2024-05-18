-- Licensed to the public under the GNU General Public License v3.
require "luci.http"
require "luci.dispatcher"
require "luci.model.uci"
local m, s , o
local shadowsocksr= "shadowsocksr"
local cjson = require("cjson") 
local uci = luci.model.uci.cursor()
local server_count = 0
local server_table = {}
uci:foreach("shadowsocksr", "servers", function(s)
    server_count = server_count + 1
    s["name"] = s[".name"]
    table.insert(server_table, s)
end)
local name = ""
uci:foreach("shadowsocksr", "global", function(s) name = s[".name"] end)
m = Map("shadowsocksr")
m:section(SimpleSection).template = "shadowsocksr/status"

-- [[ Servers Manage ]]--
s = m:section(TypedSection, "servers")
s.anonymous = true
s.addremove = true
s.template = "cbi/tblsection"
s.sortable = true
s.des = server_count
s.current = uci:get("shadowsocksr", name, "global_server")
s.servers = cjson.encode(server_table)
s.template = "shadowsocksr/tblsection"
s.extedit = luci.dispatcher.build_url("admin", "services", "shadowsocksr", "servers", "%s")
function s.create(...)
	local sid = TypedSection.create(...)
	if sid then
		luci.http.redirect(s.extedit % sid)
		return
	end
end

o = s:option(DummyValue, "type", translate("Type"))
function o.cfgvalue(self, section)
	return m:get(section, "xray_protocol") or Value.cfgvalue(self, section) or translate("None")
end

o = s:option(DummyValue, "alias", translate("Alias"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or translate("None")
end

o = s:option(DummyValue, "server_port", translate("Server Port"))
function o.cfgvalue(...)
	return Value.cfgvalue(...) or "N/A"
end

o = s:option(DummyValue, "server_port", translate("Socket Connected"))
o.template = "shadowsocksr/socket"
o.width = "10%"

o = s:option(DummyValue, "server", translate("Ping Latency"))
o.template = "shadowsocksr/ping"
o.width = "10%"

node = s:option(Button, "apply_node", translate("Apply"))
node.inputstyle = "apply"
node.write = function(self, section)
	uci:set("shadowsocksr", '@global[0]', 'global_server', section)
	uci:save("shadowsocksr")
	uci:commit("shadowsocksr")
	luci.http.redirect(luci.dispatcher.build_url("admin", "services", "shadowsocksr", "restart"))
end

o = s:option(Flag, "switch_enable", translate("Auto Switch"))
o.rmempty = false
function o.cfgvalue(...)
	return Value.cfgvalue(...) or 1
end
m:append(Template("shadowsocksr/server_list"))
m:section(SimpleSection).template  = "shadowsocksr/status_bottom"
return m