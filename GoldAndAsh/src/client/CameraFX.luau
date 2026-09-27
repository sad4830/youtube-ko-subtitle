--!strict
-- 카메라 연출: 흔들림, FOV 펀치, 임팩트 프레임(색 반전 느낌), 분진막 시야 가림

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local CameraFX = {}

local trauma = 0
local fovOffset = 0
local fovTarget = 0
local baseFov = 70

local cutsceneTarget: BasePart? = nil
local cutsceneUntil = 0
local cutsceneLength = 1

function CameraFX.cutscene(target: BasePart, duration: number)
	cutsceneTarget = target
	cutsceneLength = duration
	cutsceneUntil = os.clock() + duration
end

local cc: ColorCorrectionEffect
local veilCC: ColorCorrectionEffect
local blur: BlurEffect

function CameraFX.init()
	cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "HitFlashCC"
	cc.Parent = Lighting
	veilCC = Instance.new("ColorCorrectionEffect")
	veilCC.Name = "VeilCC"
	veilCC.Parent = Lighting
	blur = Instance.new("BlurEffect")
	blur.Name = "VeilBlur"
	blur.Size = 0
	blur.Parent = Lighting

	RunService:BindToRenderStep("CameraFX", Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		trauma = math.max(0, trauma - dt * 1.8)
		fovOffset += (fovTarget - fovOffset) * math.min(1, dt * 14)
		fovTarget += (0 - fovTarget) * math.min(1, dt * 6)
		cam.FieldOfView = baseFov + fovOffset
		-- 각성 컷신: 잠깐 카메라가 캐릭터 정면으로 돌아 들어간다
		local target = cutsceneTarget
		if target and os.clock() < cutsceneUntil and target.Parent then
			local k = 1 - (cutsceneUntil - os.clock()) / cutsceneLength
			local cf = target.CFrame
			local side = math.sin(k * math.pi) * 4
			local dist = 11 - k * 3.5
			local eye = cf.Position + cf.LookVector * dist + cf.RightVector * side + Vector3.new(0, 2.4 - k * 0.8, 0)
			cam.CFrame = CFrame.lookAt(eye, cf.Position + Vector3.new(0, 1.3, 0))
		elseif target then
			cutsceneTarget = nil
		end
		if trauma > 0 then
			local s = trauma * trauma
			local t = os.clock() * 38
			local ox = math.noise(t, 0.3) * 1.2 * s
			local oy = math.noise(0.7, t) * 1.2 * s
			local rz = math.noise(t, t * 0.5) * 0.05 * s
			cam.CFrame = cam.CFrame * CFrame.new(ox, oy, 0) * CFrame.Angles(0, 0, rz)
		end
	end)
end

function CameraFX.shake(amount: number)
	trauma = math.clamp(trauma + amount, 0, 1)
end

function CameraFX.fovPunch(amount: number)
	fovTarget += amount
end

-- 강타 순간 한두 프레임 흑백·고대비로 번쩍
function CameraFX.impact(strength: number?)
	local s = strength or 1
	cc.Saturation = -1 * s
	cc.Contrast = 0.9 * s
	cc.Brightness = 0.12 * s
	task.delay(0.07, function()
		TweenService:Create(cc, TweenInfo.new(0.18), { Saturation = 0, Contrast = 0, Brightness = 0 }):Play()
	end)
end

function CameraFX.flash(color: Color3, time: number?)
	cc.TintColor = color
	TweenService:Create(cc, TweenInfo.new(time or 0.35), { TintColor = Color3.new(1, 1, 1) }):Play()
end

local veilOn = false
function CameraFX.setVeil(on: boolean)
	if on == veilOn then
		return
	end
	veilOn = on
	local info = TweenInfo.new(0.5)
	if on then
		TweenService:Create(veilCC, info, { Brightness = -0.28, Saturation = -0.7, Contrast = 0.15 }):Play()
		TweenService:Create(blur, info, { Size = 12 }):Play()
	else
		TweenService:Create(veilCC, info, { Brightness = 0, Saturation = 0, Contrast = 0 }):Play()
		TweenService:Create(blur, info, { Size = 0 }):Play()
	end
end

----------------------------------------------------------------------
-- 집중선(스피드 라인): 화면 가장자리에서 가운데로 모이는 흰 선. 대시·강타·각성 때 번쩍인다.
----------------------------------------------------------------------
local linesGui: ScreenGui? = nil
local lines: { Frame } = {}
local linesUntil = 0
local linesStrength = 0
local linesColor = Color3.new(1, 1, 1)
local LINE_COUNT = 34

local function ensureLines(): ScreenGui
	local g = linesGui
	if g and g.Parent then
		return g
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "SpeedLines"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	for i = 1, LINE_COUNT do
		local f = Instance.new("Frame")
		f.Name = "Line" .. i
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.BorderSizePixel = 0
		f.BackgroundColor3 = Color3.new(1, 1, 1)
		f.BackgroundTransparency = 1
		f.Parent = gui
		lines[i] = f
	end
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	linesGui = gui
	return gui
end

function CameraFX.speedLines(duration: number, strength: number?, color: Color3?)
	ensureLines()
	linesUntil = math.max(linesUntil, os.clock() + duration)
	linesStrength = math.max(linesStrength, strength or 1)
	linesColor = color or Color3.new(1, 1, 1)
end

RunService.RenderStepped:Connect(function()
	if #lines == 0 then
		return
	end
	local now = os.clock()
	local active = now < linesUntil
	if not active then
		if linesStrength > 0 then
			linesStrength = 0
			for _, f in lines do
				f.BackgroundTransparency = 1
			end
		end
		return
	end
	local cam = workspace.CurrentCamera
	local vp = if cam then cam.ViewportSize else Vector2.new(1280, 720)
	local diag = vp.Magnitude * 0.5
	local fade = math.clamp((linesUntil - now) / 0.15, 0, 1)
	for i, f in lines do
		-- 매 프레임 조금씩 흔들려서 만화 같은 떨림을 준다
		local a = (i / LINE_COUNT) * math.pi * 2 + math.random() * 0.18
		local len = diag * (0.25 + math.random() * 0.35) * linesStrength
		local r = diag * (0.78 + math.random() * 0.12) - len * 0.5
		local x = vp.X * 0.5 + math.cos(a) * r
		local y = vp.Y * 0.5 + math.sin(a) * r
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(len, math.max(1, (2 + math.random() * 3) * linesStrength))
		f.Rotation = math.deg(a)
		f.BackgroundColor3 = linesColor
		f.BackgroundTransparency = 1 - (0.35 + math.random() * 0.4) * fade
	end
end)

return CameraFX
