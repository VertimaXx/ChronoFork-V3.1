-- One supplied connection layer for the original-compatible replication service.
local B={}
local run=game:GetService("RunService")
local active=setmetatable({}, {__mode="k"})
function B.Start(root)
	assert(not active[root],"This package is already connected")
	local F=require(root) local settings=require(root.Settings)
	local handles={} local entities={} local origins={} local stopped=false
	local function connect(signal,callback) local c=signal:Connect(callback) table.insert(handles,c) return c end
	local state={runtime=F,entities=entities}
	active[root]=state
	if settings.mode=="Engine" then
		local hook=require(root.Hooks)
		local binding=F.Competitive.Simulation.Bind(hook.Simulate,{engineAuthority=settings.engineConfirmed})
		table.insert(handles,binding)
	else
		local config=F.Config
		for name in config.FLAGS do if settings[name]~=nil then config.FLAGS[name]=settings[name] end end
		local values={PLAYER_REPLICATION=if settings.players then "AUTOMATIC" else "CUSTOM",
			EXPERIMENTAL_PREDICTION=settings.experimentalPrediction,
			EXPERIMENTAL_PREDICTION_DRAW=settings.experimentalDraw,
			EXPERIMENTAL_PREDICTION_SECONDS=settings.experimentalSeconds,
			EXPERIMENTAL_PREDICTION_DISTANCE=settings.experimentalDistance,
			EXPERIMENTAL_PREDICTION_SPEED=settings.experimentalSpeed,
			EXPERIMENTAL_PREDICTION_ACCELERATION=settings.experimentalAcceleration,
			EXPERIMENTAL_PREDICTION_TURN=settings.experimentalTurn,
			EXPERIMENTAL_PREDICTION_ANGULAR=settings.experimentalAngular,
			EXPERIMENTAL_PREDICTION_GAP=settings.experimentalGap,
			EXPERIMENTAL_PREDICTION_TELEPORT=settings.experimentalTeleport,
			EXPERIMENTAL_PREDICTION_LEARNING=settings.experimentalLearning,
			EXPERIMENTAL_PREDICTION_DELAY=settings.experimentalDelay,
			EXPERIMENTAL_PREDICTION_LEAD=settings.experimentalLead,
			DEFAULT_MODEL_REPLICATION_MODE=settings.modelMode,DEFAULT_INTERPOLATION_MODE=settings.interpolation,
			VISUAL_CURVE=settings.curve,MIN_BUFFER=settings.minBuffer,MAX_BUFFER=settings.maxBuffer,
			VISUAL_PREDICTION_SECONDS=settings.predictionSeconds,VISUAL_PREDICTION_DISTANCE=settings.predictionDistance,VISUAL_PREDICTION_SPEED=settings.predictionSpeed,
			MAX_SNAPSHOT_COUNT=settings.snapshots,DEFAULT_NORMAL_TICK_DISTANCE=settings.normalDistance,DEFAULT_HALF_TICK_DISTANCE=settings.halfDistance,
			GRID_UPDATE_INTERVAL=settings.gridInterval,GRID_MAX_UPDATE_TIME=settings.gridBudget/1000,
			MAX_TOTAL_BYTES_PER_FRAME_PER_PLAYER=settings.byteRate,WARNING_SEVERITY=settings.warning,
			REPLICATE_DEATHS=settings.deaths,REPLICATE_CFRAME_SETTERS=settings.setters}
		for key,value in values do config.SetConfig(key,value) end
		config.RegisterEntityType("PLAYER",{TICK_RATE=1/settings.sendHz,BUFFER=0,HALF_TICK_DISTANCE=math.huge,
			MODEL_REPLICATION_MODE=settings.modelMode,FULL_ROTATION=settings.fullRotation,ASSEMBLY_ROOT_PART_CHECK=true})
		config.RegisterEntityType("EXTRA",{TICK_RATE=1/settings.sendHz,BUFFER=0,FULL_ROTATION=settings.fullRotation,
			MODEL_REPLICATION_MODE=settings.modelMode,STORE_SNAPSHOTS=true})
		local hooks=require(root.Hooks)
		if hooks.Configure then hooks.Configure(F,settings) end
		F.Start()
		if run:IsServer() then
			local function add(object)
				if stopped or entities[object] or not object:IsDescendantOf(workspace) or not (object:IsA("Model") or object:IsA("BasePart")) then return end
				if F.Holder.GetEntityFromModel(object) then return end
				if object:IsA("Model") and not object.PrimaryPart then warn("ChronoFork: set PrimaryPart for "..object:GetFullName()) return end
				if object:IsA("BasePart") and object:FindFirstAncestorWhichIsA("Model") then
					local model=object:FindFirstAncestorWhichIsA("Model")
					if model:FindFirstChildOfClass("Humanoid") then warn("ChronoFork: tag/select the whole character model, not a limb") return end
				end
				origins[object]=object.Parent
				local e=F.Entity.new("EXTRA",object,settings.modelMode) entities[object]=e
				if hooks.Connected then hooks.Connected(F,e,object) end
			end
			local function remove(object)
				local e=entities[object] if not e then return end entities[object]=nil
				-- Leave game-created models intact when the tag/link is removed.
				if hooks.Disconnected then hooks.Disconnected(F,e,object) end
				F.Entity.Destroy(e,true)
				local previous=origins[object] origins[object]=nil
				if settings.modelMode=="CUSTOM" and object.Parent and previous and previous:IsDescendantOf(game) then object.Parent=previous end
			end
			if settings.extraSource=="Tag" then
				local tags=game:GetService("CollectionService")
				connect(tags:GetInstanceAddedSignal(settings.tag),add) connect(tags:GetInstanceRemovedSignal(settings.tag),remove)
				for _,o in tags:GetTagged(settings.tag) do add(o) end
			elseif settings.extraSource=="Selection" then
				for _,ref in root.References:GetChildren() do if ref:IsA("ObjectValue") and ref.Value then add(ref.Value) end end
			end
			if settings.debugger then
				local allowed={} for id in settings.adminIds:gmatch("[^,%s]+") do allowed[tonumber(id)]=true end
				local function grant(player) if run:IsStudio() or allowed[player.UserId] then F.Stats.ReplicateStatsForPlayer(player) end end
				connect(game.Players.PlayerAdded,grant) for _,p in game.Players:GetPlayers() do grant(p) end
			end
		elseif settings.debugger then
			table.insert(handles,require(root.DebugUI).Mount(F,root))
		end
	end
	function state.Disconnect()
		if stopped then return end stopped=true
		for _,c in handles do c:Disconnect() end
		-- The original replication loop is started once for this Play session.
		-- Full uninstall/configuration changes require Stop, then Edit-time Undo.
		active[root]=nil
	end
	root:SetAttribute(if run:IsServer() then "ChronoForkServerStarted" else "ChronoForkClientStarted",true)
	return state
end
return B
