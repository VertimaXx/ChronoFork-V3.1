-- Wire v2: validate the WHOLE packet before returning any decoded state.
-- API-compatible with Chrono; wire v2 peers must use the same package.
-- Full f64 source clocks remove the five-day u32 wrap ambiguity from state packets.
local P = {Version = 2, MaxPayload = 900, Header = 5, FullBytes = 41, YawBytes = 37}
local MAGIC = 0xCF32
local TAU = 2 * math.pi
local function finite(n) return type(n) == "number" and n == n and math.abs(n) < math.huge end
local function integer(n, lo, hi) return finite(n) and n % 1 == 0 and n >= lo and n <= hi end
local function frame(cf)
	if typeof(cf) ~= "CFrame" then return false end
	for _, n in {cf:GetComponents()} do if not finite(n) then return false end end
	local p = cf.Position
	local x,y,z=cf.RightVector,cf.UpVector,cf.ZVector
	return math.max(math.abs(p.X), math.abs(p.Y), math.abs(p.Z)) <= 1e7
		and math.abs(x.Magnitude-1)<1e-4 and math.abs(y.Magnitude-1)<1e-4 and math.abs(z.Magnitude-1)<1e-4
		and math.abs(x:Dot(y))<1e-4 and math.abs(y:Dot(z))<1e-4 and math.abs(z:Dot(x))<1e-4 and x:Cross(y):Dot(z)>0.9999
end
function P.Record(entity, time, cf, full, half, teleport, stop)
	assert(integer(entity.id, 1, 65535) and integer(entity.generation, 1, 4294967295), "invalid entity lifetime")
	assert(integer(entity.ownershipRevision or 0, 0, 4294967295), "invalid ownership revision")
	assert(integer(entity._sendSequence, 0, 4294967295), "invalid state sequence")
	assert(finite(time) and time >= 0 and time <= 1e12 and frame(cf), "invalid position or source time")
	local b = buffer.create(if full then P.FullBytes else P.YawBytes)
	buffer.writeu16(b, 0, entity.id)
	local flags = (if full then 1 else 0) + (if half then 2 else 0) + (if teleport then 4 else 0) + (if stop then 8 else 0)
	buffer.writeu8(b, 2, flags)
	buffer.writeu32(b, 3, entity.generation)
	buffer.writeu32(b, 7, entity.ownershipRevision or 0)
	buffer.writeu32(b, 11, entity._sendSequence)
	buffer.writef64(b, 15, time)
	buffer.writef32(b, 23, cf.X) buffer.writef32(b, 27, cf.Y) buffer.writef32(b, 31, cf.Z)
	local rx, ry, rz = cf:ToOrientation()
	local function angle(offset, value) buffer.writeu16(b, offset, math.round((value + math.pi) / TAU * 65535)) end
	if full then angle(35, rx) angle(37, ry) angle(39, rz) else angle(35, ry) end
	return b
end
function P.WithHalf(record, half)
	local out = buffer.create(buffer.len(record)) buffer.copy(out, 0, record)
	local flags = buffer.readu8(out, 2)
	buffer.writeu8(out, 2, if half then bit32.bor(flags, 2) else bit32.band(flags, bit32.bnot(2)))
	return out
end
function P.Pack(records)
	local packets, group, bytes,seen = {}, {}, P.Header,{}
	local function flush()
		if #group == 0 then return end
		local b = buffer.create(bytes)
		buffer.writeu16(b, 0, MAGIC) buffer.writeu8(b, 2, P.Version) buffer.writeu16(b, 3, #group)
		local offset = P.Header
		for _, row in group do buffer.copy(b, offset, row) offset += buffer.len(row) end
		table.insert(packets, b) group, bytes,seen = {}, P.Header,{}
	end
	for _, row in records do
		local length = buffer.len(row)
		assert(length == P.FullBytes or length == P.YawBytes, "invalid state record size")
		local id=buffer.readu16(row,0)
		if bytes + length > P.MaxPayload or seen[id] then flush() end
		seen[id]=true
		table.insert(group, row) bytes += length
	end
	flush()
	return packets
end
function P.Decode(b)
	if typeof(b) ~= "buffer" then return nil, "packet_type" end
	local length = buffer.len(b)
	if length < P.Header or length > P.MaxPayload then return nil, "packet_size" end
	if buffer.readu16(b, 0) ~= MAGIC or buffer.readu8(b, 2) ~= P.Version then return nil, "packet_version" end
	local count = buffer.readu16(b, 3)
	if count == 0 or count > 32 then return nil, "packet_count" end
	local rows, seen, offset = {}, {}, P.Header
	for _ = 1, count do
		if length - offset < 3 then return nil, "packet_truncated" end
		local flags = buffer.readu8(b, offset + 2)
		if flags > 15 then return nil, "packet_flags" end
		local full = bit32.band(flags, 1) ~= 0
		local size = if full then P.FullBytes else P.YawBytes
		if length - offset < size then return nil, "packet_truncated" end
		local id = buffer.readu16(b, offset)
		local generation = buffer.readu32(b, offset + 3)
		if id == 0 or generation == 0 or seen[id] then return nil, "packet_entity" end
		seen[id] = true
		local time = buffer.readf64(b, offset + 15)
		local x, y, z = buffer.readf32(b, offset + 23), buffer.readf32(b, offset + 27), buffer.readf32(b, offset + 31)
		if not finite(time) or time < 0 or time > 1e12 or not finite(x) or not finite(y) or not finite(z)
			or math.max(math.abs(x), math.abs(y), math.abs(z)) > 1e7 then return nil, "packet_numeric" end
		local function angle(at) return buffer.readu16(b, offset + at) / 65535 * TAU - math.pi end
		local cf = CFrame.new(x, y, z) * (if full then CFrame.fromOrientation(angle(35), angle(37), angle(39)) else CFrame.fromOrientation(0, angle(35), 0))
		local copy = buffer.create(size) buffer.copy(copy, 0, b, offset, size)
		table.insert(rows, {id = id, generation = generation,
			ownershipRevision = buffer.readu32(b, offset + 7), sequence = buffer.readu32(b, offset + 11),
			time = time, frame = cf, full = full, half = bit32.band(flags, 2) ~= 0,
			teleport = bit32.band(flags, 4) ~= 0, stop = bit32.band(flags, 8) ~= 0, record = copy})
		offset += size
	end
	if offset ~= length then return nil, "packet_trailing_bytes" end
	return rows
end
return table.freeze(P)
