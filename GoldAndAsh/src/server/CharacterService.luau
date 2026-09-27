--!strict
-- 캐릭터 선택/스폰/부활, 훈련용 허수아비

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local CharacterDefs = require(Shared.CharacterDefs)
local RigBuilder = require(Shared.RigBuilder)

local Combat = require(script.Parent.Combat)
local MapService = require(script.Parent.MapService)

type Entity = Combat.Entity

local CharacterService = {}

local chosen: { [Player]: string } = {}
CharacterService.onBotDied = nil :: ((ent: Entity) -> ())?

local function clearCharacter(player: Player)
	local old = player.Character
	if old then
		player.Character = nil
		old:Destroy()
	end
end

function CharacterService.spawnPlayer(player: Player, charId: string)
	if not CharacterDefs.get(charId) or not player.Parent then
		return
	end
	chosen[player] = charId
	clearCharacter(player)
	local model = RigBuilder.build(charId)
	model.Name = player.Name
	RigBuilder.place(model, MapService.getSpawn())
	local plate = model:FindFirstChild("Nameplate", true)
	if plate then
		local label = plate:FindFirstChild("NameLabel")
		if label and label:IsA("TextLabel") then
			label.Text = label.Text .. " · " .. player.DisplayName
		end
	end
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

-- 클라이언트 요청: 캐릭터 선택
function CharacterService.select(player: Player, payload: any)
	local charId = if typeof(payload) == "table" then payload.charId else nil
	if typeof(charId) ~= "string" or not CharacterDefs.get(charId) then
		return
	end
	local ent = Combat.fromPlayer(player)
	if ent and ent.alive and os.clock() - ent.lastHitTime < 5 and ent.lastHitBy ~= nil then
		Combat.notify(ent, "전투 중에는 캐릭터를 바꿀 수 없다 (5초)", "warn")
		return
	end
	CharacterService.spawnPlayer(player, charId)
end

-- 클라이언트 요청: 선택 화면으로 돌아가기
function CharacterService.unselect(player: Player)
	local ent = Combat.fromPlayer(player)
	if ent and ent.alive and os.clock() - ent.lastHitTime < 5 and ent.lastHitBy ~= nil then
		Combat.notify(ent, "전투 중에는 나갈 수 없다 (5초)", "warn")
		return
	end
	chosen[player] = nil
	clearCharacter(player)
	Remotes.Selected:FireClient(player, nil)
end

----------------------------------------------------------------------
-- 훈련용 허수아비
----------------------------------------------------------------------
type Dummy = { ent: Entity?, home: CFrame, mode: string }
local dummies: { Dummy } = {}

local function spawnDummy(d: Dummy)
	local model = RigBuilder.build("Dummy")
	model.Name = if d.mode == "block" then "훈련용 허수아비 (막기)" else "훈련용 허수아비"
	local plate = model:FindFirstChild("Nameplate", true)
	if plate then
		local label = plate:FindFirstChild("NameLabel")
		if label and label:IsA("TextLabel") then
			label.Text = model.Name
		end
	end
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

local function dummyLoop()
	while true do
		task.wait(0.5)
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

	Players.PlayerRemoving:Connect(function(player)
		chosen[player] = nil
		local c = player.Character
		if c then
			c:Destroy()
		end
	end)
end

return CharacterService
