-- A replicated parent can arrive before its descendants. Wait for explicit paths,
-- not a descendant count that unrelated dynamically created objects could satisfy.
local A={}
function A.Ready(root,timeout)
	local deadline=os.clock()+(timeout or 30)
	local descriptor=root:WaitForChild("ReadyPaths",timeout or 30)
	assert(descriptor and descriptor:IsA("StringValue"),"ChronoFork package is incomplete: ReadyPaths is missing")
	while #descriptor.Value==0 do assert(os.clock()<deadline,"ChronoFork path list did not arrive") task.wait() end
	local paths=game:GetService("HttpService"):JSONDecode(descriptor.Value)
	assert(type(paths)=="table" and #paths>0 and #paths<=4096,"Invalid ChronoFork package path list")
	for _,path in paths do
		assert(type(path)=="string" and #path<=512,"Invalid package path")
		local object=root
		for segment in path:gmatch("[^/]+") do
			local child=object:FindFirstChild(segment)
			while not child do
				assert(os.clock()<deadline,"ChronoFork package is incomplete: "..path)
				task.wait() child=object:FindFirstChild(segment)
			end
			object=child
		end
	end
	return true
end
return table.freeze(A)
