--!strict
-- 플레이어의 로블록스 아바타를 R6 전투용 캐릭터로 만든다 (가강전처럼 자기 아바타로 싸움)
--  · 아바타는 한 번만 불러와 캐시하고, 스폰할 때마다 복제해서 쓴다
--  · 캐릭터 선택 화면 미리보기용 복제본을 ReplicatedStorage.AvatarPreviews 에 올린다
--  · 아바타를 못 불러오면(스튜디오 테스트 서버의 가짜 플레이어 등) 기본 모양으로 대신한다

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local RigBuilder = require(Shared.RigBuilder)

local AvatarService = {}

local cache: { [number]: Model } = {}
local loading: { [number]: boolean } = {}

local previews = Instance.new("Folder")
previews.Name = "AvatarPreviews"
previews.Parent = ReplicatedStorage

local SKIN = Color3.fromRGB(234, 184, 146)

local function fromDescription(desc: HumanoidDescription): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R6)
	end)
	if ok and model then
		return model
	end
	warn("[AvatarService] 아바타 모델 생성 실패: " .. tostring(model))
	return nil
end

-- 봇 등에 쓰는 기본 아바타 (색만 캐릭터 테마로)
function AvatarService.buildDefault(torso: Color3, legs: Color3): Model
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = SKIN
	desc.LeftArmColor = SKIN
	desc.RightArmColor = SKIN
	desc.TorsoColor = torso
	desc.LeftLegColor = legs
	desc.RightLegColor = legs
	local model = fromDescription(desc) or RigBuilder.buildFallback({ head = SKIN, torso = torso, arms = SKIN, legs = legs })
	RigBuilder.prepare(model, { collisionGroup = "Characters" })
	return model
end

local function buildFor(player: Player): Model
	local model: Model? = nil
	if player.UserId > 0 then
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
		end)
		if ok and desc then
			model = fromDescription(desc)
		end
	end
	if not model then
		model = RigBuilder.buildFallback({ head = SKIN, torso = Color3.fromRGB(40, 120, 200), arms = SKIN, legs = Color3.fromRGB(60, 60, 70) })
	end
	local m = model :: Model
	m.Name = player.Name
	RigBuilder.prepare(m, { displayName = player.DisplayName, collisionGroup = "Characters" })
	return m
end

-- 플레이어 아바타 원본 (장비 없음). 처음 한 번만 불러온다.
function AvatarService.base(player: Player): Model
	local id = player.UserId
	while loading[id] do
		task.wait(0.1)
	end
	local cached = cache[id]
	if cached then
		return cached
	end
	loading[id] = true
	local model = buildFor(player)
	cache[id] = model
	loading[id] = nil

	-- 선택 화면 미리보기용 복제본
	local preview = model:Clone()
	preview.Name = tostring(id)
	local plate = preview:FindFirstChild("Nameplate", true)
	if plate then
		plate:Destroy()
	end
	local old = previews:FindFirstChild(preview.Name)
	if old then
		old:Destroy()
	end
	preview.Parent = previews
	return model
end

-- 스폰용 새 캐릭터 (장비는 호출한 쪽에서 붙인다)
function AvatarService.spawnModel(player: Player): Model
	return AvatarService.base(player):Clone()
end

function AvatarService.forget(player: Player)
	local id = player.UserId
	local m = cache[id]
	if m then
		m:Destroy()
	end
	cache[id] = nil
	local p = previews:FindFirstChild(tostring(id))
	if p then
		p:Destroy()
	end
end

return AvatarService
