--!strict
-- 클라이언트 진입점

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Sounds = require(Shared.Sounds)
local CharacterDefs = require(Shared.CharacterDefs)

local Animator = require(script.Parent.Animator)
local CameraFX = require(script.Parent.CameraFX)
local VFX = require(script.Parent.VFX)
local UI = require(script.Parent.UI)
local Input = require(script.Parent.Input)

local player = Players.LocalPlayer

Animator.start()
CameraFX.init()
VFX.init()
UI.init()
Input.init()

VFX.onCombo = UI.combo
VFX.onAwakenTitle = UI.awakenTitle
VFX.onAwakenReady = UI.awakenReady

Input.send = function(action: string, payload: any)
	Remotes.Action:FireServer(action, payload)
end

UI.onSelect = function(charId: string)
	Remotes.Action:FireServer("Select", { charId = charId })
end

UI.onAction = function(name: string, payload: any)
	if name == "SkillTap" then
		Input.skill(payload :: number)
	elseif name == "M1Hold" then
		Input.setM1Held(payload == true)
	elseif name == "BlockHold" then
		Input.setBlock(payload == true)
	elseif name == "DashTap" then
		Input.dash()
	elseif name == "AwakenTap" then
		Input.awaken()
	else
		Remotes.Action:FireServer(name, payload)
	end
end

----------------------------------------------------------------------
-- 서버 → 클라이언트
----------------------------------------------------------------------
Remotes.Anim.OnClientEvent:Connect(function(model: Model?, name: string?, speed: number?)
	if not model then
		return
	end
	if name then
		Animator.play(model, name, speed)
	else
		Animator.stop(model)
	end
end)

Remotes.FX.OnClientEvent:Connect(function(name: string, data: any)
	VFX.handle(name, data)
end)

Remotes.Push.OnClientEvent:Connect(function(vel: Vector3, duration: number)
	Input.applyPush(vel, duration)
end)

Remotes.Ragdoll.OnClientEvent:Connect(function(on: boolean)
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	local root = c and c:FindFirstChild("HumanoidRootPart")
	if hum then
		if on then
			hum:ChangeState(Enum.HumanoidStateType.Physics)
		else
			-- 넘어진 몸을 똑바로 세운 뒤 일어난다 (옆으로 누운 채 튀어 오르는 현상 방지)
			if root and root:IsA("BasePart") then
				local pos = root.Position
				local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
				if look.Magnitude < 0.1 then
					look = Vector3.new(0, 0, -1)
				end
				local up = pos + Vector3.new(0, 1.2, 0)
				root.AssemblyLinearVelocity = Vector3.zero
				root.AssemblyAngularVelocity = Vector3.zero
				root.CFrame = CFrame.lookAt(up, up + look.Unit)
			end
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end)

Remotes.Notify.OnClientEvent:Connect(function(text: string, kind: string?)
	UI.notify(text, kind)
end)

Remotes.Cooldown.OnClientEvent:Connect(function(key: string, endsAt: number, duration: number)
	UI.setCooldown(key, endsAt, duration)
end)

Remotes.Feed.OnClientEvent:Connect(function(killer: string, victim: string)
	UI.feed(killer, victim)
end)

----------------------------------------------------------------------
-- 카메라 / 음악 / 화면 전환
----------------------------------------------------------------------
local selecting = true
local selectT = 0

local function selectCameraCFrame(): CFrame
	local map = workspace:FindFirstChild("Map")
	local part = map and map:FindFirstChild("SelectCamera")
	if part and part:IsA("BasePart") then
		return part.CFrame
	end
	return CFrame.lookAt(Vector3.new(0, 25, 70), Vector3.new(0, 4, 0))
end

local function enterSelect()
	selecting = true
	UI.showSelect(true, false)
	UI.setDead(false)
	Sounds.playMusic("lobby")
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Scriptable
	end
end

local function enterGame(charId: string)
	selecting = false
	UI.setCharacter(charId)
	UI.showSelect(false)
	Sounds.playMusic("battle")
	-- CharacterAdded 가 선택 결과보다 먼저 올 수도 있으니 여기서도 카메라를 돌려놓는다
	local cam = workspace.CurrentCamera
	local c = player.Character
	local hum = c and c:FindFirstChildOfClass("Humanoid")
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		if hum then
			cam.CameraSubject = hum
		end
	end
end

RunService.RenderStepped:Connect(function(dt: number)
	if selecting then
		selectT += dt
		local cam = workspace.CurrentCamera
		if cam then
			cam.CameraType = Enum.CameraType.Scriptable
			local base = selectCameraCFrame()
			cam.CFrame = base * CFrame.new(math.sin(selectT * 0.2) * 3, math.sin(selectT * 0.13) * 0.8, 0) * CFrame.Angles(0, math.sin(selectT * 0.2) * 0.03, 0)
		end
	end
end)

Remotes.Selected.OnClientEvent:Connect(function(charId: string?)
	if charId then
		enterGame(charId)
	else
		enterSelect()
	end
end)

local function onCharacter(c: Model)
	local hum = c:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = Enum.CameraType.Custom
		cam.CameraSubject = hum
	end
	UI.setDead(false)
	-- 자기 머리 위 이름표는 숨긴다
	local plate = c:FindFirstChild("Nameplate", true)
	if plate and plate:IsA("BillboardGui") then
		plate.Enabled = false
	end
	hum.Died:Connect(function()
		UI.setDead(true)
		Sounds.playMusic("battle")
	end)
	-- 각성 시 캐릭터 테마곡
	c:GetAttributeChangedSignal("Awakened"):Connect(function()
		local cid = c:GetAttribute("CharId")
		local def = if typeof(cid) == "string" then CharacterDefs.get(cid) else nil
		if c:GetAttribute("Awakened") == true and def then
			Sounds.playMusic(def.music)
		elseif not selecting then
			Sounds.playMusic("battle")
		end
	end)
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

-- 다른 캐릭터들의 머리 위 체력바 갱신
RunService.Heartbeat:Connect(function()
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m ~= player.Character then
			local hum = m:FindFirstChildOfClass("Humanoid")
			local head = m:FindFirstChild("Head")
			local plate = head and head:FindFirstChild("Nameplate")
			if hum and plate then
				local bar = plate:FindFirstChild("Bar")
				local fill = bar and bar:FindFirstChild("Fill")
				if fill and fill:IsA("Frame") then
					fill.Size = UDim2.fromScale(math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1), 1)
				end
			end
		end
	end
end)

enterSelect()
