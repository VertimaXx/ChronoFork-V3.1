-- Synthetic delivery schedules. This is NOT a Roblox network simulator result.
local T={}
function T.Run(fixture)
	local shared=fixture.ChronoFork.Replication.Shared local P=require(shared.Protocol) local Gate=require(shared.StateGate)
	local random=Random.new(2026102702) local packets={}
	for i=1,100 do
		local generation=if i>=70 then 2 else 1 local revision=if i>=40 and i<70 then 1 else 0
		local sequence=if i>=70 then i-69 elseif i>=40 then i-39 else i
		local e={id=1,generation=generation,ownershipRevision=revision,_sendSequence=sequence}
		packets[i]=P.Pack({P.Record(e,i/20,CFrame.new(i,0,0),true)})[1]
	end
	local report={scope="synthetic packet delivery and lifecycle replay; not live latency or hit fairness",seed=2026102702,scenarios=0,assertions=0,accepted=0,refused=0,failures={},profiles={}}
	for _,rtt in {0,0.02,0.05,0.1,0.16,0.25,0.4,0.8,1.6} do
	for _,asymmetry in {0.1,0.5,0.9} do
	for _,jitter in {0,0.01,0.04,0.1} do
	for _,loss in {0,0.01,0.05,0.2} do
	for _,burst in {0,0.3} do
		local delay=rtt*asymmetry local delivery={}
		for i,b in packets do if random:NextNumber()>=loss then
			local at=i/20+math.max(0,delay+random:NextNumber(-jitter,jitter))
			if burst>0 and i>=45 and i<=50 then at+=burst end
			table.insert(delivery,{at=at,index=i,packet=b})
		end end
		table.sort(delivery,function(a,b)return if a.at==b.at then a.index<b.index else a.at<b.at end)
		local e={generation=1,ownershipRevision=0} local control=0 local accepted,refused=0,0
		for _,event in delivery do
			-- Reliable ownership/lifetime notification can arrive AFTER new state.
			if event.at>=2+delay+0.08 and control==0 then e.ownershipRevision=1 e._receivedSequence=nil control=1 end
			if event.at>=3.5+delay+0.08 and control<2 then e.generation=2 e.ownershipRevision=0 e._receivedSequence=nil control=2 end
			local row=assert(P.Decode(event.packet))[1]
			local ok=Gate.Check(e,row)
			if ok then
				local previous=e._receivedSequence
				assert(row.generation==e.generation and row.ownershipRevision==e.ownershipRevision,"crossed lifecycle boundary")
				assert(previous==nil or row.sequence>previous,"accepted stale sequence")
				e._receivedSequence=row.sequence accepted+=1 report.assertions+=2
			else refused+=1 end
		end
		report.scenarios+=1 report.accepted+=accepted report.refused+=refused
		table.insert(report.profiles,{rtt=rtt,asymmetry=asymmetry,jitter=jitter,loss=loss,burst=burst,accepted=accepted,refused=refused})
		if report.scenarios%40==0 then task.wait() end
	end end end end end
	report.ok=true return report
end
return T
