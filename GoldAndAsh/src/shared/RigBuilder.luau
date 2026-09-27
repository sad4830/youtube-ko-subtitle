--!strict
-- 캐릭터 모델을 에셋 업로드 없이 파트만으로 조립한다 (R6 규격 리그).
-- 관절 C0/C1 을 "회전 없는" 형태로 잡아 두어서, 애니메이션 쪽에서
-- Motor6D.Transform 을 x=앞뒤, y=좌우 회전, z=옆 기울기 로 직관적으로 쓸 수 있다.

local RigBuilder = {}

local rad = math.rad

export type Joints = {
	Root: Motor6D,
	Neck: Motor6D,
	RS: Motor6D,
	LS: Motor6D,
	RH: Motor6D,
	LH: Motor6D,
}

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

local function ellipsoid(
	container: Instance,
	attachTo: BasePart,
	name: string,
	size: Vector3,
	rel: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = deco(container, attachTo, name, size, rel, color, material)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
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

local function motor(name: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = part0
	m.Part1 = part1
	m.C0 = c0
	m.C1 = c1
	m.Parent = part0
	return m
end

-- 래그돌용 볼소켓 (평소엔 꺼져 있음)
local function ragdollSocket(jointName: string, part0: BasePart, part1: BasePart, c0: CFrame, c1: CFrame, cone: number, twist: number)
	local down = CFrame.Angles(0, 0, rad(-90)) -- 부착점의 X축이 아래(팔다리 방향)를 향하게
	local a0 = Instance.new("Attachment")
	a0.Name = "RagA_" .. jointName
	a0.CFrame = c0 * down
	a0.Parent = part0
	local a1 = Instance.new("Attachment")
	a1.Name = "RagB_" .. jointName
	a1.CFrame = c1 * down
	a1.Parent = part1
	local s = Instance.new("BallSocketConstraint")
	s.Name = "RagSocket_" .. jointName
	s.Attachment0 = a0
	s.Attachment1 = a1
	s.LimitsEnabled = true
	s.UpperAngle = cone
	s.TwistLimitsEnabled = true
	s.TwistLowerAngle = -twist
	s.TwistUpperAngle = twist
	s.Enabled = false
	s.Parent = part1
end

local function collider(limb: BasePart, torso: BasePart)
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
	local nc = Instance.new("NoCollisionConstraint")
	nc.Part0 = c
	nc.Part1 = torso
	nc.Parent = c
	c.Parent = limb
end

type Palette = {
	skin: Color3,
	torso: Color3,
	arms: Color3,
	legs: Color3,
}

type Rig = {
	model: Model,
	root: Part,
	torso: Part,
	head: Part,
	rightArm: Part,
	leftArm: Part,
	rightLeg: Part,
	leftLeg: Part,
	humanoid: Humanoid,
	joints: Joints,
}

local function buildBase(name: string, pal: Palette, maxHealth: number, walkSpeed: number): Rig
	local model = Instance.new("Model")
	model.Name = name

	local root = basePart("HumanoidRootPart", Vector3.new(2, 2, 1), Color3.new(1, 1, 1))
	root.Transparency = 1
	root.CanCollide = false
	root.CFrame = CFrame.new(0, 3, 0)
	root.Parent = model

	local torso = basePart("Torso", Vector3.new(2, 2, 1), pal.torso, Enum.Material.Fabric)
	torso.CFrame = CFrame.new(0, 3, 0)
	torso.Parent = model

	local head = basePart("Head", Vector3.new(1.2, 1.2, 1.2), pal.skin)
	head.CFrame = CFrame.new(0, 4.6, 0)
	local headMesh = Instance.new("SpecialMesh")
	headMesh.MeshType = Enum.MeshType.Head
	headMesh.Scale = Vector3.new(1, 1, 1)
	headMesh.Parent = head
	head.Parent = model

	local rightArm = basePart("Right Arm", Vector3.new(1, 2, 1), pal.arms, Enum.Material.Fabric)
	rightArm.CFrame = CFrame.new(1.5, 3, 0)
	rightArm.CanCollide = false
	rightArm.Parent = model
	local leftArm = basePart("Left Arm", Vector3.new(1, 2, 1), pal.arms, Enum.Material.Fabric)
	leftArm.CFrame = CFrame.new(-1.5, 3, 0)
	leftArm.CanCollide = false
	leftArm.Parent = model
	local rightLeg = basePart("Right Leg", Vector3.new(1, 2, 1), pal.legs, Enum.Material.Fabric)
	rightLeg.CFrame = CFrame.new(0.5, 1, 0)
	rightLeg.CanCollide = false
	rightLeg.Parent = model
	local leftLeg = basePart("Left Leg", Vector3.new(1, 2, 1), pal.legs, Enum.Material.Fabric)
	leftLeg.CFrame = CFrame.new(-0.5, 1, 0)
	leftLeg.CanCollide = false
	leftLeg.Parent = model

	local joints: Joints = {
		Root = motor("RootJoint", root, torso, CFrame.new(), CFrame.new()),
		Neck = motor("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.6, 0)),
		RS = motor("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0)),
		LS = motor("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0)),
		RH = motor("Right Hip", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0)),
		LH = motor("Left Hip", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0)),
	}

	ragdollSocket("Neck", torso, head, CFrame.new(0, 1, 0), CFrame.new(0, -0.6, 0), 30, 40)
	ragdollSocket("RS", torso, rightArm, CFrame.new(1, 0.5, 0), CFrame.new(-0.5, 0.5, 0), 80, 45)
	ragdollSocket("LS", torso, leftArm, CFrame.new(-1, 0.5, 0), CFrame.new(0.5, 0.5, 0), 80, 45)
	ragdollSocket("RH", torso, rightLeg, CFrame.new(0.5, -1, 0), CFrame.new(0, 1, 0), 50, 20)
	ragdollSocket("LH", torso, leftLeg, CFrame.new(-0.5, -1, 0), CFrame.new(0, 1, 0), 50, 20)
	for _, limb in { rightArm, leftArm, rightLeg, leftLeg } do
		collider(limb, torso)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth = maxHealth
	humanoid.Health = maxHealth
	humanoid.WalkSpeed = walkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 50
	humanoid.BreakJointsOnDeath = false
	-- 래그돌 때 목 관절을 끄므로, 목이 끊겼다고 즉사하지 않게 한다
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	model.PrimaryPart = root

	return {
		model = model,
		root = root,
		torso = torso,
		head = head,
		rightArm = rightArm,
		leftArm = leftArm,
		rightLeg = rightLeg,
		leftLeg = leftLeg,
		humanoid = humanoid,
		joints = joints,
	}
end

-- 무기 관절: 오른손 끝에서 무기의 +Y 축이 "앞"을 향하도록.
local function weaponMotor(rig: Rig, handleName: string): Part
	local handle = basePart(handleName, Vector3.new(0.3, 0.3, 0.3), Color3.new(0, 0, 0))
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	local c0 = CFrame.new(0, -0.95, 0) * CFrame.Angles(rad(-90), 0, 0)
	handle.CFrame = rig.rightArm.CFrame * c0
	handle.Parent = rig.model
	motor("Weapon", rig.rightArm, handle, c0, CFrame.new())
	return handle
end

local function face(rig: Rig, folder: Instance, eyeColor: Color3, browColor: Color3, style: string)
	local head = rig.head
	local eyeGlow = style == "sharp"
	for _, side in { -1, 1 } do
		local eye = deco(
			folder,
			head,
			"Eye",
			Vector3.new(0.15, if eyeGlow then 0.12 else 0.2, 0.05),
			CFrame.new(side * 0.21, 0.04, -0.585),
			eyeColor,
			if eyeGlow then Enum.Material.Neon else Enum.Material.SmoothPlastic
		)
		eye.CastShadow = false
		local browRot = if style == "sharp" then CFrame.Angles(0, 0, rad(side * 16)) else CFrame.Angles(0, 0, rad(side * -6))
		local brow = deco(folder, head, "Brow", Vector3.new(0.3, 0.05, 0.05), CFrame.new(side * 0.22, 0.22, -0.585) * browRot, browColor)
		brow.CastShadow = false
		if style == "sharp" then
			-- 위로 길게 뻗은 눈꼬리
			local lash = deco(folder, head, "Lash", Vector3.new(0.16, 0.035, 0.05), CFrame.new(side * 0.3, 0.1, -0.58) * CFrame.Angles(0, 0, rad(side * 25)), browColor)
			lash.CastShadow = false
		end
	end
	if style == "sharp" then
		local mouth = deco(folder, head, "Mouth", Vector3.new(0.2, 0.035, 0.05), CFrame.new(0.03, -0.27, -0.58) * CFrame.Angles(0, 0, rad(-6)), Color3.fromRGB(120, 60, 60))
		mouth.CastShadow = false
	else
		-- 잘 웃는 둥근 얼굴
		local mouthColor = Color3.fromRGB(110, 50, 40)
		local m1 = deco(folder, head, "Mouth", Vector3.new(0.22, 0.045, 0.05), CFrame.new(0, -0.26, -0.585), mouthColor)
		m1.CastShadow = false
		for _, side in { -1, 1 } do
			local m2 = deco(folder, head, "MouthCorner", Vector3.new(0.09, 0.045, 0.05), CFrame.new(side * 0.14, -0.23, -0.58) * CFrame.Angles(0, 0, rad(side * 35)), mouthColor)
			m2.CastShadow = false
		end
		for _, side in { -1, 1 } do
			local blush = deco(folder, head, "Blush", Vector3.new(0.16, 0.08, 0.04), CFrame.new(side * 0.33, -0.12, -0.55), Color3.fromRGB(226, 140, 120))
			blush.Transparency = 0.45
			blush.CastShadow = false
		end
	end
end

local function nameplate(rig: Rig, displayName: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Size = UDim2.fromOffset(160, 38)
	gui.StudsOffset = Vector3.new(0, 2.3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 20)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Text = displayName
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
	gui.Parent = rig.head
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

----------------------------------------------------------------------
-- 린 위안
----------------------------------------------------------------------
local function buildLinYuan(): Model
	local skin = Color3.fromRGB(226, 178, 132)
	local white = Color3.fromRGB(238, 234, 224)
	local vest = Color3.fromRGB(30, 27, 26)
	local pants = Color3.fromRGB(112, 78, 46)
	local hair = Color3.fromRGB(22, 18, 17)
	local gold = Color3.fromRGB(232, 182, 74)
	local wood = Color3.fromRGB(126, 84, 48)

	local rig = buildBase("린 위안", { skin = skin, torso = white, arms = skin, legs = pants }, 115, 17)
	local model = rig.model
	local deco_ = Instance.new("Folder")
	deco_.Name = "Look"
	deco_.Parent = model

	-- 얼굴 & 머리
	face(rig, deco_, Color3.fromRGB(58, 34, 20), hair, "soft")
	local head = rig.head
	deco(deco_, head, "HairCap", Vector3.new(1.3, 0.34, 1.3), CFrame.new(0, 0.55, 0.02), hair, Enum.Material.SmoothPlastic)
	deco(deco_, head, "HairBack", Vector3.new(1.3, 0.75, 0.3), CFrame.new(0, 0.2, 0.52), hair)
	for _, side in { -1, 1 } do
		deco(deco_, head, "HairSide", Vector3.new(0.18, 0.55, 0.9), CFrame.new(side * 0.62, 0.28, 0.12), hair)
	end
	-- 헝클어진 머리 삐침
	local tufts = {
		{ 0.25, 0.78, -0.25, 25, 0, -20 },
		{ -0.3, 0.8, -0.1, -15, 0, 25 },
		{ 0.05, 0.84, 0.25, 10, 30, 10 },
		{ -0.15, 0.62, -0.58, -40, 0, 15 },
		{ 0.2, 0.6, -0.6, -35, 0, -20 },
		{ 0.45, 0.68, 0.2, 0, 0, -45 },
		{ -0.48, 0.66, 0.25, 0, 0, 45 },
	}
	for i, t in tufts do
		deco(deco_, head, "Tuft" .. i, Vector3.new(0.34, 0.26, 0.34), CFrame.new(t[1], t[2], t[3]) * CFrame.Angles(rad(t[4]), rad(t[5]), rad(t[6])), hair)
	end

	-- 몸통: 흰 상의 + 검은 소매 없는 겉옷 + 넉넉한 체형
	local torso = rig.torso
	ellipsoid(deco_, torso, "Belly", Vector3.new(2.05, 1.5, 1.35), CFrame.new(0, -0.35, -0.08), white, Enum.Material.Fabric)
	ellipsoid(deco_, torso, "Chest", Vector3.new(2.15, 1.3, 1.2), CFrame.new(0, 0.45, 0), white, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		deco(deco_, torso, "VestFront", Vector3.new(0.72, 2.05, 0.14), CFrame.new(side * 0.68, 0.02, -0.62) * CFrame.Angles(0, rad(side * -8), 0), vest, Enum.Material.Fabric)
		deco(deco_, torso, "VestTrim", Vector3.new(0.08, 2.05, 0.16), CFrame.new(side * 0.33, 0.02, -0.66), gold, Enum.Material.Fabric)
		deco(deco_, torso, "VestSide", Vector3.new(0.16, 2.05, 1.25), CFrame.new(side * 1.04, 0.02, 0), vest, Enum.Material.Fabric)
		ellipsoid(deco_, torso, "Shoulder", Vector3.new(1.0, 0.7, 1.2), CFrame.new(side * 0.95, 0.85, 0), vest, Enum.Material.Fabric)
	end
	deco(deco_, torso, "VestBack", Vector3.new(2.2, 2.05, 0.14), CFrame.new(0, 0.02, 0.64), vest, Enum.Material.Fabric)
	deco(deco_, torso, "Sash", Vector3.new(2.25, 0.34, 1.42), CFrame.new(0, -0.82, -0.02), Color3.fromRGB(128, 52, 30), Enum.Material.Fabric)
	deco(deco_, torso, "SashKnot", Vector3.new(0.34, 0.5, 0.2), CFrame.new(0.55, -0.98, -0.72) * CFrame.Angles(0, 0, rad(15)), Color3.fromRGB(128, 52, 30), Enum.Material.Fabric)

	-- 삿갓 (등 뒤)
	local hatRel = CFrame.new(0, 0.35, 0.95) * CFrame.Angles(rad(-12), 0, rad(8))
	discZ(deco_, torso, "HatBrim", 2.7, 0.1, hatRel, Color3.fromRGB(196, 160, 96), Enum.Material.Wood)
	discZ(deco_, torso, "HatMid", 1.8, 0.14, hatRel * CFrame.new(0, 0, 0.12), Color3.fromRGB(186, 150, 88), Enum.Material.Wood)
	discZ(deco_, torso, "HatTop", 0.9, 0.16, hatRel * CFrame.new(0, 0, 0.26), Color3.fromRGB(170, 134, 76), Enum.Material.Wood)
	deco(deco_, torso, "HatCord", Vector3.new(0.06, 2.3, 0.06), CFrame.new(0.3, 0.3, -0.66) * CFrame.Angles(0, 0, rad(38)), Color3.fromRGB(90, 60, 30))

	-- 등에 멘 목봉
	local staffBack = Instance.new("Model")
	staffBack.Name = "StaffBack"
	staffBack.Parent = deco_
	local backRel = CFrame.new(0, 0, 0.78) * CFrame.Angles(0, 0, rad(58))
	deco(staffBack, torso, "Staff", Vector3.new(5.6, 0.26, 0.26), backRel, wood, Enum.Material.Wood, Enum.PartType.Cylinder)
	deco(staffBack, torso, "Grip1", Vector3.new(0.4, 0.3, 0.3), backRel * CFrame.new(1.0, 0, 0), Color3.fromRGB(60, 36, 20), Enum.Material.Fabric, Enum.PartType.Cylinder)
	deco(staffBack, torso, "Grip2", Vector3.new(0.4, 0.3, 0.3), backRel * CFrame.new(-1.0, 0, 0), Color3.fromRGB(60, 36, 20), Enum.Material.Fabric, Enum.PartType.Cylinder)

	-- 팔: 흰 소매(걷어 올림) + 굳은살 손
	for _, arm in { rig.rightArm, rig.leftArm } do
		deco(deco_, arm, "Sleeve", Vector3.new(1.12, 1.05, 1.12), CFrame.new(0, 0.5, 0), white, Enum.Material.Fabric)
		deco(deco_, arm, "Cuff", Vector3.new(1.16, 0.18, 1.16), CFrame.new(0, -0.05, 0), Color3.fromRGB(214, 208, 196), Enum.Material.Fabric)
		deco(deco_, arm, "Wrap", Vector3.new(1.06, 0.28, 1.06), CFrame.new(0, -0.62, 0), Color3.fromRGB(200, 186, 160), Enum.Material.Fabric)
		-- 각성 시 드러나는 금빛 영력의 결
		local line = deco(deco_, arm, "ChiLine", Vector3.new(0.08, 1.9, 1.08), CFrame.new(0, 0, 0), gold, Enum.Material.Neon)
		line.Transparency = 1
		local line2 = deco(deco_, arm, "ChiLine", Vector3.new(1.08, 1.9, 0.08), CFrame.new(0, 0, 0), gold, Enum.Material.Neon)
		line2.Transparency = 1
	end

	-- 다리: 넉넉한 바지 + 낡은 천 신발
	for _, leg in { rig.rightLeg, rig.leftLeg } do
		ellipsoid(deco_, leg, "Baggy", Vector3.new(1.25, 1.7, 1.3), CFrame.new(0, 0.25, 0), pants, Enum.Material.Fabric)
		deco(deco_, leg, "Ankle", Vector3.new(1.08, 0.3, 1.08), CFrame.new(0, -0.65, 0), Color3.fromRGB(214, 206, 188), Enum.Material.Fabric)
		deco(deco_, leg, "Shoe", Vector3.new(1.06, 0.34, 1.28), CFrame.new(0, -0.84, -0.1), Color3.fromRGB(44, 38, 34), Enum.Material.Fabric)
	end

	-- 손에 쥐는 목봉 (기술 사용 시에만 보임)
	local handle = weaponMotor(rig, "StaffHandle")
	local staffHand = Instance.new("Model")
	staffHand.Name = "StaffHand"
	staffHand.Parent = model
	local hand = cylY(staffHand, handle, "Staff", 5.6, 0.26, CFrame.new(0, 0.4, 0), wood, Enum.Material.Wood)
	cylY(staffHand, handle, "Grip1", 0.4, 0.3, CFrame.new(0, 1.4, 0), Color3.fromRGB(60, 36, 20), Enum.Material.Fabric)
	cylY(staffHand, handle, "Grip2", 0.4, 0.3, CFrame.new(0, -0.6, 0), Color3.fromRGB(60, 36, 20), Enum.Material.Fabric)
	for _, p in staffHand:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("ShowT", p.Transparency)
			p.Transparency = 1
		end
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "TrailA"
	a0.Position = Vector3.new(2.7, 0, 0)
	a0.Parent = hand
	local a1 = Instance.new("Attachment")
	a1.Name = "TrailB"
	a1.Position = Vector3.new(-2.7, 0, 0)
	a1.Parent = hand
	makeTrail(hand, a0, a1, Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 160, 40), 0.2)

	model:SetAttribute("CharId", "LinYuan")
	nameplate(rig, "린 위안", Color3.fromRGB(255, 196, 74))
	return model
end

----------------------------------------------------------------------
-- 칸자키 렌
----------------------------------------------------------------------
local function buildKanzakiRen(): Model
	local skin = Color3.fromRGB(242, 214, 196)
	local shirt = Color3.fromRGB(80, 80, 90)
	local jacket = Color3.fromRGB(36, 36, 44)
	local red = Color3.fromRGB(150, 28, 32)
	local pants = Color3.fromRGB(44, 44, 52)
	local hair = Color3.fromRGB(20, 18, 24)
	local steel = Color3.fromRGB(200, 204, 212)

	local rig = buildBase("칸자키 렌", { skin = skin, torso = shirt, arms = jacket, legs = pants }, 100, 19)
	local model = rig.model
	local deco_ = Instance.new("Folder")
	deco_.Name = "Look"
	deco_.Parent = model

	-- 얼굴: 선명한 적색 눈, 위로 뻗은 날카로운 눈매
	face(rig, deco_, Color3.fromRGB(214, 36, 52), hair, "sharp")
	local head = rig.head
	-- 턱선을 조금 넘는 거친 검은 단발
	deco(deco_, head, "HairCap", Vector3.new(1.34, 0.32, 1.34), CFrame.new(0, 0.56, 0.02), hair)
	deco(deco_, head, "HairBack", Vector3.new(1.38, 1.1, 0.32), CFrame.new(0, 0.05, 0.56), hair)
	for _, side in { -1, 1 } do
		deco(deco_, head, "HairSide", Vector3.new(0.22, 1.05, 1.18), CFrame.new(side * 0.66, 0.08, 0.05), hair)
		deco(deco_, head, "HairSideTip", Vector3.new(0.2, 0.3, 0.4), CFrame.new(side * 0.68, -0.52, -0.25) * CFrame.Angles(rad(-20), 0, rad(side * -10)), hair)
	end
	-- 불규칙하게 갈라진 앞머리
	local bangs = {
		{ -0.42, 0.34, 0.24, 0.5, 8 },
		{ -0.18, 0.3, 0.22, 0.62, -4 },
		{ 0.06, 0.36, 0.2, 0.46, 6 },
		{ 0.28, 0.3, 0.24, 0.58, -8 },
		{ 0.48, 0.36, 0.2, 0.44, -14 },
	}
	for i, b in bangs do
		deco(deco_, head, "Bang" .. i, Vector3.new(b[3], b[4], 0.14), CFrame.new(b[1], b[2], -0.6) * CFrame.Angles(rad(-8), 0, rad(b[5])), hair)
	end
	-- 목덜미 쪽 짧게 들뜬 머리
	for i, x in { -0.4, 0, 0.4 } do
		deco(deco_, head, "Nape" .. i, Vector3.new(0.3, 0.22, 0.22), CFrame.new(x, -0.5, 0.62) * CFrame.Angles(rad(35), 0, rad(x * 30)), hair)
	end

	-- 몸통: 숯빛 셔츠 + 허리까지 오는 짧은 현장 재킷(안감 적색)
	local torso = rig.torso
	for _, side in { -1, 1 } do
		deco(deco_, torso, "JacketFront", Vector3.new(0.74, 1.75, 0.14), CFrame.new(side * 0.64, 0.14, -0.55), jacket, Enum.Material.Fabric)
		deco(deco_, torso, "Lining", Vector3.new(0.07, 1.75, 0.15), CFrame.new(side * 0.25, 0.14, -0.56), red, Enum.Material.Fabric)
		deco(deco_, torso, "JacketSide", Vector3.new(0.14, 1.75, 1.12), CFrame.new(side * 1.03, 0.14, 0), jacket, Enum.Material.Fabric)
		deco(deco_, torso, "Pocket", Vector3.new(0.4, 0.3, 0.06), CFrame.new(side * 0.62, -0.4, -0.64), Color3.fromRGB(34, 34, 38), Enum.Material.Fabric)
	end
	deco(deco_, torso, "JacketBack", Vector3.new(2.1, 1.75, 0.14), CFrame.new(0, 0.14, 0.55), jacket, Enum.Material.Fabric)
	deco(deco_, torso, "Collar", Vector3.new(2.16, 0.34, 1.2), CFrame.new(0, 0.96, 0.02), jacket, Enum.Material.Fabric)
	deco(deco_, torso, "CollarBack", Vector3.new(1.6, 0.45, 0.16), CFrame.new(0, 1.12, 0.52) * CFrame.Angles(rad(-15), 0, 0), jacket, Enum.Material.Fabric)
	deco(deco_, torso, "Belt", Vector3.new(2.08, 0.22, 1.1), CFrame.new(0, -0.9, 0), Color3.fromRGB(16, 16, 18), Enum.Material.Fabric)
	deco(deco_, torso, "Buckle", Vector3.new(0.28, 0.2, 0.06), CFrame.new(0, -0.9, -0.56), Color3.fromRGB(150, 150, 156), Enum.Material.Metal)
	-- 목에 느슨하게 건 방진 마스크
	deco(deco_, torso, "Mask", Vector3.new(0.9, 0.34, 0.22), CFrame.new(0, 0.9, -0.66) * CFrame.Angles(rad(20), 0, 0), Color3.fromRGB(150, 152, 158), Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		deco(deco_, torso, "MaskStrap", Vector3.new(0.05, 0.05, 0.9), CFrame.new(side * 0.5, 1.0, -0.2) * CFrame.Angles(rad(-15), 0, 0), Color3.fromRGB(60, 60, 64))
	end
	-- 오른쪽 허리: ARK 단말 + 밀폐형 회분 수거통
	deco(deco_, torso, "ARK", Vector3.new(0.14, 0.5, 0.36), CFrame.new(1.08, -0.72, -0.15), Color3.fromRGB(30, 32, 36), Enum.Material.Metal)
	local arkLight = deco(deco_, torso, "ARKLight", Vector3.new(0.05, 0.08, 0.08), CFrame.new(1.16, -0.6, -0.15), Color3.fromRGB(80, 220, 210), Enum.Material.Neon)
	arkLight.CastShadow = false
	cylY(deco_, torso, "AshCanister", 0.6, 0.42, CFrame.new(0.95, -0.85, 0.42), Color3.fromRGB(70, 72, 78), Enum.Material.Metal)
	cylY(deco_, torso, "AshCanisterCap", 0.1, 0.46, CFrame.new(0.95, -0.52, 0.42), Color3.fromRGB(150, 28, 32), Enum.Material.Metal)

	-- 왼쪽 허리: 무광 검은 칼집 + 봉인선 10개
	local scabbard = Instance.new("Model")
	scabbard.Name = "Scabbard"
	scabbard.Parent = model
	local scabRel = CFrame.new(-1.18, -0.8, 0.2) * CFrame.Angles(rad(24), rad(-8), 0)
	local sheath = deco(scabbard, torso, "Sheath", Vector3.new(0.24, 0.3, 3.3), scabRel, Color3.fromRGB(14, 14, 16), Enum.Material.SmoothPlastic)
	sheath.Name = "Sheath"
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
	-- 칼집에 꽂힌 상태의 칼자루 (최대 출력 충전 중에만 보임)
	local sheathed = Instance.new("Model")
	sheathed.Name = "KatanaSheathed"
	sheathed.Parent = model
	deco(sheathed, torso, "Tsuba", Vector3.new(0.5, 0.5, 0.06), scabRel * CFrame.new(0, 0, -1.72), Color3.fromRGB(40, 40, 44), Enum.Material.Metal)
	deco(sheathed, torso, "Hilt", Vector3.new(0.2, 0.22, 0.95), scabRel * CFrame.new(0, 0, -2.22), Color3.fromRGB(18, 18, 20), Enum.Material.Fabric)
	deco(sheathed, torso, "HiltWrap", Vector3.new(0.22, 0.24, 0.7), scabRel * CFrame.new(0, 0, -2.22), red, Enum.Material.Fabric).Transparency = 0.4
	for _, p in sheathed:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("ShowT", p.Transparency)
			p.Transparency = 1
		end
	end

	-- 팔: 재킷 소매 + 왼팔 적색 식별선 + 얇게 가공된 장갑
	for i, arm in { rig.rightArm, rig.leftArm } do
		deco(deco_, arm, "Sleeve", Vector3.new(1.1, 1.5, 1.1), CFrame.new(0, 0.28, 0), jacket, Enum.Material.Fabric)
		deco(deco_, arm, "Cuff", Vector3.new(1.14, 0.16, 1.14), CFrame.new(0, -0.45, 0), Color3.fromRGB(34, 34, 38), Enum.Material.Fabric)
		deco(deco_, arm, "Glove", Vector3.new(1.05, 0.5, 1.05), CFrame.new(0, -0.76, 0), Color3.fromRGB(12, 12, 14), Enum.Material.Fabric)
		if i == 2 then
			deco(deco_, arm, "IDStripe", Vector3.new(1.14, 0.18, 1.14), CFrame.new(0, 0.62, 0), red, Enum.Material.Fabric)
		end
	end

	-- 다리: 검은 전술 바지 + 무릎 보호대 + 부츠
	for _, leg in { rig.rightLeg, rig.leftLeg } do
		deco(deco_, leg, "Pants", Vector3.new(1.08, 1.5, 1.1), CFrame.new(0, 0.25, 0), pants, Enum.Material.Fabric)
		deco(deco_, leg, "KneePad", Vector3.new(0.7, 0.45, 0.14), CFrame.new(0, -0.1, -0.56), Color3.fromRGB(46, 46, 52), Enum.Material.Fabric)
		deco(deco_, leg, "Boot", Vector3.new(1.08, 0.55, 1.24), CFrame.new(0, -0.74, -0.08), Color3.fromRGB(14, 14, 16), Enum.Material.SmoothPlastic)
	end

	-- 손에 쥔 JN-47 영력전도 도검
	local handle = weaponMotor(rig, "KatanaHandle")
	local katana = Instance.new("Model")
	katana.Name = "KatanaHand"
	katana.Parent = model
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

	model:SetAttribute("CharId", "KanzakiRen")
	nameplate(rig, "칸자키 렌", Color3.fromRGB(214, 44, 52))
	return model
end

----------------------------------------------------------------------
-- 훈련용 허수아비
----------------------------------------------------------------------
local function buildDummy(): Model
	local burlap = Color3.fromRGB(184, 156, 108)
	local rig = buildBase("훈련용 허수아비", { skin = burlap, torso = burlap, arms = burlap, legs = Color3.fromRGB(150, 120, 80) }, 200, 0)
	local model = rig.model
	local deco_ = Instance.new("Folder")
	deco_.Name = "Look"
	deco_.Parent = model
	local head = rig.head
	for _, side in { -1, 1 } do
		deco(deco_, head, "XEye", Vector3.new(0.3, 0.06, 0.05), CFrame.new(side * 0.22, 0.05, -0.59) * CFrame.Angles(0, 0, rad(45)), Color3.fromRGB(40, 30, 20))
		deco(deco_, head, "XEye", Vector3.new(0.3, 0.06, 0.05), CFrame.new(side * 0.22, 0.05, -0.59) * CFrame.Angles(0, 0, rad(-45)), Color3.fromRGB(40, 30, 20))
	end
	discZ(deco_, rig.torso, "Target", 1.4, 0.06, CFrame.new(0, 0.1, -0.52), Color3.fromRGB(200, 40, 40))
	discZ(deco_, rig.torso, "TargetIn", 0.9, 0.07, CFrame.new(0, 0.1, -0.53), Color3.fromRGB(240, 235, 225))
	discZ(deco_, rig.torso, "TargetDot", 0.4, 0.08, CFrame.new(0, 0.1, -0.54), Color3.fromRGB(200, 40, 40))
	deco(deco_, rig.torso, "Vest", Vector3.new(2.1, 0.5, 1.1), CFrame.new(0, 0.75, 0), Color3.fromRGB(30, 30, 34), Enum.Material.Fabric)
	deco(deco_, head, "Stitch", Vector3.new(0.05, 1.0, 0.05), CFrame.new(0, 0.1, 0.6), Color3.fromRGB(90, 70, 40))
	model:SetAttribute("CharId", "Dummy")
	nameplate(rig, "훈련용 허수아비", Color3.fromRGB(120, 200, 120))
	return model
end

function RigBuilder.build(charId: string): Model
	if charId == "LinYuan" then
		return buildLinYuan()
	elseif charId == "KanzakiRen" then
		return buildKanzakiRen()
	end
	return buildDummy()
end

-- 발끝이 cf 위치의 지면에 닿도록 배치 (HRP 는 지면 + 3)
function RigBuilder.place(model: Model, cf: CFrame)
	model:PivotTo(cf * CFrame.new(0, 3, 0))
end

return RigBuilder
