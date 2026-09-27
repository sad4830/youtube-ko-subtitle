--[[
	tools/build_place.luau — 최종 플레이스 파일 빌드 (Lune 0.10)

	1) rojo build 로 만든 플레이스(스크립트만 들어 있음)를 읽는다
	2) src/server/MapBuilder.luau 를 그대로 실행해 맵을 Workspace 에 미리 구워 넣고, 조명을 설정한다
	3) build/GoldAndAsh.rbxl 로 저장한다 → Roblox Studio 에서 바로 열고 ▶ 플레이

	사용법 (프로젝트 루트에서):
		rojo build default.project.json -o build/scripts_only.rbxl
		lune run tools/build_place.luau
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local IN_PATH = "build/scripts_only.rbxl"
local OUT_PATH = "build/GoldAndAsh.rbxl"

local game = roblox.deserializePlace(fs.readFile(IN_PATH))
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")

local env = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	BrickColor = roblox.BrickColor,
	Enum = roblox.Enum,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	PhysicalProperties = roblox.PhysicalProperties,
	Font = roblox.Font,
}

local chunk = luau.load(fs.readFile("src/server/MapBuilder.luau"), { debugName = "MapBuilder", environment = env })
local MapBuilder = chunk()

local old = workspace:FindFirstChild("Map")
if old then
	old:Destroy()
end
local map = MapBuilder.build(workspace)
MapBuilder.applyLighting(lighting)
pcall(function()
	lighting.Technology = roblox.Enum.Technology.Future
end)

local parts = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		parts += 1
	end
end

fs.writeFile(OUT_PATH, roblox.serializePlace(game))
print(string.format("built %s  (map parts: %d)", OUT_PATH, parts))
