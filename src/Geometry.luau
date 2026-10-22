--!strict
local Guard = require(script.Parent.Guard)
local Geometry = {}
local EPSILON = 1e-9

function Geometry.SegmentDistanceSquared(start: Vector3,finish: Vector3,point: Vector3): number
	local delta=finish-start
	local lengthSquared=delta:Dot(delta)
	local alpha=if lengthSquared>1e-12 then math.clamp((point-start):Dot(delta)/lengthSquared,0,1) else 0
	local offset=point-(start+delta*alpha)
	return offset:Dot(offset)
end

function Geometry.RayOBB(origin: Vector3, direction: Vector3, length: number, frame: CFrame, size: Vector3): number?
	if not Guard.Vector(origin) or not Guard.Unit(direction) or not Guard.Number(length) or length < 0
		or not Guard.Frame(frame) or not Guard.Size(size) then return nil end
	local o, d, half = frame:PointToObjectSpace(origin), frame:VectorToObjectSpace(direction), size * 0.5
	local enter, leave = 0, length
	for _, axis in {"X", "Y", "Z"} do
		local start, delta, extent = o[axis], d[axis], half[axis]
		if math.abs(delta) < EPSILON then
			if math.abs(start) > extent then return nil end
		else
			local a, b = (-extent - start) / delta, (extent - start) / delta
			if a > b then a, b = b, a end
			enter, leave = math.max(enter, a), math.min(leave, b)
			if enter > leave then return nil end
		end
	end
	return enter
end

-- Exact moving sphere vs a stationary OBB, including rounded edges/corners.
-- Split the ray at box-plane crossings; point-to-box distance is quadratic on each interval.
function Geometry.SphereSweepOBB(start: Vector3, finish: Vector3, radius: number, frame: CFrame, size: Vector3): number?
	if not Guard.Vector(start) or not Guard.Vector(finish) or not Guard.Number(radius) or radius < 0 or radius > 32
		or not Guard.Frame(frame) or not Guard.Size(size) then return nil end
	local origin = frame:PointToObjectSpace(start)
	local delta = frame:VectorToObjectSpace(finish - start)
	local half = size * 0.5
	local cuts = {0, 1}
	for _, axis in {"X", "Y", "Z"} do
		if math.abs(delta[axis]) > EPSILON then
			for _, sign in {-1, 1} do
				local t = (sign * half[axis] - origin[axis]) / delta[axis]
				if t > 0 and t < 1 then table.insert(cuts, t) end
			end
		end
	end
	table.sort(cuts)
	for i = 1, #cuts - 1 do
		local lower, upper = cuts[i], cuts[i + 1]
		local midpoint = (lower + upper) * 0.5
		local a, b, c = 0, 0, -radius * radius
		for _, axis in {"X", "Y", "Z"} do
			local p = origin[axis] + delta[axis] * midpoint
			if math.abs(p) > half[axis] then
				local offset = origin[axis] - (if p > 0 then half[axis] else -half[axis])
				a += delta[axis] * delta[axis]
				b += 2 * delta[axis] * offset
				c += offset * offset
			end
		end
		if (a * lower + b) * lower + c <= EPSILON then return lower end
		if a > EPSILON then
			local discriminant = b * b - 4 * a * c
			if discriminant >= -EPSILON then
				local root = (-b - math.sqrt(math.max(discriminant, 0))) / (2 * a)
				if root >= lower - EPSILON and root <= upper + EPSILON then return math.clamp(root, lower, upper) end
			end
		end
	end
	return nil
end

return table.freeze(Geometry)
