--!strict
-- 캐릭터(무브셋) 선택 / 스폰 / 부활, 킬 기록, 훈련용 허수아비
-- 가강전처럼 자기 아바타로 싸우고, 캐릭터는 "무브셋 + 무기"로 고른다.
-- 전투 중이 아니면 살아 있는 상태에서 바로 캐릭터를 바꿀 수 있다.

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local CharacterDefs = require(Shared.CharacterDefs)
local RigBuilder = require(Shared.RigBuilder)
local Locale = require(Shared.Locale)

local Combat = require(script.Parent.Combat)
local MapService = require(script.Parent.MapService)
local AvatarService = require(script.Parent.AvatarService)

type Entity = Combat.Entity

local CharacterService = {}

local chosen: { [Player]: string } = {}
CharacterService.onBotDied = nil :: ((ent: Entity) -> ())?

local COMBAT_LOCK = 5 -- 마지막으로 맞은 뒤 이 시간 동안은 캐릭터 변경 불가

local function clearCharacter(player: Player)
	local old = player.Character
	if old then
		player.Character = nil
		old:Destroy()
	end
end

local function plateText(player: Player, def: CharacterDefs.CharDef): Locale.Text
	return { ko = def.name .. " · " .. player.DisplayName, en = def.en.name .. " · " .. player.DisplayName }
end

function CharacterService.spawnPlayer(player: Player, charId: string)
	local def = CharacterDefs.get(charId)
	if not def or not player.Parent then
		return
	end
	chosen[player] = charId
	local model = AvatarService.spawnModel(player)
	if not player.Parent then
		model:Destroy()
		return
	end
	clearCharacter(player)
	RigBuilder.equip(model, charId)
	RigBuilder.setNameplate(model, plateText(player, def), def.color)
	model.Name = player.Name
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.MaxHealth = def.maxHealth
	hum.Health = def.maxHealth
	hum.WalkSpeed = def.walkSpeed
	RigBuilder.place(model, MapService.getSpawn())
	player.Character = model
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(player)
	end)
	Combat.register(model, player, charId)
	Remotes.Selected:FireClient(player, charId)
	Combat.fx("Spawn", { model = model, pos = root.Position })
end

local function inCombat(ent: Entity): boolean
	return ent.lastHitBy ~= nil and os.clock() - ent.lastHitTime < COMBAT_LOCK
end

-- 클라이언트 요청: 캐릭터 선택 (처음이면 스폰, 살아 있으면 그 자리에서 무브셋 교체)
function CharacterService.select(player: Player, payload: any)
	local charId = if typeof(payload) == "table" then payload.charId else nil
	if typeof(charId) ~= "string" then
		return
	end
	local def = CharacterDefs.get(charId)
	if not def then
		return
	end
	local ent = Combat.fromPlayer(player)
	if ent and ent.alive then
		if ent.charId == charId then
			Remotes.Selected:FireClient(player, charId)
			return
		end
		if inCombat(ent) then
			Combat.notify(ent, "n.combat_lock", "warn", { n = COMBAT_LOCK })
			return
		end
		chosen[player] = charId
		Combat.changeCharacter(ent, charId)
		RigBuilder.setNameplate(ent.model, plateText(player, def), def.color)
		Remotes.Selected:FireClient(player, charId)
		return
	end
	if ent and not ent.alive then
		-- 죽어 있는 동안 고르면 부활할 때 적용
		chosen[player] = charId
		Remotes.Notify:FireClient(player, "n.respawn_as", "info", { char = CharacterDefs.names(def) })
		return
	end
	CharacterService.spawnPlayer(player, charId)
end

----------------------------------------------------------------------
-- 킬 기록 (리더보드)
----------------------------------------------------------------------
-- 리더보드 항목 이름은 모두에게 같은 글자로 보이므로 두 언어 모두 알아보는 짧은 이름을 쓴다
local STAT_KILLS = "KO"
local STAT_STREAK = "Streak"

local function setupStats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local kills = Instance.new("IntValue")
	kills.Name = STAT_KILLS
	kills.Parent = stats
	local streak = Instance.new("IntValue")
	streak.Name = STAT_STREAK
	streak.Parent = stats
	stats.Parent = player
end

local function statOf(player: Player?, name: string): IntValue?
	if not player then
		return nil
	end
	local stats = player:FindFirstChild("leaderstats")
	local v = stats and stats:FindFirstChild(name)
	return if v and v:IsA("IntValue") then v else nil
end

function CharacterService.recordKill(killer: Entity?, victim: Entity)
	local vs = statOf(victim.player, STAT_STREAK)
	if vs then
		vs.Value = 0
	end
	if killer and killer ~= victim then
		local k = statOf(killer.player, STAT_KILLS)
		if k then
			k.Value += 1
		end
		local s = statOf(killer.player, STAT_STREAK)
		if s then
			s.Value += 1
			if s.Value >= 3 and killer.player then
				Remotes.Notify:FireAllClients("n.streak", "awaken", { player = killer.player.DisplayName, n = s.Value })
			end
		end
	end
end

----------------------------------------------------------------------
-- 훈련용 허수아비
----------------------------------------------------------------------
type Dummy = { ent: Entity?, home: CFrame, mode: string }
local dummies: { Dummy } = {}

local function spawnDummy(d: Dummy)
	local model = RigBuilder.buildDummy()
	local key = if d.mode == "block" then "plate.dummy_block" else "plate.dummy"
	model.Name = Locale.t(key, nil, "en")
	RigBuilder.prepare(model, { displayName = Locale.both(key), collisionGroup = "Characters" })
	local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	hum.MaxHealth = 200
	hum.Health = 200
	hum.WalkSpeed = 0
	RigBuilder.place(model, d.home)
	model.Parent = workspace
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	local ent = Combat.register(model, nil, "Dummy", { dummy = true })
	d.ent = ent
	if d.mode == "block" then
		ent.data.alwaysBlock = true
	end
end

local function dummyTick()
	local t = os.clock()
	for _, d in dummies do
			local ent = d.ent
			if not ent or not ent.model.Parent then
				spawnDummy(d)
			elseif ent.alive then
				if ent.data.alwaysBlock and not ent.blocking and not Combat.isStunned(ent) and not Combat.isBusy(ent) then
					ent.blocking = true
					ent.blockStart = t - 1
					Combat.anim(ent, "block_Dummy")
				end
				-- 한동안 맞지 않았고 멀리 밀려났으면 제자리로
				local far = (ent.root.Position - d.home.Position).Magnitude > 6
				if far and t - ent.lastHitTime > 4 and not Combat.isStunned(ent) then
					RigBuilder.place(ent.model, d.home)
					ent.root.AssemblyLinearVelocity = Vector3.zero
					ent.humanoid.Health = ent.humanoid.MaxHealth
					Combat.fx("Spawn", { model = ent.model, pos = ent.root.Position })
				elseif t - ent.lastHitTime > 4 then
					ent.humanoid.Health = ent.humanoid.MaxHealth
				end
			end
		end
end

local function dummyLoop()
	while true do
		task.wait(0.5)
		local ok, err = pcall(dummyTick :: any)
		if not ok and Combat.onError then
			Combat.onError("허수아비", err)
		end
	end
end

----------------------------------------------------------------------
function CharacterService.init()
	Players.CharacterAutoLoads = false

	local spots = MapService.getDummySpots()
	for i, cf in spots do
		table.insert(dummies, { ent = nil, home = cf, mode = if i == 2 then "block" else "normal" })
	end
	for _, d in dummies do
		spawnDummy(d)
	end
	task.spawn(dummyLoop)

	Combat.onDied = function(ent: Entity)
		local killer = ent.lastHitBy
		CharacterService.recordKill(if killer and os.clock() - ent.lastHitTime < 12 then killer else nil, ent)
		task.wait(Config.RespawnDelay)
		local player = ent.player
		if player then
			if player.Parent and player.Character == ent.model then
				local charId = chosen[player]
				if charId then
					CharacterService.spawnPlayer(player, charId)
				else
					clearCharacter(player)
				end
			end
		elseif ent.isBot then
			local cb = CharacterService.onBotDied
			if cb then
				cb(ent)
			end
		elseif ent.model.Parent then
			ent.model:Destroy()
		end
	end

	local function onPlayer(player: Player)
		setupStats(player)
		-- 아바타를 미리 불러와 선택 화면 미리보기를 준비한다
		task.spawn(function()
			local ok, err = pcall(AvatarService.base, player)
			if not ok and Combat.onError then
				Combat.onError("아바타 불러오기", err)
			end
		end)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, p in Players:GetPlayers() do
		onPlayer(p)
	end

	Players.PlayerRemoving:Connect(function(player)
		chosen[player] = nil
		local c = player.Character
		if c then
			c:Destroy()
		end
		AvatarService.forget(player)
	end)
end

return CharacterService
