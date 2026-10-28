-- Server-owned conflict tokens for possession, rounds and move state.
-- Reserve the next revision BEFORE callbacks; a partial failure stays reserved.
local V={} V.__index=V
function V.new(initial)
	initial=initial or 0 assert(type(initial)=="number" and initial%1==0 and initial>=0 and initial<9007199254740991)
	return setmetatable({revision=initial,busy=false,ambiguous=false},V)
end
function V:Get() return self.revision end
function V:Apply(expected,callback)
	if self.busy or self.ambiguous then return false,"state_ambiguous" end
	if expected~=self.revision then return false,"state_changed" end
	assert(type(callback)=="function" and self.revision<9007199254740991)
	self.revision+=1 self.busy=true
	local thread=coroutine.create(callback) local ok,confirmed=coroutine.resume(thread,self.revision)
	local finished=coroutine.status(thread)=="dead"
	if not finished then coroutine.close(thread) end self.busy=false
	if not ok or not finished or confirmed~=true then self.ambiguous=true return false,"state_ambiguous" end
	return true,self.revision
end
-- Recovery is an explicit server reconciliation, never a client request/retry.
function V:Reconcile() assert(not self.busy and self.revision<9007199254740991) self.ambiguous=false self.revision+=1 return self.revision end
return V
