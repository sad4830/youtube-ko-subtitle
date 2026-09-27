--!strict
-- 입력: 키보드/마우스, 게임패드, 모바일 버튼
-- 대시는 반응성을 위해 클라이언트가 먼저 움직이고(예측) 서버에 알린다.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Physics = require(Shared.Physics)

local Animator = require(script.Parent.Animator)
local VFX = require(script.Parent.VFX)
local UI = require(script.Parent.UI)

local Input = {}
Input.send = nil :: ((action: string, payload: any) -> ())?

local player = Players.LocalPlayer
local m1Held = false
local blockHeld = false
local m1Timer = 0
local blockTimer = 0
local UP = Vector3.new(0, 1, 0)

local function send(a: string, p: any)
	local cb = Input.send
	if cb then
		cb(a, p)
	end
end

local function char(): (Model?, Humanoid?, BasePart?)
	local c = player.Character
	if not c then
		return nil, nil, nil
	end
	local hum = c:FindFirstChildOfClass("Humanoid")
	local root = c:FindFirstChild("HumanoidRootPart")
	if hum and root and root:IsA("BasePart") and hum.Health > 0 then
		return c, hum, root
	end
	return nil, nil, nil
end

local function flat(v: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	return if f.Magnitude > 0.05 then f.Unit else Vector3.new(0, 0, -1)
end

local function aim(): Vector3
	local cam = workspace.CurrentCamera
	if cam then
		return flat(cam.CFrame.LookVector)
	end
	local _, _, root = char()
	return if root then flat(root.CFrame.LookVector) else Vector3.new(0, 0, -1)
end

local function canFace(c: Model): boolean
	return c:GetAttribute("Stunned") ~= true and c:GetAttribute("Busy") ~= true
end

-- 공격 방향으로 몸을 돌린다 (클라이언트가 자기 캐릭터 물리를 소유)
local function face(dir: Vector3)
	local c, _, root = char()
	if c and root and canFace(c) then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	end
end

function Input.applyPush(vel: Vector3, duration: number)
	local _, _, root = char()
	if root then
		Physics.push(root, vel, duration)
	end
end

----------------------------------------------------------------------
function Input.m1()
	local c = char()
	if not c then
		return
	end
	local a = aim()
	face(a)
	send("M1", { aim = a, jump = UserInputService:IsKeyDown(Enum.KeyCode.Space) })
end

function Input.skill(slot: number)
	local c = char()
	if not c then
		return
	end
	local a = aim()
	face(a)
	send("Skill", { slot = slot, aim = a, jump = UserInputService:IsKeyDown(Enum.KeyCode.Space) })
end

function Input.awaken()
	if char() then
		send("Awaken", nil)
	end
end

function Input.setBlock(on: boolean)
	blockHeld = on
	blockTimer = 0
	if char() then
		send("Block", { on = on })
	end
end

function Input.setM1Held(on: boolean)
	m1Held = on
	if on then
		m1Timer = 0
		Input.m1()
	end
end

local function dashDirection(hum: Humanoid): string
	local keys = UserInputService
	if keys:IsKeyDown(Enum.KeyCode.A) then
		return "left"
	elseif keys:IsKeyDown(Enum.KeyCode.D) then
		return "right"
	elseif keys:IsKeyDown(Enum.KeyCode.S) then
		return "back"
	elseif keys:IsKeyDown(Enum.KeyCode.W) then
		return "front"
	end
	-- 모바일/패드: 이동 방향을 카메라 기준으로 해석
	local md = hum.MoveDirection
	if md.Magnitude > 0.3 then
		local fwd = aim()
		local right = fwd:Cross(UP)
		local f = md:Dot(fwd)
		local r = md:Dot(right)
		if math.abs(f) >= math.abs(r) then
			return if f >= 0 then "front" else "back"
		end
		return if r >= 0 then "right" else "left"
	end
	return "front"
end

function Input.dash()
	local c, hum, root = char()
	if not c or not hum or not root then
		return
	end
	local dir = dashDirection(hum)
	local a = aim()
	if c:GetAttribute("Stunned") == true then
		-- 회피는 서버가 판단한다
		send("Dash", { dir = "back", aim = a })
		return
	end
	if c:GetAttribute("Busy") == true or c:GetAttribute("Blocking") == true then
		return
	end
	local key = if dir == "front" then "DashFront" else "DashSide"
	if UI.cooldownLeft(key) > 0 then
		return
	end
	local right = a:Cross(UP)
	local vel: Vector3
	local time: number
	if dir == "front" then
		vel, time = a * Config.Dash.FrontSpeed, Config.Dash.FrontTime
		root.CFrame = CFrame.lookAt(root.Position, root.Position + a)
	elseif dir == "back" then
		vel, time = -a * Config.Dash.SideSpeed, Config.Dash.SideTime
	elseif dir == "left" then
		vel, time = -right * Config.Dash.SideSpeed, Config.Dash.SideTime
	else
		vel, time = right * Config.Dash.SideSpeed, Config.Dash.SideTime
	end
	Input.applyPush(vel, time)
	local cid = c:GetAttribute("CharId")
	local animName = if dir == "front" and cid == "LinYuan" then "dash_front_LinYuan" else "dash_" .. dir
	Animator.play(c, animName)
	VFX.dashEffect(c)
	local cd = if dir == "front" then Config.Dash.FrontCooldown else Config.Dash.SideCooldown
	UI.setCooldown(key, workspace:GetServerTimeNow() + cd, cd)
	send("Dash", { dir = dir, aim = a })
end

----------------------------------------------------------------------
local SKILL_KEYS: { [Enum.KeyCode]: number } = {
	[Enum.KeyCode.One] = 1,
	[Enum.KeyCode.Two] = 2,
	[Enum.KeyCode.Three] = 3,
	[Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.KeypadOne] = 1,
	[Enum.KeyCode.KeypadTwo] = 2,
	[Enum.KeyCode.KeypadThree] = 3,
	[Enum.KeyCode.KeypadFour] = 4,
	[Enum.KeyCode.DPadUp] = 1,
	[Enum.KeyCode.DPadRight] = 2,
	[Enum.KeyCode.DPadDown] = 3,
	[Enum.KeyCode.DPadLeft] = 4,
}

function Input.init()
	UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
		if processed then
			return
		end
		local kc = input.KeyCode
		local t = input.UserInputType
		if t == Enum.UserInputType.MouseButton1 or kc == Enum.KeyCode.ButtonR2 then
			Input.setM1Held(true)
		elseif kc == Enum.KeyCode.F or kc == Enum.KeyCode.ButtonL2 then
			Input.setBlock(true)
		elseif kc == Enum.KeyCode.Q or kc == Enum.KeyCode.ButtonB then
			Input.dash()
		elseif kc == Enum.KeyCode.G or kc == Enum.KeyCode.ButtonY then
			Input.awaken()
		elseif kc == Enum.KeyCode.H then
			UI.toggleHelp()
		else
			local slot = SKILL_KEYS[kc]
			if slot then
				Input.skill(slot)
			end
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		local kc = input.KeyCode
		if input.UserInputType == Enum.UserInputType.MouseButton1 or kc == Enum.KeyCode.ButtonR2 then
			m1Held = false
		elseif kc == Enum.KeyCode.F or kc == Enum.KeyCode.ButtonL2 then
			Input.setBlock(false)
		end
	end)
	RunService.Heartbeat:Connect(function(dt: number)
		if m1Held then
			m1Timer += dt
			if m1Timer >= 0.1 then
				m1Timer = 0
				Input.m1()
			end
		end
		-- 막기 키를 누르고 있는데 (스턴이 풀리는 등) 막기가 풀려 있으면 다시 요청
		if blockHeld then
			blockTimer += dt
			if blockTimer >= 0.2 then
				blockTimer = 0
				local c = char()
				if c and c:GetAttribute("Blocking") ~= true and c:GetAttribute("Stunned") ~= true and c:GetAttribute("Busy") ~= true then
					send("Block", { on = true })
				end
			end
		end
	end)
end

return Input
