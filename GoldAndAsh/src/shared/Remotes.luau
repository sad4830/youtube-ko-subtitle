--!strict
-- 서버/클라이언트가 같은 RemoteEvent를 쓰도록 이름을 한 곳에서 관리한다.
-- 서버에서 require 하면 생성하고, 클라이언트에서 require 하면 생길 때까지 기다린다.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES = {
	"Action", -- C->S : (action: string, payload: any)
	"Anim", -- S->C : (model, animName, speed?) / (model, nil) = 전부 정지
	"FX", -- S->C : (fxName, data)
	"Push", -- S->C(소유자) : (velocity, duration)
	"Ragdoll", -- S->C(소유자) : (enabled)
	"Notify", -- S->C : (text, kind)
	"Cooldown", -- S->C(소유자) : (key, endsAt(serverTime), duration)
	"Feed", -- S->C : (killerText, victimText)
	"Selected", -- S->C(소유자) : (charId)  캐릭터 선택 결과
}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	for _, name in NAMES do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

local function get(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

return {
	Action = get("Action"),
	Anim = get("Anim"),
	FX = get("FX"),
	Push = get("Push"),
	Ragdoll = get("Ragdoll"),
	Notify = get("Notify"),
	Cooldown = get("Cooldown"),
	Feed = get("Feed"),
	Selected = get("Selected"),
}
