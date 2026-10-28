-- Four-timestamp exchange bounds offset without pretending RTT/2 is measured one-way latency.
local C = {}
local function finite(x) return type(x)=="number" and x==x and math.abs(x)<math.huge end
function C.Exchange(clientSend,serverReceive,serverSend,clientReceive)
	if not finite(clientSend) or not finite(serverReceive) or not finite(serverSend) or not finite(clientReceive) then return nil,"clock_numeric" end
	if clientReceive<clientSend or serverSend<serverReceive then return nil,"clock_order" end
	local rtt=(clientReceive-clientSend)-(serverSend-serverReceive)
	if rtt<0 then return nil,"clock_order" end
	local lower,upper=serverSend-clientReceive,serverReceive-clientSend
	if not finite(rtt) or not finite(lower) or not finite(upper) or not finite((lower+upper)/2) then return nil,"clock_numeric" end
	return table.freeze({lower=lower,upper=upper,estimate=(lower+upper)/2,uncertainty=(upper-lower)/2,rtt=rtt})
end
function C.Map(bounds,clientTime,maximumAge,serverNow)
	if type(bounds)~="table" or not finite(bounds.lower) or not finite(bounds.upper) or bounds.lower>bounds.upper
		or not finite(clientTime) or not finite(serverNow) or not finite(maximumAge) or maximumAge<0 then return nil,"clock_numeric" end
	local lower,upper=clientTime+bounds.lower,clientTime+bounds.upper
	if upper>serverNow+1e-6 or lower<serverNow-maximumAge then return nil,"clock_out_of_policy" end
	return table.freeze({time=(lower+upper)/2,lower=lower,upper=upper,uncertainty=(upper-lower)/2})
end
return table.freeze(C)
