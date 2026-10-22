-- Tests the added help API and form behavior, not individual wording choices.
return function(t)
	local root=game.ServerStorage.ChronoV3Validation
	local C=require(root.Editor.Config)
	local Core=require(root.Core)
	local H=require(root.Core.Help)
	local E=t.expect
	-- Explaining a result preserves its actual code and cannot rewrite the result table.
	t.test("explanations do not change evidence",function()
		local result=table.freeze({ok=false,reason="target_state_boundary",contacts=table.freeze({})})
		local h=Core.Explain(result)
		E.equal(result.reason,"target_state_boundary") E.falsy(result.ok) E.equal(#result.contacts,0)
		E.equal(h.code,result.reason) E.truthy(h.known) E.equal(h.subject,"Possible target")
		E.truthy(#h.meaning>0 and #h.fix>0)
	end)
	-- Unknown messages stay unknown; help never turns them into an accepted check.
	t.test("unknown result stays identifiable",function()
		local h=Core.Explain("custom-game-message") E.falsy(h.known) E.equal(h.code,"custom-game-message")
		E.equal(Core.Explain(nil).code,"unknown")
	end)
	-- A search can find a term by either its code word or its plain explanation.
	t.test("word search is case insensitive and literal",function()
		E.truthy(#H.FindTerms("HISTORY")>0) E.truthy(#H.FindTerms("Saved past positions")>0)
		E.equal(#H.FindTerms("[not-a-pattern]"),0)
	end)
	-- All invalid fields are returned with places in the wizard, rather than only one error.
	t.test("form errors point to every relevant page",function()
		local c=C.Default() c.name="" c.radius=-1 c.seconds=0/0
		local found={} for _,e in C.Check(c) do found[e.field]=e.page end
		E.equal(found.name,2) E.equal(found.radius,3) E.equal(found.seconds,4)
	end)
	-- Developers can enter decimal commas without accidentally generating invalid Lua.
	t.test("decimal comma and decimal point",function()
		E.equal(C.ParseNumber(" 1,5 "),1.5) E.equal(C.ParseNumber("1.5"),1.5)
		E.equal(C.ParseNumber("one"),nil) E.equal(C.ParseNumber("1,2,3"),nil)
	end)
	-- Irrelevant hidden fields do not block a different shape from being generated.
	t.test("hidden unused dimensions do not block a ray",function()
		local c=C.Default() c.shape="Ray" c.radius="not used" c.forward="not used"
		E.truthy(C.Validate(c)) E.truthy(C.Generate(c).Actions:find("S.Sweep",1,true))
	end)
	-- Object/code names can be non-English while generated Lua keeps their exact strings.
	t.test("non English names and target ids",function()
		local c=C.Default() c.name="Fútbol contacto" c.kind="pelota" c.targets="jugador, pelota"
		E.truthy(C.Validate(c)) E.truthy(C.Generate(c).Actions:find('"pelota"',1,true))
	end)
	-- A practice runner and real game connections are deliberately distinct outputs.
	t.test("generated practice is clearly separated",function()
		local source=C.Generate(C.Default())
		E.truthy(source.RunPractice:find('IsStudio()',1,true))
		E.truthy(source.Practice:find('practiceProfile.opens=0',1,true))
		E.falsy(source.Integration:find('RunPractice',1,true))
	end)
end
