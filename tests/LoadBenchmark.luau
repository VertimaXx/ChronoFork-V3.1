-- Full contact-service CPU cost with one sphere per actor; no world provider.
-- One query per fresh server-authorized action, zero contacts; five batches per size.
return function(Core)
	local API=require(Core) local S=API.Shapes local report={}
	for _,count in {16,32,64,128,256} do
		local service=API.new({clock=function() return 100 end})
		for i=1,count do
			local p=if i==1 then Vector3.zero else Vector3.new(i*5,0,-10)
			service:Track(tostring(i),{kind="actor",trust="serverSimulated",maxSpeed=100,maxRadius=2,capture=function()
				return {root=CFrame.new(p),zones={body=S.Sphere(CFrame.new(p),1)},state={active=true}}
			end})
		end
		service:Capture()
		local profile={shape=S.Sphere(CFrame.new(0,0,-3),2),targets={"actor"},closes=1}
		local samples={}
		for batch=1,5 do
			local start=os.clock()
			for _=1,250 do local a=assert(service:BeginAction("1",profile)) assert(service:Query(a).ok) service:EndAction(a) end
			table.insert(samples,(os.clock()-start)/250*1e6) task.wait()
		end
		table.sort(samples) table.insert(report,{actors=count,iterations=1250,medianBatchUs=samples[3],minBatchUs=samples[1],maxBatchUs=samples[5]})
		service:Destroy()
	end
	return report
end
