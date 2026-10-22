return function(t)
	local root=game.ServerStorage.ChronoV3Validation.Core
	local H,S=require(root.History),require(root).Shapes
	local E=t.expect
	local function history() return H.new({capacity=4,seconds=0.6,maxGap=0.1,maxSpeed=100,maxRadius=8}) end
	local function snapshot(x,state,shape)
		return {root=CFrame.new(x or 0,0,0),zones={body=shape or S.Sphere(CFrame.new(x or 0,0,0),1)},state=state or {active=true}}
	end
	-- Empty evidence has no fallback pose.
	t.test("empty history rejects",function() E.equal(select(2,history():Sample(1,1)),"empty") end)
	-- Ring wrap retains chronological bounds and evicts the actual oldest rows.
	t.test("ring wrap bounds",function() local h=history() for i=1,8 do E.truthy(h:Push(i/16,snapshot(i/16))) end E.equal(select(2,h:Sample(0.25,0.5)),"too_old") E.near(h:Sample(0.375,0.5).root.X,0.375,1e-6) end)
	-- Positions interpolate linearly between endpoints and cannot overshoot their segment.
	t.test("linear interpolation at bounded interior",function() local h=history() h:Push(1,snapshot(0)) h:Push(1.0625,snapshot(4)) E.near(h:Sample(1.03125,1.0625).root.X,2,1e-6) end)
	-- Requests outside coverage, in the future, or older than retention reject independently.
	t.test("range age and future guards",function() local h=history() h:Push(1,snapshot()) E.equal(select(2,h:Sample(0.9,1)),"too_old") E.equal(select(2,h:Sample(1.01,1.1)),"not_recorded") E.equal(select(2,h:Sample(2,1)),"future") E.equal(select(2,h:Sample(1,2)),"expired") end)
	-- Duplicate insertion cannot rewrite an accepted snapshot.
	t.test("duplicate sample immutable",function() local h=history() h:Push(1,snapshot()) E.falsy(h:Push(1,snapshot(9))) E.equal(h:Sample(1,1).root.X,0) end)
	-- A resized or renamed zone is not interpolated through an invented intermediate volume.
	t.test("shape transition rejects",function() local h=history() h:Push(1,snapshot()) h:Push(1.0625,snapshot(0,nil,S.Capsule(CFrame.new(),1,4))) E.equal(select(2,h:Sample(1.03125,1.0625)),"geometry_boundary") end)
	-- Max radius includes the root-to-zone offset as well as shape extent.
	t.test("remote zone rejected",function() local h=history() local ok,why=h:Push(1,snapshot(0,nil,S.Sphere(CFrame.new(8,0,0),1))) E.falsy(ok) E.equal(why,"zone_out_of_bounds") end)
	-- Non-scalar state and NaN never enter historical evidence.
	t.test("invalid state rejected",function() local h=history() E.falsy(h:Push(1,snapshot(0,{nested={}}))) E.falsy(h:Push(1,snapshot(0,{number=0/0}))) end)
	-- A lifecycle boundary invalidates exact rows in the previous epoch too.
	t.test("old epoch exact sample rejects",function() local h=history() h:Push(1,snapshot()) h:Break(1.01) E.equal(select(2,h:Sample(1,1.01)),"epoch_changed") end)
end
