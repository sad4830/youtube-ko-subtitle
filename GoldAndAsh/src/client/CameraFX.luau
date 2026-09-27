--!strict
-- 카메라 연출: 흔들림, FOV 펀치, 임팩트 프레임(색 반전 느낌), 분진막 시야 가림

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local CameraFX = {}

local trauma = 0
local fovOffset = 0
local fovTarget = 0
local baseFov = 70

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

return CameraFX
