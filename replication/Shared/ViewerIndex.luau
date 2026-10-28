-- Conservative X/Z buckets for finite-range custom/locked replication.
-- Native models and infinite ranges retain original all-viewer behavior.
local I={} I.__index=I
function I.new(cell) assert(type(cell)=="number" and cell>0 and cell<math.huge) return setmetatable({cell=cell,all={},buckets={}},I) end
local function key(x,z) return tostring(x)..":"..tostring(z) end
function I:Rebuild(positions)
	self.all=table.clone(positions) self.buckets={}
	for holder,p in self.all do
		local address=key(math.floor(p.x/self.cell),math.floor(p.z/self.cell))
		local bucket=self.buckets[address] if not bucket then bucket={} self.buckets[address]=bucket end bucket[holder]=p
	end
end
function I:Query(center,radius)
	if radius==math.huge then return table.clone(self.all) end
	local loX,hiX=math.floor((center.x-radius)/self.cell),math.floor((center.x+radius)/self.cell)
	local loZ,hiZ=math.floor((center.z-radius)/self.cell),math.floor((center.z+radius)/self.cell)
	if (hiX-loX+1)*(hiZ-loZ+1)>4096 then return table.clone(self.all) end
	local result={}
	for x=loX,hiX do for z=loZ,hiZ do
		for holder,p in self.buckets[key(x,z)] or {} do result[holder]=p end
	end end
	return result
end
return I
