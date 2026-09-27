--[[
	tools/preview_map.luau — Lune (0.10) preview / validation for src/server/MapBuilder.luau

	Usage (from the project root):
		lune run tools/preview_map.luau                      -- build, validate, write build/map_preview.rbxl
		lune run tools/preview_map.luau -- --dump parts.json -- additionally dump every BasePart as JSON

	The module is loaded with the Roblox datatypes from @lune/roblox injected as globals, exactly
	like it would see them inside Roblox, then built into a fresh DataModel.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local MODULE_PATH = "src/server/MapBuilder.luau"
local OUT_PATH = "build/map_preview.rbxl"

local MAX_PARTS = 3000
local MAX_LIGHTS = 40
local MIN_BREAKABLES, MAX_BREAKABLES = 60, 120
local MAX_BREAKABLE_SIZE = 8

-- ── argument parsing ─────────────────────────────────────────────────────────
local dumpPath: string? = nil
do
	local args = process.args
	local i = 1
	while i <= #args do
		if args[i] == "--dump" then
			dumpPath = args[i + 1]
			i += 2
		else
			i += 1
		end
	end
end

-- ── static source checks ─────────────────────────────────────────────────────
local source = fs.readFile(MODULE_PATH)

local failures: { string } = {}
local function check(cond: boolean, msg: string)
	if not cond then
		table.insert(failures, msg)
	end
end

do
	-- strip comments so prose in the header does not trigger the API checks
	local code = source:gsub("%-%-%[(=*)%[.-%]%1%]", ""):gsub("%-%-[^\n]*", "")
	check(source:find("rbxasset" .. "id", 1, true) == nil, "source contains an asset id")
	local forbidden = {
		{ "%f[%w_]game%f[^%w_]", "game" },
		{ "%f[%w_]workspace%f[^%w_]", "workspace" },
		{ "%f[%w_]script%f[^%w_]", "script" },
		{ "%f[%w_]task%.", "task library" },
		{ "%f[%w_]wait%s*%(", "wait()" },
		{ "%f[%w_]spawn%s*%(", "spawn()" },
		{ "%f[%w_]tick%s*%(", "tick()" },
		{ "os%.clock", "os.clock" },
		{ "math%.random", "math.random" },
		{ "Random%.new", "Random.new" },
		{ ":PivotTo", ":PivotTo" },
		{ "GetService", "GetService" },
		{ "CollectionService", "CollectionService" },
		{ "%.Font%s*=", "legacy .Font (use FontFace = Font.fromEnum)" },
		-- Lune 0.10's CFrame.lookAt mirrors Z, so the preview would diverge from Roblox
		{ "CFrame%.lookAt", "CFrame.lookAt (use the fromMatrix-based lookAt helper)" },
		{ "Terrain", "Terrain" },
		{ ":Destroy", ":Destroy" },
	}
	for _, f in forbidden do
		check(code:find(f[1]) == nil, "source uses forbidden API: " .. f[2])
	end
	check(source:sub(1, 9) == "--!strict", "source must start with --!strict")
end

-- ── load the module with Roblox datatypes injected ───────────────────────────
local env = {
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	Vector2 = roblox.Vector2,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	BrickColor = roblox.BrickColor,
	Enum = roblox.Enum,
	NumberSequence = roblox.NumberSequence,
	NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
	ColorSequence = roblox.ColorSequence,
	ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
	NumberRange = roblox.NumberRange,
	UDim = roblox.UDim,
	UDim2 = roblox.UDim2,
	PhysicalProperties = roblox.PhysicalProperties,
	Font = roblox.Font,
}

local function loadBuilder()
	local chunk = luau.load(source, { debugName = "MapBuilder", environment = env })
	return chunk()
end

local MapBuilder = loadBuilder()

local game = roblox.Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")

MapBuilder.build(workspace)
MapBuilder.applyLighting(lighting)
MapBuilder.applyLighting(lighting) -- must be idempotent

local map = workspace:FindFirstChild("Map")
assert(map ~= nil and map.ClassName == "Model", "MapBuilder.build did not create Model 'Map'")

-- ── gather ───────────────────────────────────────────────────────────────────
local function vecStr(v): string
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

local function aabbOf(p): (any, any)
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local hx = math.abs(r.X) * s.X / 2 + math.abs(u.X) * s.Y / 2 + math.abs(l.X) * s.Z / 2
	local hy = math.abs(r.Y) * s.X / 2 + math.abs(u.Y) * s.Y / 2 + math.abs(l.Y) * s.Z / 2
	local hz = math.abs(r.Z) * s.X / 2 + math.abs(u.Z) * s.Y / 2 + math.abs(l.Z) * s.Z / 2
	local c = cf.Position
	return roblox.Vector3.new(c.X - hx, c.Y - hy, c.Z - hz), roblox.Vector3.new(c.X + hx, c.Y + hy, c.Z + hz)
end

local parts = {}
local lights = {}
local guis = 0
local emitters = 0
for _, d in map:GetDescendants() do
	if d:IsA("BasePart") then
		table.insert(parts, d)
	elseif d:IsA("Light") then
		table.insert(lights, d)
	elseif d:IsA("SurfaceGui") then
		guis += 1
	elseif d:IsA("ParticleEmitter") then
		emitters += 1
	end
end

local breakables = {}
local unanchored = 0
local minB, maxB = roblox.Vector3.new(math.huge, math.huge, math.huge), roblox.Vector3.new(-math.huge, -math.huge, -math.huge)
local arenaMin, arenaMax = minB, maxB
local byFolder: { [string]: number } = {}
for _, p in parts do
	if not p.Anchored then
		unanchored += 1
	end
	if p:GetAttribute("Breakable") == true then
		table.insert(breakables, p)
	end
	local lo, hi = aabbOf(p)
	minB = roblox.Vector3.new(math.min(minB.X, lo.X), math.min(minB.Y, lo.Y), math.min(minB.Z, lo.Z))
	maxB = roblox.Vector3.new(math.max(maxB.X, hi.X), math.max(maxB.Y, hi.Y), math.max(maxB.Z, hi.Z))
	local inSkyline = p:FindFirstAncestor("Skyline") ~= nil
	local isGround = p.Size.X > 300 or p.Size.Z > 300
	if not inSkyline and not isGround and p.Parent.Name ~= "Bounds" then
		arenaMin = roblox.Vector3.new(math.min(arenaMin.X, lo.X), math.min(arenaMin.Y, lo.Y), math.min(arenaMin.Z, lo.Z))
		arenaMax = roblox.Vector3.new(math.max(arenaMax.X, hi.X), math.max(arenaMax.Y, hi.Y), math.max(arenaMax.Z, hi.Z))
	end
	-- count per top-level zone folder
	local node = p
	local key = "?"
	while node.Parent and node.Parent ~= map do
		if node.Parent.Parent == map and node.Parent.Name == "Decor" then
			key = "Decor/" .. node.Name
			break
		end
		node = node.Parent
	end
	if key == "?" then
		key = if p.Parent == map then p.Name else (node.Name or "?")
	end
	byFolder[key] = (byFolder[key] or 0) + 1
end

-- ── required structure ───────────────────────────────────────────────────────
local function child(name: string, class: string?)
	local c = map:FindFirstChild(name)
	check(c ~= nil, "missing child '" .. name .. "'")
	if c and class then
		check(c:IsA(class), "'" .. name .. "' should be a " .. class .. " (is " .. c.ClassName .. ")")
	end
	return c
end

local spawnsF = child("Spawns", "Folder")
local dummiesF = child("DummySpots", "Folder")
child("Breakables", "Folder")
child("Decor", "Folder")
local boundsF = child("Bounds", "Folder")
local cam = child("SelectCamera", "BasePart")
local ground = child("Ground", "BasePart")
check(map.PrimaryPart == ground, "Map.PrimaryPart must be the Ground part")
if ground then
	check(math.abs(ground.CFrame.Position.Y + ground.Size.Y / 2) < 1e-3, "Ground top must be at y = 0")
end

local function checkMarker(p, label: string)
	check(p:IsA("BasePart"), label .. " is not a BasePart")
	check(p.Transparency == 1, label .. " must be invisible")
	check(p.Anchored, label .. " must be anchored")
	check(not p.CanCollide and not p.CanQuery and not p.CanTouch, label .. " must not collide/query/touch")
	check((p.Size - roblox.Vector3.new(4, 1, 4)).Magnitude < 1e-3, label .. " must be 4x1x4")
	check(math.abs(p.CFrame.Position.Y - 0.5) < 1e-3, label .. " must be at y = 0.5")
end

local spawnList = if spawnsF then spawnsF:GetChildren() else {}
check(#spawnList == 8, "expected 8 spawns, found " .. #spawnList)
for _, s in spawnList do
	checkMarker(s, "spawn " .. s.Name)
	local toCentre = (roblox.Vector3.new(0, s.CFrame.Position.Y, 0) - s.CFrame.Position).Unit
	check(s.CFrame.LookVector:Dot(toCentre) > 0.99, "spawn " .. s.Name .. " does not face the centre")
end
local dummyList = if dummiesF then dummiesF:GetChildren() else {}
check(#dummyList == 3, "expected 3 dummy spots, found " .. #dummyList)
for _, s in dummyList do
	checkMarker(s, "dummy " .. s.Name)
	check(s.CFrame.LookVector.Z > 0.99, "dummy " .. s.Name .. " must face south (+Z)")
end
if cam then
	check(cam.Transparency == 1 and cam.Anchored and not cam.CanCollide and not cam.CanQuery and not cam.CanTouch, "SelectCamera flags")
end
if boundsF then
	local b = boundsF:GetChildren()
	check(#b >= 5, "expected 4 walls + ceiling in Bounds")
	for _, w in b do
		check(w.Transparency == 1 and w.CanCollide and not w.CanQuery and not w.CanTouch and w.Anchored, "bound " .. w.Name .. " flags")
	end
	local ceiling = boundsF:FindFirstChild("Ceiling")
	check(ceiling ~= nil and math.abs(ceiling.CFrame.Position.Y - ceiling.Size.Y / 2 - 220) < 1e-3, "ceiling must start at y = 220")
end

-- ── constraints ──────────────────────────────────────────────────────────────
check(#parts <= MAX_PARTS, "BasePart count " .. #parts .. " exceeds " .. MAX_PARTS)
check(unanchored == 0, unanchored .. " parts are not anchored")
check(#lights <= MAX_LIGHTS, "light count " .. #lights .. " exceeds " .. MAX_LIGHTS)
check(#breakables >= MIN_BREAKABLES and #breakables <= MAX_BREAKABLES, "breakable count " .. #breakables .. " outside [60,120]")
for _, p in breakables do
	local s = p.Size
	check(math.max(s.X, s.Y, s.Z) <= MAX_BREAKABLE_SIZE + 1e-6, "breakable " .. p:GetFullName() .. " larger than 8 studs")
	check(p.CanCollide and p.CanQuery and p.Anchored, "breakable " .. p:GetFullName() .. " must be anchored + CanCollide + CanQuery")
	check(p:FindFirstAncestor("Breakables") ~= nil, "breakable " .. p:GetFullName() .. " is outside the Breakables folder")
end
for _, p in parts do
	local lo, hi = aabbOf(p)
	if p.Parent.Name ~= "Bounds" then
		check(lo.Y >= -10.5 and hi.Y <= 230, "part " .. p:GetFullName() .. " is out of the vertical range [-10.5, 230]")
	end
	check(p.TopSurface == roblox.Enum.SurfaceType.Smooth and p.BottomSurface == roblox.Enum.SurfaceType.Smooth, "part " .. p:GetFullName() .. " has studs")
	if p:FindFirstAncestor("Breakables") and p:GetAttribute("Breakable") ~= true then
		check(false, "part in Breakables without Breakable attribute: " .. p:GetFullName())
	end
end

-- determinism: a second build must be identical
do
	local function signature(root): string
		local out = {}
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") then
				local c = d.CFrame.Position
				table.insert(out, string.format("%s%.3f,%.3f,%.3f;%.3f,%.3f,%.3f", d.Name, c.X, c.Y, c.Z, d.Size.X, d.Size.Y, d.Size.Z))
			end
		end
		return table.concat(out, "|")
	end
	local game2 = roblox.Instance.new("DataModel")
	local ws2 = game2:GetService("Workspace")
	loadBuilder().build(ws2)
	check(signature(map) == signature(ws2:FindFirstChild("Map")), "build is not deterministic")
end

-- ── report ───────────────────────────────────────────────────────────────────
print("=== 금빛과 재 · Map preview ===")
print(string.format("BaseParts      %d / %d", #parts, MAX_PARTS))
print(string.format("Lights         %d / %d", #lights, MAX_LIGHTS))
print(string.format("Breakables     %d (allowed %d-%d)", #breakables, MIN_BREAKABLES, MAX_BREAKABLES))
print(string.format("Spawns         %d   DummySpots %d", #spawnList, #dummyList))
print(string.format("SurfaceGuis    %d   ParticleEmitters %d", guis, emitters))
print(string.format("Bounding box   %s .. %s (everything)", vecStr(minB), vecStr(maxB)))
print(string.format("Arena content  %s .. %s (no skyline/ground/bounds)", vecStr(arenaMin), vecStr(arenaMax)))
local keys = {}
for k in byFolder do
	table.insert(keys, k)
end
table.sort(keys)
print("Parts per zone:")
for _, k in keys do
	print(string.format("  %-28s %5d", k, byFolder[k]))
end
for _, s in spawnList do
	print(string.format("  %-8s %s", s.Name, vecStr(s.CFrame.Position)))
end
for _, s in dummyList do
	print(string.format("  %-8s %s", s.Name, vecStr(s.CFrame.Position)))
end
if cam then
	print(string.format("  SelectCamera pos %s look %s", vecStr(cam.CFrame.Position), vecStr(cam.CFrame.LookVector)))
end

-- ── optional JSON dump for external tooling (top-down renderer etc.) ─────────
if dumpPath then
	local out = { parts = {}, lights = {} }
	for _, p in parts do
		local c = p.CFrame
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = c:GetComponents()
		local shape = "Block"
		if p.ClassName == "Part" then
			shape = p.Shape.Name
		elseif p.ClassName == "WedgePart" then
			shape = "Wedge"
		elseif p.ClassName == "TrussPart" then
			shape = "Truss"
		end
		table.insert(out.parts, {
			name = p.Name,
			path = p:GetFullName(),
			class = p.ClassName,
			shape = shape,
			size = { p.Size.X, p.Size.Y, p.Size.Z },
			cframe = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			color = { math.floor(p.Color.R * 255 + 0.5), math.floor(p.Color.G * 255 + 0.5), math.floor(p.Color.B * 255 + 0.5) },
			material = p.Material.Name,
			transparency = p.Transparency,
			canCollide = p.CanCollide,
			canQuery = p.CanQuery,
			breakable = p:GetAttribute("Breakable") == true,
		})
	end
	for _, l in lights do
		local pos = l.Parent.CFrame.Position
		table.insert(out.lights, { class = l.ClassName, pos = { pos.X, pos.Y, pos.Z }, range = l.Range })
	end
	fs.writeFile(dumpPath, serde.encode("json", out))
	print("wrote " .. dumpPath)
end

-- ── write the place ──────────────────────────────────────────────────────────
-- every text object must carry a real Font datatype, otherwise serializePlace rejects it
for _, d in game:GetDescendants() do
	if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
		check(typeof(d.FontFace) == "Font", "text object without FontFace: " .. d:GetFullName())
	end
end

if #failures > 0 then
	print(string.format("\n%d CHECK(S) FAILED:", #failures))
	for i, f in failures do
		if i > 40 then
			print("  ...")
			break
		end
		print("  - " .. f)
	end
	process.exit(1)
end

if not fs.isDir("build") then
	fs.writeDir("build")
end
fs.writeFile(OUT_PATH, roblox.serializePlace(game))
print("\nAll checks passed. Wrote " .. OUT_PATH)
