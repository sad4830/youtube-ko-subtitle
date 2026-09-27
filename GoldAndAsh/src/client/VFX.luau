--!strict
-- 시각 효과 라이브러리 (전부 파트/파티클/빛으로 만든다 — 업로드한 텍스처나 메시 없음)
-- 서버가 Remotes.FX 로 (이름, 데이터)를 보내면 VFX.handle 이 해당 연출을 재생한다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

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
	Debris:AddItem(p, time + 0.05)
end

-- 둥근 고리 (원기둥을 납작하게 눕힘)
local function ring(pos: Vector3, normal: Vector3, diameter: number, endDiameter: number, color: Color3, time: number, thickness: number?, transparency: number?)
	local up = if math.abs(normal.Y) > 0.99 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local cf = CFrame.lookAt(pos, pos + normal, up) * CFrame.Angles(0, math.rad(90), 0)
	local th = thickness or 0.25
	local p = newPart(Vector3.new(th, diameter, diameter), cf, color, Enum.Material.Neon, transparency or 0.1)
	p.Shape = Enum.PartType.Cylinder
	tween(p, time, { Size = Vector3.new(th * 0.3, endDiameter, endDiameter), Transparency = 1 })
	Debris:AddItem(p, time + 0.05)
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
	Debris:AddItem(holder, life + 0.3)
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
	Debris:AddItem(p, time + 0.1)
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
	Debris:AddItem(h, 0.3)
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
	Debris:AddItem(a.emitter.Parent :: Instance, 2)
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
	Debris:AddItem(vis.holder, 1)
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
			Debris:AddItem(h, 3.5)
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

local function hitEffect(kind: string, pos: Vector3, fromPos: Vector3?)
	local dir = if fromPos then (pos - fromPos) else Vector3.new(0, 0, -1)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(0, 0, -1)
	end
	dir = dir.Unit
	if kind == "palm" or kind == "palm_small" or kind == "light" then
		local s = if kind == "palm_small" then 0.6 else 1
		flash(pos, 2.2 * s, GOLD_LIGHT, 0.14)
		shardBurst(pos, math.floor(6 * s), GOLD, 26, 0.35, 0.3, nil, 20, dir)
		ring(pos, dir, 1.5 * s, 6 * s, GOLD_LIGHT, 0.2, 0.15)
	elseif kind == "palm_heavy" or kind == "gold_heavy" or kind == "gold" then
		local big = kind ~= "gold"
		flash(pos, if big then 4 else 3, GOLD, 0.25, 2.6)
		shardBurst(pos, if big then 16 else 9, GOLD, 45, 0.5, 0.45, nil, 30, dir)
		ring(pos, dir, 2, if big then 16 else 10, GOLD, 0.3, 0.3)
		ring(pos, dir, 1, if big then 10 else 6, Color3.new(1, 1, 1), 0.2, 0.15)
		emit(pos, 18, { color = GOLD, size = 1.2, speed = 30, life = 0.6, light = 1 })
	elseif kind == "staff" or kind == "staff_heavy" then
		local big = kind == "staff_heavy"
		flash(pos, if big then 3.5 else 2, Color3.fromRGB(255, 180, 90), 0.18)
		shardBurst(pos, if big then 12 else 6, Color3.fromRGB(255, 170, 70), 35, 0.4, 0.35, nil, 30, dir)
		ring(pos, dir, 2, if big then 14 else 7, Color3.fromRGB(255, 200, 120), 0.25, 0.2)
	elseif kind == "slash" or kind == "slash_heavy" then
		local big = kind == "slash_heavy"
		slashLine(pos, if big then 12 else 7, Color3.fromRGB(255, 230, 230), 0.22, if big then 0.3 else 0.16)
		if big then
			slashLine(pos, 12, RED, 0.28, 0.24)
		end
		shardBurst(pos, if big then 10 else 5, RED, 30, 0.3, 0.3, nil, 25, dir)
		ashPuff(pos, if big then 12 else 6, 1.2, 12)
	elseif kind == "ash" or kind == "ash_heavy" then
		local big = kind == "ash_heavy"
		flash(pos, if big then 4 else 2.4, RED, 0.2)
		ashPuff(pos, if big then 24 else 12, if big then 3 else 1.8, if big then 20 else 12)
		slashLine(pos, if big then 14 else 8, Color3.fromRGB(255, 80, 80), 0.25, 0.22)
		if big then
			ring(pos, dir, 2, 18, RED, 0.3, 0.3)
		end
	elseif kind == "slam" then
		local g = Vector3.new(pos.X, groundY(pos), pos.Z)
		VFX.groundCrack(g, 7, "stone")
		flash(pos, 3, Color3.new(1, 1, 1), 0.15)
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
			Debris:AddItem(rock, 0.7)
		end)
	end
	ring(pos + Vector3.new(0, 0.2, 0), Vector3.new(0, 1, 0), 2, radius * 2.6, if style == "gold" then GOLD else Color3.fromRGB(220, 210, 200), 0.35, 0.2)
	dust(pos + Vector3.new(0, 1, 0), 14, 3)
	Sounds.play("ground_crack", { position = pos, random = 0.08 })
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
	local pos = d.pos :: Vector3
	local normal = (d.normal :: Vector3).Unit
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
	task.delay(dur, function()
		trail.Enabled = false
		Debris:AddItem(trail, 0.4)
		Debris:AddItem(a0, 0.4)
		Debris:AddItem(a1, 0.4)
	end)
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
	Debris:AddItem(gui, 0.85)
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
	Debris:AddItem(ghost, 0.55)
	ashPuff(pos, 16, math.max(1.5, size.Magnitude * 0.25), 6)
	Sounds.play("ren_ash_gain", { position = pos, random = 0.08 })
end

handlers.PropRestore = function(d)
	emit(d.pos :: Vector3, 6, { color = Color3.fromRGB(255, 240, 200), size = 0.5, speed = 4, life = 0.6 })
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
			Debris:AddItem(att, 0.8)
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
			Debris:AddItem(holder, 1.5)
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
