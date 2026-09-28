--!strict
-- 시각 효과 라이브러리 (전부 파트/파티클/빛으로 만든다 — 업로드한 텍스처나 메시 없음)
-- 서버가 Remotes.FX 로 (이름, 데이터)를 보내면 VFX.handle 이 해당 연출을 재생한다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local PhysicsService = game:GetService("PhysicsService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sounds = require(Shared.Sounds)
local CharacterDefs = require(Shared.CharacterDefs)

local Animator = require(script.Parent.Animator)
local CameraFX = require(script.Parent.CameraFX)

local VFX = {}
VFX.onCombo = nil :: ((count: number) -> ())?
VFX.onAwakenTitle = nil :: ((model: Model, charId: string) -> ())?
VFX.onAwakenReady = nil :: (() -> ())?

local player = Players.LocalPlayer
local folder: Folder

local GOLD = Color3.fromRGB(255, 196, 74)
local GOLD_LIGHT = Color3.fromRGB(255, 236, 170)
local RED = Color3.fromRGB(230, 40, 50)
local ASH = Color3.fromRGB(18, 16, 18)
local ASH_GREY = Color3.fromRGB(60, 56, 58)

local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local rng = Random.new()

----------------------------------------------------------------------
-- 기본 도구
----------------------------------------------------------------------
-- t 초 뒤에 지운다. Debris 서비스는 대기열이 1000개를 넘으면 오래된 것부터 바로 지워 버려서
-- (잔해가 쏟아지면 다른 잔해·소리·넉백까지 일찍 끊긴다) 여기서는 쓰지 않는다. 두 번 지워도 괜찮다.
local function destroyLater(inst: Instance, t: number)
	task.delay(t, function()
		inst:Destroy()
	end)
end

local function newPart(size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Neon
	p.Transparency = transparency or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder
	return p
end

local function ball(diameter: number, pos: Vector3, color: Color3, transparency: number?, material: Enum.Material?): Part
	local p = newPart(Vector3.new(diameter, diameter, diameter), CFrame.new(pos), color, material, transparency)
	p.Shape = Enum.PartType.Ball
	return p
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function fadeOut(p: BasePart, time: number, grow: Vector3?)
	local props: { [string]: any } = { Transparency = 1 }
	if grow then
		props.Size = grow
	end
	tween(p, time, props)
	destroyLater(p, time + 0.05)
end

-- 둥근 고리 (원기둥을 납작하게 눕힘)
local function ring(pos: Vector3, normal: Vector3, diameter: number, endDiameter: number, color: Color3, time: number, thickness: number?, transparency: number?)
	local up = if math.abs(normal.Y) > 0.99 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt(pos, pos + normal, up) * CFrame.Angles(0, math.rad(90), 0)
	local th = thickness or 0.25
	local p = newPart(Vector3.new(th, diameter, diameter), cf, color, Enum.Material.Neon, transparency or 0.1)
	p.Shape = Enum.PartType.Cylinder
	tween(p, time, { Size = Vector3.new(th * 0.3, endDiameter, endDiameter), Transparency = 1 })
	destroyLater(p, time + 0.05)
end

-- 파티클 한 번 뿜기
local function emit(pos: Vector3, count: number, props: {
	texture: string?,
	color: Color3?,
	color2: Color3?,
	size: number?,
	size2: number?,
	speed: number?,
	life: number?,
	spread: number?,
	light: number?,
	transparency: number?,
	drag: number?,
	accel: Vector3?,
	rot: number?,
})
	local holder = newPart(Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, 1)
	local att = Instance.new("Attachment")
	att.Parent = holder
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = props.texture or TEX_SPARK
	local c1 = props.color or Color3.new(1, 1, 1)
	pe.Color = ColorSequence.new(c1, props.color2 or c1)
	local s = props.size or 1
	pe.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, s),
		NumberSequenceKeypoint.new(1, props.size2 or s * 0.2),
	})
	local tr = props.transparency or 0
	pe.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, tr),
		NumberSequenceKeypoint.new(1, 1),
	})
	local life = props.life or 0.5
	pe.Lifetime = NumberRange.new(life * 0.6, life)
	local sp = props.speed or 10
	pe.Speed = NumberRange.new(sp * 0.5, sp)
	local spread = props.spread or 180
	pe.SpreadAngle = Vector2.new(spread, spread)
	pe.LightEmission = props.light or 0.8
	pe.Drag = props.drag or 3
	pe.Acceleration = props.accel or Vector3.zero
	pe.Rotation = NumberRange.new(0, 360)
	pe.RotSpeed = NumberRange.new(-(props.rot or 90), props.rot or 90)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Enabled = false
	pe.Parent = att
	pe:Emit(count)
	destroyLater(holder, life + 0.3)
end

-- 날아가는 파편 (간단한 자체 물리)
type Shard = { part: Part, vel: Vector3, spin: CFrame, life: number, maxLife: number, gravity: number }
local shards: { Shard } = {}

local function shardBurst(pos: Vector3, count: number, color: Color3, speed: number, size: number, life: number, material: Enum.Material?, gravity: number?, dirBias: Vector3?)
	for _ = 1, count do
		local dir = rng:NextUnitVector()
		if dirBias then
			dir = (dir + dirBias).Unit
		end
		local s = size * rng:NextNumber(0.5, 1.2)
		local p = newPart(Vector3.new(s * 0.5, s * 0.5, s * 1.4), CFrame.lookAt(pos, pos + dir), color, material or Enum.Material.Neon, 0)
		table.insert(shards, {
			part = p,
			vel = dir * speed * rng:NextNumber(0.5, 1.1),
			spin = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3)),
			life = life,
			maxLife = life,
			gravity = gravity or 60,
		})
	end
end

local function flash(pos: Vector3, diameter: number, color: Color3, time: number, endScale: number?)
	local b = ball(diameter, pos, color, 0.05)
	local e = diameter * (endScale or 2.2)
	fadeOut(b, time, Vector3.new(e, e, e))
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = diameter * 4
	light.Brightness = 4
	light.Parent = b
	tween(light, time, { Brightness = 0 })
end

local function slashLine(pos: Vector3, length: number, color: Color3, time: number, thickness: number?, cf: CFrame?)
	local th = thickness or 0.18
	local orient = cf or (CFrame.new(pos) * CFrame.Angles(rng:NextNumber(-1.2, 1.2), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-1.2, 1.2)))
	local p = newPart(Vector3.new(th, th, length * 0.3), orient, color, Enum.Material.Neon, 0)
	tween(p, time * 0.35, { Size = Vector3.new(th, th, length) }, Enum.EasingStyle.Quart)
	task.delay(time * 0.35, function()
		tween(p, time * 0.65, { Size = Vector3.new(0.02, 0.02, length * 1.15), Transparency = 1 })
	end)
	destroyLater(p, time + 0.1)
end

local function highlightFlash(model: Model, color: Color3)
	local h = Instance.new("Highlight")
	h.FillColor = color
	h.OutlineColor = color
	h.FillTransparency = 0.25
	h.OutlineTransparency = 0.3
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Parent = model
	tween(h, 0.22, { FillTransparency = 1, OutlineTransparency = 1 })
	destroyLater(h, 0.3)
end

local function afterimage(model: Model, color: Color3, time: number, transparency: number?)
	for _, name in { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" } do
		local src = model:FindFirstChild(name)
		if src and src:IsA("BasePart") then
			local p = newPart(src.Size, src.CFrame, color, Enum.Material.ForceField, transparency or 0.2)
			fadeOut(p, time)
		end
	end
end

local function rootOf(model: Instance?): BasePart?
	if model and model:IsA("Model") then
		local r = model:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then
			return r
		end
	end
	return nil
end

local function isLocal(model: Instance?): boolean
	return model ~= nil and model == player.Character
end

local function groundY(pos: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { folder }
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position.Y else pos.Y - 3
end

local function dust(pos: Vector3, count: number, size: number?, color: Color3?)
	emit(pos, count, {
		texture = TEX_SMOKE,
		color = color or Color3.fromRGB(170, 150, 130),
		size = size or 3,
		size2 = (size or 3) * 2.2,
		speed = 12,
		life = 0.9,
		spread = 70,
		light = 0,
		transparency = 0.35,
		drag = 5,
	})
end

local function ashPuff(pos: Vector3, count: number, size: number?, speed: number?)
	emit(pos, count, {
		texture = TEX_SMOKE,
		color = ASH,
		color2 = ASH_GREY,
		size = size or 2,
		size2 = (size or 2) * 2.5,
		speed = speed or 10,
		life = 1.1,
		spread = 180,
		light = 0,
		transparency = 0.15,
		drag = 4,
		accel = Vector3.new(0, 3, 0),
	})
	emit(pos, math.floor(count / 2), {
		texture = TEX_SPARK,
		color = RED,
		size = 0.5,
		speed = (speed or 10) * 1.5,
		life = 0.5,
		light = 1,
	})
end

----------------------------------------------------------------------
-- 금빛 영력으로 만든 형상들
----------------------------------------------------------------------
local function goldPalm(cf: CFrame, scale: number): { Part }
	local parts = {}
	local function add(size: Vector3, rel: CFrame)
		local p = newPart(size * scale, cf * CFrame.new(rel.Position * scale) * rel.Rotation, GOLD, Enum.Material.Neon, 0.3)
		table.insert(parts, p)
	end
	-- 손바닥 (앞을 보는 커다란 장심)
	add(Vector3.new(5, 5.5, 1.2), CFrame.new(0, 0, 0))
	for i = 1, 4 do
		local x = -2.1 + (i - 1) * 1.4
		local h = if i == 2 or i == 3 then 4.2 else 3.4
		add(Vector3.new(1.15, h, 1.05), CFrame.new(x, 2.75 + h / 2 - 0.3, 0) * CFrame.Angles(math.rad(-8), 0, math.rad((i - 2.5) * -5)))
	end
	add(Vector3.new(1.2, 3, 1.1), CFrame.new(3.2, 0.6, -0.2) * CFrame.Angles(0, 0, math.rad(-50)))
	return parts
end

----------------------------------------------------------------------
-- 황금 용 (뱀처럼 이어진 마디 + 머리)
----------------------------------------------------------------------
type Serpent = {
	segs: { Part },
	head: { { part: Part, rel: CFrame } },
	spacing: number,
	scale: number,
	path: (s: number) -> Vector3,
	headS: number,
	alive: boolean,
	light: PointLight?,
}

local function makeSerpent(segCount: number, scale: number, spacing: number, path: (s: number) -> Vector3, transparency: number?): Serpent
	local segs = {}
	local tr = transparency or 0.12
	for i = 1, segCount do
		local k = 1 - (i - 1) / segCount
		local d = (0.7 + 1.9 * k) * scale
		local seg = newPart(Vector3.new(d, d * 0.9, d * 1.3), CFrame.new(), if i % 4 == 0 then GOLD_LIGHT else GOLD, Enum.Material.Neon, tr)
		seg.Shape = Enum.PartType.Ball
		seg.Size = Vector3.new(d, d, d)
		table.insert(segs, seg)
	end
	local head = {}
	local function hp(size: Vector3, rel: CFrame, color: Color3?, mat: Enum.Material?)
		local p = newPart(size * scale, CFrame.new(), color or GOLD, mat or Enum.Material.Neon, tr)
		table.insert(head, { part = p, rel = CFrame.new(rel.Position * scale) * rel.Rotation })
	end
	hp(Vector3.new(2.6, 2.1, 3.2), CFrame.new(0, 0, 0))
	hp(Vector3.new(1.9, 1.2, 2.4), CFrame.new(0, -0.1, -2.4))
	hp(Vector3.new(1.7, 0.5, 2.3), CFrame.new(0, -1.0, -1.9) * CFrame.Angles(math.rad(12), 0, 0))
	for _, side in { -1, 1 } do
		hp(Vector3.new(0.35, 0.35, 3.4), CFrame.new(side * 0.8, 1.2, 1.4) * CFrame.Angles(math.rad(28), math.rad(side * 12), 0), GOLD_LIGHT)
		hp(Vector3.new(0.35, 0.3, 0.3), CFrame.new(side * 0.95, 0.5, -1.2), Color3.new(1, 1, 1))
		hp(Vector3.new(0.12, 0.12, 4.5), CFrame.new(side * 0.9, -0.3, -2.6) * CFrame.Angles(math.rad(-8), math.rad(side * 35), 0), GOLD_LIGHT)
		hp(Vector3.new(0.2, 1.2, 1.6), CFrame.new(side * 1.3, 0.2, 0.6) * CFrame.Angles(0, 0, math.rad(side * 25)), GOLD_LIGHT)
	end
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 18 * scale
	light.Brightness = 2
	light.Parent = head[1].part
	local sp: Serpent = { segs = segs, head = head, spacing = spacing, scale = scale, path = path, headS = 0, alive = true, light = light }
	return sp
end

local function updateSerpent(sp: Serpent)
	local prev = sp.path(sp.headS + 0.5)
	local headPos = sp.path(sp.headS)
	local headCF = CFrame.lookAt(headPos, headPos + (headPos - sp.path(sp.headS - 0.6)))
	for _, h in sp.head do
		h.part.CFrame = headCF * h.rel
	end
	prev = headPos
	for i, seg in sp.segs do
		local s = sp.headS - i * sp.spacing
		local pos = sp.path(s)
		seg.CFrame = CFrame.lookAt(pos, prev)
		prev = pos
	end
end

local function destroySerpent(sp: Serpent, time: number)
	sp.alive = false
	for _, seg in sp.segs do
		fadeOut(seg, time)
	end
	for _, h in sp.head do
		fadeOut(h.part, time)
	end
end

-- 각성 중 몸을 휘감는 용
type Aura = { model: Model, serpent: Serpent, t: number, mode: string, modeUntil: number, lines: { BasePart }, light: PointLight? }
local auras: { [Model]: Aura } = {}

local function startDragonAura(model: Model)
	if auras[model] then
		return
	end
	local root = rootOf(model)
	if not root then
		return
	end
	local aura: Aura
	local function path(s: number): Vector3
		local r = rootOf(model)
		local cf = if r then r.CFrame else CFrame.new()
		local tight = aura and aura.mode == "coil"
		local R = if tight then 3.4 else 5.2
		local x = math.sin(s * 0.55) * R
		local z = math.cos(s * 0.55) * R + (if tight then 0 else 2.2)
		local y = 1.2 + math.sin(s * 0.23) * (if tight then 2.2 else 3.2)
		return cf:PointToWorldSpace(Vector3.new(x, y, z))
	end
	local sp = makeSerpent(22, 0.55, 0.62, path, 0.18)
	aura = { model = model, serpent = sp, t = 0, mode = "aura", modeUntil = 0, lines = {}, light = nil }
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "ChiLine" then
			table.insert(aura.lines, d)
			d.Transparency = 0.35
		end
	end
	local l = Instance.new("PointLight")
	l.Color = GOLD
	l.Range = 14
	l.Brightness = 1.5
	l.Parent = root
	aura.light = l
	auras[model] = aura
end

local function stopDragonAura(model: Model)
	local a = auras[model]
	if not a then
		return
	end
	auras[model] = nil
	destroySerpent(a.serpent, 0.8)
	for _, line in a.lines do
		if line.Parent then
			tween(line, 0.8, { Transparency = 1 })
		end
	end
	local l = a.light
	if l then
		l:Destroy()
	end
end

-- 칸자키 렌 각성: 칼집에서 새어 나오는 재 + 붉은 봉인선
type AshAuraT = { emitter: ParticleEmitter, light: PointLight, seals: { BasePart } }
local ashAuras: { [Model]: AshAuraT } = {}

local function seals(model: Model): { BasePart }
	local list = {}
	local scab = model:FindFirstChild("Scabbard")
	if scab then
		for i = 1, 10 do
			local s = scab:FindFirstChild("Seal" .. i)
			if s and s:IsA("BasePart") then
				list[i] = s
			end
		end
	end
	return list
end

local function startAshAura(model: Model)
	if ashAuras[model] then
		return
	end
	local torso = model:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local att = Instance.new("Attachment")
	att.Name = "AshAuraAtt"
	att.Parent = torso
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TEX_SMOKE
	pe.Color = ColorSequence.new(ASH, ASH_GREY)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.8, 1.4)
	pe.Rate = 26
	pe.Speed = NumberRange.new(2, 5)
	pe.SpreadAngle = Vector2.new(180, 180)
	pe.Acceleration = Vector3.new(0, 4, 0)
	pe.LightEmission = 0
	pe.Parent = att
	local light = Instance.new("PointLight")
	light.Color = RED
	light.Range = 10
	light.Brightness = 1.2
	light.Parent = torso
	local list = seals(model)
	for _, s in list do
		s.Transparency = 0.1
	end
	ashAuras[model] = { emitter = pe, light = light, seals = list }
end

local function stopAshAura(model: Model)
	local a = ashAuras[model]
	if not a then
		return
	end
	ashAuras[model] = nil
	a.emitter.Enabled = false
	destroyLater(a.emitter.Parent :: Instance, 2)
	a.light:Destroy()
	for _, s in a.seals do
		s.Transparency = 0.85
	end
end

----------------------------------------------------------------------
-- 투사체 (회분 참격)
----------------------------------------------------------------------
type ProjVis = { parts: { { part: Part, rel: CFrame } }, pos: Vector3, dir: Vector3, speed: number, range: number, traveled: number, holder: Part, emitter: ParticleEmitter }
local projs: { [number]: ProjVis } = {}

local function buildProjectile(kind: string, width: number, height: number): ({ { part: Part, rel: CFrame } }, Part, ParticleEmitter)
	local parts = {}
	local gold = kind == "gold"
	local low = kind == "ash_low"
	local main = if gold then GOLD else ASH
	local edge = if gold then GOLD_LIGHT else RED
	local h = if low then 0.6 else math.min(height, 4) * 0.35
	-- 초승달 모양: 가운데가 앞으로 나온 여러 조각
	local n = 7
	for i = 1, n do
		local a = (i - (n + 1) / 2) / ((n - 1) / 2) -- -1..1
		local x = a * width / 2
		local z = (a * a) * width * 0.25
		local segW = width / n * 1.25
		local body = newPart(Vector3.new(segW, h, 1.4), CFrame.new(), main, if gold then Enum.Material.Neon else Enum.Material.SmoothPlastic, 0.05)
		table.insert(parts, { part = body, rel = CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(-a * 25), 0) })
		local e = newPart(Vector3.new(segW, h * 0.5, 0.3), CFrame.new(), edge, Enum.Material.Neon, 0)
		table.insert(parts, { part = e, rel = CFrame.new(x, 0, z - 0.8) * CFrame.Angles(0, math.rad(-a * 25), 0) })
	end
	local holder = newPart(Vector3.new(width, h, 1), CFrame.new(), main, Enum.Material.SmoothPlastic, 1)
	local att = Instance.new("Attachment")
	att.Parent = holder
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = TEX_SMOKE
	pe.Color = if gold then ColorSequence.new(GOLD, GOLD_LIGHT) else ColorSequence.new(ASH, ASH_GREY)
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, math.max(1, width * 0.35)), NumberSequenceKeypoint.new(1, width * 0.7) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Lifetime = NumberRange.new(0.4, 0.8)
	pe.Rate = 90
	pe.Speed = NumberRange.new(1, 3)
	pe.SpreadAngle = Vector2.new(40, 40)
	pe.LightEmission = if gold then 0.8 else 0
	pe.Parent = att
	return parts, holder, pe
end

local function projectileStart(data: { [string]: any })
	local id = data.id :: number
	local kind = data.kind :: string
	local parts, holder, pe = buildProjectile(kind, data.width :: number, data.height :: number)
	local vis: ProjVis = {
		parts = parts,
		pos = data.origin :: Vector3,
		dir = (data.dir :: Vector3).Unit,
		speed = data.speed :: number,
		range = data.range :: number,
		traveled = 0,
		holder = holder,
		emitter = pe,
	}
	projs[id] = vis
	Sounds.play("ren_ash_wave", { at = holder, random = 0.05 })
	emit(vis.pos, 8, { texture = TEX_SMOKE, color = ASH, size = 1.5, speed = 8, life = 0.6, light = 0 })
end

local function projectileEnd(id: number, pos: Vector3?)
	local vis = projs[id]
	if not vis then
		return
	end
	projs[id] = nil
	for _, e in vis.parts do
		fadeOut(e.part, 0.15)
	end
	vis.emitter.Enabled = false
	destroyLater(vis.holder, 1)
	ashPuff(pos or vis.pos, 10, 2, 8)
end

----------------------------------------------------------------------
-- 분진막
----------------------------------------------------------------------
local function ashVeil(pos: Vector3, radius: number, duration: number)
	local emitters: { ParticleEmitter } = {}
	local holders = {}
	local count = math.clamp(math.floor(radius / 3), 5, 12)
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local r = if i % 2 == 0 then radius * 0.55 else radius * 0.2
		local p = Vector3.new(pos.X + math.cos(a) * r, groundY(pos) + 3, pos.Z + math.sin(a) * r)
		local holder = newPart(Vector3.new(radius * 0.6, 6, radius * 0.6), CFrame.new(p), ASH, Enum.Material.SmoothPlastic, 1)
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = TEX_SMOKE
		pe.Color = ColorSequence.new(ASH, Color3.fromRGB(40, 36, 38))
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 11) })
		pe.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.15),
			NumberSequenceKeypoint.new(0.8, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		})
		pe.Lifetime = NumberRange.new(2, 3)
		pe.Rate = 9
		pe.Speed = NumberRange.new(0.5, 2)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.RotSpeed = NumberRange.new(-20, 20)
		pe.Rotation = NumberRange.new(0, 360)
		pe.LightEmission = 0
		pe.Parent = holder
		table.insert(emitters, pe)
		table.insert(holders, holder)
	end
	ring(Vector3.new(pos.X, groundY(pos) + 0.3, pos.Z), Vector3.new(0, 1, 0), 2, radius * 2, RED, 0.6, 0.3, 0.3)
	Sounds.play("ren_smoke", { position = pos })
	task.delay(duration, function()
		for _, pe in emitters do
			pe.Enabled = false
		end
		for _, h in holders do
			destroyLater(h, 3.5)
		end
	end)
end

----------------------------------------------------------------------
-- 피격 연출
----------------------------------------------------------------------
local HIT_SOUND: { [string]: string } = {
	light = "m1_hit",
	palm = "m1_hit",
	palm_small = "m1_hit",
	palm_heavy = "m1_hit_heavy",
	gold = "lin_palm_impact",
	gold_heavy = "lin_palm_impact",
	staff = "lin_staff_hit",
	staff_heavy = "lin_staff_hit",
	slash = "ren_slash_hit",
	slash_heavy = "ren_slash_hit",
	ash = "ren_slash_hit",
	ash_heavy = "m1_hit_heavy",
	slam = "ground_crack",
}

-- 만화식 십자 섬광: 가늘고 긴 빛줄기 두 개가 교차하며 번쩍인다
local function crossFlash(pos: Vector3, color: Color3, size: number, time: number?)
	local t = time or 0.18
	local cam = workspace.CurrentCamera
	local face = if cam then CFrame.lookAt(pos, cam.CFrame.Position) else CFrame.new(pos)
	local spin = rng:NextNumber(0, math.pi)
	for i = 0, 1 do
		local cf = face * CFrame.Angles(0, 0, spin + i * math.pi / 2)
		local beam = newPart(Vector3.new(size * 0.06, size, 0.05), cf, color, Enum.Material.Neon, 0)
		tween(beam, t, { Size = Vector3.new(0.02, size * 1.6, 0.02), Transparency = 1 }, Enum.EasingStyle.Quart)
		destroyLater(beam, t + 0.05)
	end
	local core = newPart(Vector3.new(size * 0.18, size * 0.18, 0.05), face * CFrame.Angles(0, 0, math.pi / 4 + spin), Color3.new(1, 1, 1), Enum.Material.Neon, 0)
	fadeOut(core, t * 0.8, Vector3.new(size * 0.3, size * 0.3, 0.02))
end

-- 날아가는 방향으로 뻗는 충격 줄기
local function impactStreaks(pos: Vector3, dir: Vector3, color: Color3, count: number, length: number)
	for _ = 1, count do
		local d = (dir + rng:NextUnitVector() * 0.45).Unit
		local start = pos + d * rng:NextNumber(0.5, 1.5)
		local l = length * rng:NextNumber(0.6, 1.2)
		local streak = newPart(Vector3.new(0.12, 0.12, l * 0.3), CFrame.lookAt(start, start + d), color, Enum.Material.Neon, 0)
		local endPos = start + d * l
		tween(streak, 0.16, { CFrame = CFrame.lookAt(endPos, endPos + d), Size = Vector3.new(0.04, 0.04, l), Transparency = 1 }, Enum.EasingStyle.Quart)
		destroyLater(streak, 0.2)
	end
end

-- 발밑 충격파: 흙먼지 고리 + 튀는 돌 조각
local function groundShock(pos: Vector3, radius: number, color: Color3?)
	local gy = groundY(pos)
	if pos.Y - gy > 7 then
		return
	end
	local g = Vector3.new(pos.X, gy + 0.2, pos.Z)
	ring(g, Vector3.new(0, 1, 0), 2, radius * 2.4, color or Color3.fromRGB(235, 225, 210), 0.35, 0.3, 0.2)
	dust(g + Vector3.new(0, 0.8, 0), 10, 2.5)
	shardBurst(g + Vector3.new(0, 0.5, 0), 8, Color3.fromRGB(110, 100, 94), 34, 0.55, 0.9, Enum.Material.Slate, 90, Vector3.new(0, 1.4, 0))
end

local function hitEffect(kind: string, pos: Vector3, fromPos: Vector3?)
	local dir = if fromPos then (pos - fromPos) else Vector3.new(0, 0, -1)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(0, 0, -1)
	end
	dir = dir.Unit
	if kind == "palm" or kind == "palm_small" or kind == "light" then
		local s = if kind == "palm_small" then 0.6 else 1
		flash(pos, 2.2 * s, GOLD_LIGHT, 0.14)
		crossFlash(pos, GOLD_LIGHT, 5 * s, 0.14)
		shardBurst(pos, math.floor(6 * s), GOLD, 26, 0.35, 0.3, nil, 20, dir)
		ring(pos, dir, 1.5 * s, 6 * s, GOLD_LIGHT, 0.2, 0.15)
	elseif kind == "palm_heavy" or kind == "gold_heavy" or kind == "gold" then
		local big = kind ~= "gold"
		flash(pos, if big then 5 else 3, GOLD, 0.25, 2.8)
		crossFlash(pos, GOLD_LIGHT, if big then 13 else 8, 0.22)
		impactStreaks(pos, dir, GOLD_LIGHT, if big then 10 else 5, if big then 14 else 9)
		shardBurst(pos, if big then 18 else 9, GOLD, 48, 0.5, 0.5, nil, 30, dir)
		ring(pos, dir, 2, if big then 20 else 10, GOLD, 0.32, 0.35)
		ring(pos, dir, 1, if big then 12 else 6, Color3.new(1, 1, 1), 0.2, 0.15)
		emit(pos, 22, { color = GOLD, size = 1.2, speed = 34, life = 0.6, light = 1 })
		if big then
			groundShock(pos, 7, GOLD_LIGHT)
		end
	elseif kind == "staff" or kind == "staff_heavy" then
		local big = kind == "staff_heavy"
		flash(pos, if big then 4 else 2, Color3.fromRGB(255, 180, 90), 0.18)
		crossFlash(pos, Color3.fromRGB(255, 220, 160), if big then 11 else 6, 0.18)
		shardBurst(pos, if big then 14 else 6, Color3.fromRGB(255, 170, 70), 38, 0.4, 0.35, nil, 30, dir)
		ring(pos, dir, 2, if big then 16 else 7, Color3.fromRGB(255, 200, 120), 0.25, 0.2)
		if big then
			impactStreaks(pos, dir, Color3.fromRGB(255, 220, 160), 8, 12)
			groundShock(pos, 6)
		end
	elseif kind == "slash" or kind == "slash_heavy" then
		local big = kind == "slash_heavy"
		slashLine(pos, if big then 14 else 8, Color3.fromRGB(255, 235, 235), 0.22, if big then 0.34 else 0.18)
		crossFlash(pos, Color3.fromRGB(255, 200, 200), if big then 10 else 5, 0.16)
		if big then
			slashLine(pos, 14, RED, 0.3, 0.26)
			impactStreaks(pos, dir, Color3.fromRGB(255, 90, 90), 8, 12)
			groundShock(pos, 6, Color3.fromRGB(255, 120, 120))
		end
		shardBurst(pos, if big then 12 else 5, RED, 32, 0.3, 0.3, nil, 25, dir)
		ashPuff(pos, if big then 14 else 6, 1.2, 12)
	elseif kind == "ash" or kind == "ash_heavy" then
		local big = kind == "ash_heavy"
		flash(pos, if big then 5 else 2.4, RED, 0.2)
		crossFlash(pos, Color3.fromRGB(255, 120, 120), if big then 14 else 6, 0.2)
		ashPuff(pos, if big then 26 else 12, if big then 3 else 1.8, if big then 22 else 12)
		slashLine(pos, if big then 16 else 8, Color3.fromRGB(255, 80, 80), 0.25, 0.24)
		if big then
			ring(pos, dir, 2, 22, RED, 0.32, 0.35)
			impactStreaks(pos, dir, Color3.fromRGB(255, 90, 90), 10, 15)
			groundShock(pos, 8, Color3.fromRGB(255, 110, 110))
		end
	elseif kind == "slam" then
		local g = Vector3.new(pos.X, groundY(pos), pos.Z)
		VFX.groundCrack(g, 8, "stone")
		flash(pos, 4, Color3.new(1, 1, 1), 0.15)
		crossFlash(pos, Color3.new(1, 1, 1), 12, 0.2)
		groundShock(pos, 8)
	end
end

function VFX.groundCrack(pos: Vector3, radius: number, style: string?)
	local color = if style == "gold" then Color3.fromRGB(120, 100, 80) else Color3.fromRGB(96, 90, 86)
	local n = math.clamp(math.floor(radius * 1.4), 6, 16)
	for i = 1, n do
		local a = (i / n) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = radius * rng:NextNumber(0.6, 1)
		local p = pos + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		local s = rng:NextNumber(1.2, 2.4) * radius / 7
		local rock = newPart(Vector3.new(s * 1.4, s, s * 1.8), CFrame.lookAt(p, pos) * CFrame.Angles(math.rad(-35), 0, rng:NextNumber(-0.5, 0.5)) - Vector3.new(0, s, 0), color, Enum.Material.Slate, 0)
		tween(rock, 0.12, { CFrame = rock.CFrame + Vector3.new(0, s * 0.9, 0) })
		task.delay(1.8, function()
			tween(rock, 0.6, { CFrame = rock.CFrame - Vector3.new(0, s * 1.2, 0), Transparency = 1 })
			destroyLater(rock, 0.7)
		end)
	end
	ring(pos + Vector3.new(0, 0.2, 0), Vector3.new(0, 1, 0), 2, radius * 2.6, if style == "gold" then GOLD else Color3.fromRGB(220, 210, 200), 0.35, 0.2)
	dust(pos + Vector3.new(0, 1, 0), 14, 3)
	Sounds.play("ground_crack", { position = pos, random = 0.08 })
end

----------------------------------------------------------------------
-- 지형 파괴: 잔해·재·복구 (서버 Destruction 이 보내는 "Shatter" / "Rebuild")
--  · 서버는 없앤 부피(조각마다 월드 CFrame·크기)만 보낸다. 날아가는 잔해는 각 클라이언트가 로컬 물리로 만든다.
--  · 조각이 덩어리 크기보다 크면 가장 긴 축을 무작위 비율로 자른다 (격자처럼 보이지 않게).
--  · 한 번에 만드는 덩어리 수, 초당 만드는 수, 동시에 살아 있는 수에 상한이 있다. 넘치는 부피는 먼지로 대신 보여준다.
--  · 관통 참격처럼 매 프레임 파괴가 이어져도 먼지·소리·흔들림이 쌓여 폭주하지 않게 한다.
--  · 네트워크로 온 값이라 전부 typeof 로 확인하고, 이상한 값은 버리거나 기본값으로 바꾼다.
----------------------------------------------------------------------
local RUBBLE_EVENT_CAP = 140 -- 한 번의 파괴에서 만드는 잔해 덩어리 상한
local GHOST_EVENT_CAP = 400 -- 한 번의 파괴에서 만드는 "재가 되는 조각" 상한 (고정·충돌 없음이라 싸다)
local RUBBLE_LIVE_CAP = 380 -- 동시에 살아 있는 잔해 상한 (넘으면 멈춘 것·오래된 것부터 없앤다)
local GHOST_LIVE_CAP = 900 -- 동시에 살아 있는 재 조각 상한 (잔해와 따로 센다 → 큰 재 절단이 잔해를 밀어내지 않는다)
local RUBBLE_PER_SEC, RUBBLE_BURST = 400, 200 -- 초당 새로 만드는 잔해 수 / 한꺼번에 쓸 수 있는 양
local GHOST_PER_SEC, GHOST_BURST = 900, 450 -- 초당 새로 만드는 재 조각 수 / 한꺼번에 쓸 수 있는 양
local FX_PER_SEC, FX_BURST = 36, 14 -- 초당 덧붙이는 먼지·파편 연출 수 (중심 먼지 한 번은 늘 나온다)
local LEAF_LIMIT = 1600 -- 쪼개기 계산에서 만드는 후보 조각 상한 (인스턴스가 아니라 표라서 가볍다)
local PIECE_LIMIT = 900 -- 한 이벤트에서 읽는 조각 수 상한
local CHUNK_MAX = 5.5 -- 아주 큰 파괴에서 덩어리가 커질 수 있는 최대 변 길이
local SHAKE_RANGE = 120 -- 이보다 먼 카메라는 흔들지 않는다
local FRESH_TIME = 0.15 -- 막 생긴 잔해끼리는 이 시간 동안 서로 부딪히지 않는다 (겹친 채 생겨서 튕겨 나가지 않게)
local MOVING_SPEED = 4 -- 이보다 빠르면 "아직 날아가는 중"
local REBUILD_BOX_LIMIT = 64 -- Rebuild 한 번에 검사하는 복구 파트 수 상한
local DUST_GREY = Color3.fromRGB(160, 148, 134)
-- 무겁게: 잘 튀지 않고(탄성 낮음, 가중치 높게) 금방 멈춘다
local RUBBLE_PHYS = PhysicalProperties.new(2.4, 0.8, 0.04, 1, 50)

type ShatterPiece = { cf: CFrame, size: Vector3, vol: number }
type ShatterGroup = {
	color: Color3,
	material: Enum.Material,
	transparency: number,
	shape: string,
	pieces: { ShatterPiece },
	volume: number,
}
type Chunk = { cf: CFrame, size: Vector3, shape: string, g: number, vol: number, w: number }
type ShatterCtx = {
	center: Vector3,
	radius: number,
	from: Vector3,
	dir: Vector3,
	force: number,
	sound: boolean,
	lost: number, -- 서버가 조각으로 보내지 않은 부피 (먼지 크기에만 더한다)
	ground: number?, -- 중심 아래 바닥 높이 (못 찾으면 nil)
}
type RestoredBox = { cf: CFrame, half: Vector3, center: Vector3, reach: number }

local SHATTER_SHAPES: { [string]: boolean } = { Block = true, Cylinder = true, Wedge = true, Ball = true }

local liveRubble: { BasePart } = {} -- 날아가는 잔해, 만든 순서대로 (앞쪽이 오래된 것)
local liveGhosts: { BasePart } = {} -- 재가 되는 조각, 만든 순서대로 (잔해와 따로 센다)
local lastSoundAt: { [string]: number } = {}
local lastFovPunchAt = 0
local groupOk: { [string]: boolean } = {}

-- 초당 개수 제한 (토큰 버킷): 초당 rate 개씩 차오르고 burst 개까지 모인다
type Bucket = { tokens: number, at: number, rate: number, burst: number }

local function newBucket(rate: number, burst: number): Bucket
	return { tokens = burst, at = os.clock(), rate = rate, burst = burst }
end

-- 지금 쓸 수 있는 개수 (채우기만 하고 빼지는 않는다)
local function bucketAvail(b: Bucket): number
	local now = os.clock()
	b.tokens = math.min(b.burst, b.tokens + math.max(0, now - b.at) * b.rate)
	b.at = now
	return math.floor(b.tokens)
end

local function bucketTake(b: Bucket, n: number)
	b.tokens = math.max(0, b.tokens - n)
end

local rubbleBudget = newBucket(RUBBLE_PER_SEC, RUBBLE_BURST)
local ghostBudget = newBucket(GHOST_PER_SEC, GHOST_BURST)
local fxBudget = newBucket(FX_PER_SEC, FX_BURST)

-- 덧붙이는 연출 하나를 할 여유가 있으면 하나 쓰고 true
local function fxToken(): boolean
	if bucketAvail(fxBudget) >= 1 then
		bucketTake(fxBudget, 1)
		return true
	end
	return false
end

local function finiteNum(v: any): number?
	if typeof(v) == "number" and v == v and v > -math.huge and v < math.huge then
		return v
	end
	return nil
end

local function finiteVec(v: any): Vector3?
	if typeof(v) == "Vector3" and finiteNum(v.X) and finiteNum(v.Y) and finiteNum(v.Z) then
		return v
	end
	return nil
end

local function shapeVolume(shape: string, s: Vector3): number
	if shape == "Wedge" then
		return s.X * s.Y * s.Z * 0.5
	elseif shape == "Cylinder" then
		local d = math.min(s.Y, s.Z)
		return s.X * d * d * 0.785
	elseif shape == "Ball" then
		local d = math.min(s.X, s.Y, s.Z)
		return d * d * d * 0.524
	end
	return s.X * s.Y * s.Z
end

-- 서버가 보낸 groups 를 검사해서 읽는다. 받은 조각의 전체 부피도 함께 돌려준다.
local function parseShatterGroups(raw: any): ({ ShatterGroup }, number)
	local out: { ShatterGroup } = {}
	local total = 0
	if typeof(raw) ~= "table" then
		return out, 0
	end
	local read = 0
	for _, g in raw do
		if read >= PIECE_LIMIT then
			break
		end
		if typeof(g) ~= "table" or typeof(g.pieces) ~= "table" then
			continue
		end
		local shape: string = if typeof(g.shape) == "string" and SHATTER_SHAPES[g.shape] then g.shape else "Block"
		local mat: Enum.Material = Enum.Material.Concrete
		if typeof(g.material) == "EnumItem" and g.material.EnumType == Enum.Material then
			mat = g.material :: any
		end
		local grp: ShatterGroup = {
			color = if typeof(g.color) == "Color3" then g.color else DUST_GREY,
			material = mat,
			transparency = math.clamp(finiteNum(g.transparency) or 0, 0, 0.9),
			shape = shape,
			pieces = {},
			volume = 0,
		}
		for _, p in g.pieces do
			if read >= PIECE_LIMIT then
				break
			end
			if typeof(p) ~= "table" or typeof(p.cf) ~= "CFrame" then
				continue
			end
			local cf = p.cf :: CFrame
			local s = finiteVec(p.size)
			if not s or not finiteVec(cf.Position) then
				continue
			end
			local size = Vector3.new(math.clamp(s.X, 0.05, 512), math.clamp(s.Y, 0.05, 512), math.clamp(s.Z, 0.05, 512))
			local vol = shapeVolume(shape, size)
			read += 1
			table.insert(grp.pieces, { cf = cf, size = size, vol = vol })
			grp.volume += vol
		end
		if #grp.pieces > 0 then
			table.insert(out, grp)
			total += grp.volume
		end
	end
	return out, total
end

-- 상자로 바꿔 자를 때, 원래 모양(쐐기·원기둥·공) 밖에 놓인 조각은 버린다
local function insideShape(mode: string, rel: Vector3, bs: Vector3): boolean
	if mode == "Wedge" then
		-- 쐐기: 바닥면과 뒷면(+Z)이 꽉 차 있고 경사면이 앞쪽 아래로 내려온다
		return rel.Y / bs.Y <= rel.Z / bs.Z + 0.1
	elseif mode == "Cylinder" then
		local r = math.min(bs.Y, bs.Z) * 0.54
		return rel.Y * rel.Y + rel.Z * rel.Z <= r * r
	elseif mode == "Ball" then
		return rel.Magnitude <= math.min(bs.X, bs.Y, bs.Z) * 0.54
	end
	return true
end

-- 조각을 덩어리 크기(C) 이하가 될 때까지 가장 긴 축을 무작위 비율로 자른다.
-- xOnly: 모양을 지키려고 X 축으로만 자른다 (원기둥·쐐기). mode: 상자로 바꿔 자를 때 버릴 기준.
local function cutPiece(
	cf: CFrame,
	size: Vector3,
	C: number,
	xOnly: boolean,
	leafShape: string,
	mode: string,
	base: CFrame,
	baseSize: Vector3,
	g: number,
	out: { Chunk },
	budget: { n: number }
)
	if budget.n <= 0 then
		return
	end
	local sx, sy, sz = size.X, size.Y, size.Z
	local m = if xOnly then sx else math.max(sx, sy, sz)
	if m <= C then
		if mode ~= "" and not insideShape(mode, base:PointToObjectSpace(cf.Position), baseSize) then
			return
		end
		budget.n -= 1
		table.insert(out, { cf = cf, size = size, shape = leafShape, g = g, vol = shapeVolume(leafShape, size), w = 0 })
		return
	end
	local f = rng:NextNumber(0.36, 0.64)
	local cfA, sizeA, cfB, sizeB
	if xOnly or m == sx then
		local a, b = sx * f, sx * (1 - f)
		cfA, sizeA = cf * CFrame.new(-sx / 2 + a / 2, 0, 0), Vector3.new(a, sy, sz)
		cfB, sizeB = cf * CFrame.new(sx / 2 - b / 2, 0, 0), Vector3.new(b, sy, sz)
	elseif m == sy then
		local a, b = sy * f, sy * (1 - f)
		cfA, sizeA = cf * CFrame.new(0, -sy / 2 + a / 2, 0), Vector3.new(sx, a, sz)
		cfB, sizeB = cf * CFrame.new(0, sy / 2 - b / 2, 0), Vector3.new(sx, b, sz)
	else
		local a, b = sz * f, sz * (1 - f)
		cfA, sizeA = cf * CFrame.new(0, 0, -sz / 2 + a / 2), Vector3.new(sx, sy, a)
		cfB, sizeB = cf * CFrame.new(0, 0, sz / 2 - b / 2), Vector3.new(sx, sy, b)
	end
	-- 예산이 도중에 떨어져도 늘 같은 쪽 끝만 남지 않게, 어느 쪽 반을 먼저 자를지 무작위로
	if rng:NextNumber() < 0.5 then
		cfA, sizeA, cfB, sizeB = cfB, sizeB, cfA, sizeA
	end
	cutPiece(cfA, sizeA, C, xOnly, leafShape, mode, base, baseSize, g, out, budget)
	cutPiece(cfB, sizeB, C, xOnly, leafShape, mode, base, baseSize, g, out, budget)
end

-- exact: 재가 되는 조각처럼 제자리에 모양 그대로 보여야 할 때 (모양을 상자로 바꾸지 않는다)
local function splitPiece(cf: CFrame, size: Vector3, shape: string, C: number, exact: boolean, g: number, out: { Chunk }, budget: { n: number })
	if shape == "Ball" then
		local d = math.min(size.X, size.Y, size.Z)
		local s = Vector3.new(d, d, d)
		if exact or d <= C * 1.5 then
			cutPiece(cf, s, math.huge, true, "Ball", "", cf, s, g, out, budget)
		else
			cutPiece(cf, s, C, false, "Block", "Ball", cf, s, g, out, budget)
		end
	elseif shape == "Cylinder" then
		local d = math.min(size.Y, size.Z)
		local s = Vector3.new(size.X, d, d)
		if exact or d <= C * 1.5 then
			cutPiece(cf, s, C, true, "Cylinder", "", cf, s, g, out, budget)
		else
			-- 굵은 기둥은 동전처럼 썰리면 어색하다 → 상자 덩어리로
			cutPiece(cf, s, C, false, "Block", "Cylinder", cf, s, g, out, budget)
		end
	elseif shape == "Wedge" then
		if exact or (size.Y <= C * 1.5 and size.Z <= C * 1.5) then
			cutPiece(cf, size, C, true, "Wedge", "", cf, size, g, out, budget)
		else
			cutPiece(cf, size, C, false, "Block", "Wedge", cf, size, g, out, budget)
		end
	else
		cutPiece(cf, size, C, false, "Block", "", cf, size, g, out, budget)
	end
end

-- 덩어리 수가 상한 근처가 되도록 덩어리 크기를 키워 가며 쪼갠다.
-- 후보 조각 예산(LEAF_LIMIT)은 조각마다 부피에 비례해 나눠 준다 (최소 1). 하나를 같이 쓰면 서버가 보낸
-- 순서(가까운 것부터)대로 다 써 버려서, 큰 파괴의 바깥쪽 건물에는 잔해가 하나도 생기지 않는다.
-- total: 받은 조각들의 부피 합 (parseShatterGroups 가 돌려준 값)
-- 재 조각(exact)은 상한 안에 다 들어가야 구멍이 빈틈없이 덮이므로 여유(1.3배)를 두지 않는다.
local function buildChunks(groups: { ShatterGroup }, total: number, cap: number, exact: boolean, lo: number, hi: number): { Chunk }
	local C = math.clamp((total / (0.42 * math.max(cap, 1))) ^ (1 / 3), lo, hi)
	local per = LEAF_LIMIT / math.max(total, 1e-6)
	local slack = if exact then 1 else 1.3
	local out: { Chunk } = {}
	for _ = 1, 4 do
		out = {}
		for gi, g in groups do
			for _, p in g.pieces do
				splitPiece(p.cf, p.size, g.shape, C, exact, gi, out, { n = math.max(1, math.floor(p.vol * per)) })
			end
		end
		if #out <= cap * slack or C >= hi then
			break
		end
		C = math.min(C * 1.35, hi)
	end
	return out
end

-- 상한을 넘으면 큰 덩어리 위주로(약간 무작위) 고르고, 나머지는 먼지로 돌린다
local function pickChunks(chunks: { Chunk }, cap: number): ({ Chunk }, { Chunk })
	if #chunks <= cap then
		return chunks, {}
	end
	for _, c in chunks do
		c.w = c.vol * rng:NextNumber(0.5, 1.5)
	end
	table.sort(chunks, function(a, b)
		return a.w > b.w
	end)
	local keep: { Chunk } = {}
	local rest: { Chunk } = {}
	for i, c in chunks do
		if i <= cap then
			keep[i] = c
		else
			table.insert(rest, c)
		end
	end
	return keep, rest
end

-- 받은 조각 전체에서 부피에 비례해 무작위로 n 곳을 고른다 (넘친 부피를 먼지로 보여줄 자리).
-- 덩어리가 된 것만 보면 안쪽에만 몰리므로, 바깥쪽 조각도 제 부피만큼 뽑히게 전체에서 고른다.
-- outer 가 있으면 그 점에서 먼 쪽(가장 먼 조각 거리의 70% 밖) 조각 중에서만 고른다.
local function pieceSpots(groups: { ShatterGroup }, n: number, outer: Vector3?): { ShatterPiece }
	local spots: { ShatterPiece } = {}
	if n <= 0 then
		return spots
	end
	local minD = -1
	if outer then
		local dmax = 0
		for _, g in groups do
			for _, p in g.pieces do
				dmax = math.max(dmax, (p.cf.Position - outer).Magnitude)
			end
		end
		minD = dmax * 0.7
	end
	local function eligible(p: ShatterPiece): boolean
		return minD < 0 or (p.cf.Position - (outer :: Vector3)).Magnitude >= minD
	end
	local total = 0
	for _, g in groups do
		for _, p in g.pieces do
			if eligible(p) then
				total += p.vol
			end
		end
	end
	if total <= 0 then
		return spots
	end
	local targets: { number } = {}
	for i = 1, n do
		targets[i] = rng:NextNumber(0, total)
	end
	table.sort(targets)
	local acc, ti = 0, 1
	local last: ShatterPiece? = nil
	for _, g in groups do
		for _, p in g.pieces do
			if not eligible(p) then
				continue
			end
			acc += p.vol
			last = p
			while ti <= n and targets[ti] <= acc do
				spots[ti] = p
				ti += 1
			end
		end
	end
	-- 부동소수 오차로 남은 몫은 마지막 조각에
	if last then
		while ti <= n do
			spots[ti] = last
			ti += 1
		end
	end
	return spots
end

-- 조각 안의 무작위 한 점 (큰 조각 하나가 여러 번 뽑혀도 먼지가 한곳에 겹치지 않게)
local function pointIn(p: ShatterPiece): Vector3
	local s = p.size
	return p.cf:PointToWorldSpace(Vector3.new(rng:NextNumber(-0.4, 0.4) * s.X, rng:NextNumber(-0.4, 0.4) * s.Y, rng:NextNumber(-0.4, 0.4) * s.Z))
end

-- 넘친 부피(overflow)를 먼지로 보여줄 자리 n 곳. 서버가 조각으로 보내지 못한 부피(ctx.lost)는 서버가 가까운
-- 조각부터 보내고 남은 것이라 바깥쪽에 있다 → 그 몫은 받은 조각 중 바깥쪽에서 먼저 고르고, 나머지는 전체에서 고른다.
local function overflowSpots(ctx: ShatterCtx, groups: { ShatterGroup }, overflow: number, n: number): { ShatterPiece }
	local nLost = if overflow > 0 then math.clamp(math.round(n * ctx.lost / overflow), 0, n) else 0
	local spots = pieceSpots(groups, nLost, ctx.center)
	for _, p in pieceSpots(groups, n - nLost, nil) do
		table.insert(spots, p)
	end
	return spots
end

local function newChunkPart(shape: string): BasePart
	if shape == "Wedge" then
		return Instance.new("WedgePart")
	end
	local p = Instance.new("Part")
	if shape == "Cylinder" then
		p.Shape = Enum.PartType.Cylinder
	elseif shape == "Ball" then
		p.Shape = Enum.PartType.Ball
	end
	return p
end

-- 크기를 조금씩 줄여서 덩어리 사이에 틈이 생기게 (서로 끼어서 튕기지 않고, 격자처럼 보이지 않게)
local function jitterSize(shape: string, s: Vector3): Vector3
	local function k(v: number): number
		return math.max(0.2, v * rng:NextNumber(0.8, 0.95))
	end
	if shape == "Ball" then
		local d = k(s.X)
		return Vector3.new(d, d, d)
	elseif shape == "Cylinder" then
		local d = k(math.min(s.Y, s.Z))
		return Vector3.new(k(s.X), d, d)
	end
	return Vector3.new(k(s.X), k(s.Y), k(s.Z))
end

-- 서버가 만든 충돌 그룹이 있는지 (Debris: 캐릭터와 안 부딪힘, DebrisFresh: 맵과만 부딪힘)
local function groupReady(name: string): boolean
	if not groupOk[name] then
		local ok, res = pcall(function()
			return PhysicsService:IsCollisionGroupRegistered(name)
		end)
		groupOk[name] = ok and res == true
	end
	return groupOk[name] == true
end

local function isEvicted(p: BasePart): boolean
	return p:GetAttribute("Evicted") == true
end

-- 자리를 비우려고 없애는 조각: 멈춰 있으면 제자리에서 줄어들고, 아직 날아가는 중이면 공중에 세우지 않고 그대로 옅어진다.
-- 표시해 두면 나중에 예약된 무너짐(crumbleGhost)·수명 끝(retireRubble)이 이 조각을 다시 건드리지 않는다.
local function evictPart(p: BasePart)
	p:SetAttribute("Evicted", true)
	if p.Anchored or p.AssemblyLinearVelocity.Magnitude < MOVING_SPEED then
		p.Anchored = true
		tween(p, 0.25, { Transparency = 1, Size = p.Size * 0.3 })
	else
		tween(p, 0.25, { Transparency = 1 })
	end
	destroyLater(p, 0.3)
end

-- 사라진 조각을 목록에서 빼고, n 개가 들어갈 자리가 없으면 멈춘 것 중 오래된 것부터,
-- 그래도 모자라면 날아가는 것 중 오래된 것부터 없앤다
local function makeRoom(list: { BasePart }, cap: number, n: number)
	local j = 0
	local count = #list
	for i = 1, count do
		local p = list[i]
		if p.Parent then
			j += 1
			list[j] = p
		end
	end
	for i = count, j + 1, -1 do
		list[i] = nil
	end
	local over = math.min(j + n - cap, j)
	if over <= 0 then
		return
	end
	local victim: { [number]: boolean } = {}
	local picked = 0
	for i = 1, j do
		if picked >= over then
			break
		end
		local p = list[i]
		if p.Anchored or p.AssemblyLinearVelocity.Magnitude < MOVING_SPEED then
			victim[i] = true
			picked += 1
		end
	end
	for i = 1, j do
		if picked >= over then
			break
		end
		if not victim[i] then
			victim[i] = true
			picked += 1
		end
	end
	local k = 0
	for i = 1, j do
		local p = list[i]
		if victim[i] then
			evictPart(p)
		else
			k += 1
			list[k] = p
		end
	end
	for i = j, k + 1, -1 do
		list[i] = nil
	end
end

-- 수명이 다한 잔해: 멈춰 있으면 땅속으로 가라앉듯, 굴러가는 중이면 그대로 줄어들며 사라진다
local function retireRubble(p: BasePart)
	if not p.Parent or isEvicted(p) then
		return
	end
	local t = rng:NextNumber(0.5, 0.85)
	if p.AssemblyLinearVelocity.Magnitude < MOVING_SPEED then
		p.Anchored = true
		tween(p, t, { Size = p.Size * 0.2, CFrame = p.CFrame - Vector3.new(0, p.Size.Y * 0.35, 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	else
		tween(p, t, { Size = p.Size * 0.2, Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end
	destroyLater(p, t + 0.05)
end

-- group: 처음 넣을 충돌 그룹 (nil 이면 기본). fresh 면 잠깐 뒤 "Debris" 로 바꾼다.
local function launchRubble(c: Chunk, g: ShatterGroup, ctx: ShatterCtx, group: string?, fresh: boolean): BasePart
	local p = newChunkPart(c.shape)
	local size = jitterSize(c.shape, c.size)
	local maxDim = math.max(size.X, size.Y, size.Z)
	p.Anchored = false
	p.CanCollide = true
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = maxDim > 2
	p.Massless = false
	if group then
		p.CollisionGroup = group
	end
	p.CustomPhysicalProperties = RUBBLE_PHYS
	p.Material = g.material
	p.Color = g.color
	p.Transparency = g.transparency
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = c.cf
	p.Parent = folder
	if fresh then
		-- 이웃 덩어리와 겹친 채 생겨도 첫 프레임에 서로 밀어내며 튀지 않게, 잠깐은 맵하고만 부딪힌다
		task.delay(FRESH_TIME, function()
			if p.Parent then
				p.CollisionGroup = "Debris"
			end
		end)
	end

	-- 방향: 힘이 들어온 곳에서 멀어지는 쪽 (없으면 밀어낸 방향 → 중심에서 바깥 → 위) + 주된 방향 섞기
	local pos = c.cf.Position
	local away = pos - ctx.from
	local d: Vector3
	if away.Magnitude > 0.3 then
		d = away.Unit
	elseif ctx.dir.Magnitude > 0.5 then
		d = ctx.dir
	else
		local radial = pos - ctx.center
		d = if radial.Magnitude > 0.3 then radial.Unit else Vector3.yAxis
	end
	if ctx.dir.Magnitude > 0.5 then
		d = d * 0.6 + ctx.dir * 0.85
	end
	d += rng:NextUnitVector() * 0.28
	d = if d.Magnitude > 0.05 then d.Unit else Vector3.yAxis
	if d.Y < 0.1 then
		d = Vector3.new(d.X, 0.1, d.Z).Unit
	end
	-- 중심에 가까울수록 빠르게, 큰 덩어리일수록 무겁게(느리게)
	local near = 1 - math.clamp((pos - ctx.center).Magnitude / ctx.radius, 0, 1)
	local prox = 0.6 + 0.85 * near
	local heavy = math.sqrt(math.clamp(2.4 / maxDim, 0.6, 1.3))
	local speed = math.min(32 * ctx.force * prox * heavy * rng:NextNumber(0.7, 1.25), 190)
	local up = rng:NextNumber(12, 28) * math.sqrt(ctx.force) * prox
	p.AssemblyLinearVelocity = d * speed + Vector3.new(0, up, 0)
	p.AssemblyAngularVelocity = rng:NextUnitVector() * rng:NextNumber(4, 14) * heavy

	-- 수명 5~9초. 작은 부스러기 일부는 조금 더 오래 남는다
	local life = rng:NextNumber(5, 9)
	if maxDim < 1.6 and rng:NextNumber() < 0.35 then
		life = rng:NextNumber(10, 14)
	end
	task.delay(life, retireRubble, p)
	destroyLater(p, life + 1.5)
	return p
end

-- 같은 소리를 0.05초 안에 또 틀지 않는다 (한 프레임에 파괴가 여러 번 와도 이름마다 한 번)
local function playDestructionSound(name: string, pos: Vector3, volume: number, pitch: number)
	local now = os.clock()
	local last = lastSoundAt[name]
	if last and now - last < 0.05 then
		return
	end
	lastSoundAt[name] = now
	Sounds.play(name, { position = pos, volume = volume, pitch = pitch, random = 0.06 })
end

-- 카메라와의 거리에 따라 줄어드는 흔들림.
-- 더하지 않고 "최소 이만큼"으로 건다: 매 프레임 이어지는 파괴도 가장 센 한 번의 세기로 유지될 뿐 쌓이지 않는다.
local function shakeFrom(pos: Vector3, amount: number): number
	local cam = workspace.CurrentCamera
	if not cam then
		return math.huge
	end
	local dist = (cam.CFrame.Position - pos).Magnitude
	if dist < SHAKE_RANGE then
		CameraFX.shakeAtLeast(amount * (1 - dist / SHAKE_RANGE))
	end
	return dist
end

-- 부서진 재질들의 부피 가중 평균 색과 가장 큰 그룹
local function shatterColor(groups: { ShatterGroup }): (Color3, ShatterGroup)
	local r, gg, b, w = 0, 0, 0, 0
	local best = groups[1]
	for _, grp in groups do
		local v = math.max(grp.volume, 0.001)
		r += grp.color.R * v
		gg += grp.color.G * v
		b += grp.color.B * v
		w += v
		if grp.volume > best.volume then
			best = grp
		end
	end
	return Color3.new(r / w, gg / w, b / w), best
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

-- 중심 아래 depth 안에 바닥이 있으면 그 높이
local function groundBelow(pos: Vector3, depth: number): number?
	local ignore: { Instance } = { folder }
	local ch = player.Character
	if ch then
		table.insert(ignore, ch)
	end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -(depth + 1), 0), groundParams)
	return if hit then hit.Position.Y else nil
end

-- 파괴 중심의 XZ 에서 높이 y 로 뿜을 자리. 땅속에서 뿜어 안 보이는 일이 없게 바닥 + lift 이상으로 올리고,
-- 바닥을 못 찾으면 중심보다 maxDrop 넘게 내려가지 않게만 한다.
local function liftCenter(ctx: ShatterCtx, y: number, lift: number, maxDrop: number): Vector3
	local c = ctx.center
	local gy = ctx.ground
	local yy = if gy then math.max(y, gy + lift) else math.max(y, c.Y - maxDrop)
	return Vector3.new(c.X, yy, c.Z)
end

-- 다른 XZ (조각 자리) 에서도 같은 일: pos 와 중심 중 높은 곳부터 아래로 바닥을 찾아 바닥 + lift 이상으로
local function aboveGround(pos: Vector3, center: Vector3, lift: number): Vector3
	local top = math.max(pos.Y, center.Y)
	local gy = groundBelow(Vector3.new(pos.X, top, pos.Z), top - pos.Y + 30)
	if gy and pos.Y < gy + lift then
		return Vector3.new(pos.X, gy + lift, pos.Z)
	end
	return pos
end

-- 크기 등급: 1 작음, 2 중간, 3 큼
local function shatterTier(radius: number, total: number): number
	if radius >= 12 or total >= 400 then
		return 3
	elseif radius >= 6 or total >= 60 then
		return 2
	end
	return 1
end

-- 일반 파괴: 제자리에서 덩어리로 쪼개져 날아가는 잔해 + 흙먼지
-- got: 받은 조각의 부피 합. 먼지·흔들림·소리는 서버가 조각으로 안 보낸 부피(ctx.lost)까지 더한 크기로 정한다.
local function shatterRubble(ctx: ShatterCtx, groups: { ShatterGroup }, got: number)
	local center, radius = ctx.center, ctx.radius
	local total = got + ctx.lost
	local cam = workspace.CurrentCamera
	local camDist = if cam then (cam.CFrame.Position - center).Magnitude else 0
	local want = RUBBLE_EVENT_CAP
	if camDist > 260 then
		want = math.floor(want * 0.5) -- 멀리서 난 파괴는 덩어리를 덜 만든다
	end
	-- 초당 예산: 매 프레임 파괴가 이어지면 덩어리를 줄이고, 다 쓰면 그 부피는 먼지로만 보여준다
	local cap = math.min(want, bucketAvail(rubbleBudget))
	local keep: { Chunk } = {}
	if cap > 0 then
		-- 덩어리 크기: 작은 파괴는 1~2 스터드, 벽 한 면은 3~4 스터드, 건물째 날아가면 최대 5.5 스터드
		local lo = math.clamp(got ^ (1 / 3) * 0.55, 1.2, 3.6)
		keep = pickChunks(buildChunks(groups, got, cap, false, lo, CHUNK_MAX), cap)
	end
	bucketTake(rubbleBudget, #keep)
	makeRoom(liveRubble, RUBBLE_LIVE_CAP, #keep)
	local useGroup = groupReady("Debris")
	local fresh = useGroup and groupReady("DebrisFresh")
	local group: string? = if fresh then "DebrisFresh" elseif useGroup then "Debris" else nil
	local madeVol = 0
	for _, c in keep do
		table.insert(liveRubble, launchRubble(c, groups[c.g], ctx, group, fresh))
		madeVol += c.vol
	end
	local overflow = math.max(0, total - madeVol)

	local avg, main = shatterColor(groups)
	local dustColor = avg:Lerp(DUST_GREY, 0.6)
	local dustLight = dustColor:Lerp(Color3.new(1, 1, 1), 0.3)
	local forceK = math.sqrt(math.clamp(ctx.force, 0.6, 2.5))
	local tier = shatterTier(radius, total)
	local mid = liftCenter(ctx, center.Y, 1, 0)

	-- 중심에서 뭉게뭉게 퍼지는 먼지 (넘친 부피만큼 더 짙게). 이것만은 늘 나온다.
	-- 파괴가 매 프레임 이어져 연출 예산이 바닥났으면 입자 수를 반으로 (구름이 겹쳐 쌓이기만 한다)
	local busy = if bucketAvail(fxBudget) < 1 then 0.5 else 1
	emit(mid, math.clamp(math.floor((6 + radius * 1.1 + overflow ^ (1 / 3) * 1.5) * busy), 4, 42), {
		texture = TEX_SMOKE,
		color = dustColor,
		color2 = dustLight,
		size = math.clamp(radius * 0.45, 1.6, 9),
		size2 = math.clamp(radius * 1.05, 3.5, 20),
		speed = math.clamp(radius * 1.5, 7, 34) * forceK,
		life = math.clamp(1.2 + radius * 0.06, 1.2, 2.8),
		spread = 180,
		light = 0,
		transparency = 0.3,
		drag = 3.5,
		accel = Vector3.new(0, 1.5, 0),
		rot = 40,
	})
	-- 사방으로 튀었다가 떨어지는 부스러기 가루
	if fxToken() then
		emit(mid, math.clamp(math.floor(8 + radius * 1.2), 8, 30), {
			texture = TEX_SMOKE,
			color = dustColor:Lerp(Color3.new(0, 0, 0), 0.45),
			size = 0.45,
			size2 = 0.3,
			speed = math.clamp(28 + radius * 1.5, 28, 70) * forceK,
			life = 1.1,
			spread = 180,
			light = 0,
			transparency = 0,
			drag = 0.6,
			accel = Vector3.new(0, -110, 0),
			rot = 360,
		})
	end
	-- 작은 파편
	if fxToken() then
		local bias = if ctx.dir.Magnitude > 0.5 then ctx.dir * 0.8 + Vector3.new(0, 0.6, 0) else Vector3.new(0, 0.7, 0)
		shardBurst(
			mid,
			math.clamp(math.floor(3 + radius * 0.5), 4, 8),
			main.color,
			45 * forceK,
			math.clamp(radius * 0.08, 0.35, 0.9),
			0.9,
			main.material,
			110,
			bias
		)
	end
	-- 큰 파괴: 바닥을 따라 퍼지는 충격 고리 + 낮게 깔리는 흙먼지
	if radius >= 12 then
		local gy = ctx.ground
		if gy and center.Y - gy <= radius + 4 and fxToken() then
			local g = Vector3.new(center.X, gy, center.Z)
			ring(g + Vector3.new(0, 0.3, 0), Vector3.yAxis, radius * 0.5, radius * 2.6, dustLight, 0.5, 0.45, 0.35)
			dust(g + Vector3.new(0, 1.2, 0), math.clamp(math.floor(radius * 0.8), 10, 24), math.clamp(radius * 0.3, 3, 7), dustColor)
		end
	elseif fxToken() then
		-- 작은·중간 파괴: 부서진 자리 아래쪽에서 확 솟는 흙먼지 (바닥 위에서)
		dust(liftCenter(ctx, center.Y - radius * 0.4, 1, 3), math.clamp(math.floor(4 + radius * 1.2), 5, 14), math.clamp(radius * 0.4, 1.5, 4.5), dustColor)
	end
	-- 덩어리로 못 만든 부피는 그 자리에서 먼지로. 자리는 받은 조각 전체에서 부피 비례로 뽑는다 (큰 파괴의 바깥쪽도 먼지가 인다)
	if overflow > 1 then
		local n = math.min(5, 1 + math.floor(overflow / 500))
		local cnt = math.clamp(math.floor(overflow ^ (1 / 3) * 1.6), 5, 18)
		local size = math.clamp(overflow ^ (1 / 3) * 0.45, 2.5, 7)
		for _, p in overflowSpots(ctx, groups, overflow, n) do
			if not fxToken() then
				break
			end
			dust(aboveGround(pointIn(p), center, 1), cnt, size, dustColor)
		end
	end

	-- 카메라 흔들림 (쌓이지 않게 최소값으로), 가까운 큰 파괴는 FOV 도 살짝 (0.15초에 한 번까지)
	local sizeScore = math.clamp(math.max(radius, total ^ (1 / 3) * 1.3), 0, 40)
	local amount = math.min(math.clamp(0.05 + sizeScore * 0.022, 0.05, 0.75) * math.clamp(0.75 + ctx.force * 0.25, 0.75, 1.5), 0.85)
	local dist = shakeFrom(center, amount)
	if radius >= 14 and dist < 45 then
		local now = os.clock()
		if now - lastFovPunchAt > 0.15 then
			lastFovPunchAt = now
			CameraFX.fovPunch(2)
		end
	end

	-- 소리
	if ctx.sound then
		local vk = math.clamp(0.8 + ctx.force * 0.2, 0.8, 1.3)
		if tier == 1 then
			playDestructionSound("break_prop", center, math.clamp(0.7 + total * 0.01, 0.7, 1) * vk, rng:NextNumber(0.95, 1.15))
		elseif tier == 2 then
			playDestructionSound("break_prop", center, 1 * vk, rng:NextNumber(0.85, 1))
			playDestructionSound("ground_crack", center, 0.8 * vk, rng:NextNumber(0.9, 1.1))
		else
			playDestructionSound("explosion", center, 1 * vk, rng:NextNumber(0.85, 1))
			playDestructionSound("break_prop", center, 0.8 * vk, rng:NextNumber(0.7, 0.85))
		end
		-- 잔해가 바닥에 쏟아지는 소리
		if tier >= 2 and #keep >= 8 then
			local landAt = Vector3.new(center.X, ctx.ground or center.Y, center.Z)
			task.delay(rng:NextNumber(0.4, 0.65), function()
				playDestructionSound("land_heavy", landAt, 0.55 * vk, rng:NextNumber(0.75, 0.95))
			end)
		end
	end
end

-- 칸자키 렌: 잘린 부분이 제자리에서 새까맣게 변했다가 아래로 무너지며 재가 된다
local function crumbleGhost(p: BasePart, dur: number)
	if not p.Parent or isEvicted(p) then
		return
	end
	local cf = p.CFrame
	local s = p.Size
	-- 월드 위쪽과 가장 가까운 자기 축을 납작하게 만들며 아래로 무너뜨린다
	local ax, ay, az = math.abs(cf.XVector.Y), math.abs(cf.YVector.Y), math.abs(cf.ZVector.Y)
	local newSize: Vector3
	local h: number
	if p:IsA("Part") and (p :: Part).Shape == Enum.PartType.Ball then
		newSize = s * 0.1
		h = s.Y
	elseif ay >= ax and ay >= az then
		newSize = Vector3.new(s.X * 1.08, 0.05, s.Z * 1.08)
		h = s.Y * ay
	elseif ax >= az then
		newSize = Vector3.new(0.05, s.Y * 1.08, s.Z * 1.08)
		h = s.X * ax
	else
		newSize = Vector3.new(s.X * 1.08, s.Y * 1.08, 0.05)
		h = s.Z * az
	end
	tween(p, dur, { Size = newSize, CFrame = cf - Vector3.new(0, h * 0.5, 0), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
end

local function shatterAsh(ctx: ShatterCtx, groups: { ShatterGroup }, got: number)
	local center, radius = ctx.center, ctx.radius
	local total = got + ctx.lost
	-- 재 조각은 고정·충돌 없음이라 싸다: 잔해보다 넉넉한 별도 예산과 별도 상한을 쓴다
	local cap = math.min(GHOST_EVENT_CAP, bucketAvail(ghostBudget))
	local keep: { Chunk } = {}
	if cap > 0 then
		local lo = math.clamp(got ^ (1 / 3) * 0.6, 2, 6)
		keep = pickChunks(buildChunks(groups, got, cap, true, lo, 10), cap)
	end
	bucketTake(ghostBudget, #keep)
	makeRoom(liveGhosts, GHOST_LIVE_CAP, #keep)
	-- 칼이 들어온 쪽에서부터 차례로 무너진다
	local d0 = math.huge
	for _, c in keep do
		d0 = math.min(d0, (c.cf.Position - ctx.from).Magnitude)
	end
	local span = math.max(radius * 2, 1)
	local madeVol = 0
	local grow = Vector3.new(0.06, 0.06, 0.06)
	for _, c in keep do
		local g = groups[c.g]
		local p = newChunkPart(c.shape)
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.SmoothPlastic
		p.Color = g.color:Lerp(ASH, 0.6)
		p.Transparency = math.min(g.transparency, 0.3)
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Size = c.size + grow
		p.CFrame = c.cf
		p.Parent = folder
		table.insert(liveGhosts, p)
		madeVol += c.vol
		tween(p, 0.08, { Color = ASH, Transparency = 0 })
		local hold = 0.1 + math.clamp(((c.cf.Position - ctx.from).Magnitude - d0) / span, 0, 1) * 0.35 + rng:NextNumber(0, 0.08)
		local dur = rng:NextNumber(0.5, 1.1)
		task.delay(hold, crumbleGhost, p, dur)
		destroyLater(p, hold + dur + 0.15)
	end
	local overflow = math.max(0, total - madeVol)
	local mid = liftCenter(ctx, center.Y, 1, 0)

	-- 검은 재 폭발 (붉은 불티 포함). 이것만은 늘 나온다. 매 프레임 이어지는 중이면 입자 수를 반으로.
	local busy = if bucketAvail(fxBudget) < 1 then 0.5 else 1
	ashPuff(mid, math.clamp(math.floor((8 + radius * 1.1 + overflow ^ (1 / 3) * 1.2) * busy), 5, 36), math.clamp(radius * 0.32, 1.6, 6), math.clamp(radius * 1.1, 6, 22))
	-- 무너지는 순간 조각 자리에서 재가 한 번 더 인다 (+ 재 조각으로 못 만든 부피가 크면 받은 조각 전체에서 부피 비례로 몇 곳 더)
	local puffs: { { pos: Vector3, size: number } } = {}
	if fxToken() then
		if #keep > 0 then
			for _ = 1, math.min(2, #keep) do
				local c = keep[rng:NextInteger(1, #keep)]
				table.insert(puffs, { pos = c.cf.Position, size = math.clamp(c.size.Magnitude * 0.3, 1.2, 4) })
			end
		else
			for _, p in pieceSpots(groups, 2, nil) do
				table.insert(puffs, { pos = pointIn(p), size = math.clamp(p.size.Magnitude * 0.3, 1.2, 4) })
			end
		end
	end
	if overflow > 200 then
		local size = math.clamp(overflow ^ (1 / 3) * 0.3, 2, 5)
		for _, p in overflowSpots(ctx, groups, overflow, math.min(4, math.ceil(overflow / 800))) do
			if not fxToken() then
				break
			end
			table.insert(puffs, { pos = pointIn(p), size = size })
		end
	end
	if #puffs > 0 then
		task.delay(0.3, function()
			for _, pf in puffs do
				ashPuff(aboveGround(pf.pos, center, 1), 8, pf.size, 6)
			end
		end)
	end
	-- 아래로 가라앉는 재 구름 (긴 상자 영역이면 반지름이 커서 땅속에서 뿜어졌다 → 바닥 위 2 스터드 이상)
	if fxToken() then
		emit(liftCenter(ctx, center.Y - radius * 0.3, 2, 4), math.clamp(math.floor(radius * 1.2), 6, 22), {
			texture = TEX_SMOKE,
			color = ASH,
			color2 = ASH_GREY,
			size = math.clamp(radius * 0.4, 2, 8),
			size2 = math.clamp(radius * 0.9, 4, 16),
			speed = math.clamp(radius * 0.6, 3, 12),
			life = 2,
			spread = 180,
			light = 0,
			transparency = 0.25,
			drag = 2.5,
			accel = Vector3.new(0, -3, 0),
			rot = 30,
		})
	end
	-- 팔랑이며 떨어지는 검은 재 조각
	if fxToken() then
		shardBurst(
			center + Vector3.new(0, radius * 0.3, 0),
			math.clamp(math.floor(4 + radius * 0.35), 4, 10),
			ASH,
			12,
			math.clamp(radius * 0.05, 0.3, 0.7),
			1.8,
			Enum.Material.SmoothPlastic,
			14,
			Vector3.new(0, 0.9, 0)
		)
	end

	local sizeScore = math.clamp(math.max(radius, total ^ (1 / 3) * 1.3), 0, 40)
	shakeFrom(center, math.clamp(0.05 + sizeScore * 0.022, 0.05, 0.75) * 0.5)

	if ctx.sound then
		local big = shatterTier(radius, total) >= 3
		playDestructionSound("ren_ash_gain", center, if big then 1.2 else 0.9, rng:NextNumber(0.85, 1.05))
		if big then
			playDestructionSound("ren_ash_wave", center, 0.9, rng:NextNumber(0.7, 0.85))
		end
	end
end

-- 복구된 파트 자리 안에 남아 있는 로컬 잔해·재 조각을 지운다.
-- (조각이 너무 많아 서버가 일찍 복구하면, 아직 살아 있는 잔해가 다시 생긴 벽 속에 박혀 튕겨 나간다)
-- cframes / sizes: 같은 순서의 목록. 둘 중 하나라도 없으면 아무것도 안 한다.
local function clearRestored(cframes: any, sizes: any)
	if typeof(cframes) ~= "table" or typeof(sizes) ~= "table" then
		return
	end
	local boxes: { RestoredBox } = {}
	for i, raw in cframes do
		if #boxes >= REBUILD_BOX_LIMIT then
			break
		end
		if typeof(raw) ~= "CFrame" then
			continue
		end
		local cf = raw :: CFrame
		local s = finiteVec(sizes[i])
		if not s or not finiteVec(cf.Position) then
			continue
		end
		local half = Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z)) / 2 + Vector3.new(0.5, 0.5, 0.5)
		table.insert(boxes, { cf = cf, half = half, center = cf.Position, reach = half.Magnitude })
	end
	if #boxes == 0 then
		return
	end
	for _, list in { liveRubble, liveGhosts } do
		for _, p in list do
			if not p.Parent then
				continue
			end
			local pos = p.Position
			for _, b in boxes do
				if (pos - b.center).Magnitude <= b.reach then
					local rel = b.cf:PointToObjectSpace(pos)
					if math.abs(rel.X) <= b.half.X and math.abs(rel.Y) <= b.half.Y and math.abs(rel.Z) <= b.half.Z then
						p:Destroy()
						break
					end
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- 핸들러
----------------------------------------------------------------------
local handlers: { [string]: (data: { [string]: any }) -> () } = {}

handlers.Hit = function(d)
	local target = d.target :: Model?
	local attacker = d.attacker :: Model?
	local pos = d.pos :: Vector3
	local kind = (d.kind :: string?) or "light"
	local aRoot = rootOf(attacker)
	local hitPos = if aRoot then pos + (aRoot.Position - pos).Unit * 0.8 else pos
	hitEffect(kind, hitPos, if aRoot then aRoot.Position else nil)
	local snd = (d.sound :: string?) or HIT_SOUND[kind] or "m1_hit"
	Sounds.play(snd, { position = pos, random = 0.08 })
	local stop = (d.hitstop :: number?) or 0.05
	if target then
		Animator.freeze(target, stop)
		highlightFlash(target, if d.armored then GOLD else Color3.new(1, 1, 1))
	end
	if attacker then
		Animator.freeze(attacker, stop)
	end
	local shake = (d.shake :: number?) or 0.12
	if isLocal(target) or isLocal(attacker) then
		CameraFX.shake(shake)
		if shake >= 0.35 then
			CameraFX.speedLines(0.12 + shake * 0.25, 0.7 + shake * 0.5)
		end
		if shake >= 0.5 then
			CameraFX.impact(math.min(1, shake))
			CameraFX.fovPunch(6)
		end
	else
		local lr = rootOf(player.Character)
		if lr and (lr.Position - pos).Magnitude < 40 and shake >= 0.5 then
			CameraFX.shake(shake * 0.4)
		end
	end
end

-- 벽꽝: 벽에 금이 가며 파편이 튀고 먼지가 인다
handlers.WallSlam = function(d)
	local pos = finiteVec(d.pos)
	if not pos then
		return
	end
	local rawNormal = finiteVec(d.normal)
	local normal = if rawNormal and rawNormal.Magnitude > 0.01 then rawNormal.Unit else Vector3.yAxis
	-- broke: 몸이 벽을 뚫고 지나갔다. 그 자리 벽면은 방금 부서져 없으니 금·돌은 그리지 않는다 (구멍 속에 떠 있게 된다)
	if d.broke ~= true then
		local up = if math.abs(normal.Y) > 0.9 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
		local right = normal:Cross(up).Unit
		local wallUp = right:Cross(normal).Unit
		local base = CFrame.fromMatrix(pos, right, wallUp, -normal)
		-- 금 간 벽면 (방사형 균열 + 튀어나온 돌)
		for i = 1, 9 do
			local a = (i / 9) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
			local len = rng:NextNumber(2.5, 5)
			local dir = right * math.cos(a) + wallUp * math.sin(a)
			local mid = pos + dir * (len / 2) + normal * 0.08
			local crack = newPart(Vector3.new(0.18, 0.12, len), CFrame.lookAt(mid, mid + dir), Color3.fromRGB(30, 26, 24), Enum.Material.Slate, 0)
			task.delay(2, function()
				fadeOut(crack, 0.8)
			end)
			local s = rng:NextNumber(0.7, 1.4)
			local rock = newPart(Vector3.new(s, s * 0.7, s), base * CFrame.new(math.cos(a) * len * 0.45, math.sin(a) * len * 0.45, -0.3) * CFrame.Angles(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), 0), Color3.fromRGB(110, 100, 94), Enum.Material.Slate, 0)
			task.delay(1.6, function()
				fadeOut(rock, 0.8)
			end)
		end
	end
	shardBurst(pos + normal * 0.5, 12, Color3.fromRGB(120, 110, 100), 30, 0.6, 0.8, Enum.Material.Slate, 70, normal)
	dust(pos + normal * 1.5, 12, 3)
	ring(pos + normal * 0.2, normal, 2, 12, Color3.fromRGB(230, 220, 205), 0.3, 0.25)
	Sounds.play("ground_crack", { position = pos, random = 0.08 })
	Sounds.play("m1_hit_heavy", { position = pos, volume = 0.8, pitch = 0.85 })
	local lr = rootOf(player.Character)
	if isLocal(d.model) then
		CameraFX.shake(0.55)
		CameraFX.impact(0.6)
	elseif lr and (lr.Position - pos).Magnitude < 40 then
		CameraFX.shake(0.2)
	end
end

-- 크게 날아가는 동안 몸에 바람 궤적이 붙는다
handlers.Knockback = function(d)
	local model = d.model :: Model?
	local torso = model and model:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local color = (d.color :: Color3?) or Color3.new(1, 1, 1)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = torso
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.2, 0)
	a1.Parent = torso
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.25
	trail.LightEmission = 0.5
	trail.FaceCamera = true
	trail.Parent = torso
	Sounds.play("knockback_whoosh", { at = torso, random = 0.1 })
	local dur = (d.duration :: number?) or 0.7
	if isLocal(model) then
		CameraFX.speedLines(dur * 0.8, 1.1, color)
	end
	task.delay(dur, function()
		trail.Enabled = false
		destroyLater(trail, 0.4)
		destroyLater(a0, 0.4)
		destroyLater(a1, 0.4)
	end)
end

-- 앞대시 돌진 공격
handlers.DashStrike = function(d)
	local model = d.model :: Model?
	local pos = d.pos :: Vector3
	local dir = (d.dir :: Vector3).Unit
	local isRen = d.charId == "KanzakiRen"
	local color = if isRen then Color3.fromRGB(255, 90, 90) else GOLD_LIGHT
	ring(pos, dir, 2, 16, color, 0.3, 0.3)
	ring(pos - dir * 1.5, dir, 1.5, 10, Color3.new(1, 1, 1), 0.22, 0.18)
	impactStreaks(pos, dir, color, 10, 13)
	groundShock(pos, 6, color)
	if model then
		afterimage(model, color, 0.3, 0.3)
	end
	local lr = rootOf(player.Character)
	if isLocal(model) or (lr and (lr.Position - pos).Magnitude < 8) then
		CameraFX.speedLines(0.25, 1)
		CameraFX.fovPunch(5)
	end
end

handlers.Block = function(d)
	local pos = d.pos :: Vector3
	flash(pos, 2, Color3.fromRGB(170, 210, 255), 0.12)
	shardBurst(pos, 5, Color3.fromRGB(200, 230, 255), 22, 0.25, 0.25, nil, 10)
	Sounds.play("block_hit", { position = pos, random = 0.06 })
	if isLocal(d.model) then
		CameraFX.shake(0.08)
	end
end

handlers.GuardBreak = function(d)
	local pos = d.pos :: Vector3
	flash(pos, 4, Color3.fromRGB(150, 200, 255), 0.25)
	shardBurst(pos, 18, Color3.fromRGB(170, 220, 255), 40, 0.5, 0.6, Enum.Material.Glass, 50)
	ring(pos, Vector3.new(0, 1, 0), 2, 16, Color3.fromRGB(170, 220, 255), 0.35, 0.3)
	Sounds.play("guard_break", { position = pos })
	if isLocal(d.model) then
		CameraFX.shake(0.4)
		CameraFX.impact(0.6)
	end
end

handlers.Parry = function(d)
	local pos = d.pos :: Vector3
	flash(pos, 3.5, Color3.new(1, 1, 1), 0.2, 3)
	ring(pos, Vector3.new(0, 1, 0), 2, 14, Color3.new(1, 1, 1), 0.3, 0.2)
	ring(pos, Vector3.new(1, 0, 0), 2, 10, Color3.fromRGB(255, 240, 200), 0.3, 0.15)
	emit(pos, 24, { color = Color3.new(1, 1, 1), size = 0.8, speed = 40, life = 0.4 })
	Sounds.play("parry", { position = pos })
	local lr = rootOf(player.Character)
	if lr and (lr.Position - pos).Magnitude < 12 then
		CameraFX.shake(0.3)
		CameraFX.impact(0.5)
	end
end

handlers.Dash = function(d)
	local model = d.model :: Model?
	if not model or (d.exceptOwner ~= nil and d.exceptOwner == player) then
		return
	end
	VFX.dashEffect(model)
end

function VFX.dashEffect(model: Model)
	local root = rootOf(model)
	if not root then
		return
	end
	local cid = model:GetAttribute("CharId")
	local def = if typeof(cid) == "string" then CharacterDefs.get(cid) else nil
	local color = if def then def.color else Color3.new(1, 1, 1)
	if isLocal(model) then
		CameraFX.speedLines(0.22, 0.75)
		CameraFX.fovPunch(4)
	end
	afterimage(model, color, 0.35, 0.4)
	task.delay(0.08, function()
		if model.Parent then
			afterimage(model, color, 0.3, 0.6)
		end
	end)
	dust(Vector3.new(root.Position.X, groundY(root.Position) + 0.5, root.Position.Z), 6, 2)
end

handlers.Evasive = function(d)
	local model = d.model :: Model?
	local pos = d.pos :: Vector3
	flash(pos, 3, Color3.new(1, 1, 1), 0.2)
	ring(pos, Vector3.new(0, 1, 0), 2, 12, Color3.new(1, 1, 1), 0.3, 0.2)
	if model then
		afterimage(model, Color3.new(1, 1, 1), 0.4, 0.3)
	end
end

handlers.Damage = function(d)
	local model = d.model :: Model?
	local root = rootOf(model)
	local lr = rootOf(player.Character)
	if not root or not model or model == player.Character then
		return
	end
	if lr and (lr.Position - root.Position).Magnitude > 70 then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(80, 30)
	gui.StudsOffsetWorldSpace = Vector3.new(rng:NextNumber(-1.5, 1.5), 3.5, rng:NextNumber(-1.5, 1.5))
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 20
	label.TextColor3 = Color3.fromRGB(255, 240, 220)
	label.TextStrokeTransparency = 0.2
	label.Text = tostring(d.amount)
	label.Parent = gui
	gui.Adornee = root
	gui.Parent = folder
	tween(gui, 0.8, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0) })
	tween(label, 0.8, { TextTransparency = 1, TextStrokeTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	destroyLater(gui, 0.85)
end

handlers.Combo = function(d)
	local cb = VFX.onCombo
	if cb then
		cb(d.count :: number)
	end
end

handlers.AwakenReady = function(_d)
	Sounds.play("awaken_ready", {})
	local cb = VFX.onAwakenReady
	if cb then
		cb()
	end
end

handlers.Death = function(d)
	local pos = d.pos :: Vector3
	Sounds.play("death", { position = pos })
	Sounds.play("explosion", { position = pos, volume = 0.6, pitch = 1.2 })
	flash(pos, 7, Color3.new(1, 1, 1), 0.3, 3)
	crossFlash(pos, Color3.new(1, 1, 1), 20, 0.3)
	ring(pos, Vector3.new(0, 1, 0), 3, 30, Color3.new(1, 1, 1), 0.45, 0.4)
	groundShock(pos, 10)
	local lr = rootOf(player.Character)
	if lr and (lr.Position - pos).Magnitude < 60 then
		CameraFX.impact(1)
		CameraFX.shake(0.6)
		CameraFX.speedLines(0.35, 1.2)
	end
	emit(pos, 30, { texture = TEX_SMOKE, color = Color3.fromRGB(30, 30, 34), size = 2, size2 = 5, speed = 8, life = 1.4, light = 0, transparency = 0.3 })
	ring(pos, Vector3.new(0, 1, 0), 2, 14, Color3.fromRGB(200, 60, 60), 0.5, 0.2)
end

handlers.Spawn = function(d)
	local pos = d.pos :: Vector3
	local g = groundY(pos)
	local pillar = newPart(Vector3.new(6, 30, 6), CFrame.new(pos.X, g + 15, pos.Z), Color3.fromRGB(255, 240, 210), Enum.Material.Neon, 0.4)
	pillar.Shape = Enum.PartType.Cylinder
	pillar.CFrame = CFrame.new(pos.X, g + 15, pos.Z) * CFrame.Angles(0, 0, math.rad(90))
	pillar.Size = Vector3.new(30, 5, 5)
	fadeOut(pillar, 0.6, Vector3.new(30, 0.2, 0.2))
	ring(Vector3.new(pos.X, g + 0.3, pos.Z), Vector3.new(0, 1, 0), 2, 14, Color3.fromRGB(255, 230, 190), 0.5, 0.2)
end

handlers.PropBreak = function(d)
	local pos = d.pos :: Vector3
	local size = d.size :: Vector3
	local color = d.color :: Color3
	local n = math.clamp(math.floor(size.Magnitude * 1.2), 4, 10)
	for _ = 1, n do
		local s = math.max(0.4, size.Magnitude * rng:NextNumber(0.08, 0.18))
		local chunk = newPart(Vector3.new(s, s * 0.7, s * 1.2), CFrame.new(pos + rng:NextUnitVector() * size.Magnitude * 0.2), color, (d.material :: Enum.Material?) or Enum.Material.Wood, 0)
		table.insert(shards, {
			part = chunk,
			vel = (rng:NextUnitVector() + Vector3.new(0, 1.2, 0)).Unit * rng:NextNumber(18, 36),
			spin = CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.3, 0.3)),
			life = 1.4,
			maxLife = 1.4,
			gravity = 90,
		})
	end
	dust(pos, 8, 2.5)
	Sounds.play("break_prop", { position = pos, random = 0.1 })
end

handlers.PropAsh = function(d)
	local pos = d.pos :: Vector3
	local size = d.size :: Vector3
	-- 물체 모양 그대로 검게 변했다가 가루로 무너진다
	local ghost = newPart(size, CFrame.new(pos), ASH, Enum.Material.SmoothPlastic, 0)
	tween(ghost, 0.5, { Size = Vector3.new(size.X * 1.05, 0.1, size.Z * 1.05), CFrame = CFrame.new(pos - Vector3.new(0, size.Y / 2, 0)), Transparency = 0.6 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	destroyLater(ghost, 0.55)
	ashPuff(pos, 16, math.max(1.5, size.Magnitude * 0.25), 6)
	Sounds.play("ren_ash_gain", { position = pos, random = 0.08 })
end

handlers.PropRestore = function(d)
	emit(d.pos :: Vector3, 6, { color = Color3.fromRGB(255, 240, 200), size = 0.5, speed = 4, life = 0.6 })
end

-- 지형 파괴: 없앤 부피를 잔해(또는 재)로 만든다
handlers.Shatter = function(d)
	local center = finiteVec(d.center)
	if not center then
		return
	end
	local radius = math.clamp(finiteNum(d.radius) or 4, 0.5, 120)
	local dir = finiteVec(d.dir) or Vector3.zero
	local ctx: ShatterCtx = {
		center = center,
		radius = radius,
		from = finiteVec(d.from) or center,
		dir = if dir.Magnitude > 0.01 then dir.Unit else Vector3.zero,
		force = math.clamp(finiteNum(d.force) or 1, 0.2, 5),
		sound = d.sound ~= false,
		-- 조각 수 상한 때문에 서버가 조각으로 보내지 않은 부피 (없으면 0)
		lost = math.clamp(finiteNum(d.lost) or 0, 0, 1e6),
		ground = groundBelow(center, radius + 20),
	}
	local ash = d.ash == true
	local groups, got = parseShatterGroups(d.groups)
	if #groups == 0 then
		-- 조각 목록이 잘려서 안 왔으면 먼지(재)만. 서버가 알려 준 없앤 부피가 크면 그만큼 키운다
		local s = math.max(radius, ctx.lost ^ (1 / 3) * 0.8)
		local mid = liftCenter(ctx, center.Y, 1, 0)
		if ash then
			ashPuff(mid, 12, math.clamp(s * 0.3, 1.5, 5), 10)
		else
			dust(mid, math.clamp(math.floor(s * 1.2), 6, 20), math.clamp(s * 0.4, 2, 7))
		end
		return
	end
	if ash then
		shatterAsh(ctx, groups, got)
	else
		shatterRubble(ctx, groups, got)
	end
end

-- 복구된 파트 자리에 부드러운 금빛 반짝임 (+ 그 자리에 남은 로컬 잔해 정리)
handlers.Rebuild = function(d)
	local sizes = d.sizes
	clearRestored(d.cframes, sizes)
	local positions = d.positions
	if typeof(positions) ~= "table" then
		return
	end
	local cam = workspace.CurrentCamera
	local shown = 0
	for i, raw in positions do
		if shown >= 12 then
			break
		end
		local pos = finiteVec(raw)
		if not pos or (cam and (cam.CFrame.Position - pos).Magnitude > 300) then
			continue
		end
		local s = if typeof(sizes) == "table" then finiteVec(sizes[i]) else nil
		local m = math.clamp(if s then s.Magnitude else 5, 1, 60)
		shown += 1
		emit(pos, math.clamp(math.floor(m * 0.5), 4, 14), {
			texture = TEX_SPARK,
			color = GOLD_LIGHT,
			color2 = Color3.new(1, 1, 1),
			size = math.clamp(m * 0.07, 0.4, 1.6),
			size2 = 0,
			speed = math.clamp(m * 0.3, 2, 10),
			life = 0.8,
			spread = 180,
			light = 0.6,
			transparency = 0.3,
			drag = 4,
			accel = Vector3.new(0, 2, 0),
			rot = 60,
		})
	end
end

handlers.AshGain = function(d)
	local model = d.model :: Model?
	if not model then
		return
	end
	local scab = model:FindFirstChild("Scabbard")
	local sheath = scab and scab:FindFirstChild("Sheath")
	if sheath and sheath:IsA("BasePart") then
		emit(sheath.Position, 6 * (d.amount :: number), { texture = TEX_SMOKE, color = ASH, size = 0.8, size2 = 0.2, speed = 3, life = 0.5, light = 0, spread = 180 })
		local list = seals(model)
		local ash = model:GetAttribute("Ash")
		local count = if typeof(ash) == "number" then ash else 0
		for i, s in list do
			if i <= count + (d.amount :: number) then
				s.Transparency = 0.2
				tween(s, 0.5, { Transparency = 0.85 })
			end
		end
	end
end

handlers.AshVent = function(d)
	local model = d.model :: Model?
	if not model then
		return
	end
	local scab = model:FindFirstChild("Scabbard")
	local sheath = scab and scab:FindFirstChild("Sheath")
	if sheath and sheath:IsA("BasePart") then
		ashPuff(sheath.Position, 5 + 3 * (d.amount :: number), 1, 5)
	end
end

handlers.Projectile = function(d)
	projectileStart(d)
end

handlers.ProjectileEnd = function(d)
	projectileEnd(d.id :: number, d.pos :: Vector3?)
end

handlers.ProjectileRedirect = function(d)
	local id = d.id :: number
	local old = projs[id]
	if old then
		projectileEnd(id, d.pos :: Vector3)
	end
	local w = if old then old.holder.Size.X else 4
	projectileStart({ id = id, kind = "gold", origin = d.pos, dir = d.dir, speed = d.speed, range = d.range, width = w, height = 3 })
	flash(d.pos :: Vector3, 3, GOLD, 0.2)
end

handlers.ChiCharge = function(d)
	local model = d.model :: Model?
	if not model then
		return
	end
	local arm = model:FindFirstChild("Right Arm")
	if arm and arm:IsA("BasePart") then
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(0, -1, 0)
		att.Parent = arm
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = TEX_SPARK
		pe.Color = ColorSequence.new(GOLD)
		pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
		pe.Lifetime = NumberRange.new(0.3, 0.5)
		pe.Rate = 60
		pe.Speed = NumberRange.new(-8, -4)
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.LightEmission = 1
		pe.Parent = att
		local light = Instance.new("PointLight")
		light.Color = GOLD
		light.Brightness = 3
		light.Range = 8
		light.Parent = att
		task.delay((d.duration :: number?) or 0.4, function()
			pe.Enabled = false
			tween(light, 0.3, { Brightness = 0 })
			destroyLater(att, 0.8)
		end)
	end
end

handlers.GoldenPalm = function(d)
	local origin = d.origin :: Vector3
	local dir = (d.dir :: Vector3).Unit
	local length = d.length :: number
	local startCF = CFrame.lookAt(origin + dir * 2.5, origin + dir * 10) * CFrame.Angles(math.rad(90), 0, 0)
	local parts = goldPalm(startCF, 0.45)
	local endCF = CFrame.lookAt(origin + dir * (length * 0.75), origin + dir * (length + 5)) * CFrame.Angles(math.rad(90), 0, 0)
	local startScale = 0.45
	local endScale = 1.25
	local t0 = os.clock()
	local rels: { CFrame } = {}
	local sizes: { Vector3 } = {}
	for _, p in parts do
		rels[#rels + 1] = startCF:ToObjectSpace(p.CFrame)
		sizes[#sizes + 1] = p.Size
	end
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local a = math.clamp((os.clock() - t0) / 0.16, 0, 1)
		local e = 1 - (1 - a) ^ 3
		local cf = startCF:Lerp(endCF, e)
		local sc = startScale + (endScale - startScale) * e
		local k = sc / startScale
		for i, p in parts do
			local rel = rels[i]
			p.CFrame = cf * CFrame.new(rel.Position * k) * rel.Rotation
			p.Size = sizes[i] * k
		end
		if a >= 1 then
			conn:Disconnect()
			for _, p in parts do
				fadeOut(p, 0.35, p.Size * 1.3)
			end
		end
	end)
	Sounds.play("lin_palm_impact", { position = origin + dir * length * 0.6, volume = 0.6, pitch = 0.8 })
	ring(origin + dir * (length * 0.8), dir, 3, 18, GOLD, 0.35, 0.35)
	flash(origin + dir * (length * 0.8), 5, GOLD, 0.3)
	emit(origin + dir * (length * 0.5), 30, { color = GOLD, size = 1, speed = 35, life = 0.6, light = 1, spread = 35 })
end

handlers.RedirectStance = function(d)
	local model = d.model :: Model?
	local root = rootOf(model)
	if not root or not model then
		return
	end
	local orbs: { Part } = {}
	for i = 1, 8 do
		local o = ball(0.6, root.Position, GOLD, 0.2)
		orbs[i] = o
	end
	local t0 = os.clock()
	local dur = (d.duration :: number?) or 0.9
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local r = rootOf(model)
		if t > dur or not r then
			conn:Disconnect()
			for _, o in orbs do
				fadeOut(o, 0.2)
			end
			return
		end
		for i, o in orbs do
			local a = t * 7 + (i / 8) * math.pi * 2
			o.CFrame = r.CFrame * CFrame.new(math.cos(a) * 3.2, math.sin(t * 5 + i) * 1.4, math.sin(a) * 3.2)
		end
	end)
end

handlers.Redirect = function(d)
	local pos = d.pos :: Vector3
	for i = 1, 3 do
		task.delay(i * 0.06, function()
			ring(pos, Vector3.new(0, 1, 0), 3, 10 + i * 4, GOLD, 0.35, 0.3)
		end)
	end
	flash(pos, 4, GOLD_LIGHT, 0.3)
	emit(pos, 30, { color = GOLD, size = 1, speed = 25, life = 0.7, light = 1 })
end

handlers.StaffRing = function(d)
	local pos = d.pos :: Vector3
	local r = d.radius :: number
	ring(pos, Vector3.new(0, 1, 0), 2, r * 2.2, Color3.fromRGB(255, 200, 110), 0.25, 0.4, 0.2)
	if d.final then
		ring(pos + Vector3.new(0, 1.5, 0), Vector3.new(0, 1, 0), 2, r * 2.6, GOLD, 0.35, 0.3)
		dust(Vector3.new(pos.X, groundY(pos) + 0.5, pos.Z), 10, 3)
	end
end

handlers.Barrage = function(d)
	local model = d.model :: Model?
	local dir = (d.dir :: Vector3).Unit
	local dur = (d.duration :: number?) or 1
	local t0 = os.clock()
	task.spawn(function()
		while os.clock() - t0 < dur do
			local r = rootOf(model)
			if not r then
				break
			end
			local right = dir:Cross(Vector3.new(0, 1, 0))
			local p = r.Position + dir * rng:NextNumber(2.5, 4.5) + right * rng:NextNumber(-2, 2) + Vector3.new(0, rng:NextNumber(-0.5, 1.8), 0)
			local cf = CFrame.lookAt(p, p + dir) * CFrame.Angles(math.rad(90), 0, 0)
			for _, part in goldPalm(cf, 0.22) do
				fadeOut(part, 0.18)
			end
			if rng:NextNumber() < 0.5 then
				Sounds.play("m1_swing", { position = p, volume = 0.35, pitch = 1.3, random = 0.1 })
			end
			task.wait(0.045)
		end
	end)
end

handlers.GroundCrack = function(d)
	VFX.groundCrack(d.pos :: Vector3, (d.radius :: number?) or 7, d.color :: string?)
end

handlers.Shockwave = function(d)
	local pos = d.pos :: Vector3
	local r = d.radius :: number
	local color = if d.color == "gold" then GOLD elseif d.color == "ash" then RED else Color3.new(1, 1, 1)
	ring(pos, Vector3.new(0, 1, 0), 2, r * 2, color, 0.4, 0.5)
	flash(pos, r * 0.4, color, 0.3, 2)
	if d.color == "ash" then
		ashPuff(pos, 20, 3, 18)
	else
		emit(pos, 25, { color = color, size = 1.2, speed = 45, life = 0.6, light = 1 })
	end
	local lr = rootOf(player.Character)
	if lr and (lr.Position - pos).Magnitude < r * 2.5 then
		CameraFX.shake(0.35)
	end
end

handlers.AwakenStart = function(d)
	local model = d.model :: Model?
	local charId = d.charId :: string
	local root = rootOf(model)
	if not root or not model then
		return
	end
	local isLin = charId == "LinYuan"
	local color = if isLin then GOLD else RED
	Sounds.play(if isLin then "lin_awaken" else "ren_awaken", { at = root })
	-- 빛기둥 / 재의 소용돌이
	local g = groundY(root.Position)
	local pillar = newPart(Vector3.new(60, 3, 3), CFrame.new(root.Position.X, g + 30, root.Position.Z) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, 0.5)
	pillar.Shape = Enum.PartType.Cylinder
	tween(pillar, 1.2, { Size = Vector3.new(60, 10, 10) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(1.2, function()
		fadeOut(pillar, 0.5, Vector3.new(60, 0.5, 0.5))
	end)
	if isLin then
		emit(root.Position, 40, { color = GOLD, size = 1, speed = -12, life = 1.2, light = 1 })
		task.delay(1.1, function()
			Sounds.play("lin_gong", { at = root })
			Sounds.play("lin_dragon_roar", { at = root })
			ring(Vector3.new(root.Position.X, g + 0.4, root.Position.Z), Vector3.new(0, 1, 0), 2, 50, GOLD, 0.8, 0.5)
			flash(root.Position, 8, GOLD_LIGHT, 0.5)
		end)
	else
		ashPuff(root.Position, 30, 3, 16)
		task.delay(1.1, function()
			Sounds.play("ren_unsheathe", { at = root })
			ring(Vector3.new(root.Position.X, g + 0.4, root.Position.Z), Vector3.new(0, 1, 0), 2, 44, RED, 0.8, 0.5)
			ashPuff(root.Position, 40, 4, 30)
			slashLine(root.Position + Vector3.new(0, 1, 0), 30, RED, 0.5, 0.4, CFrame.new(root.Position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, math.rad(90), 0))
		end)
	end
	if isLocal(model) then
		CameraFX.cutscene(root, if isLin then 1.6 else 1.4)
		task.delay(1.05, function()
			CameraFX.speedLines(0.9, 1.4, if isLin then GOLD_LIGHT else Color3.fromRGB(255, 150, 150))
		end)
	end
	local lr = rootOf(player.Character)
	if lr and (lr.Position - root.Position).Magnitude < 90 then
		task.delay(1.1, function()
			CameraFX.shake(0.6)
			CameraFX.impact(0.8)
		end)
	end
	local cb = VFX.onAwakenTitle
	if cb then
		cb(model, charId)
	end
end

handlers.AwakenEnd = function(d)
	local model = d.model :: Model?
	if model then
		stopDragonAura(model)
		stopAshAura(model)
	end
end

handlers.DragonAura = function(d)
	local model = d.model :: Model?
	if not model then
		return
	end
	if d.on then
		startDragonAura(model)
	else
		stopDragonAura(model)
	end
end

handlers.AshAura = function(d)
	local model = d.model :: Model?
	if not model then
		return
	end
	if d.on then
		startAshAura(model)
	else
		stopAshAura(model)
	end
end

handlers.DragonPaw = function(d)
	local model = d.model :: Model?
	local root = rootOf(model)
	if not root then
		return
	end
	local dir = (d.dir :: Vector3).Unit
	local base = root.Position + dir * 2 + Vector3.new(0, 0.5, 0)
	for i = -1, 1 do
		local right = dir:Cross(Vector3.new(0, 1, 0))
		local p0 = base + right * (i * 0.9)
		local claw = newPart(Vector3.new(0.35, 0.35, 2), CFrame.lookAt(p0, p0 + dir), GOLD, Enum.Material.Neon, 0.1)
		tween(claw, 0.1, { Size = Vector3.new(0.35, 0.35, 9), CFrame = CFrame.lookAt(p0 + dir * 4.5, p0 + dir * 10) }, Enum.EasingStyle.Quart)
		task.delay(0.1, function()
			fadeOut(claw, 0.2)
		end)
	end
	if d.finisher then
		flash(base + dir * 6, 4, GOLD, 0.25)
	end
end

handlers.DragonClaw = function(d)
	local origin = d.origin :: Vector3
	local dir = (d.dir :: Vector3).Unit
	local length = d.length :: number
	local right = dir:Cross(Vector3.new(0, 1, 0))
	local function path(s: number): Vector3
		local sc = math.max(s, 0)
		return origin - dir * 4 + dir * sc + right * math.sin(sc * 0.25) * 2.5 + Vector3.new(0, 2.5 + math.sin(sc * 0.15) * 1.5, 0)
	end
	local sp = makeSerpent(18, 0.75, 1.1, path, 0.1)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		sp.headS = math.min(length + 4, t * 170)
		updateSerpent(sp)
		if t > 0.45 then
			conn:Disconnect()
			destroySerpent(sp, 0.35)
		end
	end)
	Sounds.play("lin_dragon_whoosh", { position = origin })
	Sounds.play("lin_dragon_roar", { position = origin, volume = 0.6, pitch = 1.15 })
	task.delay(0.22, function()
		local tip = origin + dir * length
		flash(tip, 5, GOLD, 0.3)
		ring(tip, dir, 3, 16, GOLD, 0.3, 0.3)
	end)
end

handlers.DragonCoil = function(d)
	local model = d.model :: Model?
	local root = rootOf(model)
	if not root or not model then
		return
	end
	local a = auras[model]
	local dur = (d.duration :: number?) or 2
	if a then
		a.mode = "coil"
		task.delay(dur, function()
			if auras[model] == a then
				a.mode = "aura"
			end
		end)
	end
	local shield = ball(9, root.Position, GOLD, 0.7, Enum.Material.ForceField)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local r = rootOf(model)
		if os.clock() - t0 > dur or not r then
			conn:Disconnect()
			fadeOut(shield, 0.3, Vector3.new(14, 14, 14))
			return
		end
		shield.CFrame = CFrame.new(r.Position) * CFrame.Angles(0, os.clock() * 2, 0)
	end)
	Sounds.play("lin_dragon_whoosh", { at = root })
end

handlers.RisingDragon = function(d)
	local pos = d.pos :: Vector3
	local base = Vector3.new(pos.X, groundY(pos), pos.Z)
	local function path(s: number): Vector3
		local sc = math.max(s, 0)
		return base + Vector3.new(math.cos(sc * 0.45) * 3.2, sc, math.sin(sc * 0.45) * 3.2)
	end
	local sp = makeSerpent(20, 0.7, 1.0, path, 0.1)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		sp.headS = math.min(45, t * 110)
		updateSerpent(sp)
		if t > 0.55 then
			conn:Disconnect()
			destroySerpent(sp, 0.4)
		end
	end)
	Sounds.play("lin_dragon_roar", { position = pos, volume = 0.8 })
	Sounds.play("lin_dragon_whoosh", { position = pos })
	ring(base + Vector3.new(0, 0.3, 0), Vector3.new(0, 1, 0), 2, 16, GOLD, 0.4, 0.3)
end

handlers.DragonDive = function(d)
	local pos = d.pos :: Vector3
	local g = Vector3.new(pos.X, groundY(pos), pos.Z)
	local streak = newPart(Vector3.new(1.5, 1.5, 30), CFrame.lookAt(pos + Vector3.new(0, 15, 0), g), GOLD, Enum.Material.Neon, 0.2)
	fadeOut(streak, 0.3, Vector3.new(0.2, 0.2, 34))
	task.delay(0.12, function()
		VFX.groundCrack(g, 8, "gold")
		flash(g + Vector3.new(0, 1, 0), 6, GOLD, 0.3)
	end)
end

handlers.GoldenReturn = function(d)
	local center = d.pos :: Vector3
	local R = (d.radius :: number?) or 60
	local g = groundY(center)
	local function path(s: number): Vector3
		local a = s / R
		return Vector3.new(center.X + math.cos(a) * R, g + 6 + math.sin(s * 0.08) * 4, center.Z + math.sin(a) * R)
	end
	local sp = makeSerpent(30, 2.6, 4.2, path, 0.05)
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		sp.headS = t * 260
		updateSerpent(sp)
		if t > 1.9 then
			conn:Disconnect()
			destroySerpent(sp, 0.6)
		end
	end)
	Sounds.play("lin_dragon_roar", { position = center, volume = 1.2, pitch = 0.9 })
	Sounds.play("lin_chi_charge", { position = center })
	task.delay(1.45, function()
		Sounds.play("lin_gong", { position = center, volume = 1.2 })
		Sounds.play("explosion", { position = center })
		for i = 1, 3 do
			task.delay(i * 0.08, function()
				ring(Vector3.new(center.X, g + 0.5 + i, center.Z), Vector3.new(0, 1, 0), 4, R * 2.2, if i == 2 then Color3.new(1, 1, 1) else GOLD, 0.6, 0.8)
			end)
		end
		flash(center + Vector3.new(0, 3, 0), 20, GOLD_LIGHT, 0.6, 3)
		emit(center, 60, { color = GOLD, size = 2, speed = 80, life = 1, light = 1 })
		local lr = rootOf(player.Character)
		if lr and (lr.Position - center).Magnitude < R * 2 then
			CameraFX.shake(1)
			CameraFX.impact(1)
			CameraFX.flash(GOLD_LIGHT, 0.6)
		end
	end)
end

handlers.SlashLine = function(d)
	local from = d.from :: Vector3
	local to = d.to :: Vector3
	local mid = (from + to) / 2
	local len = (to - from).Magnitude
	local cf = CFrame.lookAt(mid, to)
	slashLine(mid, len + 4, Color3.fromRGB(255, 235, 235), 0.3, 0.25, cf)
	slashLine(mid, len + 2, RED, 0.4, 0.4, cf * CFrame.Angles(0, 0, math.rad(90)))
	for i = 0, 4 do
		ashPuff(from:Lerp(to, i / 4), 3, 1, 4)
	end
end

handlers.SeveranceDash = function(d)
	local model = d.model :: Model?
	if not model then
		return
	end
	for i = 0, 4 do
		task.delay(i * 0.03, function()
			if model.Parent then
				afterimage(model, RED, 0.5, 0.35)
			end
		end)
	end
	Sounds.play("ren_slash", { position = d.from :: Vector3, pitch = 0.8 })
end

handlers.SeveranceLine = function(d)
	local from = d.from :: Vector3
	local to = d.to :: Vector3
	local delayT = (d.delay :: number?) or 0.45
	local mid = (from + to) / 2
	local len = (to - from).Magnitude
	local line = newPart(Vector3.new(0.15, 0.15, len), CFrame.lookAt(mid, to), RED, Enum.Material.Neon, 0)
	tween(line, delayT, { Size = Vector3.new(0.5, 0.5, len) })
	task.delay(delayT, function()
		fadeOut(line, 0.2, Vector3.new(3, 3, len))
		for i = 0, 5 do
			local p = from:Lerp(to, i / 5)
			flash(p, 3, RED, 0.25)
			ashPuff(p, 8, 2, 14)
		end
		Sounds.play("explosion", { position = mid, volume = 0.7, pitch = 1.3 })
	end)
end

handlers.SealTick = function(d)
	local model = d.model :: Model?
	if not model then
		return
	end
	local i = d.index :: number
	local list = seals(model)
	local s = list[i]
	if s then
		s.Transparency = 0
		flash(s.Position, 0.8, RED, 0.2)
	end
	local root = rootOf(model)
	Sounds.play("ren_seal_tick", { at = root, pitch = 1 + i * 0.07 })
	if i == 10 and root then
		ring(root.Position, Vector3.new(0, 1, 0), 2, 18, RED, 0.3, 0.3)
	end
end

handlers.SealReset = function(d)
	local model = d.model :: Model?
	if not model then
		return
	end
	local keep = ashAuras[model] ~= nil
	for _, s in seals(model) do
		s.Transparency = if keep then 0.1 else 0.85
	end
end

handlers.MaxOutput = function(d)
	local origin = d.origin :: Vector3
	local dir = (d.dir :: Vector3).Unit
	local length = d.length :: number
	local width = d.width :: number
	Sounds.play("ren_max_output", { position = origin, volume = 1.3 })
	local parts, holder, pe = buildProjectile("ash", width, 8)
	pe.Rate = 200
	local t0 = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - t0
		local s = math.min(length, t * 420)
		local pos = origin + dir * s
		local cf = CFrame.lookAt(pos, pos + dir)
		for _, e in parts do
			e.part.CFrame = cf * e.rel
		end
		holder.CFrame = cf
		if s >= length then
			conn:Disconnect()
			for _, e in parts do
				fadeOut(e.part, 0.3)
			end
			pe.Enabled = false
			destroyLater(holder, 1.5)
		end
	end)
	-- 절단선 전체를 따라 재가 터진다
	for i = 1, 10 do
		task.delay(0.05 + i * 0.03, function()
			local p = origin + dir * (length * i / 10)
			ashPuff(p, 10, 3.5, 20)
			flash(p, 4, RED, 0.25)
		end)
	end
	local mid = origin + dir * (length / 2)
	slashLine(mid, length, Color3.fromRGB(255, 220, 220), 0.6, 0.6, CFrame.lookAt(mid, mid + dir))
	local lr = rootOf(player.Character)
	if lr then
		local dist = (lr.Position - mid).Magnitude
		if dist < length then
			CameraFX.shake(1)
			CameraFX.impact(1)
			CameraFX.flash(Color3.fromRGB(255, 120, 120), 0.5)
		end
	end
end

handlers.AshVeil = function(d)
	ashVeil(d.pos :: Vector3, d.radius :: number, d.duration :: number)
end

handlers.Cough = function(d)
	local model = d.model :: Model?
	local head = model and model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		for i = 0, 3 do
			task.delay(0.3 + i * 0.5, function()
				if head.Parent then
					emit(head.Position + head.CFrame.LookVector * 0.7, 4, { texture = TEX_SMOKE, color = ASH_GREY, size = 0.5, size2 = 1.5, speed = 4, life = 0.6, light = 0, spread = 30 })
				end
			end)
		end
	end
end

----------------------------------------------------------------------
function VFX.handle(name: string, data: any)
	local h = handlers[name]
	if h and typeof(data) == "table" then
		local ok, err = pcall(h :: any, data)
		if not ok then
			warn("[VFX] " .. name .. ": " .. tostring(err))
		end
	end
end

function VFX.init()
	folder = Instance.new("Folder")
	folder.Name = "ClientFX"
	folder.Parent = workspace

	RunService.RenderStepped:Connect(function(dt)
		-- 파편
		for i = #shards, 1, -1 do
			local s = shards[i]
			s.life -= dt
			if s.life <= 0 or not s.part.Parent then
				s.part:Destroy()
				table.remove(shards, i)
			else
				s.vel -= Vector3.new(0, s.gravity * dt, 0)
				s.part.CFrame = (s.part.CFrame + s.vel * dt) * s.spin
				s.part.Transparency = 1 - math.clamp(s.life / s.maxLife * 1.5, 0, 1)
			end
		end
		-- 투사체
		for id, v in projs do
			local step = v.speed * dt
			v.traveled += step
			if v.traveled > v.range + 10 then
				projectileEnd(id, v.pos)
			else
				v.pos += v.dir * step
				local cf = CFrame.lookAt(v.pos, v.pos + v.dir)
				for _, e in v.parts do
					e.part.CFrame = cf * e.rel
				end
				v.holder.CFrame = cf
			end
		end
		-- 각성 오라 용
		for model, a in auras do
			if not model.Parent or not rootOf(model) then
				stopDragonAura(model)
			else
				a.t += dt * (if a.mode == "coil" then 2.2 else 1)
				a.serpent.headS = a.t * 9
				updateSerpent(a.serpent)
			end
		end
		for model in ashAuras do
			if not model.Parent then
				stopAshAura(model)
			end
		end
	end)
end

VFX.fadeOut = fadeOut
VFX.ring = ring
VFX.flash = flash
VFX.emit = emit

return VFX
