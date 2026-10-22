--!strict
local Guard = {}

function Guard.Number(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge
end

function Guard.Integer(value: any, minimum: number, maximum: number): boolean
	return Guard.Number(value) and value % 1 == 0 and value >= minimum and value <= maximum
end

function Guard.Vector(value: any, limit: number?): boolean
	if typeof(value) ~= "Vector3" then return false end
	local bound = limit or 1e7
	return Guard.Number(value.X) and Guard.Number(value.Y) and Guard.Number(value.Z)
		and math.abs(value.X) <= bound and math.abs(value.Y) <= bound and math.abs(value.Z) <= bound
end

function Guard.Frame(value: any, limit: number?): boolean
	if typeof(value) ~= "CFrame" or not Guard.Vector(value.Position, limit) then return false end
	for _, component in {value:GetComponents()} do
		if not Guard.Number(component) then return false end
	end
	-- CFrame.new accepts explicit matrix entries. Reject scaled/sheared/reflected matrices.
	local x,y,z=value.RightVector,value.UpVector,value.ZVector
	return math.abs(x.Magnitude-1)<1e-4 and math.abs(y.Magnitude-1)<1e-4
		and math.abs(z.Magnitude-1)<1e-4 and math.abs(x:Dot(y))<1e-4
		and math.abs(y:Dot(z))<1e-4 and math.abs(z:Dot(x))<1e-4
		and x:Cross(y):Dot(z)>0.9999
end

function Guard.Size(value: any, maximum: number?): boolean
	return Guard.Vector(value, maximum or 512) and value.X > 0 and value.Y > 0 and value.Z > 0
end

function Guard.Unit(value: any): boolean
	return Guard.Vector(value, 1.01) and math.abs(value.Magnitude - 1) <= 0.001
end

return table.freeze(Guard)
