const Warn = require(script.Parent.Parent.Shared.Warn)
const Config = require(script.Parent.Parent.Shared.Config)
const Types = require(script.Parent.Parent.Shared.Types)

local MIN_BUFFER: number
local MAX_BUFFER: number

Config._WaitForLock(function()
	MIN_BUFFER = Config._GetConfig("MIN_BUFFER")
	MAX_BUFFER = Config._GetConfig("MAX_BUFFER")
end)
const Buffer = {}

function Buffer.new(clientClock: Types.ClientClock): Types.InterpolationBuffer
	return {
		init = false,
		averageLatency = 0,
		deviation = 0,
		lastLatency = 0,
		lastSendTime = nil,
		maxSendGap = 0,
		idle = false,
		arrival = nil,
		intervals = {},
		intervalHead = 1,
		interval95 = 0,

		clientClock = clientClock,
	}
end

function Buffer.Register(data: Types.InterpolationBuffer, time: number)
	const clientClock = data.clientClock
	local arrival = os.clock()
	local elapsed = if data.arrival then math.max(0, arrival-data.arrival) else clientClock.tickRate
	local wasIdle = data.idle
	if data.lastSendTime and time <= data.lastSendTime then return end
	if data.arrival and not wasIdle then
		data.intervals[data.intervalHead] = elapsed
		data.intervalHead = data.intervalHead % 64 + 1
		local sorted=table.clone(data.intervals) table.sort(sorted)
		data.interval95=sorted[math.max(1,math.ceil(#sorted*0.95))]
	end
	data.arrival = arrival
	local alpha = 1-math.exp(-elapsed/0.5)
	const clientNow = clientClock:GetEstimatedServerTime()
	const latency = clientNow - time

	if math.abs(latency) > 1 then
		clientClock:Clear()
		Warn.low(data.clientClock.name, ` latency too high, cleared cache to repredict in case of error:! {latency}`)
	end

	const lastSendTime = data.lastSendTime
	if lastSendTime and time > lastSendTime and not data.idle then
		const gap = time - lastSendTime
		if gap <= clientClock.tickRate * 3 then
			data.maxSendGap = if gap > data.maxSendGap
				then gap
				else gap + (data.maxSendGap-gap)*math.exp(-elapsed/3)
		end
	end
	if not lastSendTime or time > lastSendTime then
		data.lastSendTime = time
		data.idle = false
	end

	if not data.init then
		--using the difference between current and last latency, i could smooth out the deviation (the variation in latency, which correlates to packet loss)
		--this is using statistics https://en.wikipedia.org/wiki/Moving_average
		data.averageLatency = latency
		data.deviation = 0
		data.lastLatency = latency
		data.init = true
		return
	end

	if data.lastLatency then
		const delta = math.abs(latency - data.lastLatency)
		--deviation is essentially jitter, and we calculate that using RFC 3550 jitter estimation
		--see: https://tech.ebu.ch/docs/tech/tech3337.pdf
		data.deviation = data.deviation + (delta - data.deviation) * alpha
	end

	data.averageLatency = data.averageLatency + (latency - data.averageLatency) * alpha
	data.lastLatency = latency
end

function Buffer.MarkIdle(data: Types.InterpolationBuffer, time: number)
	const lastSendTime = data.lastSendTime
	if lastSendTime and time < lastSendTime then
		return
	end
	data.lastSendTime = time
	data.idle = true
end

function Buffer.GetBuffer(data: Types.InterpolationBuffer, tickRate: number)
	if not data then
		return MIN_BUFFER
	end

	const deviationMargin = data.deviation * 2
	local interval = data.interval95 or tickRate
	const rawBuffer = math.max(tickRate, data.maxSendGap, interval) + deviationMargin

	local buffer = if rawBuffer < MIN_BUFFER then MIN_BUFFER + (MIN_BUFFER - rawBuffer) * 0.2 else rawBuffer
	if buffer > MAX_BUFFER then
		Warn.low(`Interpolation buffer exceeded max! Was {buffer}, clamped to {MAX_BUFFER} for`, data.clientClock.name)
		buffer = MAX_BUFFER
	end

	return buffer
end

function Buffer.Reset(data)
	data.init=false data.averageLatency=0 data.deviation=0 data.lastLatency=0
	data.lastSendTime=nil data.maxSendGap=0 data.idle=false data.arrival=nil
	data.intervals={} data.intervalHead=1 data.interval95=0
end
return Buffer
