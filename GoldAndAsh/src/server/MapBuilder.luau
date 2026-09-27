--!strict
--[[
	MapBuilder
	「붕괴된 야시장 — WACA 사건 현장」  (Collapsed Night Market — WACA incident site)

	A fully procedural, deterministic battlegrounds arena made only of primitive parts
	(no meshes, no asset ids, no Terrain). The same file runs:
		* inside Roblox, required by a server script, and
		* inside Lune (tools/preview_map.luau) with the @lune/roblox datatypes injected.
	Because of that it only touches Instance.new, the plain datatypes (incl. Font for text), Enum and
	plain Luau. Orientation goes through CFrame.fromMatrix (see lookAt below).

	World conventions
		ground top surface   y = 0
		playable arena       x, z in [-180, 180] (invisible walls at ±185, ceiling at y = 220)
		north = -Z           林記麵館 (Lin family noodle shop) + night-market lane
		south = +Z           WACA cleanup zone (collapsed buildings, crater, truck)
		east  = +X           asphalt street with cars, lamps, bus stop, vending machines
		west  = -X           sunken stone canal with arched bridge, willows, pavilion
		centre               circular sparring plaza (r = 46 + steps) with dragon-scale paving

	API
		MapBuilder.build(parent) -> Model "Map"
		MapBuilder.applyLighting(lighting)
]]

local MapBuilder = {}

-- ─────────────────────────────────────────────────────────────────────────────
-- Shorthands
-- ─────────────────────────────────────────────────────────────────────────────

local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local MAT = Enum.Material
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder's X axis to +Y

-- CFrame looking from pos towards target. Built on CFrame.fromMatrix instead of CFrame.lookAt
-- because Lune 0.10's CFrame.lookAt mirrors the Z axis; fromMatrix behaves identically in both.
local function lookAt(pos: Vector3, target: Vector3, up: Vector3?): CFrame
	local look = (target - pos).Unit
	local upv = up or Vector3.yAxis
	if math.abs(look:Dot(upv)) > 0.999 then
		upv = if math.abs(look.X) < 0.9 then Vector3.xAxis else Vector3.zAxis
	end
	local right = look:Cross(upv).Unit
	local up2 = right:Cross(look).Unit
	return CFrame.fromMatrix(pos, right, up2, -look)
end

local MAX_LIGHTS = 40
local MAX_BREAKABLE_SIZE = 8

-- ─────────────────────────────────────────────────────────────────────────────
-- Deterministic PRNG (Park–Miller minimal standard; exact in doubles)
-- ─────────────────────────────────────────────────────────────────────────────

local rngState = 1

local function seedRng(s: number)
	rngState = s % 2147483647
	if rngState <= 0 then
		rngState += 2147483646
	end
end

local function rnd(): number
	rngState = (rngState * 16807) % 2147483647
	return (rngState - 1) / 2147483646
end

local function rr(a: number, b: number): number
	return a + (b - a) * rnd()
end

local function ri(a: number, b: number): number
	return math.min(b, a + math.floor(rnd() * (b - a + 1)))
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Palette
-- ─────────────────────────────────────────────────────────────────────────────

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function jitter(c: Color3, amount: number): Color3
	local d = rr(-amount, amount) / 255
	return Color3.new(math.clamp(c.R + d, 0, 1), math.clamp(c.G + d, 0, 1), math.clamp(c.B + d, 0, 1))
end

local C = {
	ground = rgb(112, 104, 96),
	cobble = rgb(122, 106, 92),
	incidentGround = rgb(104, 100, 97),
	promenade = rgb(134, 122, 106),
	lawn = rgb(86, 102, 58),
	path = rgb(160, 148, 128),
	asphalt = rgb(50, 50, 55),
	sidewalk = rgb(150, 145, 136),
	curb = rgb(176, 170, 160),
	stone = rgb(150, 138, 120),
	stoneLight = rgb(176, 162, 140),
	stoneDark = rgb(108, 98, 88),
	paving = rgb(126, 116, 104),
	pavingInner = rgb(132, 121, 108),
	scaleA = rgb(106, 98, 92),
	scaleB = rgb(148, 134, 114),
	scaleGold = rgb(196, 150, 70),
	gold = rgb(232, 182, 74),
	goldPale = rgb(250, 216, 140),
	lacquer = rgb(142, 27, 27),
	lacquerDark = rgb(96, 18, 20),
	wood = rgb(92, 62, 42),
	woodDark = rgb(56, 38, 28),
	woodLight = rgb(156, 116, 76),
	crate = rgb(150, 112, 70),
	tile = rgb(58, 58, 66),
	jade = rgb(58, 118, 100),
	plaster = rgb(196, 178, 146),
	brick = rgb(122, 60, 46),
	brickDark = rgb(88, 48, 40),
	concrete = rgb(128, 124, 118),
	concreteDark = rgb(84, 82, 80),
	charcoal = rgb(46, 46, 50),
	metal = rgb(70, 72, 78),
	steel = rgb(120, 124, 130),
	black = rgb(22, 22, 26),
	wacaRed = rgb(200, 26, 34),
	hazard = rgb(232, 186, 34),
	orange = rgb(240, 110, 30),
	lanternRed = rgb(208, 40, 30),
	neonWarm = rgb(255, 190, 105),
	windowWarm = rgb(200, 128, 64),
	lampWhite = rgb(255, 226, 176),
	water = rgb(48, 104, 122),
	foliage = rgb(96, 126, 58),
	foliageLight = rgb(126, 152, 70),
	bamboo = rgb(112, 146, 70),
	trunk = rgb(78, 60, 46),
	ash = rgb(38, 37, 39),
	glassDark = rgb(40, 52, 62),
	white = rgb(236, 232, 224),
	indigo = rgb(40, 48, 92),
	rebar = rgb(58, 46, 40),
}

-- ─────────────────────────────────────────────────────────────────────────────
-- Part helpers
-- ─────────────────────────────────────────────────────────────────────────────

--[[
	Kind controls collision / query / shadow flags:
		solid  collidable + queryable + casts shadow (default for anything > 1.5 studs)
		deco   visual only but casts shadow (foliage, cloth, glass panels)
		tiny   visual only, no shadow (small ornaments, ropes, skyline)
		ghost  invisible marker
		bound  invisible collision wall
	CanTouch is off for every non-breakable map part.
]]
type Kind = "solid" | "deco" | "tiny" | "ghost" | "bound"

local lightCount = 0

local function setup(p: BasePart, parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, kind: Kind?)
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = mat
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local k: Kind
	if kind then
		k = kind
	else
		local maxDim = math.max(size.X, size.Y, size.Z)
		local minDim = math.min(size.X, size.Y, size.Z)
		local volume = size.X * size.Y * size.Z
		k = if maxDim <= 1.5 or (minDim <= 0.3 and volume < 4) then "tiny" else "solid"
	end
	p.CanTouch = false
	if k == "solid" then
		p.CanCollide = true
		p.CanQuery = true
		p.CastShadow = true
	elseif k == "deco" then
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = true
	elseif k == "tiny" then
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
	elseif k == "ghost" then
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		p.Transparency = 1
	else -- bound
		p.CanCollide = true
		p.CanQuery = false
		p.CastShadow = false
		p.Transparency = 1
	end
	p.Parent = parent
end

local function box(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, kind: Kind?): Part
	local p = Instance.new("Part")
	setup(p, parent, name, size, cf, color, mat, kind)
	return p
end

-- axis-aligned box from two corners
local function aabb(parent: Instance, name: string, x0: number, y0: number, z0: number, x1: number, y1: number, z1: number, color: Color3, mat: Enum.Material, kind: Kind?): Part
	return box(
		parent,
		name,
		V3(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
		CF((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		color,
		mat,
		kind
	)
end

-- vertical cylinder centred at pos
local function cyl(parent: Instance, name: string, d: number, h: number, pos: Vector3, color: Color3, mat: Enum.Material, kind: Kind?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	setup(p, parent, name, V3(h, d, d), CF(pos) * UPRIGHT, color, mat, kind)
	return p
end

-- cylinder (or square beam) running from a to b
local function rod(parent: Instance, name: string, a: Vector3, b: Vector3, d: number, color: Color3, mat: Enum.Material, kind: Kind?, square: boolean?): Part
	local dir = b - a
	local len = dir.Magnitude
	local mid = (a + b) / 2
	local look = lookAt(mid, b)
	local p = Instance.new("Part")
	if square then
		setup(p, parent, name, V3(d, d, len), look, color, mat, kind)
	else
		p.Shape = Enum.PartType.Cylinder
		setup(p, parent, name, V3(len, d, d), look * ANG(0, math.pi / 2, 0), color, mat, kind)
	end
	return p
end

local function ball(parent: Instance, name: string, d: number, pos: Vector3, color: Color3, mat: Enum.Material, kind: Kind?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	setup(p, parent, name, V3(d, d, d), CF(pos), color, mat, kind)
	return p
end

-- WedgePart: the high edge is at local +Z, the slope faces local -Z / +Y
local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, kind: Kind?): WedgePart
	local p = Instance.new("WedgePart")
	setup(p, parent, name, size, cf, color, mat, kind)
	return p
end

local function truss(parent: Instance, name: string, height: number, pos: Vector3, color: Color3): TrussPart
	local p = Instance.new("TrussPart")
	setup(p, parent, name, V3(2, height, 2), CF(pos), color, MAT.Metal, "solid")
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- CFrame for a rotated block whose lowest point sits `embed` studs below height y
local function restCF(x: number, y: number, z: number, size: Vector3, rot: CFrame, embed: number): CFrame
	local hy = math.abs(rot.RightVector.Y) * size.X / 2
		+ math.abs(rot.UpVector.Y) * size.Y / 2
		+ math.abs(rot.LookVector.Y) * size.Z / 2
	return CF(x, y + hy - embed, z) * rot
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Lights & GUI
-- ─────────────────────────────────────────────────────────────────────────────

local function pointLight(p: BasePart, range: number, brightness: number, color: Color3): PointLight
	lightCount += 1
	assert(lightCount <= MAX_LIGHTS, "MapBuilder: light budget exceeded")
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color
	l.Shadows = false
	l.Parent = p
	return l
end

local function spotLight(p: BasePart, range: number, brightness: number, angle: number, color: Color3): SpotLight
	lightCount += 1
	assert(lightCount <= MAX_LIGHTS, "MapBuilder: light budget exceeded")
	local l = Instance.new("SpotLight")
	l.Face = Enum.NormalId.Front
	l.Range = range
	l.Brightness = brightness
	l.Angle = angle
	l.Color = color
	l.Shadows = true
	l.Parent = p
	return l
end

type Line = {
	text: string,
	color: Color3,
	y: number,
	h: number,
	font: Enum.Font?,
	stroke: Color3?,
}

local function surfaceText(p: BasePart, face: Enum.NormalId, ppu: number, bg: Color3?, lines: { Line }, lightInfluence: number?, brightness: number?): SurfaceGui
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Sign" .. face.Name
	sg.Face = face
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = ppu
	sg.LightInfluence = lightInfluence or 0.35
	sg.Brightness = brightness or 1.3
	sg.ClipsDescendants = true
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	if bg then
		local frame = Instance.new("Frame")
		frame.Name = "Background"
		frame.Size = UDim2.fromScale(1, 1)
		frame.BackgroundColor3 = bg
		frame.BackgroundTransparency = 0
		frame.BorderSizePixel = 0
		frame.ZIndex = 1
		frame.Parent = sg
	end
	for i, ln in lines do
		local tl = Instance.new("TextLabel")
		tl.Name = "Line" .. i
		tl.BackgroundTransparency = 1
		tl.BorderSizePixel = 0
		tl.Size = UDim2.new(0.94, 0, ln.h, 0)
		tl.Position = UDim2.new(0.03, 0, ln.y, 0)
		tl.Text = ln.text
		tl.TextColor3 = ln.color
		tl.TextScaled = true
		tl.TextWrapped = true
		tl.FontFace = Font.fromEnum(ln.font or Enum.Font.Antique)
		local stroke = ln.stroke
		if stroke then
			tl.TextStrokeColor3 = stroke
			tl.TextStrokeTransparency = 0.35
		else
			tl.TextStrokeTransparency = 1
		end
		tl.ZIndex = 2
		tl.Parent = sg
	end
	sg.Parent = p
	return sg
end

local function oneLine(text: string, color: Color3, font: Enum.Font?): { Line }
	return { { text = text, color = color, y = 0.08, h = 0.84, font = font } }
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Breakable prefabs (every BasePart gets Breakable = true, CanQuery/CanCollide on)
-- ─────────────────────────────────────────────────────────────────────────────

local breakableCount = 0

local function bpart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material, shape: Enum.PartType?): Part
	assert(math.max(size.X, size.Y, size.Z) <= MAX_BREAKABLE_SIZE, "MapBuilder: breakable too large: " .. name)
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	setup(p, parent, name, size, cf, color, mat, "solid")
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = true
	p:SetAttribute("Breakable", true)
	breakableCount += 1
	return p
end

local function crate(parent: Instance, x: number, y: number, z: number, s: number, yaw: number): Part
	return bpart(parent, "Crate", V3(s, s, s), CF(x, y + s / 2, z) * ANG(0, rad(yaw), 0), jitter(C.crate, 12), MAT.WoodPlanks)
end

local function barrel(parent: Instance, x: number, y: number, z: number, color: Color3): Part
	return bpart(parent, "Barrel", V3(3.2, 2.2, 2.2), CF(x, y + 1.6, z) * UPRIGHT, color, MAT.Wood, Enum.PartType.Cylinder)
end

local function drum(parent: Instance, x: number, y: number, z: number, color: Color3): Part
	return bpart(parent, "Drum", V3(3.0, 2.1, 2.1), CF(x, y + 1.5, z) * UPRIGHT, color, MAT.Metal, Enum.PartType.Cylinder)
end

local function stool(parent: Instance, x: number, y: number, z: number, color: Color3): Part
	return bpart(parent, "Stool", V3(2.0, 1.4, 1.4), CF(x, y + 1.0, z) * UPRIGHT, color, MAT.Wood, Enum.PartType.Cylinder)
end

local function roundTable(parent: Instance, x: number, y: number, z: number)
	local m = model(parent, "StallTable")
	local leg = bpart(m, "TableLeg", V3(2.7, 0.7, 0.7), CF(x, y + 1.35, z) * UPRIGHT, C.woodDark, MAT.Wood, Enum.PartType.Cylinder)
	bpart(m, "TableTop", V3(0.3, 3.4, 3.4), CF(x, y + 2.85, z) * UPRIGHT, C.woodLight, MAT.WoodPlanks, Enum.PartType.Cylinder)
	m.PrimaryPart = leg
end

-- a table with stools around it
local function diningSet(parent: Instance, x: number, y: number, z: number, nStools: number, yaw: number)
	roundTable(parent, x, y, z)
	for i = 1, nStools do
		local a = rad(yaw) + (i - 1) * 2 * math.pi / nStools
		stool(parent, x + math.cos(a) * 2.9, y, z + math.sin(a) * 2.9, if i % 2 == 0 then C.lacquer else C.woodLight)
	end
end

local function lanternPost(parent: Instance, x: number, y: number, z: number, yaw: number, lit: boolean)
	local m = model(parent, "LanternPost")
	local o = CF(x, y, z) * ANG(0, rad(yaw), 0)
	local post = bpart(m, "Post", V3(0.5, 6.0, 0.5), o * CF(0, 3.0, 0), C.woodDark, MAT.Wood)
	local lamp = bpart(m, "Lantern", V3(1.4, 1.4, 1.4), o * CF(0, 6.6, 0), C.lanternRed, MAT.Neon, Enum.PartType.Ball)
	if lit then
		pointLight(lamp, 11, 1.3, rgb(255, 140, 80))
	end
	m.PrimaryPart = post
end

local function trafficCone(parent: Instance, x: number, y: number, z: number)
	local m = model(parent, "TrafficCone")
	local base = bpart(m, "ConeBase", V3(1.5, 0.2, 1.5), CF(x, y + 0.1, z), C.black, MAT.SmoothPlastic)
	bpart(m, "ConeBody", V3(2.2, 0.9, 0.9), CF(x, y + 1.3, z) * UPRIGHT, C.orange, MAT.SmoothPlastic, Enum.PartType.Cylinder)
	m.PrimaryPart = base
end

local function jerseyBarrier(parent: Instance, x: number, y: number, z: number, yaw: number, color: Color3)
	local m = model(parent, "JerseyBarrier")
	local o = CF(x, y, z) * ANG(0, rad(yaw), 0)
	local base = bpart(m, "BarrierBase", V3(2.4, 1.2, 7.6), o * CF(0, 0.6, 0), color, MAT.Concrete)
	bpart(m, "BarrierTop", V3(1.1, 1.8, 7.6), o * CF(0, 2.1, 0), color, MAT.Concrete)
	m.PrimaryPart = base
end

local function rubbleChunk(parent: Instance, x: number, y: number, z: number, size: Vector3, color: Color3): Part
	local rot = ANG(rad(rr(-12, 12)), rad(rr(0, 360)), rad(rr(-12, 12)))
	return bpart(parent, "Rubble", size, restCF(x, y, z, size, rot, 0.12), jitter(color, 10), MAT.Concrete)
end

local function wacaCase(parent: Instance, x: number, y: number, z: number, yaw: number): Part
	local p = bpart(parent, "WACACase", V3(3.2, 1.6, 2.0), CF(x, y + 0.8, z) * ANG(0, rad(yaw), 0), C.black, MAT.SmoothPlastic)
	surfaceText(p, Enum.NormalId.Top, 30, nil, oneLine("WACA", C.wacaRed, Enum.Font.GothamBlack), 0.6)
	return p
end

local function bench(parent: Instance, o: CFrame, breakable: boolean)
	-- o: ground centre, LookVector = direction a seated person faces
	if breakable then
		local m = model(parent, "Bench")
		local base = bpart(m, "BenchBase", V3(4.0, 1.7, 0.8), o * CF(0, 0.85, 0), C.stoneDark, MAT.Granite)
		bpart(m, "BenchSeat", V3(5.2, 0.4, 1.7), o * CF(0, 1.9, 0), C.woodLight, MAT.WoodPlanks)
		bpart(m, "BenchBack", V3(5.2, 1.5, 0.3), o * CF(0, 3.0, 0.75) * ANG(rad(-8), 0, 0), C.woodLight, MAT.WoodPlanks)
		m.PrimaryPart = base
	else
		box(parent, "BenchBase", V3(4.0, 1.7, 0.8), o * CF(0, 0.85, 0), C.stoneDark, MAT.Granite, "solid")
		box(parent, "BenchSeat", V3(5.2, 0.4, 1.7), o * CF(0, 1.9, 0), C.woodLight, MAT.WoodPlanks, "solid")
		box(parent, "BenchBack", V3(5.2, 1.5, 0.3), o * CF(0, 3.0, 0.75) * ANG(rad(-8), 0, 0), C.woodLight, MAT.WoodPlanks, "solid")
	end
end

-- wooden fence segment from a to b (ground points, same y)
local function fenceSegment(parent: Instance, a: Vector3, b: Vector3)
	local m = model(parent, "FenceSegment")
	local dir = (b - a).Unit
	local len = (b - a).Magnitude
	local post = bpart(m, "FencePost", V3(0.5, 3.2, 0.5), CF(a + V3(0, 1.6, 0)), C.woodDark, MAT.Wood)
	local mid = (a + b) / 2
	local c = mid + V3(0, 2.1, 0)
	bpart(m, "FenceRail", V3(0.25, 1.6, len - 0.5), lookAt(c, c + dir), C.wood, MAT.WoodPlanks)
	m.PrimaryPart = post
end

local function vendingMachine(parent: Instance, x: number, y: number, z: number, body: Color3, lit: boolean)
	-- front face at x (facing -X), 4 studs wide along Z
	local m = model(parent, "VendingMachine")
	local b = bpart(m, "VendingBody", V3(3, 7, 4), CF(x + 1.5, y + 3.5, z), body, MAT.SmoothPlastic)
	local panel = bpart(m, "VendingDisplay", V3(0.2, 3.4, 3.4), CF(x - 0.1, y + 4.9, z), rgb(205, 232, 255), MAT.Neon)
	bpart(m, "VendingSlot", V3(0.2, 1.0, 3.0), CF(x - 0.1, y + 1.5, z), C.black, MAT.SmoothPlastic)
	m.PrimaryPart = b
	-- a grid of little drinks on the display
	local sg = Instance.new("SurfaceGui")
	sg.Name = "Drinks"
	sg.Face = Enum.NormalId.Left
	sg.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	sg.PixelsPerStud = 40
	sg.LightInfluence = 0
	sg.Brightness = 1.2
	local drinkColors = {
		rgb(220, 40, 40),
		rgb(40, 110, 220),
		rgb(240, 200, 40),
		rgb(60, 170, 80),
		rgb(250, 250, 250),
		rgb(120, 60, 30),
		rgb(250, 130, 30),
		rgb(160, 60, 200),
	}
	for row = 0, 2 do
		for col = 0, 4 do
			local fr = Instance.new("Frame")
			fr.Name = "Drink"
			fr.BorderSizePixel = 0
			fr.BackgroundColor3 = drinkColors[((row * 5 + col) % #drinkColors) + 1]
			fr.Size = UDim2.fromScale(0.13, 0.2)
			fr.Position = UDim2.fromScale(0.06 + col * 0.18, 0.06 + row * 0.27)
			fr.Parent = sg
		end
	end
	local tl = Instance.new("TextLabel")
	tl.Name = "Cold"
	tl.BackgroundColor3 = rgb(30, 80, 190)
	tl.BorderSizePixel = 0
	tl.Size = UDim2.fromScale(1, 0.14)
	tl.Position = UDim2.fromScale(0, 0.86)
	tl.Text = "つめた〜い"
	tl.TextColor3 = rgb(255, 255, 255)
	tl.TextScaled = true
	tl.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	tl.Parent = sg
	sg.Parent = panel
	if lit then
		pointLight(panel, 10, 1.0, rgb(190, 220, 255))
	end
end

local function trashBin(parent: Instance, x: number, y: number, z: number, color: Color3): Part
	return bpart(parent, "TrashBin", V3(2.6, 1.6, 1.6), CF(x, y + 1.3, z) * UPRIGHT, color, MAT.Metal, Enum.PartType.Cylinder)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Shared decor prefabs
-- ─────────────────────────────────────────────────────────────────────────────

local function hangingLantern(parent: Instance, top: Vector3, d: number, lit: boolean, range: number?)
	cyl(parent, "LanternCap", d * 0.5, 0.25, top - V3(0, 0.12, 0), C.gold, MAT.Metal, "tiny")
	local b = ball(parent, "Lantern", d, top - V3(0, 0.2 + d / 2, 0), C.lanternRed, MAT.Neon, "tiny")
	if d >= 2 then
		cyl(parent, "LanternFoot", d * 0.4, 0.2, top - V3(0, 0.25 + d, 0), C.gold, MAT.Metal, "tiny")
	end
	if lit then
		pointLight(b, range or 12, 1.5, rgb(255, 136, 76))
	end
end

-- rope from a to b with parabolic sag; lanterns hang at evenly spaced points
local function lanternString(parent: Instance, a: Vector3, b: Vector3, sag: number, nLanterns: number, litSet: { number })
	local function at(t: number): Vector3
		return a + (b - a) * t - V3(0, sag * 4 * t * (1 - t), 0)
	end
	local segs = 5
	for i = 0, segs - 1 do
		rod(parent, "Rope", at(i / segs), at((i + 1) / segs), 0.1, rgb(40, 30, 26), MAT.Fabric, "tiny")
	end
	for i = 1, nLanterns do
		local lit = table.find(litSet, i) ~= nil
		hangingLantern(parent, at(i / (nLanterns + 1)), 1.5, lit, 12)
	end
end

local function tapeLine(parent: Instance, a: Vector3, b: Vector3)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local p = box(parent, "CautionTape", V3(0.05, 0.55, len), lookAt(mid, b), C.hazard, MAT.SmoothPlastic, "tiny")
	local text = "KEEP OUT  ·  立入禁止  ·  WACA  ·  KEEP OUT  ·  立入禁止  ·  WACA  ·  KEEP OUT"
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		surfaceText(p, face, 24, nil, { { text = text, color = C.black, y = 0.05, h = 0.9, font = Enum.Font.GothamBlack } }, 0.8)
	end
end

local function stanchion(parent: Instance, x: number, y: number, z: number)
	cyl(parent, "StanchionBase", 1.1, 0.25, V3(x, y + 0.125, z), C.black, MAT.Metal, "tiny")
	cyl(parent, "Stanchion", 0.25, 3.4, V3(x, y + 1.7, z), C.hazard, MAT.Metal, "tiny")
end

-- a cordon of stanchions with tape between them
local function cordon(parent: Instance, pts: { Vector3 })
	for i, p in pts do
		stanchion(parent, p.X, p.Y, p.Z)
		if i > 1 then
			local q = pts[i - 1]
			tapeLine(parent, q + V3(0, 3.0, 0), p + V3(0, 3.0, 0))
		end
	end
end

local function rebarCluster(parent: Instance, top: Vector3, n: number)
	for _ = 1, n do
		local base = top + V3(rr(-0.6, 0.6), -0.3, rr(-0.6, 0.6))
		local tip = base + V3(rr(-0.9, 0.9), rr(1.6, 3.2), rr(-0.9, 0.9))
		rod(parent, "Rebar", base, tip, 0.18, C.rebar, MAT.CorrodedMetal, "tiny")
	end
end

-- broken concrete pillar with exposed rebar
local function brokenPillar(parent: Instance, x: number, y: number, z: number, h: number, s: number)
	box(parent, "Pillar", V3(s, h, s), CF(x, y + h / 2, z), jitter(C.concrete, 8), MAT.Concrete, "solid")
	box(parent, "PillarBreak", V3(s * 0.8, 0.8, s * 0.6), CF(x + s * 0.1, y + h + 0.1, z) * ANG(rad(18), rad(30), rad(10)), C.concreteDark, MAT.Concrete, "tiny")
	rebarCluster(parent, V3(x, y + h, z), 3)
end

-- a mound of rotated concrete blocks (decor, solid)
local function rubblePile(parent: Instance, x: number, y: number, z: number, radius: number, n: number)
	for _ = 1, n do
		local a = rr(0, 2 * math.pi)
		local r = rr(0, radius)
		local s = V3(rr(1.8, 5), rr(1, 3), rr(1.8, 5))
		local rot = ANG(rad(rr(-25, 25)), rad(rr(0, 360)), rad(rr(-25, 25)))
		local px, pz = x + math.cos(a) * r, z + math.sin(a) * r
		local embed = 0.2 + (1 - r / radius) * 0.6
		box(parent, "RubbleBlock", s, restCF(px, y, pz, s, rot, embed), jitter(C.concrete, 14), MAT.Concrete, "solid")
	end
	if n >= 4 then
		rebarCluster(parent, V3(x, y + 1.2, z), 2)
	end
end

local function ashPile(parent: Instance, x: number, y: number, z: number, s: number)
	cyl(parent, "AshPile", 4.2 * s, 0.35, V3(x, y + 0.17, z), C.ash, MAT.Sand, "tiny")
	cyl(parent, "AshPile", 2.8 * s, 0.35, V3(x + 0.2, y + 0.45, z - 0.1), rgb(30, 29, 31), MAT.Sand, "tiny")
	cyl(parent, "AshPile", 1.4 * s, 0.3, V3(x + 0.3, y + 0.75, z), rgb(24, 23, 25), MAT.Sand, "tiny")
end

local function willow(parent: Instance, x: number, y: number, z: number, s: number)
	local top = V3(x + rr(-1.2, 1.2), y + 8.5 * s, z + rr(-1.2, 1.2))
	rod(parent, "WillowTrunk", V3(x, y - 0.5, z), top, 1.4 * s, C.trunk, MAT.Wood, "solid")
	rod(parent, "WillowBranch", top - V3(0, 1.5, 0), top + V3(rr(-2.5, 2.5), 1.6, rr(-2.5, 2.5)) * s, 0.6 * s, C.trunk, MAT.Wood, "tiny")
	for _ = 1, 3 do
		local off = V3(rr(-2.4, 2.4), rr(0.6, 2.4), rr(-2.4, 2.4)) * s
		ball(parent, "WillowCrown", rr(5.5, 7.5) * s, top + off, jitter(C.foliage, 10), MAT.Grass, "deco")
	end
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi + rr(-0.3, 0.3)
		local r = 3.7 * s
		local len = rr(5.5, 7.5) * s
		local anchor = top + V3(math.cos(a) * r, 0.8, math.sin(a) * r)
		box(parent, "WillowStrand", V3(0.25, len, 1.8 * s), CF(anchor - V3(0, len / 2, 0)) * ANG(0, -a, 0) * ANG(0, 0, rad(rr(-5, 5))), jitter(C.foliageLight, 10), MAT.Grass, "deco")
	end
end

local function bambooCluster(parent: Instance, x: number, y: number, z: number, n: number)
	for _ = 1, n do
		local px, pz = x + rr(-2.5, 2.5), z + rr(-2.5, 2.5)
		local h = rr(12, 19)
		rod(parent, "Bamboo", V3(px, y - 0.3, pz), V3(px + rr(-1, 1), y + h, pz + rr(-1, 1)), 0.5, jitter(C.bamboo, 12), MAT.SmoothPlastic, "solid")
	end
	for _ = 1, 3 do
		ball(parent, "BambooLeaves", rr(4, 6), V3(x + rr(-2, 2), y + rr(12, 17), z + rr(-2, 2)), jitter(C.foliageLight, 10), MAT.Grass, "deco")
	end
end

-- raised stone planter with a golden ginkgo (cover + a ledge to hop on)
local function ginkgoPlanter(parent: Instance, x: number, z: number)
	local m = folder(parent, "GinkgoPlanter")
	cyl(m, "PlanterRim", 10, 1.8, V3(x, 0.9, z), C.stoneLight, MAT.Granite, "solid")
	cyl(m, "PlanterSoil", 8.8, 0.2, V3(x, 1.85, z), rgb(70, 52, 38), MAT.Ground, "tiny")
	local top = V3(x + rr(-0.6, 0.6), 11, z + rr(-0.6, 0.6))
	rod(m, "GinkgoTrunk", V3(x, 1.5, z), top, 1.3, C.trunk, MAT.Wood, "solid")
	rod(m, "GinkgoBranch", top - V3(0, 3, 0), top + V3(rr(-3, 3), 1, rr(-3, 3)), 0.6, C.trunk, MAT.Wood, "tiny")
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi + rr(-0.4, 0.4)
		local off = V3(math.cos(a) * rr(1.5, 3.2), rr(-1.5, 2.5), math.sin(a) * rr(1.5, 3.2))
		local gold = if i % 2 == 0 then rgb(236, 186, 52) else rgb(222, 164, 40)
		ball(m, "GinkgoCrown", rr(5, 7), top + off, jitter(gold, 10), MAT.Grass, "deco")
	end
end

-- autumn maple (red/orange crown)
local function maple(parent: Instance, x: number, y: number, z: number, s: number)
	local top = V3(x + rr(-0.8, 0.8), y + 7.5 * s, z + rr(-0.8, 0.8))
	rod(parent, "MapleTrunk", V3(x, y - 0.4, z), top, 1.1 * s, C.trunk, MAT.Wood, "solid")
	local cols = { rgb(196, 64, 36), rgb(220, 104, 40), rgb(172, 44, 34), rgb(230, 140, 50) }
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi + rr(-0.5, 0.5)
		local off = V3(math.cos(a) * rr(1.2, 2.6), rr(-0.8, 2.2), math.sin(a) * rr(1.2, 2.6)) * s
		ball(parent, "MapleCrown", rr(4.5, 6) * s, top + off, jitter(cols[i], 10), MAT.Grass, "deco")
	end
end

-- newspaper kiosk; o = ground centre, LookVector = service window
local function kiosk(parent: Instance, o: CFrame)
	local m = model(parent, "NewsKiosk")
	local body = box(m, "KioskBody", V3(6, 6.5, 4.5), o * CF(0, 3.25, 0), rgb(40, 90, 70), MAT.Metal, "solid")
	m.PrimaryPart = body
	box(m, "KioskRoof", V3(7.4, 0.4, 6.4), o * CF(0, 6.8, -0.6), rgb(30, 60, 50), MAT.Metal, "solid")
	box(m, "KioskWindow", V3(4.6, 2.6, 0.1), o * CF(0, 4.2, -2.27), C.windowWarm, MAT.Neon, "tiny")
	box(m, "KioskCounter", V3(5.6, 0.3, 1.0), o * CF(0, 2.7, -2.7), C.woodLight, MAT.Wood, "tiny")
	local cols = { rgb(220, 60, 60), rgb(240, 200, 60), rgb(60, 140, 220), C.white, rgb(90, 190, 110) }
	for i = 1, 5 do
		box(m, "Magazine", V3(0.9, 1.2, 0.1), o * CF(-2.6 + i * 0.87, 1.6, -2.3) * ANG(rad(-12), 0, 0), cols[i], MAT.SmoothPlastic, "tiny")
	end
	local sign = box(m, "KioskSign", V3(6, 1.2, 0.2), o * CF(0, 6.2, -2.4), C.black, MAT.SmoothPlastic, "tiny")
	surfaceText(sign, Enum.NormalId.Front, 30, C.black, oneLine("報攤 · 新聞", C.goldPale, Enum.Font.Antique), 0.5)
end

-- noodle-delivery scooter; o = ground centre, LookVector = front
local function scooter(parent: Instance, o: CFrame)
	local m = model(parent, "DeliveryScooter")
	local body = box(m, "ScooterBody", V3(1.2, 1.4, 4.2), o * CF(0, 1.6, 0), rgb(200, 190, 170), MAT.SmoothPlastic, "solid")
	m.PrimaryPart = body
	for _, sz in { -1.6, 1.6 } do
		local w = Instance.new("Part")
		w.Shape = Enum.PartType.Cylinder
		setup(w, m, "ScooterWheel", V3(0.5, 1.6, 1.6), o * CF(0, 0.8, sz), C.black, MAT.SmoothPlastic, "tiny")
	end
	box(m, "ScooterSeat", V3(1.1, 0.4, 1.8), o * CF(0, 2.5, 0.4), C.black, MAT.Fabric, "tiny")
	rod(m, "ScooterStem", (o * CF(0, 1.6, -1.8)).Position, (o * CF(0, 3.6, -2.0)).Position, 0.25, C.metal, MAT.Metal, "tiny")
	box(m, "ScooterBars", V3(2.0, 0.2, 0.2), o * CF(0, 3.6, -2.0), C.metal, MAT.Metal, "tiny")
	local crateBox = box(m, "DeliveryBox", V3(1.8, 1.6, 1.8), o * CF(0, 3.5, 1.4), C.lacquer, MAT.SmoothPlastic, "solid")
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Back } do
		surfaceText(crateBox, face, 40, C.lacquer, oneLine("林記", C.gold), 0.5)
	end
end

-- a rock (rotated block) sitting on the ground
local function rock(parent: Instance, x: number, y: number, z: number, s: number)
	local size = V3(rr(1.6, 3.2), rr(1.0, 2.2), rr(1.6, 3.2)) * s
	local rot = ANG(rad(rr(-15, 15)), rad(rr(0, 360)), rad(rr(-15, 15)))
	box(parent, "Rock", size, restCF(x, y, z, size, rot, 0.3), jitter(rgb(120, 116, 108), 12), MAT.Slate, "solid")
end

-- boxy car. o = ground centre, LookVector = car front
local function car(parent: Instance, o: CFrame, body: Color3, variant: string)
	local m = model(parent, "Car")
	local W, L = 6.2, 12.5
	local main = box(m, "CarBody", V3(W, 2.2, L), o * CF(0, 1.9, 0), body, MAT.SmoothPlastic, "solid")
	m.PrimaryPart = main
	box(m, "CarCabin", V3(W - 0.6, 2.1, 6.2), o * CF(0, 4.05, 0.7), body, MAT.SmoothPlastic, "solid")
	box(m, "CarWindows", V3(W - 0.5, 1.3, 5.6), o * CF(0, 4.15, 0.7), C.glassDark, MAT.Glass, "deco")
	wedge(m, "CarWindshield", V3(W - 0.6, 2.1, 1.6), o * CF(0, 4.05, -3.2), C.glassDark, MAT.Glass, "solid")
	wedge(m, "CarRearGlass", V3(W - 0.6, 2.1, 1.1), o * CF(0, 4.05, 4.35) * ANG(0, math.pi, 0), C.glassDark, MAT.Glass, "solid")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local w = Instance.new("Part")
			w.Shape = Enum.PartType.Cylinder
			setup(w, m, "Wheel", V3(0.9, 2.2, 2.2), o * CF(sx * (W / 2 - 0.35), 1.1, sz * 3.9), rgb(28, 28, 30), MAT.SmoothPlastic, "solid")
		end
		box(m, "Headlight", V3(1.2, 0.5, 0.1), o * CF(sx * 2.0, 2.3, -L / 2 - 0.03), C.lampWhite, MAT.Neon, "tiny")
		box(m, "Taillight", V3(1.0, 0.5, 0.1), o * CF(sx * 2.1, 2.4, L / 2 + 0.03), rgb(220, 30, 30), MAT.Neon, "tiny")
	end
	box(m, "BumperFront", V3(W + 0.2, 0.6, 0.4), o * CF(0, 1.1, -L / 2 - 0.1), rgb(40, 40, 44), MAT.SmoothPlastic, "solid")
	box(m, "BumperRear", V3(W + 0.2, 0.6, 0.4), o * CF(0, 1.1, L / 2 + 0.1), rgb(40, 40, 44), MAT.SmoothPlastic, "solid")
	if variant == "taxi" then
		local sign = box(m, "TaxiSign", V3(1.8, 0.8, 0.8), o * CF(0, 5.5, 0.7), C.white, MAT.SmoothPlastic, "tiny")
		surfaceText(sign, Enum.NormalId.Front, 40, rgb(250, 250, 240), oneLine("的士", rgb(180, 20, 20), Enum.Font.GothamBold), 0.3)
		surfaceText(sign, Enum.NormalId.Back, 40, rgb(250, 250, 240), oneLine("TAXI", rgb(180, 20, 20), Enum.Font.GothamBold), 0.3)
	end
end

-- flipped, crushed car (lying on its roof)
local function crushedCar(parent: Instance, x: number, z: number, yaw: number)
	local m = model(parent, "CrushedCar")
	local o = CF(x, 3.9, z) * ANG(0, rad(yaw), 0) * ANG(rad(4), 0, math.pi)
	local body = rgb(70, 64, 60)
	local main = box(m, "CarBody", V3(6.2, 2.2, 12.5), o * CF(0, 1.9, 0) * ANG(rad(3), 0, 0), body, MAT.CorrodedMetal, "solid")
	m.PrimaryPart = main
	box(m, "CarCabinCrushed", V3(5.8, 0.9, 6.6), o * CF(0.3, 3.45, 0.9) * ANG(0, 0, rad(6)), rgb(58, 54, 52), MAT.CorrodedMetal, "solid")
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local w = Instance.new("Part")
			w.Shape = Enum.PartType.Cylinder
			setup(w, m, "Wheel", V3(0.9, 2.2, 2.2), o * CF(sx * 2.75, 1.1, sz * 3.9), rgb(28, 28, 30), MAT.SmoothPlastic, "solid")
		end
	end
	box(m, "Scorch", V3(7, 0.08, 14), CF(x, 0.1, z) * ANG(0, rad(yaw + 10), 0), rgb(24, 22, 22), MAT.Slate, "tiny")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ZONE: ground & surface overlays
-- ─────────────────────────────────────────────────────────────────────────────

local function buildGround(map: Instance, decor: Instance): Part
	local g = aabb(map, "Ground", -96, -10, -340, 340, 0, 340, C.ground, MAT.Pavement, "solid")
	local f = folder(decor, "GroundSurfaces")
	aabb(f, "GroundWest", -340, -10, -340, -112, 0, 340, C.ground, MAT.Pavement, "solid")
	aabb(f, "GroundCanalNorth", -112, -10, -340, -96, 0, -188, C.ground, MAT.Pavement, "solid")
	aabb(f, "GroundCanalSouth", -112, -10, 188, -96, 0, 340, C.ground, MAT.Pavement, "solid")
	-- zone surfaces (top y = 0.05, never overlapping each other)
	aabb(f, "MarketCobbles", -40, -0.25, -112, 40, 0.05, -50, C.cobble, MAT.Cobblestone, "solid")
	aabb(f, "IncidentConcrete", -84, -0.25, 56, 74, 0.05, 186, C.incidentGround, MAT.Concrete, "solid")
	aabb(f, "PromenadeEast", -96, -0.25, -186, -84, 0.05, 186, C.promenade, MAT.Slate, "solid")
	aabb(f, "PromenadeWest", -122, -0.25, -186, -112, 0.05, 186, C.promenade, MAT.Slate, "solid")
	aabb(f, "ParkLawn", -184, -0.25, -120, -122, 0.05, 120, C.lawn, MAT.Grass, "solid")
	aabb(f, "ParkPath", -148, -0.2, -3.5, -121, 0.1, 3.5, C.path, MAT.Cobblestone, "solid")
	-- street
	aabb(f, "Road", 84, -0.25, -186, 112, 0.05, 186, C.asphalt, MAT.Asphalt, "solid")
	aabb(f, "SidewalkWest", 74, -0.2, -186, 83.4, 0.5, 186, C.sidewalk, MAT.Concrete, "solid")
	aabb(f, "CurbWest", 83.4, -0.2, -186, 84, 0.55, 186, C.curb, MAT.Granite, "solid")
	aabb(f, "CurbEast", 112, -0.2, -186, 112.6, 0.55, 186, C.curb, MAT.Granite, "solid")
	aabb(f, "SidewalkEast", 112.6, -0.2, -186, 124, 0.5, 186, C.sidewalk, MAT.Concrete, "solid")
	return g
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ZONE: central sparring plaza
-- ─────────────────────────────────────────────────────────────────────────────

local PLAZA_TOP = 1.2 -- top of the stone plaza floor (outer ring)
local PLAZA_INNER_TOP = 1.3 -- top of the inner disc inside the gold inlay

local function lanternUpper(f: Instance, U: CFrame, withShaft: boolean, lit: boolean)
	-- U: local frame, local +Y = pillar axis, origin = bottom of the shaft (or deck when no shaft)
	local y = 0
	if withShaft then
		local s = Instance.new("Part")
		s.Shape = Enum.PartType.Cylinder
		setup(s, f, "LanternShaft", V3(4, 1.5, 1.5), U * CF(0, 2, 0) * UPRIGHT, C.stone, MAT.Granite, "solid")
		y = 4
	end
	box(f, "LanternDeck", V3(3.0, 0.6, 3.0), U * CF(0, y + 0.3, 0), C.stoneLight, MAT.Granite, "solid")
	box(f, "LanternFirebox", V3(2.2, 2.2, 2.2), U * CF(0, y + 1.7, 0), C.stone, MAT.Granite, "solid")
	local glowColor = if lit then C.neonWarm else rgb(34, 30, 28)
	local glowMat = if lit then MAT.Neon else MAT.Slate
	local glow = box(f, "LanternGlow", V3(2.3, 1.1, 1.1), U * CF(0, y + 1.75, 0), glowColor, glowMat, "tiny")
	box(f, "LanternGlow", V3(1.1, 1.1, 2.3), U * CF(0, y + 1.75, 0), glowColor, glowMat, "tiny")
	box(f, "LanternRoof", V3(3.8, 0.5, 3.8), U * CF(0, y + 3.05, 0), C.stoneDark, MAT.Granite, "solid")
	box(f, "LanternRoofCap", V3(2.3, 0.7, 2.3), U * CF(0, y + 3.6, 0) * ANG(0, rad(45), 0), C.stoneDark, MAT.Granite, "solid")
	ball(f, "LanternFinial", 0.9, (U * CF(0, y + 4.3, 0)).Position, C.stoneLight, MAT.Granite, "tiny")
	if lit then
		pointLight(glow, 16, 1.2, rgb(255, 170, 90))
	end
end

local function stoneLantern(f: Instance, brk: Instance, a: number, state: string)
	local r = 44
	local x, z = math.cos(a) * r, math.sin(a) * r
	local y0 = PLAZA_TOP
	local base = CF(x, y0, z) * ANG(0, -a, 0)
	box(f, "LanternPlinth", V3(3.4, 1.0, 3.4), base * CF(0, 0.5, 0), C.stoneLight, MAT.Granite, "solid")
	box(f, "LanternPlinthTop", V3(2.6, 0.6, 2.6), base * CF(0, 1.3, 0), C.stone, MAT.Granite, "solid")
	-- tangent direction (to lay broken pieces along the ring, away from the fighting line)
	local tangent = V3(-math.sin(a), 0, math.cos(a))
	local outward = V3(math.cos(a), 0, math.sin(a))
	if state == "intact" then
		lanternUpper(f, base * CF(0, 1.6, 0), true, true)
	elseif state == "topple" then
		local s = Instance.new("Part")
		s.Shape = Enum.PartType.Cylinder
		setup(s, f, "LanternShaftStub", V3(1.8, 1.5, 1.5), base * CF(0, 2.5, 0) * UPRIGHT, C.stone, MAT.Granite, "solid")
		box(f, "LanternShard", V3(0.9, 0.5, 1.2), base * CF(0.2, 3.5, 0) * ANG(rad(20), rad(35), rad(15)), C.stone, MAT.Granite, "tiny")
		local p = V3(x, y0, z) + tangent * 3.4 + outward * 0.6
		local yaw = math.atan2(-tangent.Z, tangent.X)
		lanternUpper(f, CF(p.X, y0 + 1.9, p.Z) * ANG(0, yaw, 0) * ANG(rad(12), 0, rad(-90)), false, false)
		local q = V3(x, y0, z) - tangent * 3.4 - outward * 2.6
		rubbleChunk(brk, q.X, PLAZA_INNER_TOP, q.Z, V3(1.8, 1.0, 1.5), C.stone)
	else -- snapped: the whole column lies on the plaza
		local s = Instance.new("Part")
		s.Shape = Enum.PartType.Cylinder
		setup(s, f, "LanternShaftStub", V3(1.0, 1.5, 1.5), base * CF(0, 2.1, 0) * UPRIGHT, C.stone, MAT.Granite, "solid")
		local p = V3(x, y0, z) - tangent * 1.6
		local dir = -tangent
		local yaw = math.atan2(-dir.Z, dir.X)
		lanternUpper(f, CF(p.X, y0 + 1.9, p.Z) * ANG(0, yaw, 0) * ANG(rad(-8), 0, rad(-90)), true, false)
		local q = V3(x, y0, z) + tangent * 3.2 - outward * 3.2
		rubbleChunk(brk, q.X, PLAZA_INNER_TOP, q.Z, V3(2.2, 1.1, 1.6), C.stone)
	end
end

local function buildPlaza(root: Instance, brk: Instance)
	local f = folder(root, "Plaza")
	cyl(f, "PlazaStepOuter", 104, 1.4, V3(0, -0.3, 0), C.stoneLight, MAT.Granite, "solid") -- top 0.4
	cyl(f, "PlazaStepInner", 98, 1.4, V3(0, 0.1, 0), C.stone, MAT.Granite, "solid") -- top 0.8
	cyl(f, "PlazaFloor", 92, 1.4, V3(0, 0.5, 0), C.paving, MAT.Slate, "solid") -- top 1.2
	cyl(f, "GoldInlayRing", 85.6, 0.3, V3(0, 1.1, 0), C.gold, MAT.Metal, "solid") -- top 1.25
	cyl(f, "PlazaInnerFloor", 84, 0.3, V3(0, 1.15, 0), C.pavingInner, MAT.Slate, "solid") -- top 1.3

	-- dragon-scale paving: overlapping rows of flat discs; inner rows sit on top so the
	-- outer rows read as scallops. A two-armed golden spiral winds through the scales.
	local scales = folder(f, "DragonScales")
	local rows = { 38, 35, 32, 29, 26 }
	for k, r in rows do
		local n = math.floor(2 * math.pi * r / 5.0 + 0.5)
		local top = PLAZA_INNER_TOP + 0.03 * k
		local offset = if k % 2 == 0 then 0.5 else 0
		for i = 0, n - 1 do
			local a = (i + offset) / n * 2 * math.pi
			local phase = (a + k * 0.38) % math.pi
			local col: Color3
			if phase < 0.5 then
				col = jitter(C.scaleGold, 8)
			elseif k % 2 == 0 then
				col = jitter(C.scaleA, 6)
			else
				col = jitter(C.scaleB, 6)
			end
			cyl(scales, "Scale", 4.9, 0.1, V3(math.cos(a) * r, top - 0.05, math.sin(a) * r), col, MAT.Slate, "tiny")
		end
	end

	-- centre medallion with 8 gold rays
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		local d = V3(math.cos(a), 0, math.sin(a))
		local mid = d * 17 + V3(0, PLAZA_INNER_TOP - 0.01, 0)
		box(f, "GoldRay", V3(0.45, 0.1, 14), lookAt(mid, mid + d), C.gold, MAT.Metal, "tiny")
	end
	cyl(f, "MedallionRim", 20, 0.2, V3(0, 1.27, 0), C.gold, MAT.Metal, "tiny")
	local med = cyl(f, "Medallion", 18.4, 0.2, V3(0, 1.31, 0), C.lacquerDark, MAT.SmoothPlastic, "tiny")
	med.Reflectance = 0.06
	local emblem = box(f, "MedallionEmblem", V3(14, 0.05, 14), CF(0, 1.44, 0) * ANG(0, math.pi, 0), C.gold, MAT.SmoothPlastic, "ghost")
	surfaceText(emblem, Enum.NormalId.Top, 30, nil, oneLine("龍", C.gold), 0.5, 1.1)

	-- lin's golden chi motes drifting above the medallion
	local moteSource = box(f, "ChiMotes", V3(24, 0.2, 24), CF(0, 1.6, 0), C.gold, MAT.SmoothPlastic, "ghost")
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "GoldenChi"
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Rate = 5
	pe.Lifetime = NumberRange.new(5, 8)
	pe.Speed = NumberRange.new(0.4, 1.2)
	pe.SpreadAngle = Vector2.new(25, 25)
	pe.Acceleration = V3(0, 0.25, 0)
	pe.Color = ColorSequence.new(rgb(255, 214, 120), rgb(232, 160, 60))
	pe.LightEmission = 1
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = moteSource

	-- four stone lantern pillars on the ring (two survived, two broken)
	stoneLantern(f, brk, rad(45), "intact") -- SE
	stoneLantern(f, brk, rad(135), "topple") -- SW (incident side)
	stoneLantern(f, brk, rad(225), "intact") -- NW
	stoneLantern(f, brk, rad(315), "snapped") -- NE

	-- golden ginkgo planters on the east / west flanks
	ginkgoPlanter(f, -70, -26)
	ginkgoPlanter(f, -70, 28)
	ginkgoPlanter(f, 63, -34)
	ginkgoPlanter(f, 63, 36)

	-- hairline cracks spilling from the incident side onto the plaza steps
	for i = 1, 5 do
		local a = rad(70 + i * 9 + rr(-3, 3))
		local r0 = 46.5
		local p0 = V3(math.cos(a) * r0, 0.83, math.sin(a) * r0)
		local p1 = V3(math.cos(a + rr(-0.04, 0.04)) * 48.8, 0.83, math.sin(a + rr(-0.04, 0.04)) * 48.8)
		box(f, "Crack", V3(0.2, 0.04, (p1 - p0).Magnitude), lookAt((p0 + p1) / 2, p1), rgb(40, 36, 34), MAT.Slate, "tiny")
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ZONE NORTH: 林記麵館 and the night-market lane
-- ─────────────────────────────────────────────────────────────────────────────

local function buildNoodleShop(root: Instance, brk: Instance)
	local f = folder(root, "NoodleShop_LinJi")

	-- building masses
	aabb(f, "ShopUpperBody", -20, 14, -150, 20, 31, -112.6, C.brick, MAT.Brick, "solid")
	aabb(f, "ShopRearBody", -20, 0, -150, 20, 14, -132, C.brick, MAT.Brick, "solid")
	aabb(f, "ShopAnnex", -20, 0, -186, 20, 22, -150, C.brickDark, MAT.Brick, "solid")
	aabb(f, "ShopWallWest", -20, 0, -132, -19, 14, -112.6, C.brick, MAT.Brick, "solid")
	aabb(f, "ShopWallEast", 19, 0, -132, 20, 14, -112.6, C.brick, MAT.Brick, "solid")
	aabb(f, "ShopFloor", -19, 0, -132, 19, 0.6, -112.6, C.woodLight, MAT.WoodPlanks, "solid")
	aabb(f, "ShopThreshold", -20.6, 0, -112.6, 20.6, 0.6, -111.4, C.stoneLight, MAT.Granite, "solid")
	aabb(f, "ShopCeiling", -19, 13, -132, 19, 14, -112.6, C.woodDark, MAT.Wood, "solid")

	-- open front: lacquered columns, lintel, gold trim
	for _, x in { -19.4, -7, 7, 19.4 } do
		box(f, "FrontColumn", V3(1.6, 11.8, 1.6), CF(x, 0.6 + 5.9, -112.1), C.lacquer, MAT.SmoothPlastic, "solid")
		box(f, "ColumnBase", V3(2.2, 0.8, 2.2), CF(x, 1.0, -112.1), C.stoneLight, MAT.Granite, "solid")
	end
	aabb(f, "Lintel", -20.6, 12.4, -113, 20.6, 14, -111.2, C.woodDark, MAT.Wood, "solid")
	aabb(f, "LintelGoldTrim", -20.6, 12.2, -111.35, 20.6, 12.45, -111.1, C.gold, MAT.Metal, "tiny")

	-- noren curtains in the doorway (two of them carry characters)
	local norenText = { "", "林", "麵", "" }
	for i, x in { -5.2, -1.75, 1.75, 5.2 } do
		local n = box(f, "Noren", V3(3.3, 4.2, 0.08), CF(x, 10.3, -111.45), C.indigo, MAT.Fabric, "tiny")
		if norenText[i] ~= "" then
			surfaceText(n, Enum.NormalId.Back, 30, nil, { { text = norenText[i], color = C.white, y = 0.12, h = 0.5 } }, 0.8)
		end
	end

	-- counter, stools, bowls
	aabb(f, "Counter", -15, 0.6, -122, 15, 4.2, -119.6, C.woodDark, MAT.Wood, "solid")
	aabb(f, "CounterFront", -15, 0.9, -119.6, 15, 3.9, -119.4, C.lacquer, MAT.SmoothPlastic, "deco")
	aabb(f, "CounterGoldStrip", -15, 3.55, -119.45, 15, 3.75, -119.3, C.gold, MAT.Metal, "tiny")
	aabb(f, "CounterTop", -15.4, 4.2, -122.3, 15.4, 4.6, -119.2, C.woodLight, MAT.WoodPlanks, "solid")
	for _, x in { -12.5, -7.5, -2.5, 2.5, 7.5, 12.5 } do
		bpart(brk, "CounterStool", V3(2.45, 1.6, 1.6), CF(x, 0.6 + 1.225, -117.4) * UPRIGHT, C.lacquer, MAT.SmoothPlastic, Enum.PartType.Cylinder)
	end
	for _, x in { -10, 0.5, 9.5 } do
		for k = 0, 2 do
			cyl(f, "Bowl", 1.2, 0.32, V3(x, 4.6 + 0.16 + k * 0.32, -120.8), C.white, MAT.SmoothPlastic, "tiny")
		end
		cyl(f, "BowlRim", 1.25, 0.06, V3(x, 4.6 + 0.93, -120.8), rgb(40, 70, 150), MAT.SmoothPlastic, "tiny")
	end
	cyl(f, "ChopstickCup", 0.5, 0.9, V3(-5.5, 5.05, -120.6), C.woodDark, MAT.Wood, "tiny")
	cyl(f, "ChiliJar", 0.6, 0.8, V3(4.5, 5.0, -120.6), rgb(170, 30, 20), MAT.Glass, "tiny")

	-- kitchen: stove + the big red noodle pot
	aabb(f, "Stove", -7, 0.6, -130.6, 4, 3.6, -126, C.brickDark, MAT.Brick, "solid")
	aabb(f, "StoveFire", -4.8, 1.3, -126.1, 0.8, 1.9, -125.9, rgb(255, 120, 40), MAT.Neon, "tiny")
	cyl(f, "NoodlePot", 4.4, 3.4, V3(-2, 5.3, -128.3), rgb(172, 34, 26), MAT.Metal, "solid")
	cyl(f, "NoodlePotRim", 4.7, 0.3, V3(-2, 6.95, -128.3), C.gold, MAT.Metal, "tiny")
	cyl(f, "NoodleBroth", 4.1, 0.1, V3(-2, 6.9, -128.3), rgb(230, 196, 128), MAT.SmoothPlastic, "tiny")
	cyl(f, "SoupPot", 2.6, 2.2, V3(2.2, 4.7, -128.2), C.metal, MAT.Metal, "solid")

	-- shelves with jars on the back wall
	for _, sx in { -12, 12 } do
		for _, y in { 6.0, 8.6 } do
			box(f, "Shelf", V3(8, 0.25, 1.2), CF(sx, y, -131.4), C.woodDark, MAT.Wood, "tiny")
			for j = -1, 1 do
				local jc = if j == -1 then rgb(120, 70, 40) elseif j == 0 then C.jade else rgb(220, 200, 160)
				cyl(f, "Jar", 0.9, 1.2, V3(sx + j * 2.4, y + 0.72, -131.4), jc, MAT.Glass, "tiny")
			end
		end
	end
	-- menu plaques
	local menu = { "牛\n肉\n麵", "餛\n飩", "炸\n醬\n麵", "小\n籠\n包", "拉\n麵" }
	for i, text in menu do
		local x = -4.8 + (i - 1) * 2.4
		local p = box(f, "MenuPlaque", V3(2.0, 4.0, 0.2), CF(x, 10.2, -131.9), C.woodLight, MAT.Wood, "tiny")
		surfaceText(p, Enum.NormalId.Back, 40, nil, { { text = text, color = rgb(40, 20, 10), y = 0.05, h = 0.9 } }, 0.8)
	end
	-- hanging lamps inside
	for i, x in { -8, 8 } do
		rod(f, "LampCord", V3(x, 13, -121), V3(x, 12, -121), 0.08, C.black, MAT.Fabric, "tiny")
		local lamp = ball(f, "HangingLamp", 1.1, V3(x, 11.5, -121), C.neonWarm, MAT.Neon, "tiny")
		if i == 1 then
			pointLight(lamp, 22, 1.3, rgb(255, 170, 100))
		end
	end

	-- first-floor canopy (tiled) with red eave beam and two big lanterns
	wedge(f, "Canopy", V3(44, 2.8, 6.8), CF(0, 15.4, -109.2) * ANG(0, math.pi, 0), C.tile, MAT.Slate, "solid")
	aabb(f, "CanopyEave", -22.2, 13.5, -106.2, 22.2, 14.2, -105.6, C.lacquer, MAT.SmoothPlastic, "deco")
	for _, x in { -17.5, 17.5 } do
		hangingLantern(f, V3(x, 13.5, -106.6), 2.4, true, 14)
		rod(f, "LanternTassel", V3(x, 10.5, -106.6), V3(x, 9.4, -106.6), 0.2, C.lanternRed, MAT.Fabric, "tiny")
	end

	-- the sign board
	local sign = aabb(f, "ShopSign", -14, 17.5, -112.6, 14, 22.5, -111.9, C.lacquerDark, MAT.SmoothPlastic, "solid")
	aabb(f, "SignFrameTop", -14.4, 22.5, -112.6, 14.4, 22.9, -111.8, C.gold, MAT.Metal, "deco")
	aabb(f, "SignFrameBottom", -14.4, 17.1, -112.6, 14.4, 17.5, -111.8, C.gold, MAT.Metal, "deco")
	aabb(f, "SignFrameLeft", -14.4, 17.5, -112.6, -14, 22.5, -111.8, C.gold, MAT.Metal, "tiny")
	aabb(f, "SignFrameRight", 14, 17.5, -112.6, 14.4, 22.5, -111.8, C.gold, MAT.Metal, "tiny")
	surfaceText(sign, Enum.NormalId.Back, 40, C.lacquerDark, {
		{ text = "林記麵館", color = C.gold, y = 0.04, h = 0.64, font = Enum.Font.Antique, stroke = rgb(60, 10, 10) },
		{ text = "린 씨네 국숫집", color = C.goldPale, y = 0.70, h = 0.25, font = Enum.Font.Antique },
	}, 0.25, 1.6)

	-- upper floor: lit lattice windows, red columns, jade bracket band
	for _, xc in { -12, 0, 12 } do
		aabb(f, "UpperWindow", xc - 3.5, 23.4, -112.6, xc + 3.5, 27.6, -112.45, C.windowWarm, MAT.Neon, "deco")
		aabb(f, "WindowSill", xc - 3.8, 23.0, -112.6, xc + 3.8, 23.4, -112.0, C.woodDark, MAT.Wood, "tiny")
		for _, dx in { -1.2, 1.2 } do
			aabb(f, "Lattice", xc + dx - 0.12, 23.4, -112.45, xc + dx + 0.12, 27.6, -112.3, C.woodDark, MAT.Wood, "tiny")
		end
		aabb(f, "Lattice", xc - 3.5, 25.4, -112.45, xc + 3.5, 25.65, -112.3, C.woodDark, MAT.Wood, "tiny")
	end
	aabb(f, "UpperColumnWest", -20.4, 14, -112.9, -18.8, 31, -111.9, C.lacquer, MAT.SmoothPlastic, "solid")
	aabb(f, "UpperColumnEast", 18.8, 14, -112.9, 20.4, 31, -111.9, C.lacquer, MAT.SmoothPlastic, "solid")
	aabb(f, "BracketBand", -18.8, 29.2, -112.9, 18.8, 31, -112.3, C.jade, MAT.SmoothPlastic, "deco")
	aabb(f, "BracketGold", -18.8, 29.0, -112.35, 18.8, 29.25, -112.15, C.gold, MAT.Metal, "tiny")

	-- roof: tiled gable with gold ridge and upturned corners
	aabb(f, "RoofEaveSlab", -24, 31, -154, 24, 31.8, -108.5, C.tile, MAT.Slate, "solid")
	aabb(f, "RoofFascia", -24.2, 30.8, -108.7, 24.2, 31.9, -108.2, C.lacquer, MAT.SmoothPlastic, "deco")
	wedge(f, "RoofFront", V3(47, 7.4, 22.5), CF(0, 35.5, -119.75) * ANG(0, math.pi, 0), C.tile, MAT.Slate, "solid")
	wedge(f, "RoofBack", V3(47, 7.4, 23), CF(0, 35.5, -142.5), C.tile, MAT.Slate, "solid")
	aabb(f, "RoofRidge", -24.5, 38.6, -131.8, 24.5, 40.2, -130.2, rgb(44, 44, 50), MAT.Slate, "solid")
	aabb(f, "RidgeGold", -24.5, 40.2, -131.3, 24.5, 40.5, -130.7, C.gold, MAT.Metal, "tiny")
	for _, sx in { -1, 1 } do
		box(f, "RidgeDragonTail", V3(1.2, 3.2, 1.4), CF(sx * 24.2, 41.2, -131) * ANG(0, 0, rad(-sx * 25)), C.gold, MAT.Metal, "deco")
		wedge(f, "UpturnedEave", V3(1.2, 1.2, 3.2), CF(sx * 24.4, 32.2, -108.9) * ANG(0, 0, 0), C.lacquer, MAT.SmoothPlastic, "tiny")
	end

	-- A-frame menu board on the street
	for _, s in { -1, 1 } do
		local p = box(f, "MenuBoard", V3(1.8, 3.2, 0.12), CF(-13, 1.6, -109.6 + s * 0.45) * ANG(rad(-s * 14), rad(20), 0), C.woodDark, MAT.Wood, "tiny")
		if s == 1 then
			surfaceText(p, Enum.NormalId.Back, 40, rgb(30, 30, 30), {
				{ text = "今日", color = C.goldPale, y = 0.05, h = 0.25 },
				{ text = "牛肉麵", color = C.white, y = 0.35, h = 0.3 },
				{ text = "소고기 국수", color = C.white, y = 0.7, h = 0.2 },
			}, 0.6)
		end
	end

	-- east alley with back-alley clutter
	aabb(f, "AlleyBackWall", 20, 0, -186, 25, 16, -140, C.brickDark, MAT.Brick, "solid")
	rod(f, "DrainPipe", V3(24.7, 0, -126), V3(24.7, 21, -126), 0.5, C.metal, MAT.Metal, "tiny")
	box(f, "AirCon", V3(2.0, 1.6, 1.2), CF(24.3, 8.5, -131), rgb(200, 200, 196), MAT.SmoothPlastic, "solid")
	for i = 1, 3 do
		ball(f, "TrashBag", 1.4, V3(21.6 + i * 0.7, 0.6, -137.5 + i * 0.3), rgb(24, 24, 28), MAT.SmoothPlastic, "tiny")
	end
	crate(brk, 22.6, 0.05, -131, 3.0, 8)
	crate(brk, 22.6, 3.05, -131.2, 2.4, 22)
end

local function buildNorthRow(root: Instance, brk: Instance)
	local f = folder(root, "NorthShopRow")

	-- W1: 茶館 teahouse (2 storeys + balcony)
	aabb(f, "TeahouseBody", -60, 0, -186, -20, 24, -114, C.plaster, MAT.Concrete, "solid")
	aabb(f, "TeahouseKick", -56, 0, -114.2, -22, 1.2, -113.8, C.woodDark, MAT.Wood, "tiny")
	aabb(f, "TeahouseDoors", -56, 1.2, -114, -22, 9.2, -113.85, rgb(180, 110, 58), MAT.Neon, "deco")
	for i = 0, 6 do
		local x = -56 + i * (34 / 6)
		aabb(f, "DoorFrame", x - 0.25, 1.2, -114.1, x + 0.25, 9.6, -113.7, C.woodDark, MAT.Wood, "tiny")
	end
	aabb(f, "DoorHeader", -56.4, 9.2, -114.3, -21.6, 10.2, -113.6, C.woodDark, MAT.Wood, "deco")
	aabb(f, "TeahouseBalcony", -56, 12.5, -114, -22, 13.3, -109.6, C.woodDark, MAT.WoodPlanks, "solid")
	aabb(f, "BalconyRail", -56, 15.4, -109.9, -22, 15.7, -109.6, C.lacquer, MAT.Wood, "tiny")
	for i = 0, 8 do
		local x = -56 + i * (34 / 8)
		aabb(f, "BalconyBaluster", x - 0.12, 13.3, -109.85, x + 0.12, 15.4, -109.65, C.lacquer, MAT.Wood, "tiny")
	end
	for _, x in { -50, -39, -28 } do
		aabb(f, "TeahouseWindow", x - 3, 15, -114, x + 3, 21, -113.85, C.windowWarm, MAT.Neon, "deco")
		aabb(f, "WindowLattice", x - 0.15, 15, -113.85, x + 0.15, 21, -113.7, C.woodDark, MAT.Wood, "tiny")
	end
	aabb(f, "TeahouseCornice", -60, 23.2, -115, -20, 24.6, -113.4, C.jade, MAT.SmoothPlastic, "solid")
	local blade = aabb(f, "TeaBladeSign", -21.4, 14.5, -113.6, -21.0, 22.0, -110.6, C.lacquerDark, MAT.SmoothPlastic, "deco")
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		surfaceText(blade, face, 40, C.lacquerDark, { { text = "茶\n館", color = C.gold, y = 0.05, h = 0.9 } }, 0.3, 1.5)
	end
	rod(f, "LanternHook", V3(-39, 12.5, -111.4), V3(-39, 11.8, -111.4), 0.1, C.black, MAT.Metal, "tiny")
	hangingLantern(f, V3(-39, 11.8, -111.4), 1.6, true, 12)

	-- W2: 雜貨 sundries (1 storey, flat roof reachable by an external steel stair)
	aabb(f, "SundriesBody", -95, 0, -186, -60, 13, -114, rgb(150, 138, 122), MAT.Concrete, "solid")
	aabb(f, "SundriesShutter", -92, 5, -114, -72, 10.8, -113.8, rgb(128, 130, 132), MAT.CorrodedMetal, "deco")
	aabb(f, "SundriesInterior", -92, 0, -114, -72, 5, -113.9, rgb(28, 26, 26), MAT.SmoothPlastic, "tiny")
	local band = aabb(f, "SundriesSign", -94, 10.9, -114, -62, 12.7, -113.5, rgb(28, 40, 90), MAT.SmoothPlastic, "deco")
	surfaceText(band, Enum.NormalId.Back, 30, rgb(28, 40, 90), oneLine("雜貨  ·  잡화점", C.white, Enum.Font.Antique), 0.3)
	-- roof parapet with a gap where the stair arrives
	aabb(f, "Parapet", -95, 13, -115, -88, 14.2, -114, rgb(140, 128, 112), MAT.Concrete, "solid")
	aabb(f, "Parapet", -82, 13, -115, -60, 14.2, -114, rgb(140, 128, 112), MAT.Concrete, "solid")
	aabb(f, "Parapet", -61, 13, -150, -60, 14.2, -115, rgb(140, 128, 112), MAT.Concrete, "solid")
	aabb(f, "Parapet", -95, 13, -150, -94, 14.2, -115, rgb(140, 128, 112), MAT.Concrete, "solid")
	-- external stair: 13 treads rising westward in front of the facade
	for i = 1, 13 do
		local x = -62 - 1.5 * (i - 0.5)
		box(f, "StairTread", V3(1.6, 0.35, 3.8), CF(x, i - 0.175, -112), C.metal, MAT.DiamondPlate, "solid")
	end
	aabb(f, "StairLanding", -88, 12.6, -114, -81.5, 13, -110.2, C.metal, MAT.DiamondPlate, "solid")
	rod(f, "StairStringer", V3(-61.5, 0, -110.15), V3(-81.5, 13, -110.15), 0.5, C.charcoal, MAT.Metal, "tiny", true)
	rod(f, "StairRail", V3(-62, 3.4, -110.2), V3(-88, 16.4, -110.2), 0.2, C.charcoal, MAT.Metal, "tiny")
	for _, t in { 0.0, 0.5, 1.0 } do
		local x = -62 - 19.5 * t
		rod(f, "StairRailPost", V3(x, t * 13, -110.2), V3(x, t * 13 + 3.4, -110.2), 0.2, C.charcoal, MAT.Metal, "tiny")
	end
	-- rooftop clutter
	cyl(f, "RoofWaterTank", 5, 5, V3(-86, 16.5, -150), rgb(110, 116, 120), MAT.Metal, "solid")
	aabb(f, "RoofTankBase", -89, 13, -153, -83, 14, -147, C.concreteDark, MAT.Concrete, "solid")
	aabb(f, "RoofAirCon", -72, 13, -128, -68, 15.4, -125, rgb(200, 200, 196), MAT.SmoothPlastic, "solid")
	aabb(f, "RoofAirCon", -78, 13, -128, -74, 15.4, -125, rgb(200, 200, 196), MAT.SmoothPlastic, "solid")
	rod(f, "LaundryLine", V3(-92, 16, -122), V3(-66, 16, -140), 0.08, C.black, MAT.Fabric, "tiny")
	for i = 1, 4 do
		local t = i / 5
		local p = V3(-92, 16, -122) + V3(26, 0, -18) * t
		box(f, "Laundry", V3(1.6, 2.2, 0.08), CF(p - V3(0, 1.1, 0)) * ANG(0, math.atan2(18, 26), 0), if i % 2 == 0 then C.white else rgb(90, 140, 190), MAT.Fabric, "tiny")
	end

	-- E1: 百草堂 herbal medicine shop
	aabb(f, "HerbalBody", 25, 0, -186, 56, 22, -114, rgb(186, 158, 118), MAT.Concrete, "solid")
	aabb(f, "HerbalWindow", 27, 1, -114, 54, 9, -113.85, rgb(200, 150, 80), MAT.Neon, "deco")
	for i = 0, 4 do
		local x = 27 + i * 6.75
		aabb(f, "HerbalMullion", x - 0.3, 1, -114, x + 0.3, 9, -113.7, C.woodDark, MAT.Wood, "tiny")
	end
	local hs = aabb(f, "HerbalSign", 28, 9.8, -114, 53, 12.6, -113.4, C.jade, MAT.SmoothPlastic, "deco")
	surfaceText(hs, Enum.NormalId.Back, 30, C.jade, {
		{ text = "百草堂", color = C.gold, y = 0.03, h = 0.62 },
		{ text = "한약방", color = C.goldPale, y = 0.66, h = 0.3 },
	}, 0.3, 1.4)
	for _, x in { 31, 40.5, 50 } do
		aabb(f, "HerbalUpperWindow", x - 2.8, 14, -114, x + 2.8, 19, -113.85, rgb(60, 70, 72), MAT.Glass, "deco")
	end
	aabb(f, "HerbalEave", 24.5, 22, -140, 56.5, 22.6, -112.5, C.tile, MAT.Slate, "solid")
	wedge(f, "HerbalRoofFront", V3(32, 5, 13.75), CF(40.5, 25.1, -119.375) * ANG(0, math.pi, 0), C.tile, MAT.Slate, "solid")
	wedge(f, "HerbalRoofBack", V3(32, 5, 13.75), CF(40.5, 25.1, -133.125), C.tile, MAT.Slate, "solid")
	aabb(f, "HerbalRidge", 24.5, 27.2, -126.8, 56.5, 28.2, -125.7, rgb(44, 44, 50), MAT.Slate, "solid")
	local herbBlade = aabb(f, "HerbalBladeSign", 55.2, 12.5, -113.8, 55.6, 20, -110.8, C.jade, MAT.SmoothPlastic, "deco")
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		surfaceText(herbBlade, face, 40, C.jade, { { text = "藥", color = C.gold, y = 0.1, h = 0.8 } }, 0.3, 1.5)
	end

	-- E2: 居酒屋 izakaya (1 storey, truss ladder on its street side)
	aabb(f, "IzakayaBody", 56, 0, -186, 74, 12, -114, C.woodDark, MAT.WoodPlanks, "solid")
	aabb(f, "IzakayaDoor", 60, 0.2, -114, 70, 8.8, -113.88, rgb(200, 132, 70), MAT.Neon, "deco")
	for i, x in { 62, 65, 68 } do
		local n = box(f, "IzakayaNoren", V3(2.8, 3.4, 0.08), CF(x, 7.1, -113.75), rgb(150, 24, 24), MAT.Fabric, "tiny")
		local chars = { "焼", "鳥", "酒" }
		surfaceText(n, Enum.NormalId.Back, 30, nil, { { text = chars[i], color = C.white, y = 0.15, h = 0.6 } }, 0.8)
	end
	aabb(f, "IzakayaEave", 55.5, 10, -114, 74.5, 10.6, -111.8, C.tile, MAT.Slate, "solid")
	aabb(f, "IzakayaParapet", 56, 12, -115, 72, 13, -114, C.woodDark, MAT.Wood, "solid")
	local iz = aabb(f, "IzakayaSign", 57.4, 2.5, -113.6, 59, 9, -113.3, C.white, MAT.SmoothPlastic, "tiny")
	surfaceText(iz, Enum.NormalId.Back, 40, C.white, { { text = "居\n酒\n屋", color = C.black, y = 0.03, h = 0.94 } }, 0.5)
	rod(f, "AkachochinHook", V3(71.5, 10, -113), V3(71.5, 9.2, -113), 0.1, C.black, MAT.Metal, "tiny")
	hangingLantern(f, V3(71.5, 9.2, -113), 2.2, true, 12)
	truss(f, "IzakayaLadder", 12, V3(75, 6, -118), C.metal)
	local roofSign = aabb(f, "RoofSign", 60, 13, -118, 70, 17, -117.4, C.black, MAT.SmoothPlastic, "solid")
	surfaceText(roofSign, Enum.NormalId.Back, 30, C.black, oneLine("やきとり", rgb(255, 80, 60), Enum.Font.GothamBlack), 0, 2)
	rod(f, "RoofSignLeg", V3(61, 12, -117.7), V3(61, 13, -117.7), 0.3, C.metal, MAT.Metal, "tiny")
	rod(f, "RoofSignLeg", V3(69, 12, -117.7), V3(69, 13, -117.7), 0.3, C.metal, MAT.Metal, "tiny")
end

local function buildMarket(root: Instance, brk: Instance)
	local f = folder(root, "NightMarket")

	-- 夜市 paifang gate at the lane entrance
	local gate = folder(f, "MarketGate")
	for _, x in { -16, 16 } do
		box(gate, "GatePillar", V3(1.6, 14, 1.6), CF(x, 7, -57), C.lacquer, MAT.SmoothPlastic, "solid")
		box(gate, "GatePillarBase", V3(2.6, 1.4, 2.6), CF(x, 0.7, -57), C.stoneLight, MAT.Granite, "solid")
	end
	aabb(gate, "GateBeamLower", -18, 10.5, -57.6, 18, 11.5, -56.4, C.lacquer, MAT.SmoothPlastic, "solid")
	aabb(gate, "GateBeamUpper", -19, 14.2, -57.7, 19, 15.2, -56.3, C.lacquer, MAT.SmoothPlastic, "solid")
	aabb(gate, "GateBeamGold", -19, 14.0, -56.35, 19, 14.25, -56.2, C.gold, MAT.Metal, "tiny")
	local plaque = aabb(gate, "GatePlaque", -5, 11.5, -57.3, 5, 14.2, -56.7, C.lacquerDark, MAT.SmoothPlastic, "solid")
	for _, face in { Enum.NormalId.Back, Enum.NormalId.Front } do
		surfaceText(plaque, face, 40, C.lacquerDark, {
			{ text = "夜 市", color = C.gold, y = 0.03, h = 0.66 },
			{ text = "야시장", color = C.goldPale, y = 0.7, h = 0.26 },
		}, 0.25, 1.5)
	end
	wedge(gate, "GateRoofSouth", V3(42, 1.8, 2.8), CF(0, 16.1, -55.6) * ANG(0, math.pi, 0), C.tile, MAT.Slate, "solid")
	wedge(gate, "GateRoofNorth", V3(42, 1.8, 2.8), CF(0, 16.1, -58.4), C.tile, MAT.Slate, "solid")
	aabb(gate, "GateRidge", -21.5, 16.8, -57.4, 21.5, 17.6, -56.6, C.gold, MAT.Metal, "deco")
	for _, x in { -9, 9 } do
		hangingLantern(gate, V3(x, 10.5, -57), 1.5, false)
	end

	-- lantern poles
	local poleZ = { -72, -86, -100 }
	for _, z in poleZ do
		for _, x in { -18, 18 } do
			cyl(f, "LanternPole", 0.8, 14, V3(x, 7, z), C.woodDark, MAT.Wood, "solid")
			box(f, "LanternPoleBase", V3(1.6, 1.0, 1.6), CF(x, 0.55, z), C.stone, MAT.Granite, "solid")
			ball(f, "LanternPoleFinial", 1.0, V3(x, 14.3, z), C.gold, MAT.Metal, "tiny")
		end
	end
	-- cross strings over the lane
	local strings = folder(f, "LanternStrings")
	for _, z in poleZ do
		lanternString(strings, V3(-18, 13.6, z), V3(18, 13.6, z), 2.4, 6, { 2, 5 })
	end
	-- lengthwise strings along both edges: gate -> poles -> noodle shop canopy
	for _, sx in { -1, 1 } do
		local pts = { V3(sx * 16.8, 13.8, -57.2), V3(sx * 18, 13.6, -72), V3(sx * 18, 13.6, -86), V3(sx * 18, 13.6, -100), V3(sx * 18, 13.9, -106.3) }
		for i = 1, #pts - 1 do
			local n = if i == #pts - 1 then 1 else 2
			local lit = if i == 2 then { 1 } else {}
			lanternString(strings, pts[i], pts[i + 1], 1.2, n, lit)
		end
	end

	-- stalls (local frame: LookVector = customer side)
	type StallSpec = { x: number, z: number, awning: Color3, stripe: Color3, goods: string, sign: string, lit: boolean }
	local stalls: { StallSpec } = {
		{ x = -29, z = -65, awning = rgb(170, 40, 36), stripe = C.gold, goods = "skewer", sign = "烤串", lit = false },
		{ x = -29, z = -79, awning = rgb(40, 110, 120), stripe = rgb(232, 218, 190), goods = "dumpling", sign = "小籠包", lit = true },
		{ x = -29, z = -93, awning = rgb(222, 150, 48), stripe = rgb(170, 40, 36), goods = "sweets", sign = "糖葫蘆", lit = false },
		{ x = 29, z = -65, awning = rgb(52, 60, 110), stripe = C.white, goods = "masks", sign = "お面", lit = false },
		{ x = 29, z = -79, awning = rgb(60, 120, 90), stripe = C.gold, goods = "tea", sign = "珍珠奶茶", lit = false },
		{ x = 29, z = -93, awning = rgb(200, 80, 40), stripe = C.white, goods = "takoyaki", sign = "たこ焼き", lit = true },
	}
	for _, s in stalls do
		local m = model(f, "Stall_" .. s.goods)
		local o = lookAt(V3(s.x, 0.05, s.z), V3(0, 0.05, s.z))
		local counter = box(m, "Counter", V3(9, 3.2, 1.8), o * CF(0, 1.6, -1.6), C.wood, MAT.Wood, "solid")
		m.PrimaryPart = counter
		box(m, "CounterTop", V3(9.4, 0.3, 2.2), o * CF(0, 3.35, -1.6), C.woodLight, MAT.WoodPlanks, "solid")
		box(m, "CounterSkirt", V3(8.6, 2.2, 0.1), o * CF(0, 1.5, -2.55), s.stripe, MAT.Fabric, "tiny")
		for _, sx in { -4.4, 4.4 } do
			cyl(m, "StallPost", 0.4, 8.0, (o * CF(sx, 4.0, -2.4)).Position, C.woodDark, MAT.Wood, "solid")
			cyl(m, "StallPost", 0.4, 9.0, (o * CF(sx, 4.5, 2.4)).Position, C.woodDark, MAT.Wood, "solid")
		end
		box(m, "Awning", V3(10, 0.2, 6.6), o * CF(0, 8.4, -0.4) * ANG(rad(-12), 0, 0), s.awning, MAT.Fabric, "solid")
		local val = box(m, "Valance", V3(10, 1.0, 0.12), o * CF(0, 7.2, -3.64), s.stripe, MAT.Fabric, "tiny")
		surfaceText(val, Enum.NormalId.Front, 30, nil, oneLine(s.sign, if s.stripe == C.white or s.stripe == C.gold then rgb(30, 20, 16) else rgb(120, 20, 20), Enum.Font.Antique), 0.6)
		box(m, "BackShelf", V3(9, 5, 1), o * CF(0, 2.5, 2.1), C.wood, MAT.Wood, "solid")
		box(m, "ShelfGoods", V3(1.4, 1.0, 0.9), o * CF(-2.5, 5.5, 2.1), rgb(180, 150, 90), MAT.WoodPlanks, "tiny")
		box(m, "ShelfGoods", V3(1.2, 0.8, 0.9), o * CF(2.8, 5.4, 2.1), rgb(160, 60, 40), MAT.Fabric, "tiny")
		local top = 3.5
		if s.goods == "skewer" then
			box(m, "Grill", V3(3.4, 0.8, 1.3), o * CF(-1.5, top + 0.4, -1.6), C.black, MAT.Metal, "tiny")
			box(m, "GrillCoals", V3(3.1, 0.1, 1.05), o * CF(-1.5, top + 0.82, -1.6), rgb(255, 110, 40), MAT.Neon, "tiny")
			for k = 0, 3 do
				local zz = -2.0 + k * 0.28
				rod(m, "Skewer", (o * CF(-3.0, top + 0.95, zz)).Position, (o * CF(0.0, top + 0.95, zz)).Position, 0.18, rgb(140, 70, 40), MAT.Wood, "tiny")
			end
		elseif s.goods == "dumpling" then
			for _, sx in { -2.5, 1.5 } do
				for k = 0, 2 do
					cyl(m, "Steamer", 1.8, 0.5, (o * CF(sx, top + 0.25 + k * 0.5, -1.6)).Position, rgb(196, 160, 96), MAT.Wood, "tiny")
				end
				cyl(m, "SteamerLid", 1.8, 0.3, (o * CF(sx, top + 1.65, -1.6)).Position, rgb(180, 146, 84), MAT.Wood, "tiny")
			end
		elseif s.goods == "sweets" then
			local bundle = (o * CF(2.5, top + 1.2, -1.6)).Position
			cyl(m, "StrawBundle", 1.0, 2.4, bundle, rgb(206, 176, 110), MAT.Fabric, "tiny")
			for k = 1, 3 do
				local a = k * 2.1
				local base = bundle + V3(0, 1.2, 0)
				local tip = base + V3(math.cos(a) * 0.8, 3.2, math.sin(a) * 0.8)
				rod(m, "Stick", base, tip, 0.1, C.woodLight, MAT.Wood, "tiny")
				for j = 1, 3 do
					ball(m, "Candy", 0.5, base + (tip - base) * (0.45 + j * 0.16), rgb(220, 30, 30), MAT.Glass, "tiny")
				end
			end
		elseif s.goods == "masks" then
			local cols = { C.white, C.gold, C.black, rgb(200, 40, 40), rgb(120, 180, 230) }
			for k = 1, 5 do
				box(m, "Mask", V3(1.1, 1.3, 0.2), o * CF(-3.6 + k * 1.3, 3.7, 1.5), cols[k], MAT.SmoothPlastic, "tiny")
			end
		elseif s.goods == "tea" then
			local cols = { rgb(200, 150, 90), rgb(140, 190, 170), rgb(230, 220, 200) }
			for k = 1, 3 do
				cyl(m, "TeaJar", 1.3, 1.8, (o * CF(-3.6 + k * 1.8, top + 0.9, -1.6)).Position, cols[k], MAT.Glass, "tiny")
			end
			for k = 1, 4 do
				cyl(m, "Cup", 0.5, 0.8, (o * CF(1.6 + k * 0.6, top + 0.4, -2.0)).Position, C.white, MAT.SmoothPlastic, "tiny")
			end
		elseif s.goods == "takoyaki" then
			box(m, "Griddle", V3(4, 0.6, 1.6), o * CF(0, top + 0.3, -1.6), C.black, MAT.Metal, "tiny")
			for k = 0, 7 do
				local gx = -1.5 + (k % 4)
				local gz = -1.85 + math.floor(k / 4) * 0.55
				ball(m, "Takoyaki", 0.5, (o * CF(gx, top + 0.7, gz)).Position, rgb(176, 112, 58), MAT.SmoothPlastic, "tiny")
			end
		end
		if s.lit then
			local bulbPos = (o * CF(0, 7.5, -1.4)).Position
			rod(m, "BulbCord", bulbPos + V3(0, 0.5, 0), bulbPos + V3(0, 0.25, 0), 0.06, C.black, MAT.Fabric, "tiny")
			local bulb = ball(m, "Bulb", 0.6, bulbPos, C.neonWarm, MAT.Neon, "tiny")
			pointLight(bulb, 10, 1.3, rgb(255, 180, 110))
		end
	end

	-- props & breakables around the stalls
	crate(brk, -37.5, 0.05, -72, 3.0, 5)
	crate(brk, -37.4, 3.05, -72.2, 2.6, 30)
	barrel(brk, -37, 0.05, -86, C.wood)
	crate(brk, -37.5, 0.05, -99.5, 3.2, 12)
	crate(brk, 37.5, 0.05, -72, 3.2, 40)
	crate(brk, 37.3, 3.25, -71.8, 2.4, 8)
	barrel(brk, 37, 0.05, -86.5, rgb(130, 50, 40))
	-- dining sets in front of the noodle shop
	diningSet(brk, -13.5, 0.05, -103.5, 2, 20)
	diningSet(brk, 13.5, 0.05, -103.5, 2, 160)
	lanternPost(brk, -22.5, 0.05, -58.5, 90, true)
	lanternPost(brk, 22.5, 0.05, -58.5, -90, false)
end

local function buildNorthYards(root: Instance, brk: Instance)
	local f = folder(root, "NorthYards")
	-- NW yard: outdoor dining and clutter by the sundries stair
	diningSet(brk, -54, 0, -74, 2, 0)
	crate(brk, -66, 0, -106, 3.0, 10)
	crate(brk, -66.2, 3.0, -105.8, 2.4, 55)
	barrel(brk, -46, 0, -104, C.wood)
	barrel(brk, -43.5, 0, -102, rgb(120, 60, 40))
	lanternPost(brk, -80, 0, -70, 45, true)
	kiosk(f, lookAt(V3(-74, 0, -90), V3(0, 0, -90)))
	scooter(f, lookAt(V3(-24.5, 0.05, -108.5), V3(-24.5, 0.05, 0)))
	-- a parasol over the first table (decor pole + canopy; nothing rests on breakables)
	cyl(f, "ParasolPole", 0.3, 8.5, V3(-58.2, 4.25, -77.8), C.woodDark, MAT.Wood, "tiny")
	cyl(f, "ParasolCanopy", 8.5, 0.3, V3(-58.2, 8.4, -77.8), rgb(170, 40, 36), MAT.Fabric, "deco")

	-- NE yard: food cart, crates, barrels
	local cart = model(f, "FoodCart")
	local co = lookAt(V3(52, 0, -80), V3(40, 0, -80))
	local cbody = box(cart, "CartBody", V3(6, 3, 3.2), co * CF(0, 2.6, 0), rgb(160, 40, 34), MAT.SmoothPlastic, "solid")
	cart.PrimaryPart = cbody
	for _, sx in { -2.2, 2.2 } do
		local w = Instance.new("Part")
		w.Shape = Enum.PartType.Cylinder
		setup(w, cart, "CartWheel", V3(0.5, 2.2, 2.2), co * CF(sx, 1.1, 1.7) * ANG(0, math.pi / 2, 0), C.woodDark, MAT.Wood, "solid")
	end
	for _, sx in { -2.8, 2.8 } do
		cyl(cart, "CartPole", 0.25, 4.6, (co * CF(sx, 6.4, 0)).Position, C.woodDark, MAT.Wood, "tiny")
	end
	box(cart, "CartCanopy", V3(7, 0.25, 4.4), co * CF(0, 8.8, 0), rgb(232, 200, 90), MAT.Fabric, "deco")
	local cs = box(cart, "CartSign", V3(5, 1.2, 0.12), co * CF(0, 8.1, -2.2), rgb(232, 200, 90), MAT.Fabric, "tiny")
	surfaceText(cs, Enum.NormalId.Front, 40, nil, oneLine("煎餅果子", rgb(120, 20, 20)), 0.6)
	box(cart, "CartGriddle", V3(4, 0.3, 2.4), co * CF(0, 4.25, 0), C.black, MAT.Metal, "tiny")
	crate(brk, 62, 0, -104, 3.2, 15)
	crate(brk, 62.2, 3.2, -103.8, 2.6, 40)
	crate(brk, 66.5, 0, -104.5, 2.8, 0)
	barrel(brk, 58, 0, -104, C.wood)
	lanternPost(brk, 70, 0, -92, -90, true)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ZONE EAST: street, cars, lamps, bus stop, vending machines, storefronts
-- ─────────────────────────────────────────────────────────────────────────────

type ShopSpec = {
	name: string,
	z0: number,
	z1: number,
	h: number,
	body: Color3,
	mat: Enum.Material,
	glow: Color3,
	sign: string,
	signBg: Color3,
	signFg: Color3,
	awning: Color3?,
	blade: string?,
	bladeBg: Color3?,
	bladeFg: Color3?,
}

local function storefront(f: Instance, s: ShopSpec)
	local m = model(f, "Store_" .. s.name)
	local zc = (s.z0 + s.z1) / 2
	local len = s.z1 - s.z0
	local body = aabb(m, "StoreBody", 124, 0, s.z0, 190, s.h, s.z1, s.body, s.mat, "solid")
	m.PrimaryPart = body
	aabb(m, "StoreWindow", 123.85, 1.0, s.z0 + 2, 124, 8.4, s.z1 - 2, s.glow, MAT.Neon, "deco")
	for k = 1, 3 do
		local z = s.z0 + 2 + k * (len - 4) / 4
		aabb(m, "StoreMullion", 123.6, 1.0, z - 0.3, 124, 8.4, z + 0.3, C.charcoal, MAT.Metal, "deco")
	end
	if s.awning then
		box(m, "StoreAwning", V3(4.2, 0.2, len - 3), CF(122, 9.6, zc) * ANG(0, 0, rad(16)), s.awning, MAT.Fabric, "deco")
	end
	local sign = aabb(m, "StoreSign", 123.3, 10.6, s.z0 + 1, 124, 13.4, s.z1 - 1, s.signBg, MAT.SmoothPlastic, "deco")
	surfaceText(sign, Enum.NormalId.Left, 24, s.signBg, oneLine(s.sign, s.signFg, Enum.Font.GothamBold), 0.2, 1.8)
	-- upper floors: window ribbons with a few lit patches
	local yb = 15
	while yb + 5 <= s.h - 1.5 do
		aabb(m, "StoreUpperGlass", 123.8, yb, s.z0 + 2, 124, yb + 4.2, s.z1 - 2, C.glassDark, MAT.Glass, "deco")
		if rnd() < 0.7 then
			local w = rr(5, math.min(16, len * 0.4))
			local za = rr(s.z0 + 3, s.z1 - 3 - w)
			aabb(m, "StoreLitWindow", 123.72, yb + 0.3, za, 123.8, yb + 3.9, za + w, C.windowWarm, MAT.Neon, "tiny")
		end
		yb += 7
	end
	aabb(m, "StoreCornice", 123.4, s.h - 0.8, s.z0, 124, s.h, s.z1, C.charcoal, MAT.Concrete, "deco")
	if s.blade then
		local bh = math.min(12, s.h - 16)
		if bh >= 6 then
			local bs = box(m, "BladeSign", V3(3.0, bh, 0.6), CF(121.8, 15 + bh / 2, s.z0 + 4), s.bladeBg or C.black, MAT.SmoothPlastic, "deco")
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				surfaceText(bs, face, 30, s.bladeBg or C.black, { { text = s.blade, color = s.bladeFg or C.white, y = 0.03, h = 0.94, font = Enum.Font.GothamBlack } }, 0, 2.2)
			end
			aabb(m, "BladeBracket", 123.3, 15 + bh - 0.6, s.z0 + 3.8, 124, 15 + bh - 0.2, s.z0 + 4.2, C.metal, MAT.Metal, "tiny")
		end
	end
	-- rooftop clutter
	aabb(m, "RoofUnit", 140, s.h, zc - 3, 146, s.h + 3, zc + 3, rgb(170, 170, 166), MAT.Metal, "solid")
end

local function streetLamp(f: Instance, x: number, z: number, lit: boolean, tilt: number?)
	local base = CF(x, 0.5, z) * ANG(0, 0, rad(tilt or 0))
	box(f, "LampBase", V3(1.4, 1.0, 1.4), CF(x, 1.0, z), C.charcoal, MAT.Metal, "solid")
	local pole = Instance.new("Part")
	pole.Shape = Enum.PartType.Cylinder
	setup(pole, f, "LampPole", V3(16, 0.7, 0.7), base * CF(0, 8, 0) * UPRIGHT, C.charcoal, MAT.Metal, "solid")
	box(f, "LampArm", V3(4.4, 0.35, 0.35), base * CF(2.0, 15.8, 0), C.charcoal, MAT.Metal, "tiny")
	box(f, "LampHead", V3(2.4, 0.5, 1.2), base * CF(4.2, 15.6, 0), C.charcoal, MAT.Metal, "tiny")
	local glow = box(f, "LampGlow", V3(2.0, 0.1, 0.9), base * CF(4.2, 15.3, 0), if lit then C.lampWhite else rgb(60, 60, 60), if lit then MAT.Neon else MAT.Glass, "tiny")
	if lit then
		pointLight(glow, 26, 1.1, rgb(255, 214, 160))
	end
end

local function utilityPole(f: Instance, x: number, z: number): { Vector3 }
	cyl(f, "UtilityPole", 1.0, 22, V3(x, 11.5, z), rgb(150, 148, 142), MAT.Concrete, "solid")
	box(f, "Crossarm", V3(0.4, 0.4, 5), CF(x, 19.5, z), C.charcoal, MAT.Metal, "tiny")
	return { V3(x, 19.8, z - 2.2), V3(x, 19.8, z + 2.2) }
end

local function buildEast(root: Instance, brk: Instance)
	local f = folder(root, "EastStreet")

	-- road markings
	local marks = folder(f, "RoadMarkings")
	for _, zr in { { -186, -7 }, { 7, 186 } } do
		for _, x in { 97.7, 98.3 } do
			aabb(marks, "CenterLine", x - 0.15, -0.02, zr[1], x + 0.15, 0.08, zr[2], rgb(230, 180, 40), MAT.SmoothPlastic, "tiny")
		end
		for _, x in { 85.1, 110.9 } do
			aabb(marks, "EdgeLine", x - 0.15, -0.02, zr[1], x + 0.15, 0.08, zr[2], C.white, MAT.SmoothPlastic, "tiny")
		end
	end
	for _, x in { 91.4, 104.6 } do
		local z = -180
		while z < 180 do
			if z + 7 < -8 or z > 8 then
				aabb(marks, "LaneDash", x - 0.15, -0.02, z, x + 0.15, 0.08, z + 7, C.white, MAT.SmoothPlastic, "tiny")
			end
			z += 20
		end
	end
	for i = 0, 8 do
		local x = 86.2 + i * 2.95
		aabb(marks, "Crosswalk", x - 0.8, -0.02, -6, x + 0.8, 0.08, 6, C.white, MAT.SmoothPlastic, "tiny")
	end

	-- street lamps (west sidewalk + one on the east sidewalk); the one near the incident is bent and dead
	local lamps = folder(f, "StreetLamps")
	for _, z in { -150, -85, -30, 55 } do
		streetLamp(lamps, 76.8, z, true)
	end
	streetLamp(lamps, 76.8, 128, false, -9)

	-- utility poles & sagging wires on the east sidewalk
	local wires = folder(f, "UtilityPoles")
	local tops: { { Vector3 } } = {}
	for _, z in { -150, -70, 10, 90 } do
		table.insert(tops, utilityPole(wires, 114.2, z))
	end
	for i = 1, #tops - 1 do
		for j = 1, 2 do
			local a, b = tops[i][j], tops[i + 1][j]
			local segs = 4
			for s = 0, segs - 1 do
				local function at(t: number): Vector3
					return a + (b - a) * t - V3(0, 2.2 * 4 * t * (1 - t), 0)
				end
				rod(wires, "Wire", at(s / segs), at((s + 1) / segs), 0.08, C.black, MAT.Fabric, "tiny")
			end
		end
	end
	cyl(wires, "Transformer", 1.5, 2.4, V3(115.2, 16.5, -70), rgb(130, 132, 128), MAT.Metal, "tiny")

	-- parked cars
	local cars = folder(f, "Cars")
	car(cars, lookAt(V3(88.8, 0.05, -128), V3(88.8, 0.05, -200)), rgb(236, 236, 230), "kei")
	car(cars, lookAt(V3(107.2, 0.05, -60), V3(107.2, 0.05, 100)), rgb(186, 30, 34), "taxi")
	car(cars, lookAt(V3(107.2, 0.05, 62), V3(107.2, 0.05, 200)), rgb(40, 60, 110), "sedan")
	crushedCar(cars, 99, 146, 32)
	-- slab that landed on the crushed car
	box(cars, "FallenSlab", V3(10, 1.4, 7), CF(103.5, 3.2, 150) * ANG(rad(6), rad(20), rad(24)), C.concrete, MAT.Concrete, "solid")

	-- bus stop on the west sidewalk
	local bus = folder(f, "BusStop")
	aabb(bus, "ShelterBack", 74.6, 1.5, 22.5, 74.9, 8.5, 33.5, rgb(170, 200, 210), MAT.Glass, "deco").Transparency = 0.45
	for _, z in { 22.3, 33.7 } do
		for _, x in { 74.75, 80.8 } do
			cyl(bus, "ShelterPost", 0.35, 8.6, V3(x, 4.8, z), C.charcoal, MAT.Metal, "solid")
		end
	end
	aabb(bus, "ShelterRoof", 74.2, 9.0, 21.8, 81.6, 9.4, 34.2, C.charcoal, MAT.Metal, "solid")
	local roofGlow = aabb(bus, "ShelterLight", 75.5, 8.9, 24, 80, 9.0, 32, C.lampWhite, MAT.Neon, "tiny")
	pointLight(roofGlow, 12, 0.9, rgb(255, 230, 190))
	local ad = aabb(bus, "ShelterAd", 74.6, 1.5, 33.6, 79.8, 8.2, 33.9, rgb(40, 20, 16), MAT.SmoothPlastic, "deco")
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		surfaceText(ad, face, 30, C.lacquerDark, {
			{ text = "林記麵館", color = C.gold, y = 0.08, h = 0.3 },
			{ text = "→ 夜市", color = C.goldPale, y = 0.42, h = 0.2 },
			{ text = "since 1987", color = C.goldPale, y = 0.72, h = 0.12, font = Enum.Font.Garamond },
		}, 0.2, 1.5)
	end
	aabb(bus, "BenchSeat", 75.3, 2.0, 24, 76.9, 2.4, 32, C.woodLight, MAT.WoodPlanks, "solid")
	aabb(bus, "BenchLegs", 75.6, 0.5, 24.5, 76.6, 2.0, 31.5, C.charcoal, MAT.Metal, "solid")
	rod(bus, "StopSignPole", V3(82.8, 0.5, 20.5), V3(82.8, 8.5, 20.5), 0.25, C.steel, MAT.Metal, "tiny")
	local stopSign = box(bus, "StopSign", V3(0.2, 1.8, 1.8), CF(82.8, 8.6, 20.5), rgb(30, 90, 170), MAT.SmoothPlastic, "tiny")
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right } do
		surfaceText(stopSign, face, 40, rgb(30, 90, 170), {
			{ text = "夜市前", color = C.white, y = 0.12, h = 0.45, font = Enum.Font.GothamBold },
			{ text = "BUS", color = C.white, y = 0.6, h = 0.3, font = Enum.Font.GothamBlack },
		}, 0.3)
	end

	-- vending machines in front of the convenience store (breakable)
	vendingMachine(brk, 120.6, 0.5, -32, rgb(200, 30, 36), false)
	vendingMachine(brk, 120.6, 0.5, -27.8, C.white, true)
	vendingMachine(brk, 120.6, 0.5, -23.6, rgb(40, 90, 180), false)
	trashBin(brk, 121.8, 0.5, -19.6, rgb(60, 110, 70))
	trashBin(brk, 78, 0.5, 38, rgb(90, 96, 100))
	trafficCone(brk, 90, 0.05, 106)
	trafficCone(brk, 102, 0.05, 106)
	crate(brk, 62, 0, 20, 3.0, 25)

	-- storefronts along the east side
	local shops = folder(f, "Storefronts")
	local specs: { ShopSpec } = {
		{ name = "Sento", z0 = -186, z1 = -132, h = 14, body = rgb(170, 150, 120), mat = MAT.Wood, glow = rgb(190, 150, 90), sign = "銭湯  ゆ", signBg = rgb(30, 50, 100), signFg = C.white, awning = rgb(30, 50, 100) },
		{ name = "Ramen", z0 = -130, z1 = -78, h = 22, body = rgb(120, 60, 50), mat = MAT.Brick, glow = rgb(210, 150, 80), sign = "ラーメン 龍", signBg = rgb(170, 30, 30), signFg = C.white, awning = rgb(170, 30, 30), blade = "ら\nー\nめ\nん", bladeBg = rgb(250, 240, 220), bladeFg = rgb(170, 30, 30) },
		{ name = "Konbini", z0 = -76, z1 = -18, h = 12, body = rgb(210, 210, 206), mat = MAT.SmoothPlastic, glow = rgb(215, 235, 250), sign = "コンビニ 24H", signBg = rgb(30, 140, 90), signFg = C.white },
		{ name = "Karaoke", z0 = -16, z1 = 42, h = 30, body = rgb(70, 60, 90), mat = MAT.Concrete, glow = rgb(200, 120, 200), sign = "カラオケ 金灰", signBg = rgb(40, 20, 60), signFg = rgb(255, 120, 220), blade = "カ\nラ\nオ\nケ", bladeBg = rgb(40, 20, 60), bladeFg = rgb(255, 120, 220) },
		{ name = "Pharmacy", z0 = 44, z1 = 98, h = 18, body = rgb(200, 196, 186), mat = MAT.Concrete, glow = rgb(200, 240, 220), sign = "薬局  PHARMACY", signBg = rgb(20, 120, 70), signFg = C.white, awning = rgb(20, 120, 70) },
	}
	for _, s in specs do
		storefront(shops, s)
	end
	-- sento chimney & pharmacy neon cross
	cyl(shops, "SentoChimney", 3.4, 48, V3(162, 24, -160), rgb(130, 70, 56), MAT.Brick, "solid")
	cyl(shops, "SentoChimneyBand", 3.8, 1.2, V3(162, 44, -160), C.charcoal, MAT.Metal, "tiny")
	aabb(shops, "PharmacyCross", 123.4, 14.5, 49.5, 123.8, 17.5, 50.5, rgb(40, 255, 120), MAT.Neon, "tiny")
	aabb(shops, "PharmacyCross", 123.4, 15.5, 48.5, 123.8, 16.5, 51.5, rgb(40, 255, 120), MAT.Neon, "tiny")

	-- damaged office block at the south end (incident spill-over)
	local dmg = model(shops, "Store_Damaged")
	local db = aabb(dmg, "OfficeBody", 124, 0, 128, 190, 26, 186, rgb(118, 116, 112), MAT.Concrete, "solid")
	dmg.PrimaryPart = db
	aabb(dmg, "OfficeLower", 124, 0, 100, 190, 10, 128, rgb(110, 108, 104), MAT.Concrete, "solid")
	aabb(dmg, "OfficeLobby", 123.85, 1, 102, 124, 8, 126, rgb(30, 30, 34), MAT.Glass, "deco")
	for _, y in { 14, 20 } do
		aabb(dmg, "OfficeGlass", 123.8, y, 130, 124, y + 4, 184, C.glassDark, MAT.Glass, "deco")
	end
	aabb(dmg, "OfficeHole", 123.75, 13.5, 131, 123.8, 21, 142, rgb(14, 12, 12), MAT.SmoothPlastic, "tiny")
	box(dmg, "SlidSlab", V3(20, 1.4, 24), CF(140, 17, 118) * ANG(rad(34), 0, rad(4)), C.concrete, MAT.Concrete, "solid")
	local tilted = box(dmg, "TiltedSign", V3(0.5, 2.4, 20), CF(123.4, 11.2, 114) * ANG(rad(7), 0, 0), rgb(40, 40, 44), MAT.SmoothPlastic, "deco")
	surfaceText(tilted, Enum.NormalId.Left, 24, rgb(40, 40, 44), oneLine("金灰ビル", rgb(200, 200, 190), Enum.Font.GothamBold), 0.4)
	box(dmg, "WACATarp", V3(0.2, 14, 16), CF(123.6, 17, 160) * ANG(0, 0, rad(-3)), C.black, MAT.Fabric, "deco")
	rubblePile(dmg, 118, 0.5, 124, 5, 6)
	rubbleChunk(brk, 116, 0.5, 116, V3(2.5, 1.4, 2.0), C.concrete)
	rubbleChunk(brk, 119, 0.5, 132, V3(2.0, 1.2, 3.0), C.concrete)
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ZONE WEST: stone canal, arched bridge, willows, park & pavilion
-- ─────────────────────────────────────────────────────────────────────────────

local CANAL_X0, CANAL_X1 = -110, -98 -- inner channel
local CANAL_FLOOR = -8

local function buildCanal(root: Instance, brk: Instance)
	local f = folder(root, "Canal")
	local stoneCol = rgb(128, 118, 104)
	aabb(f, "CanalBed", CANAL_X0, -10, -188, CANAL_X1, CANAL_FLOOR, 188, rgb(70, 72, 64), MAT.Slate, "solid")
	aabb(f, "CanalWallWest", -112, -10, -188, CANAL_X0, 0, 188, stoneCol, MAT.Cobblestone, "solid")
	aabb(f, "CanalWallEast", CANAL_X1, -10, -188, -96, 0, 188, stoneCol, MAT.Cobblestone, "solid")
	aabb(f, "CulvertNorth", CANAL_X0 + 2, CANAL_FLOOR, -188.05, CANAL_X1 - 2, -2.5, -187.95, rgb(12, 12, 14), MAT.SmoothPlastic, "tiny")
	aabb(f, "CulvertSouth", CANAL_X0 + 2, CANAL_FLOOR, 187.95, CANAL_X1 - 2, -2.5, 188.05, rgb(12, 12, 14), MAT.SmoothPlastic, "tiny")
	local water = aabb(f, "CanalWater", CANAL_X0, CANAL_FLOOR + 0.1, -188, CANAL_X1, -5.5, 188, C.water, MAT.Glass, "deco")
	water.Transparency = 0.35
	water.Reflectance = 0.25
	water.CastShadow = false
	-- coping stones along both banks
	aabb(f, "CopingWest", -113, 0, -188, CANAL_X0, 0.5, 188, C.stoneLight, MAT.Granite, "solid")
	aabb(f, "CopingEast", CANAL_X1, 0, -188, -95, 0.5, 188, C.stoneLight, MAT.Granite, "solid")

	-- low stone parapets with gaps (bridge, footbridge, stairs, collapsed slab, fence)
	local parapetCol = rgb(150, 138, 118)
	for _, r in { { -186, -103 }, { -65, -7 }, { 7, 26 }, { 32, 122 }, { 138, 186 } } do
		aabb(f, "ParapetEast", -97, 0.5, r[1], -96.2, 1.9, r[2], parapetCol, MAT.Granite, "solid")
	end
	for _, r in { { -186, -103 }, { -97, -32 }, { -26, -7 }, { 7, 60 }, { 72, 122 }, { 138, 186 } } do
		aabb(f, "ParapetWest", -111.8, 0.5, r[1], -111, 1.9, r[2], parapetCol, MAT.Granite, "solid")
	end
	-- broken parapet section (west bank) with a fallen block
	box(f, "ParapetChunk", V3(0.8, 1.4, 4), CF(-114.2, 0.75, 64) * ANG(rad(10), rad(35), rad(80)), parapetCol, MAT.Granite, "solid")

	-- wooden fence on the east bank by the market (breakable)
	for i = 0, 3 do
		fenceSegment(brk, V3(-96.6, 0.5, -97 + i * 8), V3(-96.6, 0.5, -97 + (i + 1) * 8))
	end

	-- stairs down into the channel
	for i = 1, 7 do
		aabb(f, "CanalStepEast", CANAL_X1 - 3, CANAL_FLOOR, 26 + 2 * i, CANAL_X1, -i, 28 + 2 * i, C.stone, MAT.Granite, "solid")
		aabb(f, "CanalStepWest", CANAL_X0, CANAL_FLOOR, -28 - 2 * i, CANAL_X0 + 3, -i, -26 - 2 * i, C.stone, MAT.Granite, "solid")
	end

	-- arched stone bridge at z = 0
	local bridge = folder(f, "ArchedBridge")
	local cx, half, apex = -104, 17, 2.8
	local R = (half * half + apex * apex) / (2 * apex)
	local cy = apex - R
	local th0 = math.asin(half / R)
	local n = 10
	local function deckPoint(t: number): Vector3
		local th = -th0 + 2 * th0 * t
		return V3(cx + R * math.sin(th), cy + R * math.cos(th), 0)
	end
	for i = 0, n - 1 do
		local p0, p1 = deckPoint(i / n), deckPoint((i + 1) / n)
		local d = p1 - p0
		local phi = math.atan2(d.Y, d.X)
		local nrm = V3(-math.sin(phi), math.cos(phi), 0)
		local mid = (p0 + p1) / 2
		local rot = ANG(0, 0, phi)
		box(bridge, "BridgeDeck", V3(d.Magnitude + 0.25, 1.0, 10), CF(mid - nrm * 0.5) * rot, C.stoneLight, MAT.Granite, "solid")
		for _, sz in { -5.4, 5.4 } do
			box(bridge, "BridgeParapet", V3(d.Magnitude + 0.25, 2.2, 0.8), CF(mid + nrm * 1.1 + V3(0, 0, sz)) * rot, C.stone, MAT.Granite, "solid")
		end
	end
	-- vault ring under the deck
	local Rv, vcy = 6.8, 0.6 - 6.8
	local th1 = math.asin(6 / Rv)
	local nv = 8
	for i = 0, nv - 1 do
		local a0 = -th1 + 2 * th1 * i / nv
		local a1 = -th1 + 2 * th1 * (i + 1) / nv
		local p0 = V3(cx + Rv * math.sin(a0), vcy + Rv * math.cos(a0), 0)
		local p1 = V3(cx + Rv * math.sin(a1), vcy + Rv * math.cos(a1), 0)
		local d = p1 - p0
		local phi = math.atan2(d.Y, d.X)
		local nrm = V3(-math.sin(phi), math.cos(phi), 0)
		box(bridge, "BridgeVault", V3(d.Magnitude + 0.2, 1.2, 10.4), CF((p0 + p1) / 2 + nrm * 0.6) * ANG(0, 0, phi), C.stone, MAT.Granite, "solid")
	end
	for _, sx in { -1, 1 } do
		-- spandrel fill between vault and deck, abutments on the canal walls
		aabb(bridge, "BridgeSpandrel", cx + sx * 6.2, -1.2, -5, cx + sx * 3.6, 1.6, 5, C.stone, MAT.Granite, "solid")
		aabb(bridge, "BridgeAbutment", cx + sx * 9.5, -4, -5.2, cx + sx * 5.8, 1.4, 5.2, C.stone, MAT.Granite, "solid")
	end
	-- end posts with small lanterns
	for i, px in { -121.6, -86.4 } do
		for j, pz in { -5.4, 5.4 } do
			box(bridge, "BridgePost", V3(1.3, 3.6, 1.3), CF(px, 1.8, pz), C.stoneLight, MAT.Granite, "solid")
			local glow = box(bridge, "BridgePostLamp", V3(0.8, 0.8, 0.8), CF(px, 4.0, pz), C.neonWarm, MAT.Neon, "tiny")
			box(bridge, "BridgePostCap", V3(1.4, 0.3, 1.4), CF(px, 4.55, pz), C.stoneDark, MAT.Granite, "tiny")
			if (i == 1 and j == 1) or (i == 2 and j == 2) then
				pointLight(glow, 12, 1.1, rgb(255, 170, 90))
			end
		end
	end

	-- wooden footbridge (north)
	local fb = folder(f, "Footbridge")
	aabb(fb, "FootbridgeDeck", -114, 0.5, -102.5, -94, 1.0, -97.5, C.woodLight, MAT.WoodPlanks, "solid")
	for _, z in { -102.3, -97.7 } do
		rod(fb, "FootbridgeRail", V3(-113.5, 3.4, z), V3(-94.5, 3.4, z), 0.25, C.woodDark, MAT.Wood, "tiny")
		for _, x in { -113.5, -104, -94.5 } do
			rod(fb, "FootbridgePost", V3(x, 1.0, z), V3(x, 3.5, z), 0.35, C.woodDark, MAT.Wood, "tiny")
		end
	end

	-- collapsed slab lying across the canal (south), resting on rubble on the west bank
	local slabLen = 31
	local rise = 3.4
	local ang = math.atan2(rise, 30)
	box(f, "CollapsedSlab", V3(slabLen, 1.4, 11), CF(-105, 1.25, 130) * ANG(rad(2.5), 0, -ang), C.concrete, MAT.Concrete, "solid")
	rebarCluster(f, V3(-120, 3.9, 126), 3)
	rebarCluster(f, V3(-90.5, 0.6, 134), 2)
	rubblePile(f, -119, 0.05, 130, 4.5, 7)
	aabb(f, "SlabSupport", -122, 0, 125.5, -115, 3.2, 134.5, C.concreteDark, MAT.Concrete, "solid")
end

local function pavilion(f: Instance, x: number, z: number)
	local p = folder(f, "Pavilion")
	aabb(p, "PavilionPlatform", x - 8, 0, z - 8, x + 8, 1.2, z + 8, C.stoneLight, MAT.Granite, "solid")
	aabb(p, "PavilionStep", x + 8, 0, z - 4, x + 10, 0.6, z + 4, C.stone, MAT.Granite, "solid")
	for _, dx in { -6, 6 } do
		for _, dz in { -6, 6 } do
			cyl(p, "PavilionColumn", 1.2, 9, V3(x + dx, 5.7, z + dz), C.lacquer, MAT.SmoothPlastic, "solid")
		end
	end
	aabb(p, "PavilionBeamN", x - 6.8, 9.6, z - 6.6, x + 6.8, 10.4, z - 5.4, C.lacquer, MAT.SmoothPlastic, "solid")
	aabb(p, "PavilionBeamS", x - 6.8, 9.6, z + 5.4, x + 6.8, 10.4, z + 6.6, C.lacquer, MAT.SmoothPlastic, "solid")
	aabb(p, "PavilionBeamW", x - 6.6, 9.6, z - 6.8, x - 5.4, 10.4, z + 6.8, C.lacquer, MAT.SmoothPlastic, "solid")
	aabb(p, "PavilionBeamE", x + 5.4, 9.6, z - 6.8, x + 6.6, 10.4, z + 6.8, C.lacquer, MAT.SmoothPlastic, "solid")
	aabb(p, "PavilionGoldBand", x - 6.9, 10.4, z - 6.9, x + 6.9, 10.6, z + 6.9, C.gold, MAT.Metal, "deco")
	aabb(p, "PavilionEaves", x - 9, 10.6, z - 9, x + 9, 11.0, z + 9, C.tile, MAT.Slate, "solid")
	-- gable roof, ridge running north-south
	wedge(p, "PavilionRoofEast", V3(18, 3.2, 9), CF(x + 4.5, 12.6, z) * ANG(0, rad(-90), 0), C.tile, MAT.Slate, "solid")
	wedge(p, "PavilionRoofWest", V3(18, 3.2, 9), CF(x - 4.5, 12.6, z) * ANG(0, rad(90), 0), C.tile, MAT.Slate, "solid")
	aabb(p, "PavilionRidge", x - 0.6, 14.1, z - 9.5, x + 0.6, 14.9, z + 9.5, C.gold, MAT.Metal, "solid")
	for _, dz in { -9.6, 9.6 } do
		box(p, "RidgeCurl", V3(1.2, 2.2, 1.0), CF(x, 15.4, z + dz) * ANG(rad(if dz > 0 then 25 else -25), 0, 0), C.gold, MAT.Metal, "tiny")
	end
	cyl(p, "StoneTable", 3.2, 2.6, V3(x, 2.5, z), C.stone, MAT.Marble, "solid")
	cyl(p, "StoneSeat", 1.4, 1.6, V3(x - 3, 2.0, z), C.stone, MAT.Marble, "solid")
	cyl(p, "StoneSeat", 1.4, 1.6, V3(x + 3, 2.0, z), C.stone, MAT.Marble, "solid")
	rod(p, "LanternCord", V3(x, 10.6, z), V3(x, 9.4, z), 0.08, C.black, MAT.Fabric, "tiny")
	hangingLantern(p, V3(x, 9.4, z), 1.8, true, 14)
end

local function buildWest(root: Instance, brk: Instance)
	local f = folder(root, "WestPark")
	-- willows along both banks and in the park
	local trees = folder(f, "Willows")
	for _, pz in { -80, -40, 52, 96, 160 } do
		willow(trees, -89, 0.05, pz, rr(0.9, 1.1))
	end
	for _, pz in { -150, -60, 40, 100 } do
		willow(trees, -117, 0.05, pz, rr(0.9, 1.1))
	end
	willow(trees, -170, 0.05, -150, 1.15)
	willow(trees, -172, 0.05, 70, 1.1)

	-- benches facing the water
	local benches = folder(f, "Benches")
	bench(benches, lookAt(V3(-87, 0.05, -18), V3(-200, 0.05, -18)), false)
	bench(benches, lookAt(V3(-87, 0.05, 74), V3(-200, 0.05, 74)), false)
	bench(benches, lookAt(V3(-87, 0.05, 116), V3(-200, 0.05, 116)), false)
	bench(benches, lookAt(V3(-120, 0.05, -80), V3(200, 0.05, -80)), false)
	bench(brk, lookAt(V3(-120, 0.05, 20), V3(200, 0.05, 20)), true)

	pavilion(f, -150, 0)
	local maples = folder(f, "Maples")
	for _, p in { { -168, -95 }, { -138, -72 }, { -138, 72 }, { -168, 100 }, { -176, -40 } } do
		maple(maples, p[1], 0.05, p[2], rr(0.9, 1.15))
	end
	-- stepping stones from the pavilion up to the shrine
	for i = 1, 9 do
		local z = -14 - i * 11.5
		cyl(f, "SteppingStone", rr(2.4, 3.0), 0.2, V3(-150 + math.sin(i * 0.9) * 3, 0.1, z), jitter(C.stoneLight, 10), MAT.Slate, "tiny")
	end
	-- path lanterns
	for _, pz in { -6, 6 } do
		local base = CF(-134, 0.05, pz)
		box(f, "PathLanternBase", V3(1.4, 1.2, 1.4), base * CF(0, 0.6, 0), C.stone, MAT.Granite, "solid")
		box(f, "PathLanternBox", V3(1.1, 1.3, 1.1), base * CF(0, 1.85, 0), C.stoneLight, MAT.Granite, "solid")
		box(f, "PathLanternGlow", V3(1.15, 0.6, 0.6), base * CF(0, 1.9, 0), C.neonWarm, MAT.Neon, "tiny")
		box(f, "PathLanternRoof", V3(1.8, 0.4, 1.8), base * CF(0, 2.7, 0), C.stoneDark, MAT.Granite, "tiny")
	end
	-- WACA debris dump in the south-west corner
	rubblePile(f, -152, 0.05, 150, 6, 8)
	local dump = box(f, "WACAContainer", V3(6.5, 6.8, 14), CF(-168, 3.45, 168) * ANG(0, rad(80), 0), rgb(24, 24, 28), MAT.CorrodedMetal, "solid")
	surfaceText(dump, Enum.NormalId.Right, 16, nil, oneLine("WACA", C.wacaRed, Enum.Font.GothamBlack), 0.6)
	local garden = folder(f, "Garden")
	bambooCluster(garden, -177, 0.05, -28, 7)
	bambooCluster(garden, -177, 0.05, 28, 7)
	bambooCluster(garden, -130, 0.05, -168, 6)
	for _, p in { { -140, -14 }, { -162, 13 }, { -135, 15 }, { -165, -16 }, { -158, 40 } } do
		rock(garden, p[1], 0.05, p[2], rr(0.9, 1.4))
	end
	-- incense burner shrine in the north-west corner
	local shrine = folder(f, "Shrine")
	aabb(shrine, "ShrinePlinth", -158, 0, -142, -142, 0.8, -128, C.stoneLight, MAT.Granite, "solid")
	cyl(shrine, "IncenseBurner", 3.2, 2.4, V3(-150, 2.4, -135), rgb(120, 86, 40), MAT.Metal, "solid")
	cyl(shrine, "BurnerRim", 3.6, 0.3, V3(-150, 3.7, -135), C.gold, MAT.Metal, "tiny")
	for i = 1, 3 do
		rod(shrine, "IncenseStick", V3(-150.4 + i * 0.2, 3.5, -135), V3(-150.4 + i * 0.25, 5.2, -135), 0.08, rgb(200, 60, 40), MAT.Wood, "tiny")
	end
	aabb(shrine, "ShrineHouse", -154, 0.8, -142, -146, 6.8, -139, C.lacquer, MAT.Wood, "solid")
	wedge(shrine, "ShrineRoof", V3(9.5, 1.6, 4.4), CF(-150, 7.6, -140.4) * ANG(0, math.pi, 0), C.tile, MAT.Slate, "solid")
	for _, sx in { -1, 1 } do
		local base = CF(-150 + sx * 6.2, 0.8, -133)
		box(shrine, "GuardLanternBase", V3(1.6, 1.4, 1.6), base * CF(0, 0.7, 0), C.stone, MAT.Granite, "solid")
		box(shrine, "GuardLanternBox", V3(1.2, 1.4, 1.2), base * CF(0, 2.1, 0), C.stoneLight, MAT.Granite, "solid")
		box(shrine, "GuardLanternRoof", V3(1.9, 0.4, 1.9), base * CF(0, 3.0, 0), C.stoneDark, MAT.Granite, "tiny")
	end
	crate(brk, -118, 0.05, -106, 2.8, 12)
	barrel(brk, -118.5, 0.05, -110.5, C.wood)
	-- WACA cordon where the slab landed on the west bank
	trafficCone(brk, -125, 0.05, 118)
	trafficCone(brk, -128, 0.05, 124)
	-- a tree felled by the incident
	rod(f, "FallenTrunk", V3(-150, 0.8, 150), V3(-136, 1.4, 160), 1.6, C.trunk, MAT.Wood, "solid")
	ball(f, "FallenCrown", 7, V3(-133, 3.0, 162), jitter(C.foliage, 10), MAT.Grass, "deco")
	ball(f, "FallenCrown", 5.5, V3(-137, 2.4, 165), jitter(C.foliage, 10), MAT.Grass, "deco")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- ZONE SOUTH: WACA cleanup site
-- ─────────────────────────────────────────────────────────────────────────────

local function floodlightTower(f: Instance, x: number, z: number, target: Vector3)
	local t = folder(f, "FloodlightTower")
	aabb(t, "GeneratorBox", x - 1.6, 0.05, z - 2.4, x + 1.6, 2.4, z + 2.4, C.hazard, MAT.Metal, "solid")
	aabb(t, "GeneratorStripe", x - 1.65, 1.0, z - 2.45, x + 1.65, 1.4, z + 2.45, C.black, MAT.SmoothPlastic, "tiny")
	truss(t, "FloodMast", 22, V3(x, 11.05, z + 3.4), C.steel)
	local headPos = V3(x, 23.2, z + 3.4)
	local look = lookAt(headPos, target)
	box(t, "FloodFrame", V3(6, 3, 0.8), look, C.black, MAT.Metal, "solid")
	for i = 0, 3 do
		local lx = -2.0 + (i % 2) * 4.0 - 0.0
		local ly = if i < 2 then 0.7 else -0.7
		box(t, "FloodLamp", V3(1.6, 1.1, 0.12), look * CF(lx * 0.75, ly, -0.44), rgb(255, 250, 235), MAT.Neon, "tiny")
	end
	local emitter = box(t, "FloodEmitter", V3(0.5, 0.5, 0.5), look * CF(0, 0, -0.6), C.white, MAT.SmoothPlastic, "ghost")
	spotLight(emitter, 60, 3.2, 70, rgb(255, 246, 228))
end

local function wacaTruck(f: Instance, o: CFrame)
	local m = model(f, "WACATruck")
	local chassis = box(m, "Chassis", V3(7.3, 1.2, 21.6), o * CF(0, 1.9, 0.1), C.black, MAT.Metal, "solid")
	m.PrimaryPart = chassis
	box(m, "Cab", V3(7.6, 5.8, 6), o * CF(0, 4.4, -8), C.black, MAT.SmoothPlastic, "solid")
	box(m, "Windshield", V3(6.8, 2.6, 0.2), o * CF(0, 5.6, -11.05), C.glassDark, MAT.Glass, "tiny")
	for _, sx in { -1, 1 } do
		box(m, "SideWindow", V3(0.2, 2.2, 3.0), o * CF(sx * 3.85, 5.6, -8.6), C.glassDark, MAT.Glass, "tiny")
		box(m, "Headlight", V3(1.2, 0.6, 0.1), o * CF(sx * 2.8, 2.9, -11.05), C.lampWhite, MAT.Neon, "tiny")
	end
	box(m, "Bumper", V3(7.8, 1.0, 0.6), o * CF(0, 1.6, -11.2), C.charcoal, MAT.Metal, "solid")
	local cargo = box(m, "CargoBox", V3(8, 8.4, 15.4), o * CF(0, 6.3, 3), rgb(18, 18, 22), MAT.SmoothPlastic, "solid")
	box(m, "CargoStripe", V3(8.1, 0.8, 15.5), o * CF(0, 4.0, 3), C.wacaRed, MAT.SmoothPlastic, "deco")
	for _, face in { Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Back } do
		surfaceText(cargo, face, 20, nil, {
			{ text = "WACA", color = C.wacaRed, y = 0.12, h = 0.36, font = Enum.Font.GothamBlack },
			{ text = "SITE CLEANUP UNIT", color = rgb(200, 200, 200), y = 0.5, h = 0.1, font = Enum.Font.GothamBold },
		}, 0.5, 1.4)
	end
	for _, sz in { -8, 4, 7.4 } do
		for _, sx in { -1, 1 } do
			local w = Instance.new("Part")
			w.Shape = Enum.PartType.Cylinder
			setup(w, m, "Wheel", V3(1.2, 3, 3), o * CF(sx * 3.5, 1.5, sz), rgb(26, 26, 28), MAT.SmoothPlastic, "solid")
		end
	end
	local red = box(m, "LightBarRed", V3(2.4, 0.5, 1), o * CF(-1.25, 7.55, -8), C.wacaRed, MAT.Neon, "tiny")
	box(m, "LightBarBlue", V3(2.4, 0.5, 1), o * CF(1.25, 7.55, -8), rgb(40, 90, 255), MAT.Neon, "tiny")
	pointLight(red, 16, 1.4, rgb(255, 40, 40))
	-- rear loading ramp
	box(m, "LoadingRamp", V3(6, 0.4, 5.5), o * CF(0, 1.1, 13.2) * ANG(rad(24), 0, 0), C.metal, MAT.DiamondPlate, "solid")
end

local function buildSouth(root: Instance, brk: Instance)
	local f = folder(root, "WACAZone")

	-- cordon along the zone's north edge
	local tape = folder(f, "Cordon")
	cordon(tape, { V3(-82, 0.05, 62), V3(-60, 0.05, 63), V3(-36, 0.05, 61.5), V3(-12, 0.05, 62.5) })
	cordon(tape, { V3(12, 0.05, 62.5), V3(34, 0.05, 61.5), V3(56, 0.05, 63), V3(72, 0.05, 62) })
	cordon(tape, { V3(-92, 0.05, 124), V3(-92, 0.05, 136) })

	-- crater / epicentre
	local crater = folder(f, "Epicentre")
	local ecx, ecz = 0, 110
	cyl(crater, "Scorch", 30, 0.1, V3(ecx, 0.08, ecz), rgb(34, 30, 32), MAT.Slate, "tiny")
	cyl(crater, "ScorchCore", 14, 0.1, V3(ecx, 0.13, ecz), rgb(22, 20, 22), MAT.Slate, "tiny")
	for i = 1, 12 do
		local a = i / 12 * 2 * math.pi + rr(-0.15, 0.15)
		local r0, r1 = rr(3, 6), rr(16, 30)
		local p0 = V3(ecx + math.cos(a) * r0, 0.2, ecz + math.sin(a) * r0)
		local p1 = V3(ecx + math.cos(a) * r1, 0.2, ecz + math.sin(a) * r1)
		local glowing = i % 4 == 0
		box(crater, "Fissure", V3(rr(0.35, 0.6), 0.06, (p1 - p0).Magnitude), lookAt((p0 + p1) / 2, p1), if glowing then rgb(120, 60, 160) else rgb(18, 16, 18), if glowing then MAT.Neon else MAT.Slate, "tiny")
	end
	for i = 1, 11 do
		local a = i / 11 * 2 * math.pi + rr(-0.12, 0.12)
		local r = rr(14, 16)
		local size = V3(rr(4.5, 7.5), 1.2, rr(3, 4.5))
		local yaw = -a
		local tilt = rad(rr(18, 30))
		local rot = ANG(0, yaw, 0) * ANG(0, 0, tilt)
		box(crater, "RimSlab", size, restCF(ecx + math.cos(a) * r, 0.05, ecz + math.sin(a) * r, size, rot, 1.2), jitter(C.concrete, 12), MAT.Concrete, "solid")
	end
	for _, p in { { -5, 104 }, { 6, 114 }, { 2, 101 }, { -3, 117 } } do
		ashPile(crater, p[1], 0.1, p[2], rr(0.8, 1.2))
	end
	local ashSource = box(crater, "AshDrift", V3(12, 0.2, 12), CF(ecx, 0.6, ecz), C.ash, MAT.SmoothPlastic, "ghost")
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "AshFlakes"
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Rate = 6
	pe.Lifetime = NumberRange.new(4, 7)
	pe.Speed = NumberRange.new(0.8, 2.2)
	pe.SpreadAngle = Vector2.new(35, 35)
	pe.Acceleration = V3(0.4, 0.3, 0)
	pe.Color = ColorSequence.new(rgb(40, 38, 40), rgb(90, 86, 88))
	pe.LightEmission = 0
	pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0.1) })
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	pe.Parent = ashSource
	-- containment pylons with a red field line between them
	local pylons: { Vector3 } = {}
	for i = 0, 3 do
		local a = rad(45 + i * 90)
		local px, pz = ecx + math.cos(a) * 21, ecz + math.sin(a) * 21
		box(crater, "PylonBase", V3(2, 1, 2), CF(px, 0.55, pz), C.black, MAT.Metal, "solid")
		cyl(crater, "Pylon", 0.8, 6, V3(px, 4, pz), C.black, MAT.Metal, "solid")
		cyl(crater, "PylonRing", 1.1, 0.5, V3(px, 6.3, pz), C.wacaRed, MAT.Neon, "tiny")
		ball(crater, "PylonTip", 0.9, V3(px, 7.2, pz), C.wacaRed, MAT.Neon, "tiny")
		table.insert(pylons, V3(px, 6.3, pz))
	end
	for i = 1, 4 do
		local a, b = pylons[i], pylons[(i % 4) + 1]
		rod(crater, "ContainmentField", a, b, 0.12, rgb(255, 50, 60), MAT.Neon, "tiny")
	end

	-- Ren's clean katana cut: a pillar sliced diagonally, the top half slid off
	local cut = folder(f, "SlicedPillar")
	local sx, sz = -34, 96
	box(cut, "PillarLower", V3(4, 6, 4), CF(sx, 3.05, sz), C.concrete, MAT.Concrete, "solid")
	wedge(cut, "PillarCutLower", V3(4, 4, 4), CF(sx, 8.05, sz) * ANG(0, math.pi, 0), C.concrete, MAT.Concrete, "solid")
	-- the lower wedge keeps the solid below the plane y = -(z - sz); the upper piece is its
	-- complement, slid 1.3 studs down the cut plane (towards +Z) and nudged sideways
	local upper = CF(sx + 0.8, 8.05 - 1.3, sz + 1.3) * ANG(0, 0, rad(-3))
	wedge(cut, "PillarCutUpper", V3(4, 4, 4), upper * ANG(0, 0, math.pi), C.concrete, MAT.Concrete, "solid")
	box(cut, "PillarUpper", V3(4, 4.5, 4), upper * CF(0, 4.25, 0), C.concrete, MAT.Concrete, "solid")
	box(cut, "CutAshLine", V3(4.1, 0.06, 5.7), CF(sx, 8.05, sz) * ANG(rad(45), 0, 0), C.ash, MAT.Sand, "tiny")
	ashPile(cut, sx - 3.5, 0.05, sz + 2, 1.0)
	ashPile(cut, sx + 2.5, 0.05, sz + 4, 0.7)

	-- collapsed building (south-west)
	local cb = folder(f, "CollapsedBlockWest")
	aabb(cb, "Foundation", -82, 0, 134, -32, 0.8, 186, C.concreteDark, MAT.Concrete, "solid")
	local pillarSpec = {
		{ -78, 140, 6 },
		{ -62, 140, 3 },
		{ -46, 140, 12 },
		{ -36, 140, 2 },
		{ -78, 160, 15 },
		{ -62, 160, 15 },
		{ -46, 160, 9 },
		{ -36, 160, 5 },
		{ -78, 180, 15 },
		{ -62, 180, 15 },
		{ -46, 180, 11 },
		{ -36, 180, 15 },
	}
	for _, p in pillarSpec do
		if p[3] >= 15 then
			box(cb, "Pillar", V3(1.8, 14.2, 1.8), CF(p[1], 0.8 + 7.1, p[2]), C.concrete, MAT.Concrete, "solid")
		else
			brokenPillar(cb, p[1], 0.8, p[2], p[3], 1.8)
		end
	end
	aabb(cb, "UpperSlab", -80, 15, 156, -56, 16.2, 184, C.concrete, MAT.Concrete, "solid")
	rebarCluster(cb, V3(-57, 15.6, 170), 3)
	-- fallen floor section = ramp up to the upper slab
	local rampRun, rampRise = 21, 14.4
	local rampLen = math.sqrt(rampRun * rampRun + rampRise * rampRise)
	local rampAng = math.atan2(rampRise, rampRun)
	box(cb, "RampSlab", V3(10, 1.2, rampLen + 1), CF(-71, 0.8 + rampRise / 2, 135.5 + rampRun / 2) * ANG(rampAng, 0, 0), jitter(C.concrete, 6), MAT.Concrete, "solid")
	-- jagged back and side walls
	local backHeights = { 18, 10, 14, 6, 9 }
	for i, h in backHeights do
		local x0 = -82 + (i - 1) * 10
		aabb(cb, "RuinWall", x0, 0.8, 184, x0 + 10, 0.8 + h, 186, jitter(C.concrete, 8), MAT.Concrete, "solid")
	end
	for i, h in { 8, 16, 12 } do
		local z0 = 134 + (i - 1) * 16
		aabb(cb, "RuinWall", -82, 0.8, z0, -80, 0.8 + h, z0 + 16, jitter(C.concrete, 8), MAT.Concrete, "solid")
	end
	box(cb, "WACATarp", V3(0.2, 12, 14), CF(-79.6, 7, 158) * ANG(0, 0, rad(5)), C.black, MAT.Fabric, "deco")
	box(cb, "FallenSlab", V3(14, 1.2, 10), CF(-50, 2.0, 170) * ANG(0, rad(15), rad(12)), C.concrete, MAT.Concrete, "solid")
	rubblePile(cb, -52, 0.8, 150, 5, 8)
	rubblePile(cb, -40, 0.8, 172, 4, 6)
	rubblePile(cb, -84, 0.05, 146, 3, 4)

	-- sheared building (south-centre / south-east): intact lower storey, upper floors slid off
	local sb = folder(f, "ShearedBlock")
	aabb(sb, "LowerStorey", 30, 0, 150, 64, 12, 186, C.concrete, MAT.Concrete, "solid")
	for _, x in { 36, 47, 58 } do
		aabb(sb, "BrokenWindow", x - 3.5, 4, 149.85, x + 3.5, 9, 150, rgb(20, 22, 26), MAT.Glass, "deco")
	end
	aabb(sb, "BoardedWindow", 43.5, 5, 149.7, 50.5, 5.6, 149.85, C.woodLight, MAT.WoodPlanks, "tiny")
	aabb(sb, "BoardedWindow", 43.5, 7.2, 149.7, 50.5, 7.8, 149.85, C.woodLight, MAT.WoodPlanks, "tiny")
	local sRun, sRise = 18, 12
	local sLen = math.sqrt(sRun * sRun + sRise * sRise)
	local sAng = math.atan2(sRise, sRun)
	box(sb, "SlidFloor", V3(sLen + 1.5, 1.3, 14), CF(21, 6.0, 163) * ANG(0, 0, sAng), jitter(C.concrete, 6), MAT.Concrete, "solid")
	box(sb, "SlidFloor2", V3(12, 1.3, 12), CF(19, 5.2, 176) * ANG(rad(-6), rad(8), sAng * 0.9), jitter(C.concrete, 6), MAT.Concrete, "solid")
	for i, h in { 7, 10, 4 } do
		local x0 = 30 + (i - 1) * 11.33
		aabb(sb, "UpperRuin", x0, 12, 184, x0 + 11.33, 12 + h, 186, jitter(C.concrete, 8), MAT.Concrete, "solid")
	end
	brokenPillar(sb, 40, 12, 160, 5, 1.6)
	brokenPillar(sb, 54, 12, 170, 3, 1.6)
	local tank = Instance.new("Part")
	tank.Shape = Enum.PartType.Cylinder
	setup(tank, sb, "ToppledTank", V3(6, 4.5, 4.5), CF(56, 14.25, 176) * ANG(0, rad(30), 0), rgb(110, 116, 120), MAT.CorrodedMetal, "solid")
	rubblePile(sb, 16, 0.05, 150, 4, 6)
	rubblePile(sb, 26, 0.05, 146, 3.5, 5)

	-- WACA equipment: truck, tent, containers, floodlights
	wacaTruck(f, CF(56, 0.05, 100))
	local tent = folder(f, "WACATent")
	for _, dx in { -4.2, 4.2 } do
		for _, dz in { -4.2, 4.2 } do
			rod(tent, "TentLeg", V3(28 + dx, 0.05, 80 + dz), V3(28 + dx, 8, 80 + dz), 0.25, C.charcoal, MAT.Metal, "tiny")
		end
	end
	box(tent, "TentRoof", V3(9.2, 0.3, 9.2), CF(28, 8.1, 80), C.black, MAT.Fabric, "deco")
	local valance = box(tent, "TentValance", V3(9.2, 1.0, 0.1), CF(28, 7.5, 75.4), C.black, MAT.Fabric, "tiny")
	surfaceText(valance, Enum.NormalId.Front, 30, nil, oneLine("WACA  現場本部", C.wacaRed, Enum.Font.GothamBlack), 0.4, 1.5)
	aabb(tent, "TentTable", 25, 2.8, 79, 31, 3.1, 81, rgb(200, 200, 196), MAT.SmoothPlastic, "solid")
	aabb(tent, "TentTableLegs", 25.5, 0.05, 79.5, 30.5, 2.8, 80.5, C.charcoal, MAT.Metal, "solid")
	box(tent, "Monitor", V3(1.8, 1.1, 0.12), CF(26.5, 3.75, 80.3) * ANG(0, math.pi, 0), rgb(60, 160, 255), MAT.Neon, "tiny")
	box(tent, "Monitor", V3(1.8, 1.1, 0.12), CF(29.5, 3.75, 80.3) * ANG(0, math.pi, 0), rgb(255, 60, 70), MAT.Neon, "tiny")

	local containers = folder(f, "Containers")
	local c1 = box(containers, "WACAContainer", V3(6.5, 6.8, 14), CF(-66, 3.45, 100) * ANG(0, rad(12), 0), rgb(24, 24, 28), MAT.CorrodedMetal, "solid")
	surfaceText(c1, Enum.NormalId.Right, 16, nil, {
		{ text = "WACA", color = C.wacaRed, y = 0.3, h = 0.3, font = Enum.Font.GothamBlack },
		{ text = "CONTAINMENT 07", color = rgb(190, 190, 190), y = 0.62, h = 0.1, font = Enum.Font.GothamBold },
	}, 0.6)
	local c2 = box(containers, "WACAContainer", V3(6.5, 6.8, 14), CF(-58, 3.45, 84) * ANG(0, rad(-70), 0), rgb(120, 24, 28), MAT.CorrodedMetal, "solid")
	surfaceText(c2, Enum.NormalId.Left, 16, nil, oneLine("WACA", rgb(20, 20, 20), Enum.Font.GothamBlack), 0.6)

	floodlightTower(f, -52, 72, V3(-56, 2, 150))
	floodlightTower(f, 66, 72, V3(10, 1, 118))

	-- breakables: cones, barriers, drums, cases, rubble
	for _, p in { { -14, 64 }, { 14, 64 }, { 22, 90 }, { 40, 118 } } do
		trafficCone(brk, p[1], 0.05, p[2])
	end
	jerseyBarrier(brk, 90, 0.05, 112, 90, rgb(220, 220, 214))
	jerseyBarrier(brk, 98, 0.05, 112, 90, rgb(200, 40, 40))
	jerseyBarrier(brk, 106, 0.05, 112, 90, rgb(220, 220, 214))
	jerseyBarrier(brk, -20, 0.05, 76, 75, rgb(200, 40, 40))
	for _, p in { { 48, 94 }, { 48.3, 97 }, { 46, 95.5 } } do
		drum(brk, p[1], 0.05, p[2], C.hazard)
	end
	for _, p in { { 24, 86, 10 }, { 28, 86.5, -8 }, { 32.5, 86, 20 } } do
		wacaCase(brk, p[1], 0.05, p[2], p[3])
	end
	local rubbleSpots = {
		{ -12, 90, 2.4 },
		{ 9, 90, 2.0 },
		{ -26, 118, 2.6 },
		{ 18, 128, 2.2 },
		{ -44, 124, 3.0 },
		{ -30, 150, 2.8 },
	}
	for _, r in rubbleSpots do
		rubbleChunk(brk, r[1], 0.05, r[2], V3(r[3], r[3] * 0.55, r[3] * 0.8), C.concrete)
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- PERIMETER: city skyline outside the invisible walls
-- ─────────────────────────────────────────────────────────────────────────────

local SKY_BODY = {
	rgb(96, 92, 90),
	rgb(120, 112, 104),
	rgb(78, 80, 88),
	rgb(132, 94, 76),
	rgb(150, 136, 116),
	rgb(64, 66, 74),
	rgb(104, 110, 112),
	rgb(90, 70, 64),
}
local SKY_MAT = { MAT.Concrete, MAT.Concrete, MAT.SmoothPlastic, MAT.Brick, MAT.Concrete, MAT.Slate, MAT.SmoothPlastic, MAT.Brick }
local SKY_SIGNS = { "酒\n店", "ホ\nテ\nル", "麻\n雀", "銀\n行", "拉\n麵", "金\n灰", "電\n器", "旅\n館", "焼\n肉", "當\n舖" }
local SKY_SIGN_COLORS = { rgb(255, 80, 70), rgb(255, 200, 80), rgb(90, 220, 255), rgb(255, 120, 220), rgb(120, 255, 150) }
local SKY_BILLBOARDS = { "金灰", "WACA は存在しない", "夜市", "林記麵館", "SOUL NOODLE", "銀河銀行" }
local WINDOW_LIT = { rgb(255, 205, 130), rgb(255, 180, 100), rgb(255, 225, 170), rgb(210, 230, 255) }

local function pick<T>(list: { T }): T
	return list[ri(1, #list)]
end

-- front-row building; frame: LookVector points into the arena, local +Z points away.
local function skylineBuilding(f: Instance, frame: CFrame, cu: number, w: number, h: number, zf: number, depth: number)
	local ci = ri(1, #SKY_BODY)
	local bodyCol = jitter(SKY_BODY[ci], 8)
	local bodyMat = SKY_MAT[ci]
	local glassTower = h > 70 and rnd() < 0.3
	local m = model(f, "Building")
	local body = box(m, "Body", V3(w, h, depth), frame * CF(cu, h / 2, zf + depth / 2), if glassTower then rgb(52, 66, 80) else bodyCol, if glassTower then MAT.Glass else bodyMat, "tiny")
	m.PrimaryPart = body
	if glassTower then
		body.Reflectance = 0.18
	end
	local baseH, floorH = 9, if h > 90 then 12 else 10
	local nF = math.floor((h - baseH - 3) / floorH)
	local gw = w - 4
	if nF >= 1 then
		local gh = nF * floorH
		local spand = floorH * 0.36
		if glassTower then
			local nFins = math.max(3, math.floor(w / 9))
			for c = 0, nFins do
				local x = cu - w / 2 + c * w / nFins
				box(m, "Fin", V3(0.8, h - 2, 1.0), frame * CF(x, (h - 2) / 2, zf - 0.5), rgb(150, 156, 160), MAT.Metal, "tiny")
			end
		else
			box(m, "Glass", V3(gw, gh, 0.3), frame * CF(cu, baseH + gh / 2, zf - 0.15), rgb(44, 54, 64), MAT.Glass, "tiny").Reflectance = 0.15
			for k = 0, nF do
				box(m, "Spandrel", V3(gw + 0.4, spand, 0.6), frame * CF(cu, baseH + k * floorH, zf - 0.3), bodyCol, bodyMat, "tiny")
			end
			if rnd() < 0.55 then
				local nC = math.max(2, math.floor(gw / 7))
				for c = 1, nC - 1 do
					box(m, "Mullion", V3(0.9, gh, 0.6), frame * CF(cu - gw / 2 + c * gw / nC, baseH + gh / 2, zf - 0.3), bodyCol, bodyMat, "tiny")
				end
			end
		end
		local nLit = ri(2, 5)
		for li = 1, nLit do
			local fl = ri(0, nF - 1)
			local lw = rr(3, math.min(12, gw * 0.4))
			local lx = rr(cu - gw / 2 + lw / 2, cu + gw / 2 - lw / 2)
			box(m, "LitWindow", V3(lw, floorH - spand - 0.2, 0.1), frame * CF(lx, baseH + fl * floorH + floorH / 2, zf - (if glassTower then 0.05 else 0.33) - li * 0.012), pick(WINDOW_LIT), MAT.Neon, "tiny")
		end
	end
	-- street level: dark shopfront + a glowing sign strip
	box(m, "Shopfront", V3(w - 3, 5.5, 0.3), frame * CF(cu, 3.2, zf - 0.15), rgb(34, 36, 42), MAT.Glass, "tiny")
	box(m, "ShopStrip", V3(w - 5, 1.4, 0.4), frame * CF(cu, 7.2, zf - 0.3), jitter(pick(SKY_SIGN_COLORS), 30), MAT.Neon, "tiny")
	-- vertical sign
	if rnd() < 0.35 and h > 30 then
		local bh = rr(12, math.min(22, h - 14))
		local side = if rnd() < 0.5 then -1 else 1
		local vs = box(m, "VerticalSign", V3(3.2, bh, 0.5), frame * CF(cu + side * (w / 2 - 3), baseH + 2 + bh / 2, zf - 0.9), rgb(20, 18, 22), MAT.SmoothPlastic, "tiny")
		surfaceText(vs, Enum.NormalId.Front, 12, rgb(20, 18, 22), { { text = pick(SKY_SIGNS), color = pick(SKY_SIGN_COLORS), y = 0.03, h = 0.94, font = Enum.Font.GothamBlack } }, 0, 2.5)
	end
	-- roof: cornice + one or two details
	box(m, "Cornice", V3(w + 0.6, 1.2, 1.2), frame * CF(cu, h - 0.3, zf - 0.3), jitter(bodyCol, 12), bodyMat, "tiny")
	local r = rnd()
	if r < 0.35 then
		local tx = cu + rr(-w / 4, w / 4)
		local tz = zf + depth * rr(0.4, 0.7)
		box(m, "TankStand", V3(5, 2, 5), frame * CF(tx, h + 1, tz), C.charcoal, MAT.Metal, "tiny")
		local tank = Instance.new("Part")
		tank.Shape = Enum.PartType.Cylinder
		setup(tank, m, "WaterTank", V3(5, 5.5, 5.5), frame * CF(tx, h + 4.5, tz) * UPRIGHT, jitter(rgb(120, 110, 96), 10), MAT.Wood, "tiny")
	elseif r < 0.6 then
		local ax = cu + rr(-w / 3, w / 3)
		local az = zf + depth * 0.5
		local ah = rr(10, 22)
		local basePos = (frame * CF(ax, h, az)).Position
		rod(m, "Antenna", basePos, basePos + V3(0, ah, 0), 0.5, C.steel, MAT.Metal, "tiny")
		ball(m, "AntennaLight", 0.9, basePos + V3(0, ah + 0.3, 0), C.wacaRed, MAT.Neon, "tiny")
	elseif r < 0.8 then
		local bb = box(m, "Billboard", V3(math.min(w * 0.7, 26), 7, 0.6), frame * CF(cu, h + 5, zf + 2), rgb(24, 22, 26), MAT.SmoothPlastic, "tiny")
		surfaceText(bb, Enum.NormalId.Front, 8, rgb(24, 22, 26), oneLine(pick(SKY_BILLBOARDS), pick(SKY_SIGN_COLORS), Enum.Font.GothamBlack), 0, 2.2)
		box(m, "BillboardLegs", V3(math.min(w * 0.6, 22), 1.5, 0.6), frame * CF(cu, h + 0.75, zf + 2), C.charcoal, MAT.Metal, "tiny")
	else
		box(m, "RoofUnit", V3(rr(5, 9), rr(2, 4), rr(5, 9)), frame * CF(cu + rr(-w / 4, w / 4), h + 1.5, zf + depth * 0.5), rgb(150, 150, 146), MAT.Metal, "tiny")
	end
end

-- simplified tower for the far row
local function skylineTower(f: Instance, frame: CFrame, cu: number, w: number, h: number, zf: number, depth: number)
	local m = model(f, "Tower")
	local glass = rnd() < 0.45
	local col = if glass then jitter(rgb(56, 70, 86), 8) else jitter(pick(SKY_BODY), 8)
	local body = box(m, "Body", V3(w, h, depth), frame * CF(cu, h / 2, zf + depth / 2), col, if glass then MAT.Glass else MAT.Concrete, "tiny")
	body.Reflectance = if glass then 0.2 else 0
	m.PrimaryPart = body
	for li = 1, ri(2, 4) do
		local lw = rr(4, w * 0.5)
		box(m, "LitStrip", V3(lw, rr(1.5, 3.5), 0.2), frame * CF(cu + rr(-(w - lw) / 2, (w - lw) / 2), rr(12, h - 6), zf - 0.1 - li * 0.03), pick(WINDOW_LIT), MAT.Neon, "tiny")
	end
	box(m, "Crown", V3(w + 0.6, 2.4, depth + 0.6), frame * CF(cu, h - 0.9, zf + depth / 2), jitter(col, 16), MAT.Concrete, "tiny")
	if rnd() < 0.5 then
		local basePos = (frame * CF(cu, h, zf + depth / 2)).Position
		local ah = rr(14, 30)
		rod(m, "Antenna", basePos, basePos + V3(0, ah, 0), 0.8, C.steel, MAT.Metal, "tiny")
		ball(m, "AntennaLight", 1.2, basePos + V3(0, ah + 0.4, 0), C.wacaRed, MAT.Neon, "tiny")
	end
end

type SkySide = { name: string, origin: Vector3, span: number, hMin: number, hMax: number, backSpan: number, backMin: number, backMax: number, backGap: number }

local function buildSkyline(root: Instance)
	local f = folder(root, "Skyline")
	local sides: { SkySide } = {
		{ name = "North", origin = V3(0, 0, -192), span = 250, hMin = 45, hMax = 100, backSpan = 280, backMin = 95, backMax = 160, backGap = 12 },
		{ name = "South", origin = V3(0, 0, 192), span = 250, hMin = 40, hMax = 95, backSpan = 280, backMin = 90, backMax = 150, backGap = 12 },
		{ name = "East", origin = V3(192, 0, 0), span = 192, hMin = 50, hMax = 110, backSpan = 230, backMin = 100, backMax = 160, backGap = 12 },
		-- the sun sets on this side: keep it low so golden light reaches the arena
		{ name = "West", origin = V3(-192, 0, 0), span = 192, hMin = 30, hMax = 52, backSpan = 230, backMin = 55, backMax = 85, backGap = 40 },
	}
	for _, side in sides do
		local sf = folder(f, "Skyline" .. side.name)
		local frame = lookAt(side.origin, V3(0, 0, 0))
		-- front row: continuous wall of mid-rise buildings
		local u = -side.span
		while u < side.span - 10 do
			local w = rr(28, 50)
			if u + w > side.span then
				w = side.span - u
			end
			skylineBuilding(sf, frame, u + w / 2, w, rr(side.hMin, side.hMax), rr(0, 8), rr(30, 46))
			u += w + rr(0, 1.2)
		end
		-- back row: sparser, taller towers
		u = -side.backSpan
		while u < side.backSpan - 20 do
			local w = rr(28, 46)
			skylineTower(sf, frame, u + w / 2, w, rr(side.backMin, side.backMax), rr(58, 100), rr(30, 40))
			u += w + rr(side.backGap, side.backGap + 30)
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Markers, bounds, camera
-- ─────────────────────────────────────────────────────────────────────────────

local function marker(parent: Instance, name: string, pos: Vector3, target: Vector3): Part
	return box(parent, name, V3(4, 1, 4), lookAt(pos, V3(target.X, pos.Y, target.Z)), rgb(255, 255, 255), MAT.SmoothPlastic, "ghost")
end

local function buildMarkers(map: Instance)
	local spawns = folder(map, "Spawns")
	local spawnPoints = {
		V3(0, 0.5, -66), -- N: market lane
		V3(48, 0.5, -48), -- NE
		V3(66, 0.5, 0), -- E: towards the street
		V3(48, 0.5, 48), -- SE
		V3(0, 0.5, 68), -- S: WACA cordon
		V3(-48, 0.5, 48), -- SW
		V3(-66, 0.5, 0), -- W: towards the canal bridge
		V3(-48, 0.5, -48), -- NW
	}
	for i, p in spawnPoints do
		marker(spawns, "Spawn" .. i, p, V3(0, 0.5, 0))
	end

	local dummies = folder(map, "DummySpots")
	for i, x in { -8, 0, 8 } do
		local p = V3(x, 0.5, -98)
		marker(dummies, "Dummy" .. i, p, p + V3(0, 0, 10))
	end

	local bounds = folder(map, "Bounds")
	local B, T, H0, H1 = 185, 2, -12, 222
	aabb(bounds, "BoundNorth", -B - T, H0, -B - T, B + T, H1, -B, C.white, MAT.SmoothPlastic, "bound")
	aabb(bounds, "BoundSouth", -B - T, H0, B, B + T, H1, B + T, C.white, MAT.SmoothPlastic, "bound")
	aabb(bounds, "BoundEast", B, H0, -B - T, B + T, H1, B + T, C.white, MAT.SmoothPlastic, "bound")
	aabb(bounds, "BoundWest", -B - T, H0, -B - T, -B, H1, B + T, C.white, MAT.SmoothPlastic, "bound")
	aabb(bounds, "Ceiling", -B - T, 220, -B - T, B + T, 222, B + T, C.white, MAT.SmoothPlastic, "bound")

	-- character-select camera: 3/4 view of the noodle shop front with the lane and dummies
	box(map, "SelectCamera", V3(1, 1, 1), lookAt(V3(-10, 11, -76), V3(1, 12.5, -112)), rgb(255, 255, 255), MAT.SmoothPlastic, "ghost")
end

-- ─────────────────────────────────────────────────────────────────────────────
-- Public API
-- ─────────────────────────────────────────────────────────────────────────────

function MapBuilder.build(parent: Instance): Model
	seedRng(20260927)
	lightCount = 0
	breakableCount = 0

	local map = Instance.new("Model")
	map.Name = "Map"
	map:SetAttribute("Theme", "붕괴된 야시장 — WACA 사건 현장")

	local decor = folder(map, "Decor")
	local brk = folder(map, "Breakables")

	local ground = buildGround(map, decor)
	map.PrimaryPart = ground

	buildPlaza(decor, brk)
	buildNoodleShop(decor, brk)
	buildNorthRow(decor, brk)
	buildMarket(decor, brk)
	buildNorthYards(decor, brk)
	buildEast(decor, brk)
	buildCanal(decor, brk)
	buildWest(decor, brk)
	buildSouth(decor, brk)
	buildSkyline(decor)
	buildMarkers(map)

	map:SetAttribute("LightCount", lightCount)
	map:SetAttribute("BreakableCount", breakableCount)
	map.Parent = parent
	return map
end

local function removeChild(parent: Instance, name: string)
	local child = parent:FindFirstChild(name)
	while child do
		child.Parent = nil
		child = parent:FindFirstChild(name)
	end
end

function MapBuilder.applyLighting(lighting: Instance)
	local L = (lighting :: any) :: Lighting
	L.ClockTime = 17.6
	L.GeographicLatitude = 35
	L.Brightness = 2.2
	L.Ambient = rgb(70, 55, 50)
	L.OutdoorAmbient = rgb(140, 110, 95)
	L.ColorShift_Top = rgb(255, 196, 140)
	L.ColorShift_Bottom = rgb(70, 40, 60)
	L.EnvironmentDiffuseScale = 1
	L.EnvironmentSpecularScale = 1
	L.GlobalShadows = true
	L.ShadowSoftness = 0.2
	L.ExposureCompensation = 0.1
	pcall(function()
		(L :: any).Technology = Enum.Technology.Future
	end)

	for _, name in { "MapAtmosphere", "MapBloom", "MapColor", "MapSunRays", "MapSky" } do
		removeChild(L, name)
	end
	-- only one Atmosphere / Sky can be active: drop any others
	for _, child in L:GetChildren() do
		local inst: Instance = child
		if inst:IsA("Atmosphere") or inst:IsA("Sky") then
			(inst :: Instance).Parent = nil
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "MapAtmosphere"
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.1
	atmosphere.Color = rgb(255, 184, 150)
	atmosphere.Decay = rgb(120, 86, 130)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.8
	atmosphere.Parent = L

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "MapBloom"
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.4
	bloom.Parent = L

	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "MapColor"
	color.TintColor = rgb(255, 244, 228)
	color.Saturation = 0.12
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.Parent = L

	local rays = Instance.new("SunRaysEffect")
	rays.Name = "MapSunRays"
	rays.Intensity = 0.06
	rays.Spread = 0.7
	rays.Parent = L

	local sky = Instance.new("Sky")
	sky.Name = "MapSky"
	sky.SunAngularSize = 14
	sky.MoonAngularSize = 9
	sky.StarCount = 2000
	sky.Parent = L
end

return MapBuilder
