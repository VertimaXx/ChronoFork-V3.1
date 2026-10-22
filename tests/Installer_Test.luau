return function(t)
	local Config=require(game.ServerStorage.ChronoV3Validation.Editor.Config)
	local E=t.expect
	-- Each supplied preset is a complete plain-data configuration.
	t.test("all editable presets validate",function() for _,name in {"Sports","Melee","Hitscan"} do E.truthy(Config.Validate(Config.Preset(name,Config.Default()))) end end)
	-- Invalid numbers and namespace injection cannot enter generated source.
	t.test("invalid configuration rejected",function()
		for _,field in {"opens","closes","radius","seconds","maxRewind"} do local c=Config.Default() c[field]=0/0 E.falsy(Config.Validate(c)) end
		local c=Config.Default() c.name='Bad\");error("injected' E.falsy(Config.Validate(c))
	end)
	-- All five primitive options produce profiles without gameplay side effects.
	t.test("all primitive templates generate",function()
		for _,shape in {"Box","Sphere","Capsule","Ray","SweptSphere"} do local c=Config.Default() c.shape=shape local sources=Config.Generate(c) E.truthy(sources.Actions:find("shape%s*=")) E.falsy(sources.Integration:find("RemoteEvent",1,true)) end
	end)
	-- Rewind needs a deliberate timing provider; the wizard cannot infer it.
	t.test("rewind is opt in",function() local c=Config.Default() E.equal(c.maxRewind,0) E.falsy(Config.Generate(c).Settings:find("resolveRewind=",1,true)) end)
	-- Reference tracking deliberately remains unverified.
	t.test("reference provider cannot claim trust",function() local sources=Config.Generate(Config.Default()) E.truthy(sources.Bindings:find('end,"unverified",kind)',1,true)) end)
end
