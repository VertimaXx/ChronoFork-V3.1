-- Customize your game INSIDE the package. No separate helper system is required.
local Hooks={}
function Hooks.Configure(chrono,settings)
	-- Both sides, before Start: register additional entity types/model templates.
	-- chrono.Config.RegisterEntityModel("Ball", script.Parent.Models.Ball)
end
function Hooks.Connected(chrono,entity,object)
	-- Server: optional ownership, data, replication rules or authored pose setup.
	-- chrono.Entity.SetNetworkOwner(entity, player)
end
function Hooks.Disconnected(chrono,entity,object)
	-- Server: optional ownership/physics hand-back when a tag is removed.
	-- The supplied connector keeps the original game-created model intact.
end
function Hooks.Simulate(dt,simulationTime,resimulating)
	-- Engine mode only, on BOTH sides. Put the game's shared simulation here.
	-- Use predicted instance attributes for state; normal tables are not rewound.
	-- Read InputActions, update synchronized properties, and use simulationTime.
	-- Apply effects outside simulation; Competitive.Simulation.DeferOutcome helps
	-- reserve server outcome keys. Do not drive the same objects with Legacy Start.
end
return Hooks
