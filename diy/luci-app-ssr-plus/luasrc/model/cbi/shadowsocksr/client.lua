-- Copyright (C) 2017 yushi studio <ywb94@qq.com> github.com/ywb94
-- Copyright (C) 2018 lean <coolsnowwolf@gmail.com> github.com/coolsnowwolf
-- Licensed to the public under the GNU General Public License v3.

local m, s, sec, o
local uci = luci.model.uci.cursor()
local gfw_count=0
local ad_count=0
local ip_count=0
local gfwmode=0
local nfip_count=0
local uci = luci.model.uci.cursor()
local sys = require "luci.sys"

if nixio.fs.access("/etc/ssrplus/gfw_list.conf") then
	gfw_count = tonumber(luci.sys.exec("cat /etc/ssrplus/gfw_list.conf | wc -l")) / 2
end

if nixio.fs.access("/etc/ssrplus/ad.conf") then
	ad_count = tonumber(luci.sys.exec("cat /etc/ssrplus/ad.conf | wc -l"))
end

if nixio.fs.access("/etc/ssrplus/china_ssr.txt") then
	ip_count = tonumber(luci.sys.exec("cat /etc/ssrplus/china_ssr.txt | wc -l"))
end

if nixio.fs.access("/etc/ssrplus/netflixip.list") then
	nfip_count = tonumber(luci.sys.exec("cat /etc/ssrplus/netflixip.list | wc -l"))
end


local validation = require "luci.cbi.datatypes"
local function is_finded(e)
	return luci.sys.exec('type -t -p "%s"' % e) ~= "" and true or false
end

m = Map("shadowsocksr", translate("<strong><font color=\"#7bcfa6\">ShadowSocksrR Plus+</font></strong>"))
m:section(SimpleSection).template = "shadowsocksr/status"


local server_table = {}
uci:foreach("shadowsocksr", "servers", function(s)
	if s.alias then
		server_table[s[".name"]] = "[%s]:%s" % {string.upper(s.xray_protocol or s.type), s.alias}
	elseif s.server and s.server_port then
		server_table[s[".name"]] = "[%s]:%s:%s" % {string.upper(s.xray_protocol or s.type), s.server, s.server_port}
	end
end)

local key_table = {}
for key, _ in pairs(server_table) do
	table.insert(key_table, key)
end

table.sort(key_table)

-- [[ Global Setting ]]--
s = m:section(TypedSection, "global")
s.anonymous = true

s:tab("Main", translate("Main"))

o = s:taboption("Main", ListValue,  "global_server", translate("Main Server"))
o:value("nil", translate("Disable"))
for _, key in pairs(key_table) do
	o:value(key, server_table[key])
end
o.default = "nil"
o.rmempty = false

o = s:taboption("Main", ListValue,  "udp_relay_server", translate("Game Mode UDP Server"))
o:value("", translate("Disable"))
o:value("same", translate("Same as Global Server"))
for _, key in pairs(key_table) do
	o:value(key, server_table[key])
end

if uci:get_first("shadowsocksr", 'global', 'netflix_enable', '0') == '1' then
o = s:taboption("Main", ListValue,  "netflix_server", translate("Netflix Node"))
o:value("nil", translate("Disable"))
o:value("same", translate("Same as Global Server"))
for _, key in pairs(key_table) do
	o:value(key, server_table[key])
end
o.default = "nil"
o.rmempty = false

o = s:taboption("Main", Flag, "netflix_proxy", translate("External Proxy Mode"))
o.rmempty = false
o.description = translate("Forward Netflix Proxy through Main Proxy")
o.default = "0"
end

o = s:taboption("Main", ListValue,  "threads", translate("Multi Threads Option"))
o:value("0", translate("Auto Threads"))
o:value("1", translate("1 Thread"))
o:value("2", translate("2 Threads"))
o:value("4", translate("4 Threads"))
o:value("8", translate("8 Threads"))
o:value("16", translate("16 Threads"))
o:value("32", translate("32 Threads"))
o:value("64", translate("64 Threads"))
o:value("128", translate("128 Threads"))
o.default = "0"
o.rmempty = false

o = s:taboption("Main", ListValue,  "run_mode", translate("Running Mode"))
o:value("gfw", translate("GFW List Mode"))
o:value("router", translate("IP Route Mode"))
o:value("all", translate("Global Mode"))
o:value("oversea", translate("Oversea Mode"))
o.default = gfw

o = s:taboption("Main", ListValue,  "dports", translate("Proxy Ports"))
o:value("1", translate("All Ports"))
o:value("2", translate("Only Common Ports"))
o:value("3", translate("Custom Ports"))
cp = s:option(Value, "custom_ports", translate("Enter Custom Ports"))
cp:depends("dports", "3")  -- 仅当用户选择“Custom Ports”时显示
cp.placeholder = "e.g., 80,443,8080"
o.default = 1

o = s:taboption("Main", ListValue,  "pdnsd_enable", translate("Resolve Dns Mode"))
o:value("1", translate("Use DNS2TCP query"))
o:value("2", translate("Use DNS2SOCKS query and cache"))
if is_finded("mosdns") then
o:value("3", translate("Use MOSDNS query (Not Support Oversea Mode)"))
end
o:value("0", translate("Use Local DNS Service listen port 5335"))
o.default = 1

o = s:taboption("Main", Value, "tunnel_forward", translate("Anti-pollution DNS Server"))
o:value("8.8.4.4:53", translate("Google Public DNS (8.8.4.4)"))
o:value("8.8.8.8:53", translate("Google Public DNS (8.8.8.8)"))
o:value("208.67.222.222:53", translate("OpenDNS (208.67.222.222)"))
o:value("208.67.220.220:53", translate("OpenDNS (208.67.220.220)"))
o:value("209.244.0.3:53", translate("Level 3 Public DNS (209.244.0.3)"))
o:value("209.244.0.4:53", translate("Level 3 Public DNS (209.244.0.4)"))
o:value("4.2.2.1:53", translate("Level 3 Public DNS (4.2.2.1)"))
o:value("4.2.2.2:53", translate("Level 3 Public DNS (4.2.2.2)"))
o:value("4.2.2.3:53", translate("Level 3 Public DNS (4.2.2.3)"))
o:value("4.2.2.4:53", translate("Level 3 Public DNS (4.2.2.4)"))
o:value("1.1.1.1:53", translate("Cloudflare DNS (1.1.1.1)"))
o:value("114.114.114.114:53", translate("Oversea Mode DNS-1 (114.114.114.114)"))
o:value("114.114.115.115:53", translate("Oversea Mode DNS-2 (114.114.115.115)"))
o:depends("pdnsd_enable", "1")
o:depends("pdnsd_enable", "2")
o.description = translate("Custom DNS Server format as IP:PORT (default: 8.8.4.4:53)")
o.datatype = "ip4addrport"

o = s:taboption("Main", ListValue,  "tunnel_forward_mosdns", translate("Anti-pollution DNS Server"))
o:value("tcp://8.8.4.4:53,tcp://8.8.8.8:53", translate("Google Public DNS"))
o:value("tcp://208.67.222.222:53,tcp://208.67.220.220:53", translate("OpenDNS"))
o:value("tcp://209.244.0.3:53,tcp://209.244.0.4:53", translate("Level 3 Public DNS-1 (209.244.0.3-4)"))
o:value("tcp://4.2.2.1:53,tcp://4.2.2.2:53", translate("Level 3 Public DNS-2 (4.2.2.1-2)"))
o:value("tcp://4.2.2.3:53,tcp://4.2.2.4:53", translate("Level 3 Public DNS-3 (4.2.2.3-4)"))
o:value("tcp://1.1.1.1:53,tcp://1.0.0.1:53", translate("Cloudflare DNS"))
o:depends("pdnsd_enable", "3")
o.description = translate("Custom DNS Server for mosdns")

o = s:taboption("Main", Flag, "mosdns_ipv6", translate("Disable IPv6 in MOSDNS query mode"))
o:depends("pdnsd_enable", "3")
o.rmempty = false
o.default = "0"

if is_finded("chinadns-ng") then
	o = s:taboption("Main", ListValue,   "chinadns_forward", translate("Domestic DNS Server"))
	o:value("", translate("Disable ChinaDNS-NG"))
	o:value("wan", translate("Use DNS from WAN"))
	o:value("wan_114", translate("Use DNS from WAN and 114DNS"))
	o:value("114.114.114.114:53", translate("Nanjing Xinfeng 114DNS (114.114.114.114)"))
	o:value("119.29.29.29:53", translate("DNSPod Public DNS (119.29.29.29)"))
	o:value("223.5.5.5:53", translate("AliYun Public DNS (223.5.5.5)"))
	o:value("180.76.76.76:53", translate("Baidu Public DNS (180.76.76.76)"))
	o:value("101.226.4.6:53", translate("360 Security DNS (China Telecom) (101.226.4.6)"))
	o:value("123.125.81.6:53", translate("360 Security DNS (China Unicom) (123.125.81.6)"))
	o:value("1.2.4.8:53", translate("CNNIC SDNS (1.2.4.8)"))
	o:depends({pdnsd_enable = "1", run_mode = "router"})
	o:depends({pdnsd_enable = "2", run_mode = "router"})
	o.description = translate("Custom DNS Server format as IP:PORT (default: disabled)")
	o.validate = function(self, value, section)
		if (section and value) then
			if value == "wan" or value == "wan_114" then
				return value
			end

			if validation.ip4addrport(value) then
				return value
			end

			return nil, translate("Expecting: %s"):format(translate("valid address:port"))
		end

		return value
	end
end

s:tab("Shunt", translate("Shunt"))


o = s:taboption("Shunt", ListValue, "netflix_server", translate("Netflix Node"))
o:value("nil", translate("Disable"))
o:value("same", translate("Same as Global Server"))
for _,key in pairs(key_table) do o:value(key,server_table[key]) end
o.default = "nil"
o.rmempty = false
o.description = ("<font color='auburn'>" ..translate("Support all types of diversion").."</font>")

o = s:taboption("Shunt", Flag, "netflix_proxy", translate("External Proxy Mode"))
o.rmempty = false
o.description = ("<font color='auburn'>" ..translate("Forward Netflix Proxy through Main Proxy").."</font>")
o.default="0"

s:tab("Update", translate("Update"))

o = s:taboption("Update",Button,"google",translate("Google Connectivity"))
o.value = translate("No Check")
o.template = "shadowsocksr/check"

o = s:taboption("Update",Button,"baidu",translate("Baidu Connectivity"))
o.value = translate("No Check")
o.template = "shadowsocksr/check"

o = s:taboption("Update",Button,"gfw_data",translate("GFW List Data"))
o.rawhtml  = true
o.template = "shadowsocksr/refresh"
o.value =tostring(math.ceil(gfw_count)) .. " " .. translate("Records")

o = s:taboption("Update",Button,"ad_data",translate("Advertising Data")) 
o .rawhtml  = true
o .template = "shadowsocksr/refresh"
o .value =tostring(math.ceil(ad_count)) .. " " .. translate("Records")

o = s:taboption("Update",Button,"ip_data",translate("China IP Data"))
o.rawhtml  = true
o.template = "shadowsocksr/refresh"
o.value =ip_count .. " " .. translate("Records")

o = s:taboption("Update",Button,"nfip_data",translate("Netflix IP Data"))
o.rawhtml = true
o.template = "shadowsocksr/refresh"
o.value = nfip_count .. " " .. translate("Records")

o = s:taboption("Update",Button,"check_port",translate("Check Server Port"))
o.template = "shadowsocksr/checkport"
o.value =translate("No Check")

s = m:section(TypedSection, "socks5_proxy")
s.anonymous = true

s:tab("socks5", translate("Socks5 Proxy"))

o = s:taboption("socks5",ListValue, "server", translate("Socks5 Server"))
o:value("nil", translate("Disable"))
o:value("same", translate("Same as Global Server"))
for _,key in pairs(key_table) do o:value(key,server_table[key]) end
o.default = "nil"
o.rmempty = false

o = s:taboption("socks5",Value, "local_port", translate("Local Port"))
o.datatype = "port"
o.default = 1082
o.rmempty = false

-- [[ HTTP Proxy ]]--
if nixio.fs.access("/usr/sbin/privoxy") then
o = s:taboption("socks5",Flag, "http_enable", translate("Enable HTTP Proxy"))
o.rmempty = false

o = s:taboption("socks5",Value, "http_port", translate("Proxy Port"))
o.datatype = "port"
o.default = 1083
o.rmempty = false
end

s:tab("advanced", translate("Advanced Settings"), translate("<h3>Server failsafe auto swith and custom update settings</h3>"))

o = s:taboption("advanced", Flag, "enable_switch", translate("Enable Auto Switch"))
o.rmempty = false
o.default = "1"

o = s:taboption("advanced", Value, "switch_time", translate("Switch check cycly(second)"))
o.datatype = "uinteger"
o:depends("enable_switch", "1")
o.default = 667

o = s:taboption("advanced", Value, "switch_timeout", translate("Check timout(second)"))
o.datatype = "uinteger"
o:depends("enable_switch", "1")
o.default = 5

o = s:taboption("advanced", Value, "switch_try_count", translate("Check Try Count"))
o.datatype = "uinteger"
o:depends("enable_switch", "1")
o.default = 3

o = s:taboption("advanced", Value, "gfwlist_url", translate("gfwlist Update url"))
o:value("https://fastly.jsdelivr.net/gh/YW5vbnltb3Vz/domain-list-community@release/gfwlist.txt", translate("v2fly/domain-list-community"))
o:value("https://fastly.jsdelivr.net/gh/Loyalsoldier/v2ray-rules-dat@release/gfw.txt", translate("Loyalsoldier/v2ray-rules-dat"))
o:value("https://fastly.jsdelivr.net/gh/Loukky/gfwlist-by-loukky/gfwlist.txt", translate("Loukky/gfwlist-by-loukky"))
o:value("https://fastly.jsdelivr.net/gh/gfwlist/gfwlist/gfwlist.txt", translate("gfwlist/gfwlist"))
o.default = "https://fastly.jsdelivr.net/gh/YW5vbnltb3Vz/domain-list-community@release/gfwlist.txt"

o = s:taboption("advanced", Value, "chnroute_url", translate("Chnroute Update url"))
o:value("https://ispip.clang.cn/all_cn.txt", translate("Clang.CN"))
o:value("https://ispip.clang.cn/all_cn_cidr.txt", translate("Clang.CN.CIDR"))
o:value("https://fastly.jsdelivr.net/gh/gaoyifan/china-operator-ip@ip-lists/china.txt", translate("china-operator-ip"))
o.default = "https://ispip.clang.cn/all_cn.txt"

o = s:taboption("advanced", Flag, "netflix_enable", translate("Enable Netflix Mode"))
o.rmempty = false

o = s:taboption("advanced", Value, "nfip_url", translate("nfip_url"))
o:value("https://fastly.jsdelivr.net/gh/QiuSimons/Netflix_IP/NF_only.txt", translate("Netflix IP Only"))
o:value("https://fastly.jsdelivr.net/gh/QiuSimons/Netflix_IP/getflix.txt", translate("Netflix and AWS"))
o.default = "https://fastly.jsdelivr.net/gh/QiuSimons/Netflix_IP/NF_only.txt"
o.description = translate("Customize Netflix IP Url")
o:depends("netflix_enable", "1")

o = s:taboption("advanced", ListValue, "shunt_dns_mode", translate("DNS Query Mode For Shunt Mode"))
o:value("1", translate("Use DNS2SOCKS query and cache"))
o:value("2", translate("Use MOSDNS query"))
o:depends("netflix_enable", "1")
o.default = 1

o = s:taboption("advanced", Value, "shunt_dnsserver", translate("Anti-pollution DNS Server For Shunt Mode"))
o:value("8.8.4.4:53", translate("Google Public DNS (8.8.4.4)"))
o:value("8.8.8.8:53", translate("Google Public DNS (8.8.8.8)"))
o:value("208.67.222.222:53", translate("OpenDNS (208.67.222.222)"))
o:value("208.67.220.220:53", translate("OpenDNS (208.67.220.220)"))
o:value("209.244.0.3:53", translate("Level 3 Public DNS (209.244.0.3)"))
o:value("209.244.0.4:53", translate("Level 3 Public DNS (209.244.0.4)"))
o:value("4.2.2.1:53", translate("Level 3 Public DNS (4.2.2.1)"))
o:value("4.2.2.2:53", translate("Level 3 Public DNS (4.2.2.2)"))
o:value("4.2.2.3:53", translate("Level 3 Public DNS (4.2.2.3)"))
o:value("4.2.2.4:53", translate("Level 3 Public DNS (4.2.2.4)"))
o:value("1.1.1.1:53", translate("Cloudflare DNS (1.1.1.1)"))
o:depends("shunt_dns_mode", "1")
o.description = translate("Custom DNS Server format as IP:PORT (default: 8.8.4.4:53)")
o.datatype = "ip4addrport"

o = s:taboption("advanced", ListValue, "shunt_mosdns_dnsserver", translate("Anti-pollution DNS Server"))
o:value("tcp://8.8.4.4:53,tcp://8.8.8.8:53", translate("Google Public DNS"))
o:value("tcp://208.67.222.222:53,tcp://208.67.220.220:53", translate("OpenDNS"))
o:value("tcp://209.244.0.3:53,tcp://209.244.0.4:53", translate("Level 3 Public DNS-1 (209.244.0.3-4)"))
o:value("tcp://4.2.2.1:53,tcp://4.2.2.2:53", translate("Level 3 Public DNS-2 (4.2.2.1-2)"))
o:value("tcp://4.2.2.3:53,tcp://4.2.2.4:53", translate("Level 3 Public DNS-3 (4.2.2.3-4)"))
o:value("tcp://1.1.1.1:53,tcp://1.0.0.1:53", translate("Cloudflare DNS"))
o:depends("shunt_dns_mode", "2")
o.description = translate("Custom DNS Server for mosdns")

o = s:taboption("advanced", Flag, "shunt_mosdns_ipv6", translate("Disable IPv6 In MOSDNS Query Mode (Shunt Mode)"))
o:depends("shunt_dns_mode", "2")
o.rmempty = false
o.default = "0"

o = s:taboption("advanced", Flag, "adblock", translate("Enable adblock"))
o.rmempty = false

o = s:taboption("advanced", Value, "adblock_url", translate("adblock_url"))
o:value("https://raw.githubusercontent.com/neodevpro/neodevhost/master/lite_dnsmasq.conf", translate("NEO DEV HOST Lite"))
o:value("https://raw.githubusercontent.com/neodevpro/neodevhost/master/dnsmasq.conf", translate("NEO DEV HOST Full"))
o:value("https://anti-ad.net/anti-ad-for-dnsmasq.conf", translate("anti-AD"))
o.default = "https://raw.githubusercontent.com/neodevpro/neodevhost/master/lite_dnsmasq.conf"
o:depends("adblock", "1")
o.description = translate("Support AdGuardHome and DNSMASQ format list")

o = s:taboption("advanced", Button, "reset", translate("Reset to defaults"))
o.rawhtml = true
o.template = "shadowsocksr/reset"

return m


