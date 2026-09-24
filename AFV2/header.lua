local Players            = game:GetService("Players")
local Replicated         = game:GetService("ReplicatedStorage")
local StarterGui         = game:GetService("StarterGui")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local PathfindingService  = game:GetService("PathfindingService")
local HttpService        = game:GetService("HttpService")

local Player    = Players.LocalPlayer
local PlayerGui = Player:WaitForChild("PlayerGui", 10)

--==============================================================
--// LAYERS
--//
--// Every function in this file lives on one of the tables below.
--// A layer only ever calls downward in this list, never upward,
--// so the dependency direction stays readable at a glance.
--//
--//
--// The tables are declared up front and filled in further down, so
--// call order between layers does not depend on definition order.
--==============================================================
local AFConfig = {}
local AFProfile = {}
local AFCombatUtils = {}
local AFCombat = {}
local AFFeature = {}
local AFUI = {}
local AFDebug = {}

--// Every module keeps its mutable state on its own S table. Ownership is
--// then obvious from the name alone, resetting a whole area is one
--// table.clear, and none of it costs a local register, which is what put
--// this file into the compiler limit before.
AFProfile.S = {}
AFCombat.S = {}
AFCombatUtils.S = {}
AFFeature.S = {}
AFUI.S = {}
AFDebug.S = {}

--// Luau allows 200 local registers in a chunk and this file had reached
--// exactly that, which the compiler rejects outright, so nothing loaded at
--// all. Related state lives on a table instead of one register each: the UI
--// handles and everything the patrol keeps between frames.
local UIRef = {}
local PatrolState = {}

--// Utils is expected to be a ModuleScript named "Utils" under ReplicatedStorage.
local Utils = loadstring(game:HttpGet("https://raw.githubusercontent.com/Endmin1strator/AutoFarmingV5/refs/heads/master/Utils.lua"))()
local UI = Utils.new("AUTO FARMING v2.38")

local function NotifyAction(Action, Message, Duration)
	if UI and type(UI.Notify) == "function" then
		UI:Notify(Action, Message, Duration or 2.5)
	end
end

