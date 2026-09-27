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

-- 로블록스 API 호출이 멈춰 버려도 게임이 영원히 기다리지 않도록 시간 제한을 둔다
local function withTimeout(seconds: number, fn: () -> any): (boolean, any)
	local done = false
	local ok = false
	local result: any = nil
	task.spawn(function()
		ok, result = pcall(fn)
		done = true
	end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < seconds do
		task.wait(0.1)
	end
	if not done then
		return false, "시간 초과"
	end
	return ok, result
end

local function fromDescription(desc: HumanoidDescription): Model?
	local ok, model = withTimeout(10, function()
		return Players:CreateHumanoidModelFromDescriptionAsync(desc, Enum.HumanoidRigType.R6)
	end)
	if ok and typeof(model) == "Instance" and model:IsA("Model") then
		return model
	end
	warn("[AvatarService] 아바타 모델 생성 실패 → 기본 모양 사용: " .. tostring(model))
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
		local ok, desc = withTimeout(8, function()
			return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
		end)
		if ok and typeof(desc) == "Instance" and desc:IsA("HumanoidDescription") then
			model = fromDescription(desc)
		else
			warn("[AvatarService] 아바타 정보 불러오기 실패 → 기본 모양 사용: " .. tostring(desc))
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
	local ok, built = pcall(buildFor, player)
	local model: Model
	if ok and built then
		model = built
	else
		warn("[AvatarService] 아바타 준비 중 오류 → 기본 모양 사용: " .. tostring(built))
		model = RigBuilder.buildFallback({ head = SKIN, torso = Color3.fromRGB(40, 120, 200), arms = SKIN, legs = Color3.fromRGB(60, 60, 70) })
		model.Name = player.Name
		RigBuilder.prepare(model, { displayName = player.DisplayName, collisionGroup = "Characters" })
	end
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
