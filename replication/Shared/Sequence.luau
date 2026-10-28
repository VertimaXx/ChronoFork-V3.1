-- Modular counters for state packets; lifetimes and owners are separate counters.
local S = {MOD = 4294967296, HALF = 2147483648}
function S.Newer(value, previous)
	if type(value) ~= "number" or value % 1 ~= 0 or value < 0 or value >= S.MOD then return false end
	if previous == nil then return true end
	local delta = (value - previous) % S.MOD
	return delta > 0 and delta < S.HALF
end
function S.Next(value) return ((value or 0) + 1) % S.MOD end
return table.freeze(S)
