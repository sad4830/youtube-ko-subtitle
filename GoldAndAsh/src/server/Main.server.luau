--!strict
-- 서버 진입점

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local MapService = require(script.Parent.MapService)
local Combat = require(script.Parent.Combat)
local Actions = require(script.Parent.Actions)
require(script.Parent.Moves.LinYuan)
require(script.Parent.Moves.KanzakiRen)
local CharacterService = require(script.Parent.CharacterService)
local Bot = require(script.Parent.Bot)

Players.CharacterAutoLoads = false

-- 충돌 그룹: 캐릭터끼리는 서로 통과하고(가강전처럼 몸으로 밀어 날리는 버그 방지),
-- 부서져 날아가는 파편도 캐릭터와 부딪히지 않는다. 캐릭터와 맵은 정상적으로 충돌한다.
for _, g in { "Characters", "Debris" } do
	if not PhysicsService:IsCollisionGroupRegistered(g) then
		PhysicsService:RegisterCollisionGroup(g)
	end
end
PhysicsService:CollisionGroupSetCollidable("Characters", "Characters", false)
PhysicsService:CollisionGroupSetCollidable("Debris", "Characters", false)

MapService.init()
Combat.MapService = MapService
Combat.start()
CharacterService.init()
Bot.init()

-- 초당 요청 수 제한 (간단한 스팸 방지)
local budget: { [Player]: number } = {}
task.spawn(function()
	while true do
		task.wait(1)
		table.clear(budget)
	end
end)

Remotes.Action.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
	if typeof(action) ~= "string" then
		return
	end
	local used = (budget[player] or 0) + 1
	budget[player] = used
	if used > 40 then
		return
	end

	if action == "Select" then
		CharacterService.select(player, payload)
		return
	elseif action == "SpawnBot" then
		local charId = if typeof(payload) == "table" and typeof(payload.charId) == "string" then payload.charId else nil
		if not Bot.spawn(charId) then
			Remotes.Notify:FireClient(player, "봇은 최대 3명까지 소환할 수 있다", "warn")
		end
		return
	elseif action == "ClearBots" then
		Bot.clear()
		return
	end

	local ent = Combat.fromPlayer(player)
	if ent and ent.alive then
		Actions.handle(ent, action, payload)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	budget[player] = nil
end)
