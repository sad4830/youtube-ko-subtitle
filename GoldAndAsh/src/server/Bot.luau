--!strict
-- 간단한 전투 봇: 혼자서도 대전을 즐길 수 있도록 두 캐릭터를 모두 조작한다.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local CharacterDefs = require(Shared.CharacterDefs)
local RigBuilder = require(Shared.RigBuilder)

local Combat = require(script.Parent.Combat)
local Actions = require(script.Parent.Actions)
local MapService = require(script.Parent.MapService)
local CharacterService = require(script.Parent.CharacterService)

type Entity = Combat.Entity

local Bot = {}

type BotState = {
	ent: Entity,
	charId: string,
	thinkT: number,
	blockUntil: number,
	strafe: number,
	strafeT: number,
	aggression: number,
}

local bots: { BotState } = {}

-- 기술별 사용 거리 (이 거리 안일 때 사용)
local SKILL_RANGE: { [string]: number } = {
	GoldenPalm = 11,
	Redirect = 7,
	StaffSpin = 8,
	Kneading = 6,
	DragonClaw = 32,
	DragonCoil = 9,
	RisingDragon = 7,
	GoldenReturn = 45,
	Peel = 16,
	AshReturn = 55,
	SideShave = 45,
	AshVeil = 10,
	ChainReturn = 55,
	Severance = 24,
	VeilHunt = 12,
	MaxOutput = 90,
}

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.05 then f.Unit else Vector3.new(0, 0, -1)
end

local function findTarget(self: Entity): Entity?
	local best: Entity? = nil
	local bestD = Config.Bot.AggroRange
	for _, e in Combat.entities do
		if e ~= self and e.alive and not e.isDummy then
			local d = (e.root.Position - self.root.Position).Magnitude
			if d < bestD then
				bestD = d
				best = e
			end
		end
	end
	return best
end

local function think(b: BotState)
	local ent = b.ent
	local hum = ent.humanoid
	local t = os.clock()
	local target = findTarget(ent)
	if not target then
		hum:Move(Vector3.zero)
		return
	end
	local toT = target.root.Position - ent.root.Position
	local dist = toT.Magnitude
	local dir = flat(toT)

	if Combat.isStunned(ent) then
		if ent.evasive >= Config.Evasive.Max and math.random() < 0.06 then
			Actions.dash(ent, { dir = "back", aim = dir })
		end
		return
	end
	if Combat.isBusy(ent) then
		return
	end

	-- 막기 유지/해제
	if ent.blocking then
		if t > b.blockUntil then
			Actions.block(ent, false)
		else
			hum:Move(Vector3.zero)
			return
		end
	end

	-- 각성
	if ent.awakening >= Config.Awakening.Max and not ent.awakened and math.random() < 0.3 then
		Actions.awaken(ent)
		return
	end

	-- 상대가 공격 중이면 확률적으로 막기
	local targetAttacking = target.busyUntil > t and target.moveName ~= nil and target.moveName ~= "Dash"
	if targetAttacking and dist < 10 and math.random() < Config.Bot.ReactionBlockChance then
		-- 린 위안 봇은 가끔 유전으로 받아친다
		local def = ent.def
		if def and not ent.awakened and ent.charId == "LinYuan" and not Combat.onCooldown(ent, "Redirect") and math.random() < 0.4 then
			Actions.skill(ent, { slot = 2, aim = dir })
			return
		end
		Actions.block(ent, true)
		b.blockUntil = t + 0.5 + math.random() * 0.5
		return
	end

	-- 기술
	local def = ent.def
	if def and math.random() < 0.18 * b.aggression then
		local list = if ent.awakened then def.awakenedMoves else def.moves
		local order = { 1, 2, 3, 4 }
		for i = #order, 2, -1 do
			local j = math.random(1, i)
			order[i], order[j] = order[j], order[i]
		end
		for _, slot in order do
			local mv = list[slot]
			local range = SKILL_RANGE[mv.id] or 8
			local usable = dist <= range and not Combat.onCooldown(ent, mv.id)
			if mv.id == "Redirect" then
				usable = false -- 반응형으로만 사용
			elseif mv.id == "GoldenReturn" or mv.id == "MaxOutput" then
				usable = usable and (ent.awakenEnd - t < 12 or math.random() < 0.15)
			elseif mv.id == "AshReturn" then
				usable = usable and (ent.ash >= 1 or ent.awakened)
			elseif mv.id == "SideShave" or mv.id == "AshVeil" then
				usable = usable and (ent.ash >= 1 or ent.awakened)
			end
			if usable then
				Actions.skill(ent, { slot = slot, aim = dir })
				return
			end
		end
	end

	-- 근접 M1
	if dist < 6.2 then
		Actions.m1(ent, { aim = dir, jump = math.random() < 0.15 })
		hum:Move(Vector3.zero)
		return
	end

	-- 이동 (멀면 대시로 접근, 가까우면 옆으로 흔들며 접근)
	if dist > 28 and math.random() < 0.08 then
		Actions.dash(ent, { dir = "front", aim = dir })
		return
	end
	if t > b.strafeT then
		b.strafeT = t + 0.6 + math.random()
		b.strafe = (math.random() * 2 - 1) * 0.6
	end
	local side = dir:Cross(Vector3.new(0, 1, 0))
	local move = if dist > 12 then dir else (dir + side * b.strafe).Unit
	hum:Move(move)
	if math.random() < 0.01 then
		hum.Jump = true
	end
end

function Bot.count(): number
	local n = 0
	for _, b in bots do
		if b.ent.model.Parent then
			n += 1
		end
	end
	return n
end

function Bot.spawn(charId: string?): Entity?
	if Bot.count() >= Config.MaxBots then
		return nil
	end
	local id = charId
	if not id or not CharacterDefs.get(id) then
		id = CharacterDefs.Order[math.random(1, #CharacterDefs.Order)]
	end
	local cid = id :: string
	local def = CharacterDefs.get(cid)
	local model = RigBuilder.build(cid)
	model.Name = "[봇] " .. (if def then def.name else cid)
	local plate = model:FindFirstChild("Nameplate", true)
	if plate then
		local label = plate:FindFirstChild("NameLabel")
		if label and label:IsA("TextLabel") then
			label.Text = model.Name
		end
	end
	RigBuilder.place(model, MapService.getSpawn())
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local ent = Combat.register(model, nil, cid, { bot = true })
	table.insert(bots, {
		ent = ent,
		charId = cid,
		thinkT = 0,
		blockUntil = 0,
		strafe = 0,
		strafeT = 0,
		aggression = 0.8 + math.random() * 0.4,
	})
	Combat.fx("Spawn", { model = model, pos = root.Position })
	return ent
end

function Bot.clear()
	for _, b in bots do
		if b.ent.model.Parent then
			b.ent.model:Destroy()
		end
	end
	table.clear(bots)
end

function Bot.init()
	CharacterService.onBotDied = function(ent: Entity)
		for i, b in bots do
			if b.ent == ent then
				table.remove(bots, i)
				if ent.model.Parent then
					ent.model:Destroy()
				end
				-- 같은 캐릭터로 다시 등장
				Bot.spawn(b.charId)
				return
			end
		end
		if ent.model.Parent then
			ent.model:Destroy()
		end
	end

	RunService.Heartbeat:Connect(function(dt)
		for i = #bots, 1, -1 do
			local b = bots[i]
			if not b.ent.model.Parent then
				table.remove(bots, i)
			elseif b.ent.alive then
				b.thinkT -= dt
				if b.thinkT <= 0 then
					b.thinkT = Config.Bot.ThinkInterval
					think(b)
				end
			end
		end
	end)
end

return Bot
