--!strict
-- 서버 진입점

local Players = game:GetService("Players")

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
	elseif action == "Unselect" then
		CharacterService.unselect(player)
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
