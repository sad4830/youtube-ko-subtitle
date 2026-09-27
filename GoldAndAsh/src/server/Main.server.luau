--!strict
-- 서버 진입점
-- 어느 단계에서든 오류가 나면 조용히 멈추지 않고, ReplicatedStorage.ServerErrors 에 기록해
-- 플레이어 화면에 빨간 글씨로 보여 준다 (원인을 캡처 한 장으로 알 수 있게).

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local errorsValue = Instance.new("StringValue")
errorsValue.Name = "ServerErrors"
errorsValue.Parent = ReplicatedStorage

local reported: { [string]: boolean } = {}
local function report(where: string, err: any)
	local msg = where .. ": " .. tostring(err)
	warn("[금빛과 재] " .. msg)
	local key = string.sub(msg, 1, 160)
	if reported[key] then
		return
	end
	reported[key] = true
	errorsValue.Value = string.sub(errorsValue.Value .. msg .. "\n", -1800)
end

local function safe(where: string, fn: (...any) -> ...any, ...: any): boolean
	local ok, err = xpcall(fn, debug.traceback, ...)
	if not ok then
		report(where, err)
	end
	return ok
end

Players.CharacterAutoLoads = false

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)

-- 충돌 그룹: 캐릭터끼리는 서로 통과하고(가강전처럼 몸으로 밀어 날리는 버그 방지),
-- 부서져 날아가는 파편도 캐릭터와 부딪히지 않는다. 캐릭터와 맵은 정상적으로 충돌한다.
safe("충돌 그룹", function()
	for _, g in { "Characters", "Debris" } do
		if not PhysicsService:IsCollisionGroupRegistered(g) then
			PhysicsService:RegisterCollisionGroup(g)
		end
	end
	PhysicsService:CollisionGroupSetCollidable("Characters", "Characters", false)
	PhysicsService:CollisionGroupSetCollidable("Debris", "Characters", false)
end)

local MapService = require(script.Parent.MapService)
local Combat = require(script.Parent.Combat)
local Actions = require(script.Parent.Actions)
require(script.Parent.Moves.LinYuan)
require(script.Parent.Moves.KanzakiRen)
local CharacterService = require(script.Parent.CharacterService)
local Bot = require(script.Parent.Bot)

Combat.onError = report

safe("맵", MapService.init)
Combat.MapService = MapService
safe("전투", Combat.start)
safe("캐릭터", CharacterService.init)
safe("봇", Bot.init)

-- 초당 요청 수 제한 (간단한 스팸 방지)
local budget: { [Player]: number } = {}
task.spawn(function()
	while true do
		task.wait(1)
		table.clear(budget)
	end
end)

local function handle(player: Player, action: string, payload: any)
	if action == "Select" then
		CharacterService.select(player, payload)
		return
	elseif action == "SpawnBot" then
		local charId = if typeof(payload) == "table" and typeof(payload.charId) == "string" then payload.charId else nil
		if not Bot.spawn(charId) then
			Remotes.Notify:FireClient(player, "n.bot_limit", "warn", { n = Config.MaxBots })
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
end

Remotes.Action.OnServerEvent:Connect(function(player: Player, action: any, payload: any)
	if typeof(action) ~= "string" then
		return
	end
	local used = (budget[player] or 0) + 1
	budget[player] = used
	if used > 40 then
		return
	end
	if not safe("요청 " .. action, handle, player, action, payload) then
		Remotes.Notify:FireClient(player, "n.server_error", "warn")
	end
end)

Players.PlayerRemoving:Connect(function(player)
	budget[player] = nil
end)
