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
function H.MovementLimits(object,settings) return settings.walk,settings.jump end
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
