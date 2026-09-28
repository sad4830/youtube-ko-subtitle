--!strict
-- 지형 파괴 (가강전 스타일 복셀 파괴)
--
-- 맵의 건물·사물은 전부 스킬과 날아가는 몸에 부서진다.
--  · 부서지는 영역(상자/구)에 걸친 파트를 자기 축을 따라 반씩 쪼갠다.
--    영역 안에 완전히 들어간 조각은 없애고, 영역 밖 조각은 제자리에 고정된 채 남긴다 → 진짜 구멍이 뚫린다.
--    경계에 걸친 조각은 "결(grain)" 크기까지 계속 쪼갠다. 결은 영역 크기에 맞춰 커진다.
--  · 원기둥·쐐기는 모양이 유지되는 길이 축으로만 쪼개고, 공·트러스·간판(SurfaceGui)·조명이 달린 파트는 통째로 없앤다.
--  · 날아가는 잔해는 서버가 만들지 않는다. 없앤 조각 목록을 클라이언트에 보내면 각자 로컬 물리로 흩뿌린다.
--  · 일정 시간 뒤 원래 모양으로 복구한다 (그 자리에 캐릭터가 있으면 비킬 때까지 미룬다).
--  · 바닥·도로·운하·경계벽·배경 스카이라인은 부서지지 않는다.
--
-- Roblox 공간 쿼리는 CanQuery = false 인 장식 파트를 못 찾기 때문에, 파괴 대상 파트를 직접 격자에 색인해서 찾는다.

local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Destruction = {}

----------------------------------------------------------------------
-- 설정
----------------------------------------------------------------------
local Settings = Config.Destruction
local CELL = 12 -- 색인 격자 한 칸 (스터드)
local ARENA = 190 -- 이 밖(스카이라인 배경)은 색인하지 않는다
local FLOOR_TOP = 1.05 -- 윗면이 이 높이 이하인 파트는 바닥으로 보고 부수지 않는다
local FLOOR_SLAB_TOP = 1.6 -- 윗면이 이 높이 이하이고
local FLOOR_SLAB_THICK = 1.6 -- 두께가 이 이하이고
local FLOOR_SLAB_WIDE = 4 -- 가로·세로가 둘 다 이 이상인 판도 바닥 (광장 바닥·원판 장식·정자 마루처럼 살짝 올라온 바닥)
local SMALL = 8 -- propsOnly(평타 등)일 때 부술 수 있는 최대 크기
local WHOLE_BELOW = 1.6 -- 이보다 작은 파트는 쪼개지 않고 통째로

export type Opts = {
	from: Vector3?, -- 힘이 들어온 곳 (잔해가 여기서 멀어지는 쪽으로 튄다)
	dir: Vector3?, -- 주된 밀어내는 방향
	force: number?, -- 잔해 속도 배율 (기본 1)
	ash: boolean?, -- 칸자키 렌: 잔해 대신 검은 재로 무너진다
	propsOnly: boolean?, -- 작은 사물만 (평타·대시 타격)
	grain: number?, -- 가장 작은 조각 크기 (기본: 영역 크기에서 자동)
	sound: boolean?, -- false 면 소리 없이 (여러 번 연달아 부를 때)
	maxParts: number?, -- 한 번에 부술 파트 수 상한 (궁극기처럼 큰 파괴에서 늘린다)
}

-- 부서지는 영역: 상자(cf, half) 또는 구(center, radius)
type Region = {
	sphere: boolean,
	cf: CFrame,
	half: Vector3,
	center: Vector3,
	radius: number,
	r2: number,
}

-- 파트마다: 쪼갤 수 있는 축 (1 = X, 2 = Y, 3 = Z). 비어 있으면 통째로만 부서진다.
type Kind = { axes: { number }, shape: string }

type Family = {
	original: BasePart,
	parent: Instance,
	kind: Kind,
	template: BasePart?,
	pieces: { [BasePart]: boolean },
	broken: boolean,
	restoreAt: number,
	brokenAt: number,
	primaryOf: Model?, -- 이 파트가 PrimaryPart 인 모델 (로블록스는 파트가 모델 밖으로 나가면 PrimaryPart 를 비운다)
	holeMin: Vector3?, -- 없앤 부분(구멍)의 범위, 원본 기준 좌표
	holeMax: Vector3?,
}

local registered: { [BasePart]: Kind } = {} -- 지금 맵에 있는 파괴 가능한 파트 (원본 또는 조각)
local familyOf: { [BasePart]: Family } = {}
local brokenFamilies: { [Family]: boolean } = {}
local pieceCount = 0
local holding: Folder

----------------------------------------------------------------------
-- 격자 색인
----------------------------------------------------------------------
local grid: { [number]: { [BasePart]: boolean } } = {}
local cellsOf: { [BasePart]: { number } } = {}

local function key(ix: number, iz: number): number
	return (ix + 4096) * 8192 + (iz + 4096)
end

-- 회전된 상자의 월드 AABB 반 크기
local function worldHalf(cf: CFrame, size: Vector3): Vector3
	local r, u, b = cf.XVector, cf.YVector, cf.ZVector
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	return Vector3.new(
		math.abs(r.X) * hx + math.abs(u.X) * hy + math.abs(b.X) * hz,
		math.abs(r.Y) * hx + math.abs(u.Y) * hy + math.abs(b.Y) * hz,
		math.abs(r.Z) * hx + math.abs(u.Z) * hy + math.abs(b.Z) * hz
	)
end

local function indexAdd(p: BasePart)
	local h = worldHalf(p.CFrame, p.Size)
	local pos = p.Position
	local x0, x1 = math.floor((pos.X - h.X) / CELL), math.floor((pos.X + h.X) / CELL)
	local z0, z1 = math.floor((pos.Z - h.Z) / CELL), math.floor((pos.Z + h.Z) / CELL)
	local list = {}
	for ix = x0, x1 do
		for iz = z0, z1 do
			local k = key(ix, iz)
			local cell = grid[k]
			if not cell then
				cell = {}
				grid[k] = cell
			end
			cell[p] = true
			table.insert(list, k)
		end
	end
	cellsOf[p] = list
end

local function indexRemove(p: BasePart)
	local list = cellsOf[p]
	if not list then
		return
	end
	for _, k in list do
		local cell = grid[k]
		if cell then
			cell[p] = nil
		end
	end
	cellsOf[p] = nil
end

-- 월드 AABB 와 겹칠 수 있는 파트들
local function query(center: Vector3, half: Vector3): { BasePart }
	local out = {}
	local seen: { [BasePart]: boolean } = {}
	local x0, x1 = math.floor((center.X - half.X) / CELL), math.floor((center.X + half.X) / CELL)
	local z0, z1 = math.floor((center.Z - half.Z) / CELL), math.floor((center.Z + half.Z) / CELL)
	for ix = x0, x1 do
		for iz = z0, z1 do
			local cell = grid[key(ix, iz)]
			if cell then
				for p in cell do
					if not seen[p] then
						seen[p] = true
						-- 월드 AABB 끼리 겹치는지 먼저 거른다 (특히 높이)
						local ph = worldHalf(p.CFrame, p.Size)
						local d = p.Position - center
						if
							math.abs(d.X) <= ph.X + half.X
							and math.abs(d.Y) <= ph.Y + half.Y
							and math.abs(d.Z) <= ph.Z + half.Z
						then
							table.insert(out, p)
						end
					end
				end
			end
		end
	end
	return out
end

----------------------------------------------------------------------
-- 기하: 조각(회전 상자) vs 영역
----------------------------------------------------------------------
local EPS = 1e-4

-- 조각과 영역이 겹치는가
local function intersects(cf: CFrame, size: Vector3, R: Region): boolean
	if R.sphere then
		local p = cf:PointToObjectSpace(R.center)
		local dx = math.max(0, math.abs(p.X) - size.X / 2)
		local dy = math.max(0, math.abs(p.Y) - size.Y / 2)
		local dz = math.max(0, math.abs(p.Z) - size.Z / 2)
		return dx * dx + dy * dy + dz * dz <= R.r2
	end
	-- 회전 상자 두 개의 분리축 검사 (15축)
	local a1, a2, a3 = cf.XVector, cf.YVector, cf.ZVector
	local rc = R.cf
	local b1, b2, b3 = rc.XVector, rc.YVector, rc.ZVector
	local ea1, ea2, ea3 = size.X / 2, size.Y / 2, size.Z / 2
	local eb1, eb2, eb3 = R.half.X, R.half.Y, R.half.Z
	local d = rc.Position - cf.Position
	local t1, t2, t3 = d:Dot(a1), d:Dot(a2), d:Dot(a3)
	local r11, r12, r13 = a1:Dot(b1), a1:Dot(b2), a1:Dot(b3)
	local r21, r22, r23 = a2:Dot(b1), a2:Dot(b2), a2:Dot(b3)
	local r31, r32, r33 = a3:Dot(b1), a3:Dot(b2), a3:Dot(b3)
	local q11, q12, q13 = math.abs(r11) + EPS, math.abs(r12) + EPS, math.abs(r13) + EPS
	local q21, q22, q23 = math.abs(r21) + EPS, math.abs(r22) + EPS, math.abs(r23) + EPS
	local q31, q32, q33 = math.abs(r31) + EPS, math.abs(r32) + EPS, math.abs(r33) + EPS
	-- 조각의 축
	if math.abs(t1) > ea1 + eb1 * q11 + eb2 * q12 + eb3 * q13 then
		return false
	end
	if math.abs(t2) > ea2 + eb1 * q21 + eb2 * q22 + eb3 * q23 then
		return false
	end
	if math.abs(t3) > ea3 + eb1 * q31 + eb2 * q32 + eb3 * q33 then
		return false
	end
	-- 영역의 축
	if math.abs(t1 * r11 + t2 * r21 + t3 * r31) > ea1 * q11 + ea2 * q21 + ea3 * q31 + eb1 then
		return false
	end
	if math.abs(t1 * r12 + t2 * r22 + t3 * r32) > ea1 * q12 + ea2 * q22 + ea3 * q32 + eb2 then
		return false
	end
	if math.abs(t1 * r13 + t2 * r23 + t3 * r33) > ea1 * q13 + ea2 * q23 + ea3 * q33 + eb3 then
		return false
	end
	-- 교차 축 (a_i × b_j)
	if math.abs(t3 * r21 - t2 * r31) > ea2 * q31 + ea3 * q21 + eb2 * q13 + eb3 * q12 then
		return false
	end
	if math.abs(t3 * r22 - t2 * r32) > ea2 * q32 + ea3 * q22 + eb1 * q13 + eb3 * q11 then
		return false
	end
	if math.abs(t3 * r23 - t2 * r33) > ea2 * q33 + ea3 * q23 + eb1 * q12 + eb2 * q11 then
		return false
	end
	if math.abs(t1 * r31 - t3 * r11) > ea1 * q31 + ea3 * q11 + eb2 * q23 + eb3 * q22 then
		return false
	end
	if math.abs(t1 * r32 - t3 * r12) > ea1 * q32 + ea3 * q12 + eb1 * q23 + eb3 * q21 then
		return false
	end
	if math.abs(t1 * r33 - t3 * r13) > ea1 * q33 + ea3 * q13 + eb1 * q22 + eb2 * q21 then
		return false
	end
	if math.abs(t2 * r11 - t1 * r21) > ea1 * q21 + ea2 * q11 + eb2 * q33 + eb3 * q32 then
		return false
	end
	if math.abs(t2 * r12 - t1 * r22) > ea1 * q22 + ea2 * q12 + eb1 * q33 + eb3 * q31 then
		return false
	end
	if math.abs(t2 * r13 - t1 * r23) > ea1 * q23 + ea2 * q13 + eb1 * q32 + eb2 * q31 then
		return false
	end
	return true
end

-- 조각이 영역 안에 완전히 들어가는가
local function inside(cf: CFrame, size: Vector3, R: Region): boolean
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	if R.sphere then
		local p = cf:PointToObjectSpace(R.center)
		local dx, dy, dz = math.abs(p.X) + hx, math.abs(p.Y) + hy, math.abs(p.Z) + hz
		return dx * dx + dy * dy + dz * dz <= R.r2
	end
	local rc = R.cf
	local c = rc:PointToObjectSpace(cf.Position)
	local a1, a2, a3 = cf.XVector, cf.YVector, cf.ZVector
	local b1, b2, b3 = rc.XVector, rc.YVector, rc.ZVector
	local s1 = math.abs(b1:Dot(a1)) * hx + math.abs(b1:Dot(a2)) * hy + math.abs(b1:Dot(a3)) * hz
	local s2 = math.abs(b2:Dot(a1)) * hx + math.abs(b2:Dot(a2)) * hy + math.abs(b2:Dot(a3)) * hz
	local s3 = math.abs(b3:Dot(a1)) * hx + math.abs(b3:Dot(a2)) * hy + math.abs(b3:Dot(a3)) * hz
	return math.abs(c.X) + s1 <= R.half.X + EPS and math.abs(c.Y) + s2 <= R.half.Y + EPS and math.abs(c.Z) + s3 <= R.half.Z + EPS
end

local function pointInside(pos: Vector3, R: Region): boolean
	if R.sphere then
		return (pos - R.center).Magnitude <= R.radius
	end
	local c = R.cf:PointToObjectSpace(pos)
	return math.abs(c.X) <= R.half.X and math.abs(c.Y) <= R.half.Y and math.abs(c.Z) <= R.half.Z
end

type Piece = { cf: CFrame, size: Vector3 }

-- 영역에 맞춰 조각낸다. keep: 남길 조각, removed: 없앨 조각
local function fracture(cf: CFrame, size: Vector3, axes: { number }, R: Region, grain: number, keep: { Piece }, removed: { Piece }, budget: { n: number })
	if not intersects(cf, size, R) then
		table.insert(keep, { cf = cf, size = size })
		return
	end
	if inside(cf, size, R) then
		table.insert(removed, { cf = cf, size = size })
		return
	end
	-- 쪼갤 수 있는 축 중 가장 긴 축
	local best, bestLen = 0, 0
	for _, ax in axes do
		local len = if ax == 1 then size.X elseif ax == 2 then size.Y else size.Z
		if len > bestLen then
			best, bestLen = ax, len
		end
	end
	if best == 0 or bestLen <= grain or budget.n <= 0 then
		-- 더 못 쪼개면: 영역에 조금이라도 걸친 작은 조각은 없앤다.
		-- 예산이 바닥났을 때는 중심이 영역 안에 있을 때만 없앤다 (구멍이 너무 커지지 않게).
		if best == 0 or bestLen <= grain or pointInside(cf.Position, R) then
			table.insert(removed, { cf = cf, size = size })
		else
			table.insert(keep, { cf = cf, size = size })
		end
		return
	end
	budget.n -= 1
	local axis: Vector3
	local half: Vector3
	if best == 1 then
		axis = cf.XVector * (size.X / 4)
		half = Vector3.new(size.X / 2, size.Y, size.Z)
	elseif best == 2 then
		axis = cf.YVector * (size.Y / 4)
		half = Vector3.new(size.X, size.Y / 2, size.Z)
	else
		axis = cf.ZVector * (size.Z / 4)
		half = Vector3.new(size.X, size.Y, size.Z / 2)
	end
	fracture(cf + axis, half, axes, R, grain, keep, removed, budget)
	fracture(cf - axis, half, axes, R, grain, keep, removed, budget)
end

----------------------------------------------------------------------
-- 분류: 어떤 파트를 부술 수 있고, 어떻게 쪼개나
----------------------------------------------------------------------
local EXCLUDED_FOLDERS = {
	GroundSurfaces = true,
	Skyline = true,
	Bounds = true,
	Spawns = true,
	DummySpots = true,
}

local function isExcluded(p: BasePart, map: Instance): boolean
	local node: Instance? = p.Parent
	while node and node ~= map do
		if EXCLUDED_FOLDERS[node.Name] then
			return true
		end
		node = node.Parent
	end
	return false
end

local function kindOf(p: BasePart): Kind
	local shape = "Block"
	local axes: { number } = { 1, 2, 3 }
	if p:IsA("WedgePart") then
		shape = "Wedge"
		axes = { 1 }
	elseif p:IsA("Part") then
		if p.Shape == Enum.PartType.Cylinder then
			shape = "Cylinder"
			axes = { 1 }
		elseif p.Shape == Enum.PartType.Ball then
			shape = "Ball"
			axes = {}
		elseif p.Shape ~= Enum.PartType.Block then
			axes = {}
		end
	else
		-- 트러스·메시 등은 통째로
		axes = {}
	end
	-- 글씨·조명·파티클이 달린 파트는 쪼개면 어색하다 → 통째로
	for _, c in p:GetChildren() do
		if not c:IsA("Texture") then
			axes = {}
			break
		end
	end
	if p:GetAttribute("Breakable") == true or math.max(p.Size.X, p.Size.Y, p.Size.Z) < WHOLE_BELOW then
		axes = {}
	end
	return { axes = axes, shape = shape }
end

local function classify(p: BasePart, map: Instance): boolean
	if p:GetAttribute("Breakable") == true then
		return true
	end
	if p.Transparency >= 0.99 or isExcluded(p, map) then
		return false
	end
	local h = worldHalf(p.CFrame, p.Size)
	local pos = p.Position
	local top = pos.Y + h.Y
	if top <= FLOOR_TOP then
		return false -- 바닥 / 땅속 (도로, 보도, 운하 벽…)
	end
	if top <= FLOOR_SLAB_TOP and h.Y * 2 <= FLOOR_SLAB_THICK and math.min(h.X, h.Z) * 2 >= FLOOR_SLAB_WIDE then
		-- 살짝 올라온 얇은 바닥. 광장 바닥은 눕힌 원판 원기둥이라 두께 축으로만 쪼개져서 스치기만 해도 통째로 사라진다
		return false
	end
	if math.abs(pos.X) > ARENA or math.abs(pos.Z) > ARENA then
		return false
	end
	if p.Material == Enum.Material.Water then
		return false
	end
	return true
end

local function register(p: BasePart, kind: Kind)
	registered[p] = kind
	indexAdd(p)
end

local function unregister(p: BasePart)
	registered[p] = nil
	indexRemove(p)
end

----------------------------------------------------------------------
-- 파괴
----------------------------------------------------------------------
local function familyFor(p: BasePart, kind: Kind): Family
	local f = familyOf[p]
	if f then
		return f
	end
	local parent = p.Parent :: Instance
	local primaryOf: Model? = nil
	if parent:IsA("Model") and parent.PrimaryPart == p then
		primaryOf = parent
	end
	local fam: Family = {
		original = p,
		parent = parent,
		primaryOf = primaryOf,
		kind = kind,
		template = nil,
		pieces = {},
		broken = false,
		restoreAt = 0,
		brokenAt = 0,
		holeMin = nil,
		holeMax = nil,
	}
	familyOf[p] = fam
	return fam
end

local function templateOf(f: Family): BasePart
	local t = f.template
	if t then
		return t
	end
	local tmpl = f.original:Clone()
	for _, c in tmpl:GetChildren() do
		if not c:IsA("Texture") then
			c:Destroy()
		end
	end
	tmpl:SetAttribute("Broken", nil)
	f.template = tmpl
	return tmpl
end

type Group = {
	color: Color3,
	material: Enum.Material,
	transparency: number,
	shape: string,
	pieces: { Piece },
}

local function autoGrain(R: Region): number
	local minDim = if R.sphere then R.radius * 2 else math.min(R.half.X, R.half.Y, R.half.Z) * 2
	return math.clamp(minDim / 3.5, 1.25, 8)
end

local function makeRegion(sphere: boolean, cf: CFrame, half: Vector3, radius: number): Region
	return { sphere = sphere, cf = cf, half = half, center = cf.Position, radius = radius, r2 = radius * radius }
end

local function destroyRegion(R: Region, opts: Opts): number
	local now = os.clock()
	local grain = opts.grain or autoGrain(R)
	-- 조각이 너무 많으면 결을 굵게
	if pieceCount > Settings.MaxPieces * 0.75 then
		grain *= 2
	end
	local qHalf = if R.sphere then Vector3.new(R.radius, R.radius, R.radius) else worldHalf(R.cf, R.half * 2)
	local candidates = query(R.center, qHalf)
	-- 가까운 것부터 (상한에 걸려도 중심부가 먼저 부서지게)
	local dist: { [BasePart]: number } = {}
	for _, p in candidates do
		dist[p] = (p.Position - R.center).Magnitude
	end
	table.sort(candidates, function(a, b)
		return dist[a] < dist[b]
	end)

	local groups: { Group } = {}
	local affected = 0
	local sent = 0
	local budget = { n = Settings.MaxSplitsPerCall }
	local maxParts = opts.maxParts or Settings.MaxPartsPerCall

	for _, part in candidates do
		if affected >= maxParts then
			break
		end
		local kind = registered[part]
		if not kind or not part.Parent then
			continue
		end
		local sz = part.Size
		if opts.propsOnly and math.max(sz.X, sz.Y, sz.Z) > SMALL and part:GetAttribute("Breakable") ~= true then
			continue
		end
		local keep: { Piece } = {}
		local removed: { Piece } = {}
		if #kind.axes == 0 or opts.propsOnly then
			if intersects(part.CFrame, sz, R) then
				table.insert(removed, { cf = part.CFrame, size = sz })
			end
		else
			fracture(part.CFrame, sz, kind.axes, R, grain, keep, removed, budget)
		end
		if #removed == 0 then
			continue
		end
		affected += 1

		local fam = familyOf[part] or familyFor(part, kind)
		-- 구멍 범위를 원본 기준 좌표로 모아 둔다 (조각은 원본과 같은 회전). 복구할 때 이 안에 캐릭터가 있는지만 본다
		local ocf = fam.original.CFrame
		for _, r in removed do
			local c = ocf:PointToObjectSpace(r.cf.Position)
			local lo, hi = c - r.size / 2, c + r.size / 2
			local hMin, hMax = fam.holeMin, fam.holeMax
			fam.holeMin = if hMin then hMin:Min(lo) else lo
			fam.holeMax = if hMax then hMax:Max(hi) else hi
		end
		-- 잔해 목록 (너무 많으면 잘라서 보낸다 — 나머지는 먼지로만 보인다)
		local room = Settings.MaxDebrisSent - sent
		if room > 0 then
			if #removed > room then
				local cut = {}
				for i = 1, room do
					cut[i] = removed[i]
				end
				removed = cut
			end
			sent += #removed
			table.insert(groups, {
				color = part.Color,
				material = part.Material,
				transparency = part.Transparency,
				shape = kind.shape,
				pieces = removed,
			})
		end

		-- 원래 파트(또는 조각)를 맵에서 뺀다
		unregister(part)
		if part == fam.original then
			templateOf(fam)
			part.Parent = holding
			fam.broken = true
			fam.brokenAt = now
			brokenFamilies[fam] = true
		else
			fam.pieces[part] = nil
			familyOf[part] = nil
			pieceCount -= 1
			part:Destroy()
		end
		fam.restoreAt = now + Settings.RestoreTime

		-- 남는 조각을 제자리에 고정해서 만든다
		if #keep > 0 then
			local tmpl = templateOf(fam)
			for _, k in keep do
				local piece = tmpl:Clone()
				piece.Size = k.size
				piece.CFrame = k.cf
				piece.Anchored = true
				piece.Parent = fam.parent
				fam.pieces[piece] = true
				familyOf[piece] = fam
				pieceCount += 1
				register(piece, fam.kind)
			end
		end
	end

	if affected > 0 then
		local from = opts.from or R.center
		local dir = opts.dir
		Remotes.FX:FireAllClients("Shatter", {
			center = R.center,
			radius = if R.sphere then R.radius else R.half.Magnitude,
			from = from,
			dir = if dir and dir.Magnitude > 0.01 then dir.Unit else Vector3.zero,
			force = opts.force or 1,
			ash = opts.ash == true,
			sound = opts.sound ~= false,
			groups = groups,
		})
	end
	-- 조각이 한도를 넘으면 오래된 것부터 빨리 복구
	if pieceCount > Settings.MaxPieces then
		local list: { Family } = {}
		for f in brokenFamilies do
			table.insert(list, f)
		end
		table.sort(list, function(a, b)
			return a.brokenAt < b.brokenAt
		end)
		local over = pieceCount - Settings.MaxPieces
		for _, f in list do
			if over <= 0 then
				break
			end
			local n = 0
			for _ in f.pieces do
				n += 1
			end
			-- 조각 없이 통째로 사라진 가족은 복구해도 조각 수가 줄지 않는다 (궁극기 직후엔 이런 가족이 수백 개)
			if n > 0 then
				f.restoreAt = 0
				over -= n
			end
		end
	end
	return affected
end

----------------------------------------------------------------------
-- 공개 API
----------------------------------------------------------------------
-- 회전 상자 영역 (cf = 가운데, size = 전체 크기) 안을 부순다. 부서진 파트 수를 돌려준다.
function Destruction.destroyBox(cf: CFrame, size: Vector3, opts: Opts?): number
	return destroyRegion(makeRegion(false, cf, size / 2, 0), opts or {})
end

-- 구 영역 안을 부순다
function Destruction.destroySphere(center: Vector3, radius: number, opts: Opts?): number
	return destroyRegion(makeRegion(true, CFrame.new(center), Vector3.new(radius, radius, radius), radius), opts or {})
end

function Destruction.isDestructible(part: Instance): boolean
	return part:IsA("BasePart") and registered[part] ~= nil
end

function Destruction.pieceCount(): number
	return pieceCount
end

----------------------------------------------------------------------
-- 복구
----------------------------------------------------------------------
local occupancy = OverlapParams.new()
occupancy.FilterType = Enum.RaycastFilterType.Include

local function charactersAt(cf: CFrame, size: Vector3): boolean
	local chars: { Instance } = {}
	for _, m in workspace:GetChildren() do
		if m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
			table.insert(chars, m)
		end
	end
	if #chars == 0 then
		return false
	end
	occupancy.FilterDescendantsInstances = chars
	return #workspace:GetPartBoundsInBox(cf, size + Vector3.new(0.5, 0.5, 0.5), occupancy) > 0
end

local function restore(f: Family): boolean
	local o = f.original
	-- 구멍 자리에 캐릭터가 있으면 미룬다. 원본 전체로 보면 큰 바닥·건물 위 먼 곳에 서 있기만 해도 영영 안 돌아온다
	local cf, size = o.CFrame, o.Size
	local lo, hi = f.holeMin, f.holeMax
	if lo and hi then
		cf = o.CFrame * CFrame.new((lo + hi) / 2)
		size = hi - lo
	end
	if charactersAt(cf, size) then
		f.restoreAt = os.clock() + 2
		return false
	end
	f.holeMin = nil
	f.holeMax = nil
	for piece in f.pieces do
		unregister(piece)
		familyOf[piece] = nil
		pieceCount -= 1
		piece:Destroy()
	end
	table.clear(f.pieces)
	o.Parent = f.parent
	local model = f.primaryOf
	if model and model.PrimaryPart == nil then
		model.PrimaryPart = o
	end
	register(o, f.kind)
	f.broken = false
	brokenFamilies[f] = nil
	return true
end

local function restoreTick()
	local now = os.clock()
	local restoredPos: { Vector3 } = {}
	local restoredSize: { Vector3 } = {}
	local done = 0
	for f in brokenFamilies do
		if done >= Settings.RestorePerTick then
			break
		end
		if f.restoreAt <= now then
			if restore(f) then
				done += 1
				if #restoredPos < 24 then
					table.insert(restoredPos, f.original.Position)
					table.insert(restoredSize, f.original.Size)
				end
			end
		end
	end
	if #restoredPos > 0 then
		Remotes.FX:FireAllClients("Rebuild", { positions = restoredPos, sizes = restoredSize })
	end
end

----------------------------------------------------------------------
function Destruction.init(map: Instance)
	local h = ServerStorage:FindFirstChild("DestroyedMap")
	if h and h:IsA("Folder") then
		holding = h
	else
		holding = Instance.new("Folder")
		holding.Name = "DestroyedMap"
		holding.Parent = ServerStorage
	end
	local count = 0
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") and classify(d, map) then
			register(d, kindOf(d))
			count += 1
		end
	end
	map:SetAttribute("DestructibleCount", count)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.5 then
			acc = 0
			restoreTick()
		end
	end)
end

-- 테스트용: 내부 함수 노출
Destruction._test = {
	intersects = intersects,
	inside = inside,
	fracture = fracture,
	makeRegion = makeRegion,
	classify = classify,
	kindOf = kindOf,
	worldHalf = worldHalf,
	query = query,
	restoreAll = function()
		for f in brokenFamilies do
			f.restoreAt = 0
		end
		restoreTick()
	end,
}

return Destruction
