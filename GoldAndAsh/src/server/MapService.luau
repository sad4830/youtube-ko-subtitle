--!strict
-- 맵: 스폰 지점, 허수아비 위치, 부서지는 소품 처리
-- 플레이스 파일에 Map 이 이미 들어 있으면 그대로 쓰고, 없으면 MapBuilder 로 즉석에서 만든다.

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Remotes = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Remotes)

local MapBuilder = require(script.Parent.MapBuilder)

local MapService = {}

local map: Model? = nil
local spawns: { BasePart } = {}
local dummySpots: { BasePart } = {}

type Saved = {
	cf: CFrame,
	transparency: number,
	canCollide: boolean,
	canQuery: boolean,
	anchored: boolean,
	group: string,
}
local saved: { [BasePart]: Saved } = {}

local PROP_RESPAWN = 22

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

local function restore(part: BasePart)
	local s = saved[part]
	if not s or not part.Parent then
		return
	end
	part.Anchored = true
	part.AssemblyLinearVelocity = Vector3.zero
	part.AssemblyAngularVelocity = Vector3.zero
	part.CFrame = s.cf
	part.Transparency = s.transparency
	part.CanCollide = s.canCollide
	part.CanQuery = s.canQuery
	part.CollisionGroup = s.group
	part:SetAttribute("Broken", false)
	Remotes.FX:FireAllClients("PropRestore", { pos = s.cf.Position, size = part.Size })
end

-- 소품을 부순다. toAsh 이면 칼날이 닿은 물체가 검은 재로 무너진다 (칸자키 렌).
function MapService.breakPart(part: BasePart, fromPos: Vector3, dir: Vector3, toAsh: boolean): boolean
	if part:GetAttribute("Broken") == true or part:GetAttribute("Breakable") ~= true then
		return false
	end
	part:SetAttribute("Broken", true)
	if not saved[part] then
		saved[part] = {
			cf = part.CFrame,
			transparency = part.Transparency,
			canCollide = part.CanCollide,
			canQuery = part.CanQuery,
			anchored = part.Anchored,
			group = part.CollisionGroup,
		}
	end
	local pos = part.Position
	if toAsh then
		part.Transparency = 1
		part.CanCollide = false
		part.CanQuery = false
		Remotes.FX:FireAllClients("PropAsh", { pos = pos, size = part.Size, color = part.Color })
	else
		Remotes.FX:FireAllClients("PropBreak", { pos = pos, size = part.Size, color = part.Color, material = part.Material })
		part.CanQuery = false
		-- 날아가는 파편이 캐릭터를 튕겨 내지 않도록 캐릭터와는 충돌하지 않게 한다
		part.CollisionGroup = "Debris"
		part.Anchored = false
		local away = pos - fromPos
		local push = if away.Magnitude > 0.1 then away.Unit else dir
		part.AssemblyLinearVelocity = push * 55 + dir * 20 + Vector3.new(0, 38, 0)
		part.AssemblyAngularVelocity = Vector3.new(math.random() * 16 - 8, math.random() * 16 - 8, math.random() * 16 - 8)
		pcall(function()
			part:SetNetworkOwner(nil)
		end)
		task.delay(3.5, function()
			if part:GetAttribute("Broken") == true and part.Parent then
				local tw = TweenService:Create(part, TweenInfo.new(1), { Transparency = 1 })
				tw:Play()
				tw.Completed:Wait()
				if part:GetAttribute("Broken") == true then
					part.Anchored = true
					part.CanCollide = false
				end
			end
		end)
	end
	task.delay(PROP_RESPAWN, function()
		restore(part)
	end)
	return true
end

function MapService.getMap(): Model?
	return map
end

return MapService
