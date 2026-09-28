--!strict
-- 맵: 스폰 지점, 허수아비 위치. 건물·사물 파괴는 Destruction 이 맡는다.
-- 플레이스 파일에 Map 이 이미 들어 있으면 그대로 쓰고, 없으면 MapBuilder 로 즉석에서 만든다.

local Lighting = game:GetService("Lighting")

local MapBuilder = require(script.Parent.MapBuilder)
local Destruction = require(script.Parent.Destruction)

local MapService = {}

local map: Model? = nil
local spawns: { BasePart } = {}
local dummySpots: { BasePart } = {}

function MapService.init()
	local existing = workspace:FindFirstChild("Map")
	if existing and existing:IsA("Model") then
		map = existing
	else
		map = MapBuilder.build(workspace)
	end
	if not Lighting:FindFirstChild("MapAtmosphere") then
		MapBuilder.applyLighting(Lighting)
	end
	local m = map :: Model
	local sp = m:FindFirstChild("Spawns")
	if sp then
		for _, p in sp:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(spawns, p)
			end
		end
	end
	Destruction.init(m)
	local ds = m:FindFirstChild("DummySpots")
	if ds then
		for _, p in ds:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(dummySpots, p)
			end
		end
	end
end

function MapService.getSpawn(): CFrame
	if #spawns == 0 then
		return CFrame.new(0, 0.5, 0)
	end
	-- 다른 캐릭터와 가장 먼 스폰을 고른다
	local best: BasePart = spawns[math.random(1, #spawns)]
	local bestScore = -1
	for _, s in spawns do
		local minDist = math.huge
		for _, child in workspace:GetChildren() do
			if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
				local r = child:FindFirstChild("HumanoidRootPart")
				if r and r:IsA("BasePart") then
					minDist = math.min(minDist, (r.Position - s.Position).Magnitude)
				end
			end
		end
		local score = minDist + math.random() * 20
		if score > bestScore then
			bestScore = score
			best = s
		end
	end
	return best.CFrame
end

function MapService.getDummySpots(): { CFrame }
	local list = {}
	for _, p in dummySpots do
		table.insert(list, p.CFrame)
	end
	return list
end

function MapService.getMap(): Model?
	return map
end

return MapService
