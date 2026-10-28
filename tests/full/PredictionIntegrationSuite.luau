-- Real packaged service/config and Entity lifecycle; run in disposable Server Play.
local Suite={}
function Suite.Run(fixture)
	local root=fixture.ChronoFork:Clone() root.Name="ExperimentalPredictionUnitFixture" root.Parent=game.ServerStorage
	local count=0 local function check(v,why) count+=1 assert(v,why or "experimental integration check failed") end
	local ok,result=xpcall(function()
		local C=require(root.Replication.Shared.Config)
		local P=require(root.Replication.Shared.ExperimentalPrediction)
		local e={id=1,generation=1,ownershipRevision=0}
		check(not P.Inspect(e).enabled,"default must be off")
		check(not P.Observe(e,1,CFrame.identity,Vector3.zero))
		local frame,info=P.Estimate(e,1.1) check(frame==nil and info.status=="experimental_disabled")
		for _,key in {"EXPERIMENTAL_PREDICTION_SECONDS","EXPERIMENTAL_PREDICTION_SPEED","EXPERIMENTAL_PREDICTION_GAP"} do
			check(not pcall(C.SetConfig,key,0/0)) check(not pcall(C.SetConfig,key,-1)) check(not pcall(C.SetConfig,key,math.huge))
		end
		check(not pcall(C.SetConfig,"EXPERIMENTAL_PREDICTION_SECONDS",0))
		check(not pcall(C.SetConfig,"EXPERIMENTAL_PREDICTION_SECONDS",1))
		C.SetConfig("EXPERIMENTAL_PREDICTION",true)
		C.SetConfig("PLAYER_REPLICATION","CUSTOM") C.SetConfig("WARNING_SEVERITY","NONE")
		check(P.Observe(e,1,CFrame.identity,Vector3.xAxis,"owner-clock"))
		check(P.Observe(e,1.05,CFrame.new(0.05,0,0),Vector3.xAxis,"owner-clock"))
		frame,info=P.Estimate(e,1.15)
		check(frame and math.abs(frame.X-0.15)<1e-5,"causal source-time forecast")
		check(info.experimental and info.trust=="estimate" and info.clockDomain=="owner-clock")
		check(P.Inspect(e).accepted==2,"persistent per-entity state")
		check(not P.Observe(e,1.04,CFrame.identity,Vector3.xAxis,"owner-clock"))
		check(P.Inspect(e).accepted==2 and P.Inspect(e).rejected==1)
		frame,info=P.EstimateCurrent(e,0.1) check(frame~=nil and info.assumedSourceDelay==0.1)
		check(P.EstimateCurrent(e,-1)==nil)
		e.ownershipRevision+=1 check(P.Estimate(e,1.2)==nil,"revision invalidates before next packet")
		check(P.Observe(e,2,CFrame.new(10,0,0),Vector3.zero,"owner-clock"))
		e.networkOwner={} check(P.Estimate(e,2.1)==nil,"owner invalidates before next packet")
		check(P.Observe(e,3,CFrame.new(20,0,0),Vector3.zero,"server-clock"))
		e.model={} check(P.Estimate(e,3.1)==nil,"model replacement invalidates")
		check(P.Observe(e,4,CFrame.new(30,0,0),Vector3.zero,"server-clock"))
		e.paused=true check(P.Estimate(e,4.1)==nil) e.paused=false
		P.Reset(e) check(not P.Inspect(e).active)
		C._Lock()
		local E=require(root.Replication.Shared.Entity)
		local actual=E.new("DEFAULT",nil,"NATIVE",CFrame.identity)
		E.Push(actual,5,CFrame.identity,Vector3.xAxis)
		E.Push(actual,5.05,CFrame.new(0.05,0,0),Vector3.xAxis)
		local before=actual.latestCFrame local time=actual.latestTime
		frame,info=P.Estimate(actual,5.15) check(frame and frame.X>before.X)
		check(actual.latestCFrame==before and actual.latestTime==time,"prediction contaminated actual position")
		check(E.GetCFrame(actual)==before,"prediction replaced Entity.GetCFrame")
		local accepted=P.Inspect(actual).accepted E._PushStopped(actual,5.08,before)
		check(P.Inspect(actual).accepted==accepted,"inferred stop contaminated predictor")
		E.SetCFrame(actual,CFrame.new(100,0,0)) check(not P.Inspect(actual).active,"teleport reset")
		E.Push(actual,6,CFrame.new(100,0,0),Vector3.zero)
		E.PauseReplication(actual) check(not P.Inspect(actual).active,"pause reset")
		E.ResumeReplication(actual) E.Push(actual,7,CFrame.new(101,0,0),Vector3.zero)
		E.Clear(actual) check(not P.Inspect(actual).active,"clear reset")
		E.Push(actual,8,CFrame.new(102,0,0),Vector3.zero)
		E.Destroy(actual) check(not P.Inspect(actual).active,"destroy reset")
		return {ok=true,assertions=count}
	end,debug.traceback)
	root:Destroy()
	if not ok then error(result) end return result
end
return Suite
