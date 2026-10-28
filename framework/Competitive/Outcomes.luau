-- A server-owned action/contact key is reserved before invoking game code.
-- An exception is ambiguous: never retry a possibly partially applied outcome automatically.
local O={} O.__index=O
function O.new(capacity)
	capacity=capacity or 4096 assert(type(capacity)=="number" and capacity%1==0 and capacity>=1 and capacity<=65536)
	return setmetatable({capacity=capacity,rows={},count=0},O)
end
function O:Apply(key,expires,now,callback)
	assert(type(key)=="string" and #key>0 and #key<=256 and type(callback)=="function")
	assert(type(now)=="number" and now==now and type(expires)=="number" and expires>now and expires-now<=30)
	assert(math.abs(now)<math.huge and math.abs(expires)<math.huge)
	for id,row in self.rows do if now>=row.expires then self.rows[id]=nil self.count-=1 end end
	local previous=self.rows[key]
	if previous then return false,if previous.status=="applied" then "already_applied" else "outcome_ambiguous" end
	if self.count>=self.capacity then return false,"outcome_capacity" end
	local record={status="pending",expires=expires} self.rows[key]=record self.count+=1
	local thread=coroutine.create(callback) local ok,value=coroutine.resume(thread,key)
	if not ok or coroutine.status(thread)~="dead" then
		if coroutine.status(thread)~="dead" then coroutine.close(thread) end
		record.status="ambiguous" return false,"outcome_ambiguous"
	end
	if value~=true then record.status="ambiguous" return false,"outcome_not_confirmed" end
	record.status="applied" return true,"applied"
end
function O:Inspect(key) local row=self.rows[key] return row and row.status end
return O
