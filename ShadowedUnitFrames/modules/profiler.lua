-- Optional per-function profiling via the FunctionProfiler addon (/fp to toggle the UI).
-- FunctionProfiler is listed in OptionalDeps so it loads first when present; without it
-- this file is a complete no-op and released builds are unaffected.
local FP = _G.NumyFunctionProfiler
if( not FP ) then return end

-- SUF dispatch is name-based and resolved at call time (handler[func] in OnEvent,
-- module[event] in FireModuleEvent, names stored in fullUpdates/registeredEvents),
-- so wrapping module methods in place is picked up even after registrations.
-- This file loads last in the TOC, so every module table already exists.

-- movers.lua redirects module functions into config/test environments via setfenv;
-- setfenv on a profiler wrapper would not redirect the wrapped original, so keep a
-- wrapper -> original map for movers to target the real function.
local originals = {}
ShadowUF.profilerOriginals = originals

local function wrapModuleTable(name, tbl)
	local before = {}
	for key, value in pairs(tbl) do
		if( type(value) == "function" ) then before[key] = value end
	end
	FP:WrapModules("ShadowedUnitFrames", name, tbl, 1)
	for key, old in pairs(before) do
		if( tbl[key] ~= old ) then originals[tbl[key]] = old end
	end
end

for name, module in pairs(ShadowUF.modules) do
	wrapModuleTable("modules." .. name, module)
end
wrapModuleTable("ShadowUF", ShadowUF)

-- Exposed for lazily created functions that live in file locals (tag render
-- closures in tags.lua); those are wrapped at creation time, after this ran.
ShadowUF.functionProfiler = FP
