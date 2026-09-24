--// AFV2 loader
--//
--// Fetches every AFV2 source, joins them into one chunk and loads that chunk
--// once. The layers are namespaces, not modules: they all close over the same
--// top-level locals, which Lua binds as upvalues where a function is defined.
--// Loading the files one at a time would give each its own copy of that state
--// and the script would do nothing useful, so the text is joined before any
--// loadstring call.
--//
--// Each source stores its slice of the original file plus one terminating
--// newline. Stripping exactly one newline per part and joining with "\n"
--// reproduces the reviewed file byte for byte.
--//
--// Usage:
--//   loadstring(game:HttpGet(".../AFV2/init.lua"))()

local BRANCH = "main"
local BASE = "https://raw.githubusercontent.com/zeroschth38-jpg/svgrbxtest/refs/heads/"
	.. BRANCH .. "/AFV2/"

--// Concatenation order. This list is the single source of truth for it.
local ORDER = {
	"header.lua",
	"state.lua",
	"config.lua",
	"profile.lua",
	"combatutils.lua",
	"combat.lua",
	"feature.lua",
	"ui.lua",
	"debug.lua",
	"build.lua",
	"wire.lua",
	"main.lua",
}

local FETCH_ATTEMPTS = 3
local RETRY_DELAY = 0.4
local MIN_SOURCE_BYTES = 64
local FETCH_TIMEOUT = 30

local function FetchSource(Name)
	local LastError = nil

	for Attempt = 1, FETCH_ATTEMPTS do
		local Success, Body = pcall(function()
			return game:HttpGet(BASE .. Name, true)
		end)

		--// A cache or error page can come back with a 200 and a tiny body, so
		--// size is checked as well as the call succeeding.
		if Success and type(Body) == "string" and #Body >= MIN_SOURCE_BYTES then
			return Body
		end

		LastError = (not Success) and tostring(Body)
			or ("short response (" .. tostring(Body and #Body or 0) .. " bytes)")

		if Attempt < FETCH_ATTEMPTS then
			task.wait(RETRY_DELAY * Attempt)
		end
	end

	return nil, LastError
end

local Sources = table.create(#ORDER)
local Errors = {}
local Completed = 0

--// Fetched in parallel. Done one at a time this costs about half a second per
--// file; in parallel the whole set costs roughly the slowest single request.
for Index, Name in ipairs(ORDER) do
	task.spawn(function()
		local Body, FetchError = FetchSource(Name)

		if Body then
			Sources[Index] = Body
		else
			table.insert(Errors, Name .. ": " .. tostring(FetchError))
		end

		Completed += 1
	end)
end

local Deadline = os.clock() + FETCH_TIMEOUT
repeat
	task.wait()
until Completed >= #ORDER or os.clock() > Deadline

if Completed < #ORDER then
	error("AFV2 loader: timed out after " .. FETCH_TIMEOUT .. "s with "
		.. Completed .. "/" .. #ORDER .. " sources fetched", 0)
end

if #Errors > 0 then
	error("AFV2 loader: could not fetch " .. #Errors .. " source(s)\n  "
		.. table.concat(Errors, "\n  "), 0)
end

--// Never load a partial chunk. A missing slice would not be a syntax error in
--// every case, it could silently drop whole layers instead.
for Index, Name in ipairs(ORDER) do
	if type(Sources[Index]) ~= "string" then
		error("AFV2 loader: missing source " .. Name, 0)
	end

	Sources[Index] = (Sources[Index]:gsub("\n$", ""))
end

local Chunk = table.concat(Sources, "\n")
local Loaded, CompileError = loadstring(Chunk, "=AFV2")

if not Loaded then
	error("AFV2 loader: the assembled chunk did not compile\n  "
		.. tostring(CompileError), 0)
end

return Loaded()
