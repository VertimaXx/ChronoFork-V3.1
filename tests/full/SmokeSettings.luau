local F=require(script.Parent)
local config=F.Config
config.SetConfig("PLAYER_REPLICATION","CUSTOM")
config.SetConfig("WARNING_SEVERITY","NONE")
config.SetConfig("CHECK_NEW_VERSION",false)
if F.Version then config.SetConfig("VISUAL_CURVE","SEGMENT") end
if F.Experimental and script.Parent:GetAttribute("TestExperimentalPrediction") then
	config.SetConfig("EXPERIMENTAL_PREDICTION",true)
	config.SetConfig("EXPERIMENTAL_PREDICTION_DRAW",true)
	config.SetConfig("EXPERIMENTAL_PREDICTION_LEAD",0.15)
end
config.RegisterEntityType("SMOKE",{TICK_RATE=1/30,BUFFER=0.09,FULL_ROTATION=true,STORE_SNAPSHOTS=true,MODEL_REPLICATION_MODE="NATIVE",NORMAL_TICK_DISTANCE=10000,HALF_TICK_DISTANCE=10000})
local template=Instance.new("Part") template.Name="SmokeTemplate" template.CanCollide=false template.Anchored=true
config.RegisterEntityModel("SmokeTemplate",template)
return true
