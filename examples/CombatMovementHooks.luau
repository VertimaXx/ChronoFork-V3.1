-- CUSTOMIZE WITHIN THE PACKAGE. Ordinary games can use these defaults.
-- These functions run on the server. Never connect an unvalidated client request directly to Begin.
local H={}
function H.State(object,root,settings)
	local player=if object:IsA("Model") then game:GetService("Players"):GetPlayerFromCharacter(object) else nil
	local humanoid=object:FindFirstChildOfClass("Humanoid")
	local active=not humanoid or humanoid.Health>0
	if settings.activeAttribute~="" then active=active and object:GetAttribute(settings.activeAttribute)==true end
	local team=if settings.teamAttribute~="" then object:GetAttribute(settings.teamAttribute) else (player and player.Team and player.Team.Name or nil)
	return {active=active,team=team}
end
-- Existing server code must already have checked cooldown, stamina, equipment and request ownership.
function H.CanStart(object,actionName,context,state) return state.active==true end
function H.CanApply(source,target,actionName,context,contact) return true end
-- Optional additional outcome function. Normally choose an existing Outcome BindableEvent instead.
function H.OnContact(source,target,actionName,context,contact) end
-- Match DIFFERENT existing server-event argument orders here, rather than rewriting the game.
function H.ReadBegin(source,actionName,key,context) return source,actionName,key,context end
function H.ReadQuery(source,key) return source,key end
function H.ReadCancel(source,key) return source,key end
function H.ApplyOutcome(event,source,target,actionName,context,contact)
	event:Fire(source,target,actionName,context,contact)
end
-- Override here for a game's existing slow/stun/dash rules. Values must come from server rules.
-- Map this game's EXISTING movement rules inside the supplied customization file.
-- The 0.35-second grace lets previously legal replicated movement arrive after a tag change.
local movementState=setmetatable({}, {__mode="k"})
local seenForces=setmetatable({}, {__mode="k"})
function H.MovementLimits(object,settings)
	local walk,jump=settings.walk,settings.jump
	if object:FindFirstChild("Action") then walk=0 jump=0 end
	if object:FindFirstChild("NoJump") then jump=0 end
	if object:FindFirstChild("Stun") then walk-=18 jump=0 end
	if object:FindFirstChild("Blocking") then walk-=15 jump=0 end
	if object:FindFirstChild("LightAttack") then walk-=4 jump=0 end
	walk=math.max(0,walk)
	local now=workspace:GetServerTimeNow()
	local root=object:FindFirstChild(settings.root)
	local previous=movementState[object]
	if not previous then
		previous={walk=walk,graceWalk=walk,walkUntil=0,jump=jump,jumpUntil=0,flightJump=jump}
		movementState[object]=previous
	end
	if walk~=previous.walk then
		previous.graceWalk=math.max(previous.walk,walk,if now<previous.walkUntil then previous.graceWalk else 0)
		previous.walkUntil=now+0.35
		previous.walk=walk
	end
	if now<previous.walkUntil then walk=math.max(walk,previous.graceWalk) end
	if jump>0 then previous.jump=jump previous.jumpUntil=now+0.35 end
	if now<previous.jumpUntil then jump=math.max(jump,previous.jump) end
	-- A new stun cannot undo a jump that was already allowed before takeoff.
	-- Keep its launch bound until landing; this does not create another jump.
	if root then
		local ray=RaycastParams.new() ray.FilterType=Enum.RaycastFilterType.Exclude
		ray.FilterDescendantsInstances={workspace.Characters} ray.RespectCanCollide=true ray.CollisionGroup=root.CollisionGroup
		local ground=workspace:Raycast(root.Position,Vector3.new(0,-settings.ground-0.5,0),ray)
		if ground and ground.Normal.Y>0.5 then previous.flightJump=jump else jump=math.max(jump,previous.flightJump) end
	end

	-- ServerHandler already creates these server-side BodyVelocity objects.
	-- Map its existing 10/.2 and 30/.65 knockbacks to the plugin's supplied allowance.
	-- This hook creates no force and changes no original damage/knockback code.
	local force=root and root:FindFirstChild("KNOCKBACK")
	if force and force:IsA("BodyVelocity") and not seenForces[force] then
		local speed=force.Velocity.Magnitude
		if math.abs(speed-10)<0.001 or math.abs(speed-30)<0.001 then
			local permitted=force.Velocity
			if speed>=20 and object:FindFirstChild("Knocked") then
				-- Original ClientHandler adds a 100-unit torso impulse on this tag.
				-- Delta-v = impulse / mass. The triangle bound covers either direction.
				local torso=object:FindFirstChild("Torso")
				local mass=math.max(0.01,math.min(root.AssemblyMass,root:GetMass()+(torso and torso:GetMass() or 0)))
				permitted=permitted.Unit*(speed+100/mass)
			end
			require(script.Parent.Connector).AllowMotion(object,permitted,if speed<20 then 0.2 else 0.65)
			seenForces[force]=true
		end
	end
	return walk,jump
end
function H.AfterCorrection(object,reason) end
-- Adapt a DIFFERENT existing checker API here, inside the supplied package.
function H.ProviderSnapshot(provider,object,time)
	if type(provider)=="function" then return provider(object,time) end
	return provider.Snapshot(object,time)
end
-- Optional custom snapshot: use the selected Provider module for existing checked position systems.
-- Provider.Snapshot(object, time) must return {ok=true, root=CFrame, zones={...}, state={...}}.
-- 'ok=true' is a declaration by that checker, not an extra check performed by Chrono.
return H
