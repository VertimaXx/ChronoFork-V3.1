-- All customization remains inside the installed package.
local T={}
T.Sources={
 Clock=[[-- Optional: replace the body with your server simulation's shared seconds clock.
-- Use the SAME clock for every position, Capture timestamp and timing provider.
return {Now=function() return workspace:GetServerTimeNow() end}
]],
 Registry=[[-- Pure server data, no Parts required. Return a dictionary keyed by stable text ids.
-- Replace this empty list with your game's already calculated/checked objects.
-- Each snapshot needs ok=true, root=CFrame, zones={Body=shape}, state={active=true}.
-- Shapes use MAP coordinates. Use require(script.Parent.Core).Shapes.
-- Optional per-object fields: kind, maxSpeed, maxRadius.
-- ok=true declares YOUR server already checked/calculated the data.
return {Snapshots=function(time) return {} end}
]],
 Timing=[[-- Return an approved delay in seconds, between zero and maximum.
-- This is called ONCE when the server accepts a move. The delay stays fixed for that move.
-- Do not accept a raw client timestamp or raw client-provided delay here.
-- Adapt your existing server timing check here, or use Measured ping in the plugin.
return {Resolve=function(actor,serverContext,captureTime,maximum)
 error("Connect your server timing rule inside this module before enabling Provider timing")
end}
]],
 World=[[-- Called for rays / swept spheres only. shape uses MAP coordinates.
-- Return {covered=true,blocked=boolean,fraction=number from 0 to 1}.
-- covered means YOUR provider actually knows obstacles at queryTime.
-- Never answer 'clear' merely because historical obstacle data is missing.
-- Moving doors, platforms and destructible cover need saved obstacle states.
return {Check=function(queryTime,currentTime,shape)
 return {covered=false}
end}
]],
 Provider=[[-- Connect your existing position checker here. A root read alone is not validation.
-- Return {ok=true,root=CFrame,zones={Body=shape},state={active=true}} only AFTER approval.
-- Shapes use MAP coordinates. Use require(script.Parent.Core).Shapes.
return {Snapshot=function(object,time) return {ok=false} end}
]]}
function T.Add(root,key,d)
 if not root or not root:FindFirstChild("ConnectionLinks") then return nil,"Add connections first." end
 if game:GetService("RunService"):IsRunning() then return nil,"Stop Play first." end
 if not T.Sources[key] then return nil,"Unknown provider template." end
 local name=key.."Provider" if root:FindFirstChild(name) then return nil,"A file named "..name.." exists. Open it; no code was replaced." end
 d=d or {} local h=d.history or game:GetService("ChangeHistoryService") local e=d.editor or game:GetService("ScriptEditorService")
 local rec=h:TryBeginRecording("ChronoProvider","Add Chrono provider template") if not rec then return nil,"Studio could not start an Undo step." end
 local object local ok,err=pcall(function()
  object=Instance.new("ModuleScript") object.Name=name e:UpdateSourceAsync(object,function() return T.Sources[key] end) object.Parent=root
 end)
 if not ok and object then object:Destroy() end h:FinishRecording(rec,if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel)
 return if ok then object else nil,err
end
return T

