--!strict
-- 캐릭터 준비 / 장비
--  · 플레이어와 봇은 로블록스 아바타(R6)를 그대로 쓰고, 캐릭터별 무기·소품만 붙인다 (가강전 방식)
--      린 위안   : 등에 멘 목봉 + 삿갓, 기술을 쓸 때 손에 드는 목봉
--      칸자키 렌 : 손에 든 카타나, 왼쪽 허리 칼집(봉인선 10개), 칼집에 꽂힌 칼자루(최대 출력용)
--  · 훈련용 허수아비 / 아바타를 못 불러왔을 때는 파트로 조립한 R6 리그를 쓴다
--
-- 애니메이터는 관절의 C0 회전을 보정하므로, 로블록스 기본 R6 관절이든 직접 만든 관절이든 똑같이 움직인다.

local Locale = require(script.Parent.Locale)

local RigBuilder = {}

local rad = math.rad
local SMOOTH = Enum.SurfaceType.Smooth

local function basePart(name: string, size: Vector3, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = SMOOTH
	p.BottomSurface = SMOOTH
	p.Anchored = false
	return p
end

-- 장식 파트: 부모 파트 기준 상대 CFrame 으로 붙인다 (Weld).
local function deco(
	container: Instance,
	attachTo: BasePart,
	name: string,
	size: Vector3,
	rel: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
): Part
	local p = basePart(name, size, color, material)
	if shape then
		p.Shape = shape
	end
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = size.Magnitude > 0.9
	p.CFrame = attachTo.CFrame * rel
	local w = Instance.new("Weld")
	w.Name = "DecoWeld"
	w.Part0 = attachTo
	w.Part1 = p
	w.C0 = rel
	w.Parent = p
	p.Parent = container
	return p
end

-- 가로로 누운 원판(원기둥). axis 가 Z 방향이 되도록 회전한다.
local function discZ(container: Instance, attachTo: BasePart, name: string, diameter: number, thickness: number, rel: CFrame, color: Color3, material: Enum.Material?): Part
	return deco(container, attachTo, name, Vector3.new(thickness, diameter, diameter), rel * CFrame.Angles(0, rad(90), 0), color, material, Enum.PartType.Cylinder)
end

-- 세로 원기둥 (axis = Y)
local function cylY(container: Instance, attachTo: BasePart, name: string, length: number, diameter: number, rel: CFrame, color: Color3, material: Enum.Material?): Part
	return deco(container, attachTo, name, Vector3.new(length, diameter, diameter), rel * CFrame.Angles(0, 0, rad(90)), color, material, Enum.PartType.Cylinder)
end

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame, parent: Instance?): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = parent or part0
	return m
end

local function makeTrail(container: Instance, a0: Attachment, a1: Attachment, c0: Color3, c1: Color3, lifetime: number): Trail
	local t = Instance.new("Trail")
	t.Name = "WeaponTrail"
	t.Attachment0 = a0
	t.Attachment1 = a1
	t.Color = ColorSequence.new(c0, c1)
	t.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	t.Lifetime = lifetime
	t.LightEmission = 0.6
	t.FaceCamera = false
	t.MinLength = 0.05
	t.Enabled = false
	t.Parent = container
	return t
end

-- 기술을 쓸 때만 보이는 소품: 보일 때의 투명도를 기억해 두고 숨긴다
local function hideProp(m: Instance)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("ShowT", p.Transparency)
			p.Transparency = 1
		end
	end
end

----------------------------------------------------------------------
-- 준비: 래그돌 관절, 충돌, 이름표 (아바타/파트 리그 공통)
----------------------------------------------------------------------
type RagSpec = { motor: string, key: string, cone: number, twist: number }
local RAG_SPECS: { RagSpec } = {
	{ motor = "Neck", key = "Neck", cone = 30, twist = 40 },
	{ motor = "Right Shoulder", key = "RS", cone = 80, twist = 45 },
	{ motor = "Left Shoulder", key = "LS", cone = 80, twist = 45 },
	{ motor = "Right Hip", key = "RH", cone = 50, twist = 20 },
	{ motor = "Left Hip", key = "LH", cone = 50, twist = 20 },
}
local LIMBS = { "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

-- 래그돌용 볼소켓 (평소엔 꺼져 있음). 관절의 회전과 무관하게 "팔다리 방향(아래)"으로 원뿔을 잡는다.
local function ragdollSocket(key: string, m: Motor6D, spec: RagSpec)
	local part0 = m.Part0
	local part1 = m.Part1
	if not part0 or not part1 then
		return
	end
	local down = CFrame.Angles(0, 0, rad(-90))
	local a0 = Instance.new("Attachment")
	a0.Name = "RagA_" .. key
	a0.CFrame = CFrame.new(m.C0.Position) * down
	a0.Parent = part0
	local a1 = Instance.new("Attachment")
	a1.Name = "RagB_" .. key
	a1.CFrame = CFrame.new(m.C1.Position) * down
	a1.Parent = part1
	local s = Instance.new("BallSocketConstraint")
	s.Name = "RagSocket_" .. key
	s.Attachment0 = a0
	s.Attachment1 = a1
	s.LimitsEnabled = true
	s.UpperAngle = spec.cone
	s.TwistLimitsEnabled = true
	s.TwistLowerAngle = -spec.twist
	s.TwistUpperAngle = spec.twist
	s.Enabled = false
	s.Parent = part1
end

local function collider(limb: BasePart)
	local c = Instance.new("Part")
	c.Name = "RagCollider"
	c.Size = limb.Size * Vector3.new(0.8, 0.9, 0.8)
	c.Transparency = 1
	c.CanCollide = false
	c.CanQuery = false
	c.CanTouch = false
	c.Massless = true
	c.CFrame = limb.CFrame
	local w = Instance.new("Weld")
	w.Part0 = limb
	w.Part1 = c
	w.Parent = c
	c.Parent = limb
end

-- 이름표 글자: 두 언어 버전이면 속성으로 둘 다 저장해 두고, 클라이언트가 자기 언어로 골라 보여 준다
local function setPlateText(label: TextLabel, text: Locale.Text)
	if typeof(text) == "table" then
		label:SetAttribute("TextKo", text.ko)
		label:SetAttribute("TextEn", text.en)
	else
		label:SetAttribute("TextKo", nil)
		label:SetAttribute("TextEn", nil)
	end
	label.Text = Locale.pick(text)
end

local function nameplate(head: BasePart, displayName: Locale.Text, color: Color3)
	local old = head:FindFirstChild("Nameplate")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(170, 38)
	gui.StudsOffset = Vector3.new(0, 2.3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	gui.AutoLocalize = false
	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	setPlateText(label, displayName)
	label.Parent = gui
	local barBack = Instance.new("Frame")
	barBack.Name = "Bar"
	barBack.AnchorPoint = Vector2.new(0.5, 0)
	barBack.Position = UDim2.new(0.5, 0, 0, 23)
	barBack.Size = UDim2.new(0.8, 0, 0, 6)
	barBack.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	barBack.BorderSizePixel = 0
	barBack.Parent = gui
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = barBack
	gui.Parent = head
end

export type PrepareOptions = {
	displayName: Locale.Text?,
	plateColor: Color3?,
	collisionGroup: string?, -- 서버에서만 지정 ("Characters")
}

function RigBuilder.prepare(model: Model, opts: PrepareOptions?)
	local o: PrepareOptions = opts or {}
	-- 기본 애니메이션/체력 스크립트와 Animator 제거 (관절은 우리 애니메이터가 직접 움직인다)
	for _, d in model:GetDescendants() do
		if (d:IsA("LocalScript") or d:IsA("Script")) and (d.Name == "Animate" or d.Name == "Health") then
			d:Destroy()
		elseif d:IsA("Animator") then
			d:Destroy()
		end
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.RigType = Enum.HumanoidRigType.R6
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false -- 래그돌 때 목 관절을 끄므로
		hum.UseJumpPower = true
		hum.JumpPower = 50
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end

	-- 액세서리는 판정/충돌에 끼지 않게 (날개·망토 때문에 피격 범위가 커지지 않도록)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:FindFirstAncestorOfClass("Accessory") then
			d.CanQuery = false
			d.CanTouch = false
			d.CanCollide = false
			d.Massless = true
		end
	end

	local torso = model:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		for _, spec in RAG_SPECS do
			local m = torso:FindFirstChild(spec.motor)
			if m and m:IsA("Motor6D") and not model:FindFirstChild("RagSocket_" .. spec.key, true) then
				ragdollSocket(spec.key, m, spec)
			end
		end
	end
	for _, name in LIMBS do
		local limb = model:FindFirstChild(name)
		if limb and limb:IsA("BasePart") and not limb:FindFirstChild("RagCollider") then
			collider(limb)
		end
	end

	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		nameplate(head, o.displayName or model.Name, o.plateColor or Color3.fromRGB(120, 200, 120))
	end

	local group = o.collisionGroup
	if group then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CollisionGroup = group
			end
		end
	end

	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		model.PrimaryPart = root
	end
end

function RigBuilder.setNameplate(model: Model, text: Locale.Text, color: Color3?)
	local head = model:FindFirstChild("Head")
	local plate = head and head:FindFirstChild("Nameplate")
	if not plate then
		return
	end
	local label = plate:FindFirstChild("NameLabel")
	if label and label:IsA("TextLabel") then
		setPlateText(label, text)
	end
	local bar = plate:FindFirstChild("Bar")
	local fill = bar and bar:FindFirstChild("Fill")
	if color and fill and fill:IsA("Frame") then
		fill.BackgroundColor3 = color
	end
end

----------------------------------------------------------------------
-- 장비
----------------------------------------------------------------------
-- 무기 관절: 오른손 끝에서 무기의 +Y 축이 "앞"을 향하도록.
local function weaponMotor(gear: Instance, rightArm: BasePart, handleName: string): Part
	local handle = basePart(handleName, Vector3.new(0.3, 0.3, 0.3), Color3.new(0, 0, 0))
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	local c0 = CFrame.new(0, -0.95, 0) * CFrame.Angles(rad(-90), 0, 0)
	handle.CFrame = rightArm.CFrame * c0
	handle.Parent = gear
	motor("Weapon", rightArm, handle, c0, CFrame.new(), gear)
	return handle
end

local function linGear(gear: Folder, torso: BasePart, rightArm: BasePart)
	local wood = Color3.fromRGB(126, 84, 48)
	local grip = Color3.fromRGB(60, 36, 20)

	-- 등에 멘 목봉
	local staffBack = Instance.new("Model")
	staffBack.Name = "StaffBack"
	staffBack.Parent = gear
	local backRel = CFrame.new(0, 0, 0.72) * CFrame.Angles(0, 0, rad(58))
	deco(staffBack, torso, "Staff", Vector3.new(5.6, 0.26, 0.26), backRel, wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	deco(staffBack, torso, "Grip1", Vector3.new(0.4, 0.3, 0.3), backRel * CFrame.new(1.0, 0, 0), grip, Enum.Material.Fabric, Enum.PartType.Cylinder)
	deco(staffBack, torso, "Grip2", Vector3.new(0.4, 0.3, 0.3), backRel * CFrame.new(-1.0, 0, 0), grip, Enum.Material.Fabric, Enum.PartType.Cylinder)

	-- 등 뒤의 삿갓
	local hat = Instance.new("Model")
	hat.Name = "Hat"
	hat.Parent = gear
	local hatRel = CFrame.new(0, 0.3, 0.86) * CFrame.Angles(rad(-12), 0, rad(8))
	discZ(hat, torso, "HatBrim", 2.5, 0.1, hatRel, Color3.fromRGB(196, 160, 96), Enum.Material.Wood)
	discZ(hat, torso, "HatMid", 1.7, 0.14, hatRel * CFrame.new(0, 0, 0.12), Color3.fromRGB(186, 150, 88), Enum.Material.Wood)
	discZ(hat, torso, "HatTop", 0.85, 0.16, hatRel * CFrame.new(0, 0, 0.26), Color3.fromRGB(170, 134, 76), Enum.Material.Wood)

	-- 손에 쥐는 목봉 (기술 사용 시에만 보임)
	local handle = weaponMotor(gear, rightArm, "StaffHandle")
	local staffHand = Instance.new("Model")
	staffHand.Name = "StaffHand"
	staffHand.Parent = gear
	local hand = cylY(staffHand, handle, "Staff", 5.6, 0.26, CFrame.new(0, 0.4, 0), wood, Enum.Material.Wood)
	cylY(staffHand, handle, "Grip1", 0.4, 0.3, CFrame.new(0, 1.4, 0), grip, Enum.Material.Fabric)
	cylY(staffHand, handle, "Grip2", 0.4, 0.3, CFrame.new(0, -0.6, 0), grip, Enum.Material.Fabric)
	hideProp(staffHand)
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA"
	a0.Position = Vector3.new(2.7, 0, 0)
	a0.Parent = hand
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailB"
	a1.Position = Vector3.new(-2.7, 0, 0)
	a1.Parent = hand
	makeTrail(hand, a0, a1, Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 160, 40), 0.2)
end

local function renGear(gear: Folder, torso: BasePart, rightArm: BasePart)
	local red = Color3.fromRGB(150, 28, 32)
	local steel = Color3.fromRGB(200, 204, 212)

	-- 왼쪽 허리: 무광 검은 칼집 + 봉인선 10개 (칼자루 쪽이 앞·위, 끝이 뒤·아래)
	local scabbard = Instance.new("Model")
	scabbard.Name = "Scabbard"
	scabbard.Parent = gear
	local scabRel = CFrame.new(-1.18, -0.8, 0.2) * CFrame.Angles(rad(24), rad(-8), 0)
	local sheath = deco(scabbard, torso, "Sheath", Vector3.new(0.24, 0.3, 3.3), scabRel, Color3.fromRGB(14, 14, 16), Enum.Material.SmoothPlastic)
	deco(scabbard, torso, "Koiguchi", Vector3.new(0.28, 0.34, 0.14), scabRel * CFrame.new(0, 0, -1.62), Color3.fromRGB(60, 60, 66), Enum.Material.Metal)
	for i = 1, 10 do
		local seal = deco(scabbard, torso, "Seal" .. i, Vector3.new(0.27, 0.33, 0.06), scabRel * CFrame.new(0, 0, -1.35 + (i - 1) * 0.28), Color3.fromRGB(255, 40, 50), Enum.Material.Neon)
		seal.Transparency = 0.85
		seal.CastShadow = false
	end
	local ashVent = Instance.new("Attachment")
	ashVent.Name = "AshVent"
	ashVent.Position = Vector3.new(0, 0, -1.7)
	ashVent.Parent = sheath

	-- 칼집에 꽂힌 칼자루 (최대 출력 충전 중에만 보임)
	local sheathed = Instance.new("Model")
	sheathed.Name = "KatanaSheathed"
	sheathed.Parent = gear
	deco(sheathed, torso, "Tsuba", Vector3.new(0.5, 0.5, 0.06), scabRel * CFrame.new(0, 0, -1.72), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	deco(sheathed, torso, "Hilt", Vector3.new(0.2, 0.22, 0.95), scabRel * CFrame.new(0, 0, -2.22), Color3.fromRGB(18, 18, 20), Enum.Material.Fabric)
	deco(sheathed, torso, "HiltWrap", Vector3.new(0.22, 0.24, 0.7), scabRel * CFrame.new(0, 0, -2.22), red, Enum.Material.Fabric).Transparency = 0.4
	hideProp(sheathed)

	-- 손에 쥔 JN-47 영력전도 도검
	local handle = weaponMotor(gear, rightArm, "KatanaHandle")
	local katana = Instance.new("Model")
	katana.Name = "KatanaHand"
	katana.Parent = gear
	deco(katana, handle, "Hilt", Vector3.new(0.2, 0.95, 0.22), CFrame.new(0, 0.05, 0), Color3.fromRGB(18, 18, 20), Enum.Material.Fabric)
	deco(katana, handle, "HiltWrap", Vector3.new(0.22, 0.7, 0.24), CFrame.new(0, 0.05, 0), red, Enum.Material.Fabric).Transparency = 0.4
	deco(katana, handle, "Tsuba", Vector3.new(0.5, 0.06, 0.5), CFrame.new(0, 0.56, 0), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	local blade = deco(katana, handle, "Blade", Vector3.new(0.07, 2.55, 0.24), CFrame.new(0, 1.86, 0.02), steel, Enum.Material.Metal)
	blade.Reflectance = 0.25
	local edge = deco(katana, handle, "Edge", Vector3.new(0.075, 2.5, 0.04), CFrame.new(0, 1.84, -0.1), Color3.fromRGB(235, 238, 245), Enum.Material.Neon)
	edge.Transparency = 0.35
	edge.CastShadow = false
	deco(katana, handle, "Tip", Vector3.new(0.07, 0.25, 0.18), CFrame.new(0, 3.2, 0) * CFrame.Angles(rad(35), 0, 0), steel, Enum.Material.Metal)
	local ta = Instance.new("Attachment")
	ta.Name = "TrailA"
	ta.Position = Vector3.new(0, -1.1, 0)
	ta.Parent = blade
	local tb = Instance.new("Attachment")
	tb.Name = "TrailB"
	tb.Position = Vector3.new(0, 1.3, 0)
	tb.Parent = blade
	makeTrail(blade, ta, tb, Color3.fromRGB(255, 70, 70), Color3.fromRGB(20, 16, 18), 0.16)
end

function RigBuilder.unequip(model: Model)
	local g = model:FindFirstChild("Gear")
	if g then
		g:Destroy()
	end
end

-- 캐릭터(무브셋)에 맞는 무기·소품을 붙이고 CharId 를 기록한다
function RigBuilder.equip(model: Model, charId: string)
	RigBuilder.unequip(model)
	local torso = model:FindFirstChild("Torso")
	local rightArm = model:FindFirstChild("Right Arm")
	if torso and torso:IsA("BasePart") and rightArm and rightArm:IsA("BasePart") then
		local gear = Instance.new("Folder")
		gear.Name = "Gear"
		gear.Parent = model
		if charId == "LinYuan" then
			linGear(gear, torso, rightArm)
		elseif charId == "KanzakiRen" then
			renGear(gear, torso, rightArm)
		end
	end
	model:SetAttribute("CharId", charId)
	local v = model:GetAttribute("GearVersion")
	model:SetAttribute("GearVersion", (if typeof(v) == "number" then v else 0) + 1)
end

----------------------------------------------------------------------
-- 파트로 조립한 R6 리그 (허수아비 / 아바타를 못 불러왔을 때)
----------------------------------------------------------------------
export type Palette = { head: Color3, torso: Color3, arms: Color3, legs: Color3 }

local function buildBase(name: string, pal: Palette): Model
	local model = Instance.new("Model")
	model.Name = name

	local root = basePart("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = CFrame.new(0, 3, 0)
	root.Parent = model

	local torso = basePart("Torso", Vector3.new(2, 2, 1), pal.torso)
	torso.CFrame = CFrame.new(0, 3, 0)
	torso.Parent = model

	local head = basePart("Head", Vector3.new(2, 1, 1), pal.head)
	head.CFrame = CFrame.new(0, 4.5, 0)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1.25, 1.25, 1.25)
	headMesh.Parent = head
	head.Parent = model

	type LimbSpec = { name: string, pos: Vector3, color: Color3 }
	local limbSpecs: { LimbSpec } = {
		{ name = "Right Arm", pos = Vector3.new(1.5, 3, 0), color = pal.arms },
		{ name = "Left Arm", pos = Vector3.new(-1.5, 3, 0), color = pal.arms },
		{ name = "Right Leg", pos = Vector3.new(0.5, 1, 0), color = pal.legs },
		{ name = "Left Leg", pos = Vector3.new(-0.5, 1, 0), color = pal.legs },
	}
	local limbs: { [string]: Part } = {}
	for _, spec in limbSpecs do
		local p = basePart(spec.name, Vector3.new(1, 2, 1), spec.color)
		p.CFrame = CFrame.new(spec.pos)
		p.CanCollide = false
		p.Parent = model
		limbs[spec.name] = p
	end

	motor("RootJoint", root, torso, CFrame.new(), CFrame.new())
	motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.5, 0))
	motor("Right Shoulder", torso, limbs["Right Arm"], CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0))
	motor("Left Shoulder", torso, limbs["Left Arm"], CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0))
	motor("Right Hip", torso, limbs["Right Leg"], CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0))
	motor("Left Hip", torso, limbs["Left Leg"], CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0))

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.Parent = model
	model.PrimaryPart = root
	return model
end

-- 아바타 대신 쓸 기본 모양 (로블록스 기본 얼굴)
function RigBuilder.buildFallback(pal: Palette): Model
	local model = buildBase("Fighter", pal)
	local head = model:FindFirstChild("Head") :: BasePart
	local face = Instance.new("Decal")
	face.Name = "face"
	face.Texture = "rbxasset://textures/face.png"
	face.Face = Enum.NormalId.Front
	face.Parent = head
	return model
end

-- 훈련용 허수아비
function RigBuilder.buildDummy(): Model
	local burlap = Color3.fromRGB(184, 156, 108)
	local model = buildBase("훈련용 허수아비", { head = burlap, torso = burlap, arms = burlap, legs = Color3.fromRGB(150, 120, 80) })
	local look = Instance.new("Folder")
	look.Name = "Look"
	look.Parent = model
	local head = model:FindFirstChild("Head") :: BasePart
	local torso = model:FindFirstChild("Torso") :: BasePart
	local dark = Color3.fromRGB(40, 30, 20)
	for _, side in { -1, 1 } do
		deco(look, head, "XEye", Vector3.new(0.3, 0.06, 0.05), CFrame.new(side * 0.22, 0.05, -0.61) * CFrame.Angles(0, 0, rad(45)), dark)
		deco(look, head, "XEye", Vector3.new(0.3, 0.06, 0.05), CFrame.new(side * 0.22, 0.05, -0.61) * CFrame.Angles(0, 0, rad(-45)), dark)
	end
	discZ(look, torso, "Target", 1.4, 0.06, CFrame.new(0, 0.1, -0.52), Color3.fromRGB(200, 40, 40))
	discZ(look, torso, "TargetIn", 0.9, 0.07, CFrame.new(0, 0.1, -0.53), Color3.fromRGB(240, 235, 225))
	discZ(look, torso, "TargetDot", 0.4, 0.08, CFrame.new(0, 0.1, -0.54), Color3.fromRGB(200, 40, 40))
	deco(look, torso, "Vest", Vector3.new(2.1, 0.5, 1.1), CFrame.new(0, 0.75, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Fabric)
	model:SetAttribute("CharId", "Dummy")
	return model
end

-- 발끝이 cf 위치의 지면에 닿도록 배치 (HRP 는 지면 + 3)
function RigBuilder.place(model: Model, cf: CFrame)
	model:PivotTo(cf * CFrame.new(0, 3, 0))
end

return RigBuilder
