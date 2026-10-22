--!strict
-- These guards contain yielding adapters. They cannot preempt an infinite CPU loop.
local Guard = require(script.Parent.Guard)
local Contract = {}
function Contract.Call(callback, ...)
	if type(callback) ~= "function" then return false, "callback_missing" end
	local thread = coroutine.create(callback)
	local result = table.pack(coroutine.resume(thread, ...))
	if not result[1] then return false, tostring(result[2]) end
	if coroutine.status(thread) ~= "dead" then
		coroutine.close(thread)
		return false, "callback_yielded"
	end
	return true, table.unpack(result, 2, result.n)
end
function Contract.State(state)
	if type(state) ~= "table" then return nil end
	local result, count = {}, 0
	for key, value in state do
		count += 1
		if count > 32 or type(key) ~= "string" or #key > 64 then return nil end
		if type(value) == "number" then
			if not Guard.Number(value) or math.abs(value) > 1e12 then return nil end
		elseif type(value) == "string" then
			if #value > 128 then return nil end
		elseif type(value) ~= "boolean" then return nil end
		result[key] = value
	end
	return table.freeze(result)
end
function Contract.SameState(a, b)
	for k, v in a do if b[k] ~= v then return false end end
	for k in b do if a[k] == nil then return false end end
	return true
end
return table.freeze(Contract)
