--local bit = require("bit")
--local netutil = require("netutil")
local client_sock = ngx.socket.tcp()
client_sock:settimeout(5000,1000,3000)

local use_log = true 

local tohex = function(str)
	local i = 1
	local len = string.len(str)
	local outstring = ""
	while i <= len and i < 4096 do
		outstring = outstring .. string.format("%02X",tostring(string.byte(str,i)))
		i = i + 1
	end
	return outstring
end

local data = "hello world 1234567890"
local data_len = string.len(data)
local data_len_h = netutil.htonl(data_len)
local req_data = netutil.packint32(data_len_h) .. data


local upstream_test = function(u)
	local ret,err = u:connect("127.0.0.1",8000,"127.0.0.1_8000_1");
	--local ret,err = u:connect("localhost",8000,3000);
	local reuse = u:getreusedtimes()
	if use_log then ngx.log(ngx.INFO,"connect : "..tostring(ret).." "..tostring(err).." "..tostring(reuse)) end
	if not ret then 
		return
	end

	ret,err = u:send(req_data)
	if use_log then ngx.log(ngx.INFO,"send : "..tostring(ret).." "..tostring(err)) end

	if not ret then
		return
	end
	
	local data,err = u:receive(4,nil)
	if use_log then ngx.log(ngx.INFO,"receive : "..tostring(data).." "..tostring(err)) end
	if not data then
		return
	end
	if use_log then ngx.log(ngx.INFO,"receive head data : ["..tohex(data).."]") end
	
	local totoal_len = netutil.unpackint32(string.sub(data,1,4))
	if use_log then ngx.log(ngx.INFO,"totoal_len : "..tostring(totoal_len)) end
	
	local data,err = u:receive(totoal_len - 4,nil)
	if use_log then	ngx.log(ngx.INFO,"receive again: ["..tostring(data).."] "..tostring(err)) end
	if not data then
		return
	end
	
	if totoal_len - 4 ~= #data then
		ngx.log(ngx.INFO,"receive len not match")
		return
	end
	u:setkeepalive()
end

local test_shm = function()
	local key = "x"
	local value = "hello world"
	local dogs = ngx.shared.db_lock
	local shm_value = dogs:get(key)
	if not shm_value then
		local succ, err, forcible = dogs:set(key,value,10000)
		if use_log then ngx.log(ngx.INFO,tostring(succ)..","..tostring(err)..","..tostring(forcible)) end
	end
	local shm_value = dogs:get(key)
	if use_log then ngx.log(ngx.INFO,tostring(shm_value)) end
end

while true do
	local data,r2,r3 = ngx.receive(10,6)
	--ngx.say(collectgarbage("count"))
	ngx.say("receive ret "..tostring(data).." "..tostring(r2).." "..tostring(r3) .. ","..collectgarbage("count"))
	if not data then
			ngx.say("exit")
			ngx.exit()
	end

	--ngx.sleep(5)
	
	--upstream_test(client_sock)

	test_shm()
	
	--collectgarbage()
	
	ngx.wait_next_request()
end
