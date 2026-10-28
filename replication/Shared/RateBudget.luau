-- Elapsed-time budgets do not give a low-FPS sender a different allowance.
local B = {}
function B.New(rate, burst, now)
	assert(type(rate)=="number" and rate > 0 and rate < math.huge and type(burst)=="number" and burst > 0 and burst < math.huge
		and type(now)=="number" and now==now and math.abs(now)<math.huge)
	return {rate = rate, burst = burst, credit = burst, time = now}
end
function B.Allow(b, cost, now)
	if type(cost) ~= "number" or cost ~= cost or cost < 0 or cost == math.huge then return false end
	if type(now) ~= "number" or now ~= now or math.abs(now) == math.huge or now < b.time then return false end
	b.credit = math.min(b.burst, b.credit + (now - b.time) * b.rate)
	b.time = now
	if b.credit < cost then return false end
	b.credit -= cost
	return true
end
return table.freeze(B)
