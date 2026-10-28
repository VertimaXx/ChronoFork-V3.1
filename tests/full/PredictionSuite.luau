-- Seeded synthetic source-time replay, not a claim about native multiplayer fairness.
local Suite={}
function Suite.Run(Motion,seed)
	local report={seed=seed or 20261028,assertions=0,profiles=0,samples=0,failures={},byMotion={},byDelay={},profilesDetail={}}
	local function check(v,why) report.assertions+=1 assert(v,why or "prediction check failed") end
	local function case(name,fn) local ok,why=pcall(fn) if not ok then table.insert(report.failures,{name=name,error=tostring(why)}) end end
	case("straight and rotation",function()
		local m=Motion.New()
		for i=0,10 do check(m:Observe(i/30,CFrame.new(i*16/30,0,0)*CFrame.Angles(0,i/30,0),Vector3.new(16,0,0))) end
		local f,info=m:Predict(10/30+0.2)
		check((f.Position-Vector3.new((10/30+0.2)*16,0,0)).Magnitude<1e-4,"straight exact")
		check(info.trust=="estimate")
		local _,angle=(f.Rotation:ToObjectSpace(CFrame.Angles(0,10/30+0.2,0))):ToAxisAngle()
		check(math.abs(angle)<1e-4,"angular extrapolation")
	end)
	case("invalid, reorder, cap, teleport and idle",function()
		local m=Motion.New() check(not m:Observe(0/0,CFrame.identity))
		check(m:Observe(1,CFrame.identity,Vector3.zero)) check(not m:Observe(1,CFrame.identity,Vector3.zero))
		check(not m:Observe(2,CFrame.identity,Vector3.new(math.huge,0,0)))
		check(m:Observe(1.1,CFrame.new(100,0,0),Vector3.zero))
		local f,info=m:Predict(2) check(f.Position.X==100 and info.status=="capped" and info.epoch>0)
		check(m:Predict(1)==nil) check(m:Predict(0/0)==nil)
		check(m:Observe(2.1,CFrame.new(200,0,0)))
		local reset=m:Predict(2.2) check(reset.Position.X==200,"teleport without velocity must reset")
		local epoch=m.epoch check(not m:Observe(9,CFrame.identity,Vector3.new(math.huge,0,0))) check(m.epoch==epoch,"invalid sample must not mutate")
		m:Reset() check(m:Predict(2)==nil)
	end)
	case("bounded forecasts",function()
		local r=Random.new(1234)
		for i=1,1000 do
			local m=Motion.New() local v=Vector3.new(r:NextNumber(-90,90),0,r:NextNumber(-50,50))
			m:Observe(0,CFrame.identity,v) m:Observe(0.03,CFrame.new(v*0.03),v)
			local f,info=m:Predict(r:NextNumber(0.03,2))
			check((f.Position-v*0.03).Magnitude<=8.0001,"distance cap") check(info.horizon<=0.25)
		end
	end)
	local function p(x,y,z,vx,vy,vz) return Vector3.new(x,y,z),Vector3.new(vx,vy,vz) end
	local motions={
		idle=function(t) return p(0,0,0,0,0,0) end,
		walk=function(t) return p(16*t,0,0,16,0,0) end,
		sprint=function(t) return p(80*t,0,0,80,0,0) end,
		acceleration=function(t) if t<3 then return p(2*t*t,0,0,4*t,0,0) else return p(18+12*(t-3),0,0,12,0,0) end end,
		brake=function(t) if t<2 then return p(16*t,0,0,16,0,0) elseif t<4 then local u=t-2 return p(32+16*u-4*u*u,0,0,16-8*u,0,0) else return p(48,0,0,0,0,0) end end,
		circle=function(t) return p(8*math.sin(2*t),0,8*(1-math.cos(2*t)),16*math.cos(2*t),0,16*math.sin(2*t)) end,
		stopgo=function(t) local n=math.floor(t/0.6) local u=t-n*0.6 local moving=n%2==0 return p(math.ceil(n/2)*9.6+(if moving then u*16 else 0),0,0,if moving then 16 else 0,0,0) end,
		reversal=function(t) local n=math.floor(t/0.8) local u=t-n*0.8 local s=if n%2==0 then 1 else -1 return p((if s==1 then 0 else 12.8)+s*16*u,0,0,s*16,0,0) end,
		zigzag=function(t) local n=math.floor(t/0.7) local u=t-n*0.7 local s=if n%2==0 then 1 else -1 return p(12*t,0,(if s==1 then 0 else 8.4)+s*12*u,12,0,s*12) end,
		jump=function(t) local u=t%1 return p(16*t,12*u*(1-u),0,16,12*(1-2*u),0) end,
		wall=function(t) return p(math.min(24,16*t),0,0,if t<1.5 then 16 else 0,0,0) end,
		dash=function(t) local n=math.floor(t) local u=t-n return p(n*24.8+(if u<0.2 then 60*u else 12+16*(u-0.2)),0,0,if u<0.2 then 60 else 16,0,0) end,
		teleport=function(t) return p(16*t+(if t>=3 then 60 else 0),0,0,16,0,0) end,
		microjitter=function(t) return p(16*t+0.05*math.sin(40*t),0,0,16+2*math.cos(40*t),0,0) end,
		platform=function(t) return p(6*math.sin(2*t),2*math.sin(t),8*t,12*math.cos(2*t),2*math.cos(t),8) end,
	}
	local names={} for name in motions do table.insert(names,name) end table.sort(names)
	-- Irregular, seed-dependent player decisions. These are NOT forecast inputs;
	-- predictors receive only packets that have arrived at the evaluation time.
	local random=Random.new(report.seed)
	for _,kind in {"randomCuts","randomSpeeds","randomCurves"} do
		local trace={} local position=Vector3.zero local velocity=Vector3.new(16,0,0)
		local change,heading,speed=0,0,16
		for step=0,1441 do
			local t=step/240
			if t>=change then
				change=t+random:NextNumber(0.18,0.9) heading=random:NextNumber(-math.pi,math.pi)
				speed=if kind=="randomSpeeds" then random:NextNumber(0,65) else 16
			end
			local target=Vector3.new(math.cos(heading)*speed,0,math.sin(heading)*speed)
			velocity=if kind=="randomCurves" then velocity:Lerp(target,1-math.exp(-1/240/0.15)) else target
			table.insert(trace,{position=position,velocity=velocity}) position+=velocity/240
		end
		motions[kind]=function(t)
			local i=math.min(#trace-1,math.floor(t*240)+1) local alpha=t*240-(i-1)
			return trace[i].position:Lerp(trace[i+1].position,alpha),trace[i].velocity
		end
		table.insert(names,kind)
	end
	local keys={"nativeHold","old100ms","straight250ms","adaptive"}
	local all={} for _,key in keys do all[key]={sum=0,square=0,max=0,errors={}} end
	local function aggregate(container,key,errors)
		local row=container[key] or {count=0,sums={}} container[key]=row
		row.count+=1 for k,e in errors do row.sums[k]=(row.sums[k] or 0)+e end
	end
	for _,name in names do for _,delay in {0,0.05,0.1,0.2,0.35} do for _,jitter in {0,0.05} do for _,loss in {0,0.1,0.3} do for _,hz in {15,30} do
		report.profiles+=1
		local r=Random.new(report.seed+report.profiles*997)
		local model=Motion.New() local packets={} local source=motions[name]
		for i=0,6*hz do
			local t=i/hz local position,velocity=source(t)
			if r:NextNumber()>=loss and not (loss==0.3 and t>2 and t<2.2) then
				table.insert(packets,{t=t,arrival=t+math.max(0,delay+r:NextNumber(-jitter,jitter)),frame=CFrame.new(position),velocity=velocity})
			end
		end
		table.sort(packets,function(a,b) return a.arrival<b.arrival end)
		local cursor,last=1,nil local totals={} for _,k in keys do totals[k]=0 end local count=0
		for step=0,360 do
			local t=step/60
			while cursor<=#packets and packets[cursor].arrival<=t do
				local s=packets[cursor]
				local ok=model:Observe(s.t,s.frame,s.velocity)
				if ok then last=s end cursor+=1
			end
			if last and t>=0.75 then
				local truth=source(t) local age=t-last.t
				local old=last.velocity*math.min(0.1,age) if old.Magnitude>3 then old=Vector3.zero end
				local straight=last.velocity*math.min(0.25,age) if straight.Magnitude>8 then straight=straight.Unit*8 end
				local prediction,info=model:Predict(t)
				local positions={nativeHold=last.frame.Position,old100ms=last.frame.Position+old,straight250ms=last.frame.Position+straight,adaptive=prediction.Position}
				local errors={}
				for _,key in keys do
					local e=(positions[key]-truth).Magnitude local a=all[key]
					a.sum+=e a.square+=e*e a.max=math.max(a.max,e) table.insert(a.errors,e)
					errors[key]=e totals[key]+=e
				end
				aggregate(report.byMotion,name,errors) aggregate(report.byDelay,tostring(delay),errors)
				report.samples+=1 count+=1
				check(info.trust=="estimate" and info.horizon<=0.25,"bounded trust")
			end
		end
		for k,v in totals do totals[k]=v/math.max(1,count) end
		table.insert(report.profilesDetail,{motion=name,delay=delay,jitter=jitter,loss=loss,hz=hz,mean=totals,count=count})
		if report.profiles%3==0 then task.wait() end
	end end end end end
	local function finish(groups)
		for _,row in groups do row.mean={} for k,v in row.sums do row.mean[k]=v/row.count end row.sums=nil end
	end
	finish(report.byMotion) finish(report.byDelay)
	report.summary={}
	for key,a in all do
		table.sort(a.errors)
		report.summary[key]={mean=a.sum/report.samples,rmse=math.sqrt(a.square/report.samples),p95=a.errors[math.ceil(#a.errors*0.95)],max=a.max}
	end
	report.ok=#report.failures==0
	return report
end
return Suite
