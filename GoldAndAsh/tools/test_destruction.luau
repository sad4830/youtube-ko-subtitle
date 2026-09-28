--[[
	tools/test_destruction.luau — 지형 파괴(src/server/Destruction.luau) 검사 (Lune 0.10)

	구운 맵(build/GoldAndAsh.rbxl)을 읽어서 Destruction 모듈을 로블록스 밖에서 그대로 돌려 본다.
	모듈 코드는 고치지 않고, 모듈이 쓰는 로블록스 서비스만 가짜로 넣어 준다.

	  A. 분류       — 부서지는 파트 / 안 부서지는 파트 (Decor 하위 폴더별), 사람이 판단할 의심스러운 분류 목록
	  B. 기하       — 무작위 회전 상자·영역 수천 개로 fracture / intersects / inside 성질 검사
	  C. 맵 시나리오 — 국수집 벽, 야시장 노점, 광장, WACA 구역 건물, 운하 다리, 동쪽 거리 가로등·차,
	                   렌의 전력 참격(상자), 평타(propsOnly), 궁극기(r=60). 하나씩 부수고 → 검사 → 복구
	  D. 복구       — 전부 누적해서 부순 뒤 Heartbeat 만 돌려서 맵이 처음과 완전히 같아지는지,
	                   캐릭터가 서 있을 때 복구를 미루는지
	  E. 반복 파괴   — 같은 벽을 겹치게·붙여서 여러 번 (조각의 조각)
	  F. 예산       — r=60 연속 두 번, 작은 타격 200번, 몸이 건물 관통, 조각 수 상한(MaxPieces)과 조기 복구, 호출당 시간
	  G. 경계 사례   — 빈 곳, 반지름 0, NaN, 아주 큰 영역, Shatter 기본값, propsOnly, 잔해 상한에서 자르기

	섹션 안에서 오류가 나면 (모듈이 던진 오류 포함) "X!" 실패로 기록하고 다음 섹션을 계속 돈다.

	사용법 (프로젝트 루트에서):
		lune run tools/test_destruction.luau
		lune run tools/test_destruction.luau -- --seed 7 --trials 5000 --pairs 50000
		lune run tools/test_destruction.luau -- --only A,B            -- 일부만
		lune run tools/test_destruction.luau -- --dump <폴더>         -- 렌더용 JSON (시나리오 전/후 주변 파트)
		lune run tools/test_destruction.luau -- --report <파일.json>  -- 결과·수치를 JSON 으로
		lune run tools/test_destruction.luau -- --module <경로>       -- 패치한 Destruction.luau 사본 검사

	실패가 하나라도 있으면 종료 코드 1.

	Lune 에서 돌리기 위한 우회 (로블록스에서는 필요 없다):
	  · Lune 0.10 의 BasePart 에는 Position 값이 없다 (파일에 저장되지 않는 속성이라 "missing default value" 오류).
	    그래서 모듈 소스의 `식.Position` 을 `__pos(식)` 으로 바꿔서 불러온다. __pos 는 파트면 CFrame.Position,
	    CFrame 이면 .Position 을 돌려준다. 줄 수는 그대로라 오류 줄 번호는 원본과 같다.
	    (CFrame.XVector/YVector/ZVector, PointToObjectSpace 는 Lune 에도 있어서 따로 채우지 않는다)
	  · Lune 의 Instance 는 같은 파트라도 꺼낼 때마다 다른 userdata 라서 테이블 키로 쓸 수 없다.
	    하네스는 GetDebugId() 로 파트를 구분한다. 모듈은 자기가 넣어 둔 값을 다시 꺼내 쓰므로 영향이 없지만,
	    바깥에서 새로 꺼낸 파트로 isDestructible 을 부르면 Lune 에서는 항상 false 다.
	  · 원본마다 HarnessOrigin 속성(DebugId)을 붙여 둔다. 조각은 원본을 복제해서 만들어지므로 어느 원본에서
	    나왔는지 알 수 있다. 모듈은 Breakable 속성만 읽으니 동작에는 영향이 없다.
	  · 모듈 안의 os.clock 은 가상 시계다. 복구 시간(35초)을 실제로 기다리지 않고 Heartbeat 를 돌려서 앞당긴다.
	    호출당 시간은 하네스의 진짜 os.clock 으로 잰다 (Lune 은 속성 접근이 로블록스보다 느리니 참고용).
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

----------------------------------------------------------------------
-- 인자
----------------------------------------------------------------------
local opt = {
	seed = 20260928,
	trials = 3000, -- B: fracture 성질 검사 횟수
	pairs = 30000, -- B: intersects / inside 교차 검증 쌍 수
	stress = 200, -- F: 작은 타격 수
	module = "src/server/Destruction.luau",
	config = "src/shared/Config.luau",
	place = "build/GoldAndAsh.rbxl",
	dump = nil :: string?,
	report = nil :: string?,
	only = nil :: { [string]: boolean }?,
}
do
	local args = process.args
	local i = 1
	while i <= #args do
		local a, v = args[i], args[i + 1]
		if a == "--" then
			i += 1
		elseif a == "--seed" then
			opt.seed = assert(tonumber(v), "--seed 숫자")
			i += 2
		elseif a == "--trials" then
			opt.trials = assert(tonumber(v), "--trials 숫자")
			i += 2
		elseif a == "--pairs" then
			opt.pairs = assert(tonumber(v), "--pairs 숫자")
			i += 2
		elseif a == "--stress" then
			opt.stress = assert(tonumber(v), "--stress 숫자")
			i += 2
		elseif a == "--module" then
			opt.module = assert(v, "--module 경로")
			i += 2
		elseif a == "--place" then
			opt.place = assert(v, "--place 경로")
			i += 2
		elseif a == "--dump" then
			opt.dump = assert(v, "--dump 폴더")
			i += 2
		elseif a == "--report" then
			opt.report = assert(v, "--report 파일")
			i += 2
		elseif a == "--only" then
			local set = {}
			for s in string.gmatch(assert(v, "--only A,B,..."), "[^,]+") do
				set[string.upper(s)] = true
			end
			opt.only = set
			i += 2
		else
			error("알 수 없는 인자: " .. tostring(a))
		end
	end
end

local function enabled(section: string): boolean
	return opt.only == nil or opt.only[section] == true
end

----------------------------------------------------------------------
-- 결과 기록
----------------------------------------------------------------------
type Result = { id: string, name: string, ok: boolean, detail: string }
local results: { Result } = {}
local report: { [string]: any } = { results = results, scenarios = {}, perf = {}, suspicious = {} }

local function check(id: string, name: string, ok: boolean, detail: string?): boolean
	table.insert(results, { id = id, name = name, ok = ok, detail = detail or "" })
	local tail = if detail and detail ~= "" then "  — " .. detail else ""
	print(string.format("  [%s] %-5s %s%s", if ok then "PASS" else "FAIL", id, name, tail))
	return ok
end

local function section(title: string)
	print("\n" .. string.rep("=", 96))
	print(title)
	print(string.rep("=", 96))
end

local function note(fmt: string, ...: any)
	print("    " .. string.format(fmt, ...))
end

-- 문제 목록: 개수는 전부 세고 예시는 몇 개만 남긴다
type Problems = { n: number, list: { string } }
local function problems(): Problems
	return { n = 0, list = {} }
end
local function bad(P: Problems, fmt: string, ...: any)
	P.n += 1
	if #P.list < 6 then
		table.insert(P.list, string.format(fmt, ...))
	end
end
local function describe(P: Problems): string
	if P.n == 0 then
		return ""
	end
	return string.format("%d건: %s", P.n, table.concat(P.list, " | "))
end

local function percentile(list: { number }, p: number): number
	if #list == 0 then
		return 0
	end
	local s = table.clone(list)
	table.sort(s)
	return s[math.clamp(math.ceil(#s * p), 1, #s)]
end

local function fmtV(v: Vector3): string
	return string.format("(%.1f, %.1f, %.1f)", v.X, v.Y, v.Z)
end

----------------------------------------------------------------------
-- 숫자 기하 (모듈과 독립적인 기준 구현)
----------------------------------------------------------------------
-- 회전 상자: 가운데 c, 축 ax[1..3] (단위 벡터), 반 크기 h
type Box = { c: { number }, ax: { { number } }, h: { number } }

local function boxOf(cf: CFrame, size: Vector3): Box
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return {
		c = { x, y, z },
		ax = { { r00, r10, r20 }, { r01, r11, r21 }, { r02, r12, r22 } },
		h = { size.X / 2, size.Y / 2, size.Z / 2 },
	}
end

local function dot(a: { number }, b: { number }): number
	return a[1] * b[1] + a[2] * b[2] + a[3] * b[3]
end

local function toLocal(B: Box, p: { number }): { number }
	local d = { p[1] - B.c[1], p[2] - B.c[2], p[3] - B.c[3] }
	return { dot(d, B.ax[1]), dot(d, B.ax[2]), dot(d, B.ax[3]) }
end

local function toWorld(B: Box, l: { number }): { number }
	local a1, a2, a3 = B.ax[1], B.ax[2], B.ax[3]
	return {
		B.c[1] + a1[1] * l[1] + a2[1] * l[2] + a3[1] * l[3],
		B.c[2] + a1[2] * l[1] + a2[2] * l[2] + a3[2] * l[3],
		B.c[3] + a1[3] * l[1] + a2[3] * l[2] + a3[3] * l[3],
	}
end

local function corners(B: Box): { { number } }
	local out = {}
	for sx = -1, 1, 2 do
		for sy = -1, 1, 2 do
			for sz = -1, 1, 2 do
				table.insert(out, toWorld(B, { sx * B.h[1], sy * B.h[2], sz * B.h[3] }))
			end
		end
	end
	return out
end

local function volume(B: Box): number
	return 8 * B.h[1] * B.h[2] * B.h[3]
end

-- 월드 AABB 반 크기
local function aabbHalf(B: Box): { number }
	local out = { 0, 0, 0 }
	for i = 1, 3 do
		for j = 1, 3 do
			out[i] += math.abs(B.ax[j][i]) * B.h[j]
		end
	end
	return out
end

local function cross(a: { number }, b: { number }): { number }
	return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] }
end

local function projRadius(B: Box, L: { number }): number
	return B.h[1] * math.abs(dot(B.ax[1], L)) + B.h[2] * math.abs(dot(B.ax[2], L)) + B.h[3] * math.abs(dot(B.ax[3], L))
end

-- 분리축 15개 중 가장 큰 틈. 양수면 그만큼 떨어져 있다 (정확한 거리는 아니지만 부호는 정확하다)
local function satGap(A: Box, B: Box): number
	local d = { B.c[1] - A.c[1], B.c[2] - A.c[2], B.c[3] - A.c[3] }
	local best = -math.huge
	local function try(L: { number })
		local len = math.sqrt(dot(L, L))
		if len < 1e-6 then
			return -- 평행한 모서리: 면 축들이 이미 검사한다
		end
		local u = { L[1] / len, L[2] / len, L[3] / len }
		local g = math.abs(dot(d, u)) - projRadius(A, u) - projRadius(B, u)
		if g > best then
			best = g
		end
	end
	for i = 1, 3 do
		try(A.ax[i])
		try(B.ax[i])
	end
	for i = 1, 3 do
		for j = 1, 3 do
			try(cross(A.ax[i], B.ax[j]))
		end
	end
	return best
end

local function clampInto(B: Box, p: { number }, shrink: number): { number }
	local l = toLocal(B, p)
	for i = 1, 3 do
		local h = math.max(B.h[i] - shrink, 0)
		l[i] = math.clamp(l[i], -h, h)
	end
	return toWorld(B, l)
end

local function insideBox(B: Box, p: { number }, shrink: number): boolean
	local l = toLocal(B, p)
	for i = 1, 3 do
		if math.abs(l[i]) > math.max(B.h[i] - shrink, 0) + 1e-9 then
			return false
		end
	end
	return true
end

-- 두 상자가 확실히 겹치는가: 여유(margin)만큼 줄인 두 상자에 동시에 들어가는 점(증인)을 찾는다.
-- 번갈아 투영하기(두 볼록 집합이 겹치면 교집합의 점으로 수렴)와 무작위 표본을 함께 쓴다.
local function overlapWitness(A: Box, B: Box, margin: number, samples: number): boolean
	local p = B.c
	for _ = 1, 48 do
		p = clampInto(A, p, margin)
		p = clampInto(B, p, margin)
	end
	if insideBox(A, p, margin) and insideBox(B, p, margin) then
		return true
	end
	for _ = 1, samples do
		local q = toWorld(A, { (math.random() * 2 - 1) * A.h[1], (math.random() * 2 - 1) * A.h[2], (math.random() * 2 - 1) * A.h[3] })
		if insideBox(A, q, margin) and insideBox(B, q, margin) then
			return true
		end
	end
	return false
end

-- 구 가운데에서 상자까지 거리 / 가장 먼 꼭짓점까지 거리
local function sphereNear(B: Box, c: { number }): number
	local l = toLocal(B, c)
	local s = 0
	for i = 1, 3 do
		local e = math.max(0, math.abs(l[i]) - B.h[i])
		s += e * e
	end
	return math.sqrt(s)
end

local function sphereFar(B: Box, c: { number }): number
	local l = toLocal(B, c)
	local s = 0
	for i = 1, 3 do
		local e = math.abs(l[i]) + B.h[i]
		s += e * e
	end
	return math.sqrt(s)
end

-- 상자 A 가 상자 B 에서 얼마나 튀어나왔나 (양수 = 밖으로 나감, 음수 = 그만큼 안쪽)
local function boxOut(A: Box, B: Box): number
	local worst = -math.huge
	for _, p in corners(A) do
		local l = toLocal(B, p)
		for i = 1, 3 do
			worst = math.max(worst, math.abs(l[i]) - B.h[i])
		end
	end
	return worst
end

-- 기준 영역 (모듈의 Region 과 같은 뜻)
type RefRegion = { sphere: boolean, box: Box, center: { number }, r: number }

-- 조각이 영역과: 1 = 확실히 겹침, -1 = 확실히 떨어짐, 0 = 경계라 판단 보류
local function refIntersects(P: Box, R: RefRegion, margin: number): number
	if R.sphere then
		local d = sphereNear(P, R.center)
		if d < R.r - margin then
			return 1
		elseif d > R.r + margin then
			return -1
		end
		return 0
	end
	if satGap(P, R.box) > margin then
		return -1
	end
	if overlapWitness(P, R.box, margin, 24) then
		return 1
	end
	return 0
end

-- 조각이 영역 안에: 1 = 확실히 완전히 안, -1 = 확실히 밖으로 삐져나옴, 0 = 보류
local function refInside(P: Box, R: RefRegion, margin: number): number
	if R.sphere then
		local far = sphereFar(P, R.center)
		if far < R.r - margin then
			return 1
		elseif far > R.r + margin then
			return -1
		end
		return 0
	end
	local out = boxOut(P, R.box)
	if out < -margin then
		return 1
	elseif out > margin then
		return -1
	end
	return 0
end

-- 원본 상자 기준의 로컬 AABB (조각은 원본과 같은 회전이어야 한다)
type LocalBox = { lo: { number }, hi: { number }, rotErr: number }
local function localAABB(origin: Box, piece: Box): LocalBox
	local lc = toLocal(origin, piece.c)
	local rotErr = 0
	for i = 1, 3 do
		for k = 1, 3 do
			rotErr = math.max(rotErr, math.abs(origin.ax[i][k] - piece.ax[i][k]))
		end
	end
	return {
		lo = { lc[1] - piece.h[1], lc[2] - piece.h[2], lc[3] - piece.h[3] },
		hi = { lc[1] + piece.h[1], lc[2] + piece.h[2], lc[3] + piece.h[3] },
		rotErr = rotErr,
	}
end

-- 로컬 AABB 들 중 부피가 겹치는 쌍의 수 (x 로 정렬해서 훑는다)
local function countOverlaps(list: { LocalBox }, tol: number): number
	table.sort(list, function(a, b)
		return a.lo[1] < b.lo[1]
	end)
	local n = 0
	for i = 1, #list do
		local a = list[i]
		for j = i + 1, #list do
			local b = list[j]
			if b.lo[1] >= a.hi[1] - tol then
				break
			end
			local ox = math.min(a.hi[1], b.hi[1]) - math.max(a.lo[1], b.lo[1])
			local oy = math.min(a.hi[2], b.hi[2]) - math.max(a.lo[2], b.lo[2])
			local oz = math.min(a.hi[3], b.hi[3]) - math.max(a.lo[3], b.lo[3])
			if ox > tol and oy > tol and oz > tol then
				n += 1
			end
		end
	end
	return n
end

-- a 가 b 안에 들어가는가 (둘 다 같은 원본 기준 로컬 AABB)
local function containedIn(a: LocalBox, b: LocalBox, tol: number): boolean
	for i = 1, 3 do
		if a.lo[i] < b.lo[i] - tol or a.hi[i] > b.hi[i] + tol then
			return false
		end
	end
	return true
end

----------------------------------------------------------------------
-- 모듈 불러오기
----------------------------------------------------------------------
local function baseEnv(): { [string]: any }
	return {
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		CFrame = CFrame,
		Color3 = Color3,
		BrickColor = roblox.BrickColor,
		Enum = Enum,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		NumberRange = roblox.NumberRange,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		-- 일반 표 → "table", 로블록스 값 → 타입 이름 (Lune 의 typeof 가 이미 그렇게 동작한다)
		typeof = function(v: any): string
			return typeof(v)
		end,
		require = function(m: any): any
			return m
		end,
	}
end

-- BasePart.Position 대신 (Lune 에서는 읽을 수 없다)
local function posOf(v: any): Vector3
	if typeof(v) == "Instance" then
		return v.CFrame.Position
	end
	return v.Position
end

-- `a.b.Position` → `__pos(a.b)`. 바꾸지 못한 .Position 이 남으면 멈춘다 (모듈이 바뀌면 여기서 알게 된다)
local function polyfillPosition(src: string): (string, number)
	local n = 0
	local out = string.gsub(src, "([%a_][%w_%.]*)%.Position%f[^%w_]", function(expr: string): string
		n += 1
		return "__pos(" .. expr .. ")"
	end)
	local left = string.find(out, "%.Position%f[^%w_]")
	if left then
		local lineNo = select(2, string.gsub(string.sub(out, 1, left), "\n", "")) + 1
		error(string.format("Position 우회를 적용하지 못한 곳이 있습니다 (%d번째 줄) — 하네스의 polyfillPosition 을 고쳐 주세요", lineNo))
	end
	return out, n
end

local placeBytes = fs.readFile(opt.place)
local moduleSource, positionRewrites = polyfillPosition(fs.readFile(opt.module))
local Config = luau.load(fs.readFile(opt.config), { debugName = "Config", environment = baseEnv() })()
local S = Config.Destruction
assert(type(S) == "table", "Config.Destruction 이 없습니다")

-- 한 번의 실험 세계: 새로 읽은 플레이스 + 새로 불러온 모듈 + 가짜 서비스
type FxEvent = { name: string, payload: any, at: number }
type Char = { model: Instance, root: Instance, box: Box }
type Rec = {
	inst: Instance,
	sig: string,
	full: string,
	parentId: string,
	box: Box,
	destructible: boolean,
	whole: boolean,
	axes: { number },
	breakable: boolean,
	top: number,
}
type Snapshot = { byId: { [string]: Rec }, count: number, destructible: number }
type World = {
	place: Instance,
	map: Instance,
	serverStorage: Instance,
	holding: Instance,
	D: any,
	now: number,
	hb: ((number) -> ())?,
	fx: { FxEvent },
	chars: { Char },
	occupancyQueries: number,
	snap: Snapshot,
}

local function signature(p: Instance): string
	local comps = { p.CFrame:GetComponents() }
	local parts = {}
	for i, c in comps do
		parts[i] = string.format("%.5f", c)
	end
	local s, c = p.Size, p.Color
	return string.format(
		"%s|%s|%.5f,%.5f,%.5f|%.4f,%.4f,%.4f|%s|%.4f|%s|%s",
		p:GetFullName(),
		table.concat(parts, ","),
		s.X,
		s.Y,
		s.Z,
		c.R,
		c.G,
		c.B,
		p.Material.Name,
		p.Transparency,
		tostring(p.Anchored),
		tostring(p.CanCollide)
	)
end

local function newWorld(): World
	local place = roblox.deserializePlace(placeBytes)
	local map = place:GetService("Workspace"):FindFirstChild("Map")
	assert(map, "Workspace.Map 이 없습니다")
	local serverStorage = place:GetService("ServerStorage")
	local W = {
		place = place,
		map = map,
		serverStorage = serverStorage,
		now = 100,
		hb = nil,
		fx = {},
		chars = {},
		occupancyQueries = 0,
	} :: any

	local env = baseEnv()
	env.__pos = posOf
	-- 가상 시계
	env.os = setmetatable({
		clock = function(): number
			return W.now
		end,
	}, { __index = os })
	local shared = {
		Config = Config,
		Remotes = {
			FX = {
				FireAllClients = function(_self: any, name: string, payload: any)
					table.insert(W.fx, { name = name, payload = payload, at = W.now })
				end,
			},
		},
	}
	local services = {
		RunService = {
			Heartbeat = {
				Connect = function(_self: any, fn: (number) -> ())
					assert(W.hb == nil, "Heartbeat 에 두 번 연결했습니다")
					W.hb = fn
					return { Disconnect = function() end }
				end,
			},
		},
		ServerStorage = serverStorage,
		ReplicatedStorage = {
			WaitForChild = function(_self: any, name: string): any
				assert(name == "Shared", "ReplicatedStorage:WaitForChild(" .. name .. ")")
				return shared
			end,
		},
	}
	env.game = {
		GetService = function(_self: any, name: string): any
			return assert(services[name], "가짜 서비스 없음: " .. name)
		end,
	}
	-- workspace: 캐릭터(가짜)와 겹침 조회만
	env.workspace = {
		GetChildren = function(_self: any): { Instance }
			local out = {}
			for _, c in W.chars do
				table.insert(out, c.model)
			end
			return out
		end,
		GetPartBoundsInBox = function(_self: any, cf: CFrame, size: Vector3, _params: any): { Instance }
			W.occupancyQueries += 1
			local out = {}
			local q = boxOf(cf, size)
			for _, c in W.chars do
				if satGap(q, c.box) < 0 then
					table.insert(out, c.root)
				end
			end
			return out
		end,
	}
	env.OverlapParams = {
		new = function(): any
			return { FilterType = Enum.RaycastFilterType.Exclude, FilterDescendantsInstances = {} }
		end,
	}

	W.D = luau.load(moduleSource, { debugName = "Destruction", environment = env })()

	-- 처음 상태 기록 + 조각 추적용 속성 (init 전에: 원본 복제본이 이 속성을 물려받는다)
	local snap: Snapshot = { byId = {}, count = 0, destructible = 0 }
	for _, d in map:GetDescendants() do
		if d:IsA("BasePart") then
			local id = d:GetDebugId()
			local destructible = W.D._test.classify(d, map)
			local box = boxOf(d.CFrame, d.Size)
			local axes = W.D._test.kindOf(d).axes
			snap.byId[id] = {
				inst = d,
				sig = signature(d),
				full = d:GetFullName(),
				parentId = (d.Parent :: Instance):GetDebugId(),
				box = box,
				destructible = destructible,
				whole = #axes == 0,
				axes = axes,
				breakable = d:GetAttribute("Breakable") == true,
				top = box.c[2] + aabbHalf(box)[2],
			}
			snap.count += 1
			if destructible then
				snap.destructible += 1
			end
			d:SetAttribute("HarnessOrigin", id)
		end
	end
	W.snap = snap
	W.D.init(map)
	W.holding = assert(serverStorage:FindFirstChild("DestroyedMap"), "DestroyedMap 폴더가 없습니다")
	assert(W.hb, "init 이 Heartbeat 에 연결하지 않았습니다")
	return W :: World
end

-- 가상 시간을 흘리며 Heartbeat 를 부른다
local function advance(W: World, seconds: number, step: number?)
	local dt = step or 0.1
	local t = 0
	while t < seconds - 1e-9 do
		W.now += dt
		;(W.hb :: (number) -> ())(dt)
		t += dt
	end
end

-- 가짜 캐릭터 (R6 몸 크기 4×5×1 상자). feet = 발바닥 위치
local function addCharacter(W: World, feet: Vector3): Char
	local m = Instance.new("Model")
	m.Name = "FakeCharacter"
	Instance.new("Humanoid").Parent = m
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 1)
	root.CFrame = CFrame.new(feet + Vector3.new(0, 3, 0))
	root.Parent = m
	local c = { model = m, root = root, box = boxOf(CFrame.new(feet + Vector3.new(0, 2.5, 0)), Vector3.new(4, 5, 1)) }
	table.insert(W.chars, c)
	return c
end

----------------------------------------------------------------------
-- 맵 상태 훑기와 검사
----------------------------------------------------------------------
type PieceInfo = { inst: Instance, id: string, origin: string?, box: Box }
type State = {
	all: { [string]: Instance },
	originals: { [string]: Instance },
	pieces: { PieceInfo },
	missing: { string },
	holding: { [string]: Instance },
	registered: { [string]: Instance },
	volume: number,
	originVol: { [string]: number }, -- 원본별 맵에 남은 부피 (원본 그대로면 원본 부피, 부서졌으면 조각 부피 합)
}

local QUERY_ALL_HALF = Vector3.new(800, 10000, 800)

local function scan(W: World): State
	local st: State = { all = {}, originals = {}, pieces = {}, missing = {}, holding = {}, registered = {}, volume = 0, originVol = {} }
	for _, d in W.map:GetDescendants() do
		if d:IsA("BasePart") then
			local id = d:GetDebugId()
			st.all[id] = d
			local box = boxOf(d.CFrame, d.Size)
			local v = volume(box)
			st.volume += v
			if W.snap.byId[id] then
				st.originals[id] = d
				st.originVol[id] = (st.originVol[id] or 0) + v
			else
				local origin = d:GetAttribute("HarnessOrigin")
				table.insert(st.pieces, { inst = d, id = id, origin = origin, box = box })
				if origin then
					st.originVol[origin] = (st.originVol[origin] or 0) + v
				end
			end
		end
	end
	for id in W.snap.byId do
		if not st.originals[id] then
			table.insert(st.missing, id)
		end
	end
	for _, c in W.holding:GetChildren() do
		st.holding[c:GetDebugId()] = c
	end
	for _, p in W.D._test.query(Vector3.zero, QUERY_ALL_HALF) do
		st.registered[p:GetDebugId()] = p
	end
	return st
end

-- 모듈 내부 상태와 맵이 서로 맞는지 전부 검사한다
local function validate(W: World, st: State): Problems
	local P = problems()
	-- 1. 등록된 파트는 전부 맵 안에 있어야 한다 (보관 폴더의 원본·지운 조각이 색인에 남으면 안 된다)
	for id, p in st.registered do
		if not st.all[id] then
			bad(P, "색인에 남은 파트(맵 밖): %s", p.Name)
		elseif not W.D.isDestructible(p) then
			bad(P, "색인에는 있는데 isDestructible=false: %s", p.Name)
		end
	end
	-- 2. 맵에 있는 원본은 분류대로 등록돼 있어야 한다
	for id in st.originals do
		local rec = W.snap.byId[id]
		if rec.destructible and not st.registered[id] then
			bad(P, "부서질 원본이 등록 안 됨: %s", rec.full)
		elseif not rec.destructible and st.registered[id] then
			bad(P, "부서지면 안 되는 원본이 등록됨: %s", rec.full)
		end
	end
	-- 3. 맵에서 빠진 원본은 전부 보관 폴더에 있어야 한다
	local brokenOrigins: { [string]: boolean } = {}
	for _, id in st.missing do
		brokenOrigins[id] = true
		if not st.holding[id] then
			bad(P, "원본이 사라짐(보관 폴더에도 없음): %s", W.snap.byId[id].full)
		end
		if not W.snap.byId[id].destructible then
			bad(P, "부서지면 안 되는 원본이 빠짐: %s", W.snap.byId[id].full)
		end
	end
	for id, c in st.holding do
		if not W.snap.byId[id] then
			bad(P, "보관 폴더에 원본이 아닌 것: %s", c.Name)
		end
	end
	-- 4. 조각: 고정, 원래 부모, 등록, 원본 상자 안, 원본과 같은 회전, 서로 안 겹침
	local byOrigin: { [string]: { LocalBox } } = {}
	for _, pc in st.pieces do
		local rec = if pc.origin then W.snap.byId[pc.origin] else nil
		if not rec then
			bad(P, "원본을 알 수 없는 조각: %s", pc.inst:GetFullName())
			continue
		end
		if not pc.inst.Anchored then
			bad(P, "고정 안 된 조각: %s", rec.full)
		end
		if (pc.inst.Parent :: Instance):GetDebugId() ~= rec.parentId then
			bad(P, "조각의 부모가 원본과 다름: %s → %s", rec.full, pc.inst:GetFullName())
		end
		if not st.registered[pc.id] then
			bad(P, "조각이 등록 안 됨: %s", rec.full)
		end
		if not brokenOrigins[pc.origin :: string] then
			bad(P, "원본이 맵에 있는데 조각도 있음: %s", rec.full)
		end
		local lb = localAABB(rec.box, pc.box)
		local scale = math.max(rec.box.h[1], rec.box.h[2], rec.box.h[3])
		local tol = 1e-4 * scale + 1e-4
		if lb.rotErr > 1e-4 then
			bad(P, "조각 회전이 원본과 다름(%.2g): %s", lb.rotErr, rec.full)
		end
		for i = 1, 3 do
			if lb.lo[i] < -rec.box.h[i] - tol or lb.hi[i] > rec.box.h[i] + tol then
				bad(P, "조각이 원본 상자 밖으로 나감: %s", rec.full)
				break
			end
		end
		local list = byOrigin[pc.origin :: string]
		if not list then
			list = {}
			byOrigin[pc.origin :: string] = list
		end
		table.insert(list, lb)
	end
	for origin, list in byOrigin do
		local rec = W.snap.byId[origin]
		local scale = math.max(rec.box.h[1], rec.box.h[2], rec.box.h[3])
		local n = countOverlaps(list, 1e-4 * scale + 1e-4)
		if n > 0 then
			bad(P, "같은 원본의 조각끼리 겹침 %d쌍: %s", n, rec.full)
		end
	end
	-- 5. 조각 수
	if W.D.pieceCount() ~= #st.pieces then
		bad(P, "pieceCount()=%d 인데 맵의 조각은 %d개", W.D.pieceCount(), #st.pieces)
	end
	-- 6. 색인: 조각(과 원본 일부)을 자기 자리에서 조회하면 나와야 한다
	local checked = 0
	for id, p in st.registered do
		if checked >= 1500 then
			break
		end
		checked += 1
		local found = false
		for _, q in W.D._test.query(p.CFrame.Position, Vector3.new(0.01, 0.01, 0.01)) do
			if q:GetDebugId() == id then
				found = true
				break
			end
		end
		if not found then
			bad(P, "자기 자리 조회로 안 나오는 파트: %s", p:GetFullName())
		end
	end
	return P
end

-- 맵이 처음 상태와 완전히 같은가
local function compareToSnapshot(W: World): Problems
	local P = problems()
	local seen: { [string]: boolean } = {}
	for _, d in W.map:GetDescendants() do
		if d:IsA("BasePart") then
			local id = d:GetDebugId()
			local rec = W.snap.byId[id]
			if not rec then
				bad(P, "남은 조각/낯선 파트: %s", d:GetFullName())
			else
				seen[id] = true
				local sig = signature(d)
				if sig ~= rec.sig then
					bad(P, "속성이 달라짐: %s", rec.full)
				end
				if (d.Parent :: Instance):GetDebugId() ~= rec.parentId then
					bad(P, "부모가 달라짐: %s", rec.full)
				end
			end
		end
	end
	for id, rec in W.snap.byId do
		if not seen[id] then
			bad(P, "돌아오지 않은 원본: %s", rec.full)
		end
	end
	local held = #W.holding:GetChildren()
	if held > 0 then
		bad(P, "보관 폴더가 비지 않음: %d개", held)
	end
	if W.D.pieceCount() ~= 0 then
		bad(P, "pieceCount()=%d", W.D.pieceCount())
	end
	local reg = 0
	for _, p in W.D._test.query(Vector3.zero, QUERY_ALL_HALF) do
		reg += 1
		local rec = W.snap.byId[p:GetDebugId()]
		if not rec or not rec.destructible then
			bad(P, "처음과 다른 등록: %s", p:GetFullName())
		end
	end
	if reg ~= W.snap.destructible then
		bad(P, "등록된 파트 수 %d ≠ 처음 %d", reg, W.snap.destructible)
	end
	return P
end

-- Heartbeat 만 돌려서 전부 복구. 걸린 가상 시간, Rebuild 이벤트 정보를 돌려준다
type RestoreInfo = { seconds: number, rebuilds: number, maxPerEvent: number, maxPerTick: number, contract: Problems }
local function restoreByHeartbeat(W: World, limit: number?): RestoreInfo
	local info = { seconds = 0, rebuilds = 0, maxPerEvent = 0, maxPerTick = 0, contract = problems() }
	local fx0 = #W.fx
	local maxT = limit or (S.RestoreTime + 120)
	local lastHeld = #W.holding:GetChildren()
	while info.seconds < maxT do
		advance(W, 0.5, 0.1)
		info.seconds += 0.5
		local held = #W.holding:GetChildren()
		info.maxPerTick = math.max(info.maxPerTick, lastHeld - held)
		lastHeld = held
		if held == 0 and W.D.pieceCount() == 0 then
			break
		end
	end
	for i = fx0 + 1, #W.fx do
		local e = W.fx[i]
		if e.name == "Rebuild" then
			info.rebuilds += 1
			local pl = e.payload
			if type(pl) ~= "table" or type(pl.positions) ~= "table" or type(pl.sizes) ~= "table" then
				bad(info.contract, "Rebuild 형식이 틀림")
				continue
			end
			if #pl.positions ~= #pl.sizes then
				bad(info.contract, "Rebuild positions %d ≠ sizes %d", #pl.positions, #pl.sizes)
			end
			if #pl.positions > 24 or #pl.positions == 0 then
				bad(info.contract, "Rebuild 개수 %d (1~24 여야 함)", #pl.positions)
			end
			for k = 1, #pl.positions do
				if typeof(pl.positions[k]) ~= "Vector3" or typeof(pl.sizes[k]) ~= "Vector3" then
					bad(info.contract, "Rebuild 값이 Vector3 가 아님")
					break
				end
			end
			info.maxPerEvent = math.max(info.maxPerEvent, #pl.positions)
		end
	end
	return info
end

----------------------------------------------------------------------
-- 한 번 부수기 + 통계
----------------------------------------------------------------------
type Hit = {
	id: string,
	label: string,
	sphere: boolean,
	center: Vector3,
	radius: number,
	cf: CFrame,
	size: Vector3,
	opts: { [string]: any },
	dump: string?,
	dumpExtent: number?,
	dumpCam: { number }?,
}

local SHAPES = { Block = true, Cylinder = true, Wedge = true, Ball = true }

-- Shatter 형식 검사 + 크기 어림
type ShatterInfo = { groups: number, pieces: number, volume: number, bytes: number, contract: Problems }
local function inspectShatter(pl: any): ShatterInfo
	local info = { groups = 0, pieces = 0, volume = 0, bytes = 0, contract = problems() }
	local C = info.contract
	if type(pl) ~= "table" then
		bad(C, "Shatter 가 표가 아님")
		return info
	end
	local function want(key: string, t: string)
		if typeof(pl[key]) ~= t then
			bad(C, "Shatter.%s 가 %s 가 아님 (%s)", key, t, typeof(pl[key]))
		end
	end
	want("center", "Vector3")
	want("radius", "number")
	want("from", "Vector3")
	want("dir", "Vector3")
	want("force", "number")
	want("ash", "boolean")
	want("sound", "boolean")
	want("groups", "table")
	if typeof(pl.dir) == "Vector3" then
		local m = pl.dir.Magnitude
		if m > 1e-9 and math.abs(m - 1) > 1e-3 then
			bad(C, "Shatter.dir 길이 %.4f (단위 벡터나 0 이어야 함)", m)
		end
	end
	info.bytes = 120
	if type(pl.groups) == "table" then
		for _, g in pl.groups do
			info.groups += 1
			info.bytes += 70
			if typeof(g.color) ~= "Color3" then
				bad(C, "group.color 가 Color3 가 아님")
			end
			if typeof(g.material) ~= "EnumItem" then
				bad(C, "group.material 이 EnumItem 이 아님")
			end
			if type(g.transparency) ~= "number" then
				bad(C, "group.transparency 가 숫자가 아님")
			end
			if not SHAPES[g.shape] then
				bad(C, "group.shape 가 이상함: %s", tostring(g.shape))
			end
			if type(g.pieces) ~= "table" or #g.pieces == 0 then
				bad(C, "group.pieces 가 비었음")
				continue
			end
			for _, p in g.pieces do
				info.pieces += 1
				if typeof(p.cf) ~= "CFrame" or typeof(p.size) ~= "Vector3" then
					bad(C, "piece 가 {cf, size} 가 아님")
					continue
				end
				info.volume += p.size.X * p.size.Y * p.size.Z
				-- 대략: 키 문자열 + 크기 12 + CFrame (축 정렬이면 위치 12 + 1, 아니면 + 회전 16)
				local b = boxOf(p.cf, p.size)
				local aligned = true
				for i = 1, 3 do
					for k = 1, 3 do
						local v = math.abs(b.ax[i][k])
						if v > 1e-4 and math.abs(v - 1) > 1e-4 then
							aligned = false
						end
					end
				end
				info.bytes += 14 + 12 + 12 + (if aligned then 1 else 16)
			end
		end
	end
	return info
end

type HitStats = {
	id: string,
	label: string,
	affected: number,
	created: number,
	piecesDestroyed: number,
	originalsBroken: number,
	livePieces: number,
	shatters: number,
	sentGroups: number,
	sentPieces: number,
	sentBytes: number,
	removedVolume: number,
	sentVolume: number,
	splitRemoved: number, -- 쪼갤 수 있는 파트에서 없앤 부피
	bound: number, -- 영역을 결의 대각선만큼 부풀린 부피 (쪼갤 수 있는 파트는 이만큼까지만 없어질 수 있다)
	worst: string, -- 가장 많이 없어진 원본
	worstVolume: number,
	ms: number,
	contract: Problems,
}

-- 모듈의 autoGrain 과 같은 계산 (opts.grain 이 없을 때)
local function grainOf(W: World, h: Hit): number
	local g = h.opts.grain
	if not g then
		local minDim = if h.sphere then h.radius * 2 else math.min(h.size.X, h.size.Y, h.size.Z)
		g = math.clamp(minDim / 3.5, 1.25, 8)
	end
	if W.D.pieceCount() > S.MaxPieces * 0.75 then
		g *= 2
	end
	return g
end

-- 영역을 결 조각의 대각선(g·√3)만큼 부풀린 부피: 경계 조각이 영역 밖으로 삐져나갈 수 있는 최대치
local function regionBound(h: Hit, g: number): number
	local e = g * math.sqrt(3)
	if h.sphere then
		return 4 / 3 * math.pi * (h.radius + e) ^ 3
	end
	return (h.size.X + 2 * e) * (h.size.Y + 2 * e) * (h.size.Z + 2 * e)
end

local function runHit(W: World, h: Hit, before: State?): (HitStats, State)
	local st0 = before or scan(W)
	local grain = grainOf(W, h)
	local fx0 = #W.fx
	local t0 = os.clock()
	local affected = if h.sphere then W.D.destroySphere(h.center, h.radius, h.opts) else W.D.destroyBox(h.cf, h.size, h.opts)
	local ms = (os.clock() - t0) * 1000
	local st1 = scan(W)
	local stats: HitStats = {
		id = h.id,
		label = h.label,
		affected = affected,
		created = 0,
		piecesDestroyed = 0,
		originalsBroken = #st1.missing - #st0.missing,
		livePieces = #st1.pieces,
		shatters = 0,
		sentGroups = 0,
		sentPieces = 0,
		sentBytes = 0,
		removedVolume = st0.volume - st1.volume,
		sentVolume = 0,
		splitRemoved = 0,
		bound = regionBound(h, grain),
		worst = "",
		worstVolume = 0,
		ms = ms,
		contract = problems(),
	}
	for id, v0 in st0.originVol do
		local d = v0 - (st1.originVol[id] or 0)
		if d > 1e-6 then
			local rec = W.snap.byId[id]
			if not rec.whole then
				stats.splitRemoved += d
			end
			if d > stats.worstVolume then
				stats.worstVolume = d
				stats.worst = (string.gsub(rec.full, "^Workspace%.Map%.", ""))
			end
		end
	end
	local before0: { [string]: boolean } = {}
	for _, pc in st0.pieces do
		before0[pc.id] = true
	end
	local after1: { [string]: boolean } = {}
	for _, pc in st1.pieces do
		after1[pc.id] = true
		if not before0[pc.id] then
			stats.created += 1
		end
	end
	for id in before0 do
		if not after1[id] then
			stats.piecesDestroyed += 1
		end
	end
	for i = fx0 + 1, #W.fx do
		local e = W.fx[i]
		if e.name == "Shatter" then
			stats.shatters += 1
			local si = inspectShatter(e.payload)
			stats.sentGroups += si.groups
			stats.sentPieces += si.pieces
			stats.sentBytes += si.bytes
			stats.sentVolume += si.volume
			for _, s in si.contract.list do
				bad(stats.contract, "%s", s)
			end
			stats.contract.n += math.max(0, si.contract.n - #si.contract.list)
		end
	end
	-- 계약: 부쉈으면 Shatter 한 번, 안 부쉈으면 없음. 보낸 조각 수 ≤ MaxDebrisSent. 보낸 부피 ≤ 실제로 없어진 부피
	if affected > 0 and stats.shatters ~= 1 then
		bad(stats.contract, "affected=%d 인데 Shatter %d번", affected, stats.shatters)
	end
	if affected == 0 and stats.shatters ~= 0 then
		bad(stats.contract, "affected=0 인데 Shatter 를 보냄")
	end
	if stats.sentPieces > S.MaxDebrisSent then
		bad(stats.contract, "보낸 조각 %d > MaxDebrisSent %d", stats.sentPieces, S.MaxDebrisSent)
	end
	if stats.sentVolume > stats.removedVolume * (1 + 1e-4) + 1e-3 then
		bad(stats.contract, "보낸 잔해 부피 %.1f > 없어진 부피 %.1f", stats.sentVolume, stats.removedVolume)
	end
	if stats.removedVolume < -1e-3 then
		bad(stats.contract, "부쉈는데 맵 부피가 늘어남 (%.2f)", -stats.removedVolume)
	end
	return stats, st1
end

-- 빠른 버전: 맵을 훑지 않고 시간과 Shatter 형식만 본다 (연달아 수백 번 칠 때)
local function runHitLight(W: World, h: Hit): (number, number, Problems)
	local fx0 = #W.fx
	local t0 = os.clock()
	local affected = if h.sphere then W.D.destroySphere(h.center, h.radius, h.opts) else W.D.destroyBox(h.cf, h.size, h.opts)
	local ms = (os.clock() - t0) * 1000
	local C = problems()
	local shatters = 0
	for i = fx0 + 1, #W.fx do
		local e = W.fx[i]
		if e.name == "Shatter" then
			shatters += 1
			local si = inspectShatter(e.payload)
			for _, msg in si.contract.list do
				bad(C, "%s: %s", h.id, msg)
			end
			if si.pieces > S.MaxDebrisSent then
				bad(C, "%s: 보낸 조각 %d > MaxDebrisSent", h.id, si.pieces)
			end
		end
	end
	if (affected > 0) ~= (shatters == 1) or shatters > 1 then
		bad(C, "%s: affected=%d 인데 Shatter %d번", h.id, affected, shatters)
	end
	return affected, ms, C
end

-- 시나리오 영역의 기준 표현
local function refRegionOf(h: Hit): RefRegion
	local c = { h.center.X, h.center.Y, h.center.Z }
	if h.sphere then
		return { sphere = true, box = boxOf(CFrame.new(h.center), Vector3.one * h.radius * 2), center = c, r = h.radius }
	end
	return { sphere = false, box = boxOf(h.cf, h.size), center = c, r = 0 }
end

-- 부수기 전에: 영역과 확실히 겹치는 등록 파트 (propsOnly 에서 걸러지는 큰 파트는 뺀다)
type Must = { id: string, name: string, centreInside: boolean }
local function mustBreak(W: World, st: State, h: Hit): { Must }
	local R = refRegionOf(h)
	local out = {}
	for id, p in st.registered do
		local sz = p.Size
		if h.opts.propsOnly and math.max(sz.X, sz.Y, sz.Z) > 8 and p:GetAttribute("Breakable") ~= true then
			continue
		end
		local b = boxOf(p.CFrame, sz)
		local scale = math.max(sz.X, sz.Y, sz.Z)
		if refIntersects(b, R, 1e-3 * scale + 1e-3) == 1 then
			local inside = if R.sphere then sphereNear(boxOf(CFrame.new(p.CFrame.Position), Vector3.zero), R.center) < R.r else boxOut(boxOf(CFrame.new(p.CFrame.Position), Vector3.zero), R.box) < 0
			table.insert(out, { id = id, name = p:GetFullName(), centreInside = inside })
		end
	end
	return out
end

local function printHitHeader()
	print(
		string.format(
			"    %-28s %5s %6s %6s %5s %6s %5s %6s %7s %8s %8s %6s %8s",
			"시나리오",
			"파트",
			"새조각",
			"지운조각",
			"원본",
			"살아있음",
			"그룹",
			"보냄",
			"~KB",
			"없앤부피",
			"보낸부피",
			"넘침",
			"ms"
		)
	)
end

local function printHit(s: HitStats)
	print(
		string.format(
			"    %-28s %5d %6d %6d %5d %6d %5d %6d %7.1f %8.0f %8.0f %6.2f %8.1f",
			s.id,
			s.affected,
			s.created,
			s.piecesDestroyed,
			s.originalsBroken,
			s.livePieces,
			s.sentGroups,
			s.sentPieces,
			s.sentBytes / 1024,
			s.removedVolume,
			s.sentVolume,
			s.splitRemoved / s.bound,
			s.ms
		)
	)
end

----------------------------------------------------------------------
-- 렌더용 덤프
----------------------------------------------------------------------
local function shapeName(p: Instance): string
	if p:IsA("WedgePart") then
		return "Wedge"
	elseif p:IsA("Part") then
		local s = (p :: any).Shape
		if s == Enum.PartType.Cylinder then
			return "Cylinder"
		elseif s == Enum.PartType.Ball then
			return "Ball"
		end
	end
	return "Block"
end

local function dumpAround(W: World, center: Vector3, extent: number): { any }
	local out = {}
	local c = { center.X, center.Y, center.Z }
	for _, d in W.map:GetDescendants() do
		if d:IsA("BasePart") then
			local b = boxOf(d.CFrame, d.Size)
			local ah = aabbHalf(b)
			local near = true
			for i = 1, 3 do
				if math.abs(b.c[i] - c[i]) > ah[i] + extent then
					near = false
				end
			end
			if near then
				local col = d.Color
				table.insert(out, {
					name = d.Name,
					cframe = { d.CFrame:GetComponents() },
					size = { d.Size.X, d.Size.Y, d.Size.Z },
					color = { col.R * 255, col.G * 255, col.B * 255 },
					transparency = d.Transparency,
					shape = shapeName(d),
					material = d.Material.Name,
					piece = W.snap.byId[d:GetDebugId()] == nil,
				})
			end
		end
	end
	return out
end

local function writeDump(W: World, h: Hit, phase: string, fx: { any }?)
	local dir = opt.dump
	if not dir or not h.dump then
		return
	end
	if not fs.isDir(dir) then
		fs.writeDir(dir)
	end
	local data = {
		scenario = h.dump,
		label = h.label,
		phase = phase,
		site = {
			sphere = h.sphere,
			center = { h.center.X, h.center.Y, h.center.Z },
			radius = h.radius,
			cframe = { h.cf:GetComponents() },
			size = { h.size.X, h.size.Y, h.size.Z },
		},
		camera = h.dumpCam,
		parts = dumpAround(W, h.center, h.dumpExtent or (h.radius + 30)),
		debris = fx,
	}
	fs.writeFile(dir .. "/" .. h.dump .. "_" .. phase .. ".json", serde.encode("json", data))
end

----------------------------------------------------------------------
-- 맵에서 장소 찾기
----------------------------------------------------------------------
local function find(W: World, path: string): Instance
	local node: Instance = W.map
	for name in string.gmatch(path, "[^%.]+") do
		local nxt = node:FindFirstChild(name)
		assert(nxt, "맵에 없는 경로: " .. path)
		node = nxt
	end
	return node
end

-- 폴더/모델/파트의 월드 AABB (min, max)
local function boundsOf(inst: Instance): (Vector3, Vector3)
	local lo = { math.huge, math.huge, math.huge }
	local hi = { -math.huge, -math.huge, -math.huge }
	local list = if inst:IsA("BasePart") then { inst } else inst:GetDescendants()
	for _, d in list do
		if d:IsA("BasePart") then
			local b = boxOf(d.CFrame, d.Size)
			local ah = aabbHalf(b)
			for i = 1, 3 do
				lo[i] = math.min(lo[i], b.c[i] - ah[i])
				hi[i] = math.max(hi[i], b.c[i] + ah[i])
			end
		end
	end
	return Vector3.new(lo[1], lo[2], lo[3]), Vector3.new(hi[1], hi[2], hi[3])
end

-- 폴더 안에서 부피가 가장 큰 파트
local function largestPart(inst: Instance): Instance
	local best, bestV = nil, -1
	for _, d in inst:GetDescendants() do
		if d:IsA("BasePart") then
			local v = d.Size.X * d.Size.Y * d.Size.Z
			if v > bestV then
				best, bestV = d, v
			end
		end
	end
	return assert(best, "파트가 없음: " .. inst:GetFullName())
end

-- 시험 장소들 (맵에서 이름으로 찾아서 맵이 바뀌어도 따라간다)
type Site = { id: string, label: string, center: Vector3, from: Vector3, dir: Vector3, cam: { number }? }
local function findSites(W: World): { Site }
	local sites: { Site } = {}
	-- 국수집 서쪽 벽: 바깥은 찻집 몸통과 붙어 있어서 가게 안쪽 면에서 부순다 (벽 너머 찻집까지 파인다)
	do
		local wall = find(W, "Decor.NoodleShop_LinJi.ShopWallWest")
		local lo, hi = boundsOf(wall)
		local c = Vector3.new(hi.X + 0.3, 6, (lo.Z + hi.Z) / 2)
		table.insert(sites, {
			id = "noodle_wall",
			label = "국수집 서쪽 벽 (안쪽)",
			center = c,
			from = c + Vector3.new(12, 0, 0),
			dir = Vector3.new(-1, 0, 0),
			cam = { c.X + 15, c.Y + 1.5, c.Z + 5, c.X - 1, c.Y - 0.5, c.Z - 0.5 },
		})
	end
	-- 국수집 2층 정면 (광장 쪽): 가운데 창과 간판 윗부분
	do
		local body = find(W, "Decor.NoodleShop_LinJi.ShopUpperBody")
		local lo, hi = boundsOf(body)
		local c = Vector3.new((lo.X + hi.X) / 2, 25, hi.Z + 0.3)
		table.insert(sites, {
			id = "noodle_facade",
			label = "국수집 2층 정면",
			center = c,
			from = c + Vector3.new(0, 0, 15),
			dir = Vector3.new(0, 0, -1),
			cam = { c.X + 16, c.Y - 3, c.Z + 34, c.X, c.Y - 2, c.Z - 2 },
		})
	end
	-- 야시장 노점 (꼬치)
	do
		local lo, hi = boundsOf(find(W, "Decor.NightMarket.Stall_skewer"))
		local c = Vector3.new((lo.X + hi.X) / 2, 4, (lo.Z + hi.Z) / 2)
		table.insert(sites, {
			id = "market_stall",
			label = "야시장 꼬치 노점",
			center = c,
			from = c + Vector3.new(12, 0, 0),
			dir = Vector3.new(-1, 0, 0),
			cam = { c.X + 14, c.Y + 5, c.Z + 6, c.X, c.Y - 0.5, c.Z },
		})
	end
	-- 광장 가운데 (캐릭터 허리 높이)
	table.insert(sites, {
		id = "plaza_centre",
		label = "광장 가운데",
		center = Vector3.new(0, 3, 0),
		from = Vector3.new(0, 12, 0),
		dir = Vector3.new(0, -1, 0),
		cam = { 22, 18, 22, 0, 1, 0 },
	})
	-- WACA 구역 건물: ShearedBlock 에서 가장 큰 파트의 광장 쪽 면
	do
		local body = largestPart(find(W, "Decor.WACAZone.ShearedBlock"))
		local lo, hi = boundsOf(body)
		local c = Vector3.new((lo.X + hi.X) / 2, math.min(8, (lo.Y + hi.Y) / 2), lo.Z - 0.3)
		table.insert(sites, {
			id = "waca_building",
			label = "WACA 구역 건물 (" .. body.Name .. ")",
			center = c,
			from = c - Vector3.new(0, 0, 20),
			dir = Vector3.new(0, 0, 1),
			cam = { c.X - 18, c.Y + 8, c.Z - 30, c.X, c.Y, c.Z + 2 },
		})
	end
	-- 운하 아치 다리 (가운데 상판)
	do
		local lo, hi = boundsOf(find(W, "Decor.Canal.ArchedBridge"))
		local c = Vector3.new((lo.X + hi.X) / 2, hi.Y - 1.5, (lo.Z + hi.Z) / 2)
		table.insert(sites, {
			id = "canal_bridge",
			label = "운하 아치 다리",
			center = c,
			from = c + Vector3.new(0, 10, 0),
			dir = Vector3.new(0, -1, 0),
			cam = { c.X + 20, c.Y + 12, c.Z + 24, c.X, c.Y - 2, c.Z },
		})
	end
	-- 동쪽 거리 가로등 (첫 번째 기둥 가운데 높이)
	do
		local lamps = find(W, "Decor.EastStreet.StreetLamps")
		local first = assert(lamps:FindFirstChild("LampPole"), "LampPole 이 없음")
		local lo, hi = boundsOf(first)
		local c = Vector3.new((lo.X + hi.X) / 2, (lo.Y + hi.Y) / 2, (lo.Z + hi.Z) / 2)
		table.insert(sites, {
			id = "east_lamp",
			label = "동쪽 거리 가로등 (" .. first.Name .. ")",
			center = c,
			from = c - Vector3.new(10, 0, 0),
			dir = Vector3.new(1, 0, 0),
		})
	end
	-- 동쪽 거리 자동차 (첫 번째 차)
	do
		local cars = find(W, "Decor.EastStreet.Cars")
		local first = cars:GetChildren()[1]
		local lo, hi = boundsOf(first)
		local c = (lo + hi) / 2
		table.insert(sites, {
			id = "east_car",
			label = "동쪽 거리 자동차 (" .. first.Name .. ")",
			center = c,
			from = c - Vector3.new(0, 0, 10),
			dir = Vector3.new(0, 0, 1),
		})
	end
	return sites
end

local function sphereHit(site: Site, r: number, extra: { [string]: any }?): Hit
	local o: { [string]: any } = { from = site.from, dir = site.dir, force = 1.2 }
	if extra then
		for k, v in extra do
			o[k] = v
		end
	end
	return {
		id = string.format("%s_r%g", site.id, r),
		label = site.label,
		sphere = true,
		center = site.center,
		radius = r,
		cf = CFrame.new(site.center),
		size = Vector3.new(r, r, r) * 2,
		opts = o,
	}
end

local function boxHit(id: string, label: string, cf: CFrame, size: Vector3, opts: { [string]: any }): Hit
	return {
		id = id,
		label = label,
		sphere = false,
		center = cf.Position,
		radius = size.Magnitude / 2,
		cf = cf,
		size = size,
		opts = opts,
	}
end

-- C 와 D 에서 쓰는 시나리오 목록
local function scenarioList(W: World): { Hit }
	local sites = findSites(W)
	local byId: { [string]: Site } = {}
	for _, s in sites do
		byId[s.id] = s
	end
	local list: { Hit } = {}
	for _, s in sites do
		for _, r in { 3, 6, 12 } do
			local h = sphereHit(s, r)
			if (s.id == "noodle_wall" or s.id == "noodle_facade") and r == 6 then
				h.dump, h.dumpExtent, h.dumpCam = s.id .. "_r6", 30, s.cam
			elseif s.id == "plaza_centre" and r == 3 then
				-- 광장 바닥은 눕힌 원판 원기둥이라 작은 타격에도 통째로 사라진다 (위에서 비스듬히)
				h.dump, h.dumpExtent, h.dumpCam = "plaza_centre_r3", 60, { 0, 62, 58, 0, 0, 0 }
			elseif s.id == "canal_bridge" and r == 6 then
				h.dump, h.dumpExtent, h.dumpCam = "canal_bridge_r6", 28, s.cam
			elseif s.id == "waca_building" and r == 12 then
				h.dump, h.dumpExtent, h.dumpCam = "waca_building_r12", 34, s.cam
			end
			table.insert(list, h)
		end
	end
	-- 렌더용: 노점 r=4
	do
		local s = byId.market_stall
		local h = sphereHit(s, 4)
		h.dump, h.dumpExtent, h.dumpCam = "market_stall_r4", 22, s.cam
		table.insert(list, h)
	end
	-- 몸이 벽에 박힘 (Combat: 반지름 3~7)
	do
		local s = byId.noodle_wall
		table.insert(list, sphereHit(s, 5, { force = 1.6 }))
		list[#list].id = "body_crash_noodle_r5"
	end
	-- 칸자키 렌 전력 참격: 18 × 34 × 길이 상자로 찻집(NorthShopRow)을 가른다 (maxParts 1200)
	do
		local mid = Vector3.new(-40, 12, -140)
		local h = boxHit(
			"ren_slash_teahouse",
			"렌 전력 참격 (찻집)",
			CFrame.lookAt(mid, mid + Vector3.new(0, 0, -1)),
			Vector3.new(18, 34, 90),
			{ from = Vector3.new(-40, 3, -90), dir = Vector3.new(0, 0, -1), ash = true, force = 2.2, maxParts = 1200 }
		)
		h.dump, h.dumpExtent, h.dumpCam = "ren_slash_teahouse", 60, { -95, 45, -75, -40, 8, -140 }
		table.insert(list, h)
	end
	-- 평타 (작은 사물만): 노점 앞 상자
	do
		local s = byId.market_stall
		table.insert(
			list,
			boxHit(
				"m1_props_market",
				"평타 propsOnly (노점)",
				CFrame.lookAt(s.center + Vector3.new(4, 0, 0), s.center),
				Vector3.new(6, 6, 8),
				{ from = s.from, dir = s.dir, propsOnly = true, force = 0.8 }
			)
		)
	end
	-- 궁극기: 광장 가운데 r=60 (LinYuan 과 같은 옵션)
	do
		local s = byId.plaza_centre
		local h = sphereHit(s, 60, { force = 2.4, maxParts = 1500 })
		h.id = "plaza_ult_r60"
		h.dump, h.dumpExtent, h.dumpCam = "plaza_ult_r60", 110, { 0, 175, 30, 0, 0, 0 }
		table.insert(list, h)
	end
	return list
end

-- 한 섹션을 돌린다. 섹션 안에서 오류가 나면 (모듈이 던진 오류 포함) 실패로 기록하고 다음 섹션으로 넘어간다
local function runSection(id: string, fn: () -> ())
	if not enabled(id) then
		return
	end
	local ok, err = xpcall(fn, function(e: any): string
		return tostring(e)
	end)
	if not ok then
		check(id .. "!", "섹션 " .. id .. " 실행 중 오류", false, (string.gsub(tostring(err), "%s*\n%s*", " | ")))
	end
end

----------------------------------------------------------------------
-- 시작
----------------------------------------------------------------------
math.randomseed(opt.seed)
print(string.format("Destruction 검사 — 모듈 %s, 플레이스 %s, seed %d", opt.module, opt.place, opt.seed))
print(string.format("  Lune 우회: 모듈 소스의 .Position %d곳을 __pos(...) 로 바꿔 불러옴 (BasePart.Position 을 Lune 에서 못 읽음)", positionRewrites))
do
	local cf = CFrame.new(1, 2, 3) * CFrame.Angles(0.3, 0.5, 0.7)
	local ok = pcall(function()
		local _ = cf.XVector + cf.YVector + cf.ZVector
		local _p = cf:PointToObjectSpace(Vector3.new(1, 1, 1))
	end)
	print(string.format("  Lune CFrame.XVector/YVector/ZVector/PointToObjectSpace 지원: %s (채우기 없음)", tostring(ok)))
	assert(ok, "Lune CFrame 에 XVector/PointToObjectSpace 가 없습니다")
end

----------------------------------------------------------------------
-- A. 분류
----------------------------------------------------------------------
runSection("A", function()
	section("A. 분류 — 어떤 파트가 부서지나")
	local W = newWorld()
	local map = W.map
	local st = scan(W)

	-- 최상위 묶음 이름: Decor 아래는 하위 폴더, 그 밖은 Map 바로 아래 이름
	local function groupOf(p: Instance): string
		local node: Instance = p
		local chain = {}
		while node and node ~= map do
			table.insert(chain, 1, node.Name)
			node = node.Parent :: Instance
		end
		if chain[1] == "Decor" and chain[2] then
			return "Decor." .. chain[2]
		end
		return chain[1] or "?"
	end

	type Row = { total: number, destructible: number, whole: number }
	local rows: { [string]: Row } = {}
	local order = {}
	local P = problems()
	for id, rec in W.snap.byId do
		local g = groupOf(rec.inst)
		local row = rows[g]
		if not row then
			row = { total = 0, destructible = 0, whole = 0 }
			rows[g] = row
			table.insert(order, g)
		end
		row.total += 1
		if rec.destructible then
			row.destructible += 1
			if rec.whole then
				row.whole += 1
			end
		end
		-- classify() 결과와 실제 등록이 같아야 한다
		if rec.destructible ~= (st.registered[id] ~= nil) then
			bad(P, "classify=%s 인데 등록=%s: %s", tostring(rec.destructible), tostring(st.registered[id] ~= nil), rec.full)
		end
	end
	table.sort(order)
	print(string.format("    %-28s %6s %6s %6s %6s", "묶음", "전체", "부서짐", "통째로", "제외"))
	for _, g in order do
		local r = rows[g]
		print(string.format("    %-28s %6d %6d %6d %6d", g, r.total, r.destructible, r.whole, r.total - r.destructible))
	end
	print(string.format("    %-28s %6d %6d", "합계", W.snap.count, W.snap.destructible))
	report.classification = rows
	check("A1", "classify() 결과와 실제 색인 등록이 일치", P.n == 0, describe(P))
	check(
		"A2",
		"map 의 DestructibleCount 속성 = 등록 수",
		map:GetAttribute("DestructibleCount") == W.snap.destructible,
		string.format("속성 %s, 등록 %d", tostring(map:GetAttribute("DestructibleCount")), W.snap.destructible)
	)

	-- 절대 부서지면 안 되는 묶음
	local never = { "Ground", "Decor.GroundSurfaces", "Decor.Skyline", "Bounds", "Spawns", "DummySpots" }
	for _, g in never do
		local r = rows[g]
		check("A3", "부서지지 않음: " .. g, r ~= nil and r.destructible == 0, if r then string.format("%d/%d 부서짐", r.destructible, r.total) else "묶음이 없음")
	end

	-- Breakable 소품 108개 전부 부서지고, 통째로
	local breakables, bd, bw = 0, 0, 0
	for _, rec in W.snap.byId do
		if rec.breakable then
			breakables += 1
			if rec.destructible then
				bd += 1
			end
			if rec.whole then
				bw += 1
			end
		end
	end
	check("A4", "Breakable 소품 전부 부서짐 (108개)", breakables == 108 and bd == breakables, string.format("Breakable %d, 부서짐 %d", breakables, bd))
	check("A5", "Breakable 소품은 통째로 부서짐", bw == breakables, string.format("%d/%d", bw, breakables))

	-- 규칙 검사: 물, 투명, 바닥 높이, 경기장 밖
	local R = problems()
	for _, rec in W.snap.byId do
		if rec.destructible and not rec.breakable then
			local p = rec.inst
			if p.Material == Enum.Material.Water then
				bad(R, "물: %s", rec.full)
			end
			if p.Transparency >= 0.99 then
				bad(R, "투명: %s", rec.full)
			end
			if rec.top <= 1.05 then
				bad(R, "바닥 높이: %s", rec.full)
			end
			if math.abs(rec.box.c[1]) > 190 or math.abs(rec.box.c[3]) > 190 then
				bad(R, "경기장 밖: %s", rec.full)
			end
		end
	end
	check("A6", "물·투명·바닥(윗면 ≤ 1.05)·경기장 밖 파트는 제외", R.n == 0, describe(R))

	-- 모듈 머리말: "바닥·도로·운하·경계벽·배경 스카이라인은 부서지지 않는다".
	-- 바닥 높이(윗면 ≤ 1.6)의 얇은(높이 ≤ 1.6) 넓은(가로·세로 ≥ 8) 판은 걸어 다니는 바닥이다.
	local floors = problems()
	for _, rec in W.snap.byId do
		if rec.destructible and not rec.breakable then
			local ah = aabbHalf(rec.box)
			if rec.top <= 1.6 and ah[2] * 2 <= 1.6 and math.min(ah[1], ah[3]) * 2 >= 8 then
				bad(floors, "%s (윗면 %.2f, %s)", (string.gsub(rec.full, "^Workspace%.Map%.", "")), rec.top, fmtV(rec.inst.Size))
			end
		end
	end
	check("A7", "걸어 다니는 바닥(윗면 ≤ 1.6, 두께 ≤ 1.6, 넓이 ≥ 8×8)은 부서지지 않음", floors.n == 0, describe(floors))

	-- 큰 파트(최대 치수 > 24)는 쪼개질 수 있어야 한다. 쪼갤 수 있는 축이 전부 2 이하면 스치기만 해도 통째로 사라진다.
	-- (글씨가 달린 간판처럼 일부러 통째로 부수는 파트는 뺀다)
	local unsplittable = problems()
	for _, rec in W.snap.byId do
		if rec.destructible and not rec.breakable then
			local p = rec.inst
			local sz = { p.Size.X, p.Size.Y, p.Size.Z }
			local maxDim = math.max(sz[1], sz[2], sz[3])
			local longest = 0
			for _, a in rec.axes do
				longest = math.max(longest, sz[a])
			end
			local hasGui = p:FindFirstChildWhichIsA("SurfaceGui") ~= nil
			if maxDim > 24 and longest <= 2 and not hasGui then
				bad(unsplittable, "%s (%s %s)", (string.gsub(rec.full, "^Workspace%.Map%.", "")), shapeName(p), fmtV(p.Size))
			end
		end
	end
	check("A8", "큰 파트(> 24)는 실제로 쪼개질 수 있음 (얇은 원판 원기둥은 길이 축이 두께라 못 쪼갬)", unsplittable.n == 0, describe(unsplittable))

	-- 사람이 판단할 의심스러운 분류
	print("\n    의심스러운 분류 (사람이 판단):")
	type Sus = { name: string, count: number, example: string, size: Vector3, top: number, why: string }
	local sus: { [string]: Sus } = {}
	local function flag(rec: Rec, why: string)
		local key = why .. "|" .. rec.full
		local s = sus[key]
		if s then
			s.count += 1
		else
			sus[key] = { name = rec.full, count = 1, example = rec.full, size = rec.inst.Size, top = rec.top, why = why }
		end
	end
	local walkWords = { "Floor", "Stair", "Step", "Landing", "Balcony", "Bridge", "Deck", "Slab", "Walk", "Path", "Platform", "Plank", "Tread", "Roof" }
	for _, rec in W.snap.byId do
		if not rec.destructible or rec.breakable then
			continue
		end
		local p = rec.inst
		local ah = aabbHalf(rec.box)
		local height = ah[2] * 2
		local footprint = math.min(ah[1], ah[3]) * 2
		if rec.top <= 2.0 and height <= 1.6 and footprint >= 4 then
			flag(rec, "바닥 높이의 넓고 얇은 판 (걸어 다니는 바닥?)")
		end
		for _, w in walkWords do
			if string.find(rec.full, w, 1, true) then
				flag(rec, "이름이 발판/바닥/계단/다리 (" .. w .. ")")
				break
			end
		end
		if string.find(rec.full, "Decor.Canal", 1, true) then
			flag(rec, "운하 구조물")
		end
		local maxDim = math.max(p.Size.X, p.Size.Y, p.Size.Z)
		if rec.whole and maxDim > 8 then
			local why = "통째로만 부서지는 큰 파트"
			if shapeName(p) == "Ball" then
				why ..= " (공)"
			elseif not p:IsA("Part") and not p:IsA("WedgePart") then
				why ..= " (" .. p.ClassName .. ")"
			else
				for _, c in p:GetChildren() do
					if not c:IsA("Texture") then
						why ..= " (자식 " .. c.ClassName .. ")"
						break
					end
				end
			end
			flag(rec, why)
		end
		if shapeName(p) == "Cylinder" and p.Size.X < 2 and math.min(p.Size.Y, p.Size.Z) > 6 then
			flag(rec, "원판 모양 원기둥: 길이 축(X)이 짧아 사실상 통째로 부서짐")
		end
	end
	-- 이름(경로)별로 묶어서 출력
	local byWhy: { [string]: { Sus } } = {}
	for _, s in sus do
		local list = byWhy[s.why]
		if not list then
			list = {}
			byWhy[s.why] = list
		end
		table.insert(list, s)
	end
	local whys = {}
	for w in byWhy do
		table.insert(whys, w)
	end
	table.sort(whys)
	local susOut = {}
	for _, w in whys do
		local list = byWhy[w]
		-- 같은 경로 이름을 합친다
		local merged: { [string]: { n: number, size: Vector3, top: number } } = {}
		local names = {}
		for _, s in list do
			local m = merged[s.name]
			if m then
				m.n += s.count
			else
				merged[s.name] = { n = s.count, size = s.size, top = s.top }
				table.insert(names, s.name)
			end
		end
		table.sort(names)
		print(string.format("      · %s — %d개", w, #names))
		local shown = 0
		for _, n in names do
			local m = merged[n]
			shown += 1
			if shown <= 14 then
				print(string.format("          %-62s x%-3d 크기 %s 윗면 %.2f", string.gsub(n, "^Workspace%.Map%.", ""), m.n, fmtV(m.size), m.top))
			end
			table.insert(susOut, { why = w, name = n, count = m.n, size = { m.size.X, m.size.Y, m.size.Z }, top = m.top })
		end
		if shown > 14 then
			print(string.format("          … 외 %d개", shown - 14))
		end
	end
	report.suspicious = susOut

	-- PrimaryPart 로 쓰이는 파트 (로블록스는 PrimaryPart 가 모델 밖으로 나가면 nil 로 만든다 → 복구 후에도 nil)
	local pp = 0
	local ppNames = {}
	for _, d in map:GetDescendants() do
		if d:IsA("Model") then
			local prim = (d :: any).PrimaryPart
			if prim and W.snap.byId[prim:GetDebugId()] and W.snap.byId[prim:GetDebugId()].destructible then
				pp += 1
				ppNames[d.Name] = (ppNames[d.Name] or 0) + 1
			end
		end
	end
	local ppList = {}
	for n, c in ppNames do
		table.insert(ppList, string.format("%s x%d", n, c))
	end
	table.sort(ppList)
	note("PrimaryPart 가 부서지는 파트인 모델: %d개 (%s)", pp, table.concat(ppList, ", "))
	report.primaryPartModels = pp
end)

----------------------------------------------------------------------
-- B. 기하 성질
----------------------------------------------------------------------
runSection("B", function()
	section("B. 기하 — fracture / intersects / inside")
	local W = newWorld()
	local T = W.D._test
	local TAU = math.pi * 2

	local function randRot(): CFrame
		local m = math.random()
		if m < 0.25 then
			-- 축 정렬 (90도 단위)
			return CFrame.Angles(math.random(0, 3) * math.pi / 2, math.random(0, 3) * math.pi / 2, math.random(0, 3) * math.pi / 2)
		elseif m < 0.5 then
			-- Y 축만 (맵 파트 대부분)
			return CFrame.Angles(0, math.random() * TAU, 0)
		elseif m < 0.6 then
			-- 거의 평행 (교차축이 0 에 가까운 경우)
			local e = 2e-3
			return CFrame.Angles((math.random() - 0.5) * e, (math.random() - 0.5) * e, (math.random() - 0.5) * e)
		end
		return CFrame.Angles(math.random() * TAU, math.random() * TAU, math.random() * TAU)
	end

	local function randSize(lo: number, hi: number): number
		-- 얇은 판·긴 막대도 나오게 로그 균등
		return math.exp(math.log(lo) + math.random() * (math.log(hi) - math.log(lo)))
	end

	local function randOffset(scale: { number }): Vector3
		return Vector3.new((math.random() * 2 - 1) * scale[1], (math.random() * 2 - 1) * scale[2], (math.random() * 2 - 1) * scale[3])
	end

	-- 무작위 조각 + 근처의 무작위 영역
	type Case = { cf: CFrame, size: Vector3, R: any, ref: RefRegion, scale: number }
	local function randomCase(maxSize: number): Case
		local cf = CFrame.new((math.random() - 0.5) * 40, (math.random() - 0.5) * 40, (math.random() - 0.5) * 40) * randRot()
		local size = Vector3.new(randSize(0.2, maxSize), randSize(0.2, maxSize), randSize(0.2, maxSize))
		local pb = boxOf(cf, size)
		local ph = aabbHalf(pb)
		if math.random() < 0.5 then
			local r = randSize(0.3, 12)
			local center = cf.Position + randOffset({ ph[1] + r, ph[2] + r, ph[3] + r }) * 1.05
			local R = T.makeRegion(true, CFrame.new(center), Vector3.new(r, r, r), r)
			return {
				cf = cf,
				size = size,
				R = R,
				ref = { sphere = true, box = boxOf(CFrame.new(center), Vector3.new(r, r, r) * 2), center = { center.X, center.Y, center.Z }, r = r },
				scale = math.max(size.X, size.Y, size.Z, r),
			}
		end
		local half = Vector3.new(randSize(0.15, 10), randSize(0.15, 10), randSize(0.15, 10))
		local rot = if math.random() < 0.2 then (cf - cf.Position) else randRot()
		local rb = boxOf(rot, half * 2)
		local rh = aabbHalf(rb)
		local center = cf.Position + randOffset({ ph[1] + rh[1], ph[2] + rh[2], ph[3] + rh[3] }) * 1.05
		local rcf = CFrame.new(center) * rot
		local R = T.makeRegion(false, rcf, half, 0)
		return {
			cf = cf,
			size = size,
			R = R,
			ref = { sphere = false, box = boxOf(rcf, half * 2), center = { center.X, center.Y, center.Z }, r = 0 },
			scale = math.max(size.X, size.Y, size.Z, half.X * 2, half.Y * 2, half.Z * 2),
		}
	end

	-- B1..B9: fracture 성질
	local AXES = { { 1, 2, 3 }, { 1 }, { 2 }, { 3 }, { 1, 2 }, { 1, 3 }, { 2, 3 }, {} }
	local F = {
		volume = problems(),
		contain = problems(),
		rotation = problems(),
		overlap = problems(),
		keepInside = problems(),
		removedMiss = problems(),
		axisOnly = problems(),
		grain = problems(),
		keepHits = problems(),
		budget = problems(),
	}
	local totalPieces, maxPieces, exhausted = 0, 0, 0
	local t0 = os.clock()
	for trial = 1, opt.trials do
		local c = randomCase(24)
		local axes = AXES[math.random(#AXES)]
		local maxDim = math.max(c.size.X, c.size.Y, c.size.Z)
		-- 대부분은 굵은 결, 일부는 아주 잘게 (조각 수백 개)
		local grain = if math.random() < 0.2 then math.max(maxDim / 40, 0.2) else math.max(maxDim / 12, 0.3) + math.random() * 3
		local budgetN = if math.random() < 0.15 then math.random(0, 40) else 100000
		local budget = { n = budgetN }
		local keep, removed = {}, {}
		T.fracture(c.cf, c.size, axes, c.R, grain, keep, removed, budget)
		local n = #keep + #removed
		totalPieces += n
		maxPieces = math.max(maxPieces, n)
		local ranOut = budget.n <= 0
		if ranOut then
			exhausted += 1
		end
		local orig = boxOf(c.cf, c.size)
		local tol = 1e-4 * maxDim + 1e-5
		local margin = 1e-3 * c.scale + 1e-4
		local tag = string.format("#%d", trial)

		-- (1) 부피 보존
		local vol = 0
		for _, list in { keep, removed } do
			for _, p in list do
				vol += p.size.X * p.size.Y * p.size.Z
			end
		end
		local v0 = c.size.X * c.size.Y * c.size.Z
		if math.abs(vol - v0) > 1e-6 * v0 then
			bad(F.volume, "%s 부피 %.6g ≠ %.6g", tag, vol, v0)
		end
		-- 예산: 쪼갠 횟수 = 조각 수 - 1, 음수가 되면 안 된다
		if budgetN - budget.n ~= n - 1 or budget.n < 0 then
			bad(F.budget, "%s 예산 %d→%d 인데 조각 %d개", tag, budgetN, budget.n, n)
		end

		local boxes: { LocalBox } = {}
		local splittable = { false, false, false }
		for _, a in axes do
			splittable[a] = true
		end
		for kind, list in { keep = keep, removed = removed } do
			for _, p in list do
				local pb = boxOf(p.cf, p.size)
				local lb = localAABB(orig, pb)
				table.insert(boxes, lb)
				-- (2) 원본 상자 안
				for i = 1, 3 do
					if lb.lo[i] < -orig.h[i] - tol or lb.hi[i] > orig.h[i] + tol then
						bad(F.contain, "%s %s 조각이 원본 밖", tag, kind)
						break
					end
				end
				if lb.rotErr > 1e-4 then
					bad(F.rotation, "%s %s 조각 회전 오차 %.2g", tag, kind, lb.rotErr)
				end
				-- (6) 쪼갤 수 없는 축으로는 크기·위치가 그대로
				local sz = { p.size.X, p.size.Y, p.size.Z }
				local osz = { c.size.X, c.size.Y, c.size.Z }
				for i = 1, 3 do
					if not splittable[i] then
						local mid = (lb.lo[i] + lb.hi[i]) / 2
						if sz[i] ~= osz[i] or math.abs(mid) > tol then
							bad(F.axisOnly, "%s axes={%s} 인데 %d축이 바뀜 (크기 %.4g→%.4g, 중심 %.2g)", tag, table.concat(axes, ","), i, osz[i], sz[i], mid)
							break
						end
					end
				end
				if kind == "keep" then
					-- (4) 남긴 조각이 영역 안에 완전히 들어가면 안 된다
					if refInside(pb, c.ref, margin) == 1 then
						bad(F.keepInside, "%s 영역 안에 완전히 들어간 조각을 남김", tag)
					end
					-- 예산이 남았으면 남긴 조각은 영역과 겹치면 안 된다
					if not ranOut and refIntersects(pb, c.ref, margin) == 1 then
						bad(F.keepHits, "%s 영역과 겹치는 조각을 남김 (크기 %s)", tag, fmtV(p.size))
					end
				else
					-- (5) 없앤 조각은 영역과 겹쳐야 한다
					if refIntersects(pb, c.ref, margin) == -1 then
						bad(F.removedMiss, "%s 영역과 안 겹치는 조각을 없앰", tag)
					end
					-- 결: 영역 밖으로 걸친 채 없앤 조각은 쪼갤 수 있는 축이 전부 결 이하
					if not ranOut and #axes > 0 and refInside(pb, c.ref, margin) == -1 then
						for i = 1, 3 do
							if splittable[i] and sz[i] > grain + 1e-6 then
								bad(F.grain, "%s 결 %.3g 보다 큰 경계 조각 (%d축 %.3g)", tag, grain, i, sz[i])
								break
							end
						end
					end
				end
			end
		end
		-- (3) 조각끼리 부피가 겹치면 안 된다
		local ov = countOverlaps(boxes, tol)
		if ov > 0 then
			bad(F.overlap, "%s 겹치는 쌍 %d", tag, ov)
		end
	end
	local elapsed = os.clock() - t0
	note("%d회, 조각 합계 %d (최대 %d/회), 예산 소진 %d회, %.1f초", opt.trials, totalPieces, maxPieces, exhausted, elapsed)
	check("B1", "부피 보존: 남김 + 없앰 = 원본 (상대 1e-6)", F.volume.n == 0, describe(F.volume))
	check("B2", "모든 조각이 원본 상자 안", F.contain.n == 0, describe(F.contain))
	check("B2r", "모든 조각이 원본과 같은 회전", F.rotation.n == 0, describe(F.rotation))
	check("B3", "조각끼리 부피가 겹치지 않음", F.overlap.n == 0, describe(F.overlap))
	check("B4", "남긴 조각은 영역 안에 완전히 들어가지 않음", F.keepInside.n == 0, describe(F.keepInside))
	check("B5", "없앤 조각은 전부 영역과 겹침", F.removedMiss.n == 0, describe(F.removedMiss))
	check("B6", "쪼갤 수 없는 축(원기둥·쐐기는 Y/Z)은 크기·중심 그대로", F.axisOnly.n == 0, describe(F.axisOnly))
	check("B7", "예산이 남으면 남긴 조각은 영역과 겹치지 않음", F.keepHits.n == 0, describe(F.keepHits))
	check("B8", "예산이 남으면 경계 조각은 결 이하 크기", F.grain.n == 0, describe(F.grain))
	check("B9", "쪼갠 횟수 = 조각 수 - 1, 예산은 음수가 되지 않음", F.budget.n == 0, describe(F.budget))

	-- B10..: intersects / inside 교차 검증
	local stats = {
		fn = 0, -- 확실히 겹치는데 intersects=false (버그)
		fp = 0, -- 확실히 떨어졌는데 intersects=true
		fpMaxGap = 0, -- 거짓 양성 중 가장 큰 틈 (크기 대비)
		ambiguous = 0,
		clearOverlap = 0,
		clearSep = 0,
		inFp = 0, -- 삐져나왔는데 inside=true (버그: 영역 밖 물질을 없앤다)
		inFn = 0, -- 완전히 안인데 inside=false (성능만 손해)
		harness = 0, -- 기준 구현끼리 모순 (하네스 버그)
		sphereFn = 0,
		boxFn = 0,
	}
	local fnExamples = problems()
	local inExamples = problems()
	local fpExamples = problems()
	t0 = os.clock()
	for trial = 1, opt.pairs do
		local c = randomCase(if math.random() < 0.1 then 120 else 20)
		local pb = boxOf(c.cf, c.size)
		local margin = 1e-3 * c.scale + 1e-4
		local mi = T.intersects(c.cf, c.size, c.R)
		local mIn = T.inside(c.cf, c.size, c.R)
		local ri = refIntersects(pb, c.ref, margin)
		if not c.ref.sphere then
			-- 기준끼리 모순: 증인이 있는데 분리축 틈이 양수
			if ri == 1 and satGap(pb, c.ref.box) > 0 then
				stats.harness += 1
			end
		end
		if ri == 1 then
			stats.clearOverlap += 1
			if not mi then
				stats.fn += 1
				if c.ref.sphere then
					stats.sphereFn += 1
				else
					stats.boxFn += 1
				end
				bad(fnExamples, "#%d %s 조각 %s 영역 %s", trial, if c.ref.sphere then "구" else "상자", fmtV(c.size), if c.ref.sphere then string.format("r=%.2f", c.ref.r) else "")
			end
		elseif ri == -1 then
			stats.clearSep += 1
			if mi then
				stats.fp += 1
				local gap = if c.ref.sphere then sphereNear(pb, c.ref.center) - c.ref.r else satGap(pb, c.ref.box)
				local rel = gap / c.scale
				if rel > stats.fpMaxGap then
					stats.fpMaxGap = rel
				end
				bad(fpExamples, "#%d 틈 %.3g (크기 대비 %.2g)", trial, gap, rel)
			end
		else
			stats.ambiguous += 1
		end
		local rin = refInside(pb, c.ref, margin)
		if rin == -1 and mIn then
			stats.inFp += 1
			bad(inExamples, "#%d inside=true 인데 %.3g 삐져나옴", trial, if c.ref.sphere then sphereFar(pb, c.ref.center) - c.ref.r else boxOut(pb, c.ref.box))
		elseif rin == 1 and not mIn then
			stats.inFn += 1
		end
		-- inside 이면 intersects 여야 한다
		if mIn and not mi then
			bad(inExamples, "#%d inside=true 인데 intersects=false", trial)
		end
	end
	note(
		"%d쌍 (%.1f초): 확실히 겹침 %d, 확실히 떨어짐 %d, 경계라 보류 %d",
		opt.pairs,
		os.clock() - t0,
		stats.clearOverlap,
		stats.clearSep,
		stats.ambiguous
	)
	note("intersects 거짓 음성 %d (구 %d, 상자 %d), 거짓 양성 %d (가장 큰 틈 = 크기의 %.2g)", stats.fn, stats.sphereFn, stats.boxFn, stats.fp, stats.fpMaxGap)
	note("inside 거짓 양성 %d, 거짓 음성 %d / 기준 구현 모순 %d", stats.inFp, stats.inFn, stats.harness)
	check("B10", "intersects: 확실히 겹치는 쌍을 놓치지 않음 (거짓 음성 0)", stats.fn == 0, describe(fnExamples))
	check(
		"B11",
		"intersects: 거짓 양성은 EPS 수준 (틈 ≤ 크기의 1e-3)",
		stats.fpMaxGap <= 1e-3,
		if stats.fp > 0 then string.format("%d건, 최대 %.2g — %s", stats.fp, stats.fpMaxGap, describe(fpExamples)) else ""
	)
	check("B12", "inside: 삐져나온 조각을 안이라고 하지 않음", stats.inFp == 0 and inExamples.n == stats.inFp, describe(inExamples))
	check("B13", "기준 구현(분리축·증인) 서로 모순 없음", stats.harness == 0, tostring(stats.harness))
	report.geometry = stats
end)

----------------------------------------------------------------------
-- C. 맵 시나리오
----------------------------------------------------------------------
runSection("C", function()
	section("C. 맵 시나리오 — 하나씩 부수고 검사한 뒤 Heartbeat 로 복구")
	local W = newWorld()
	local hits = scenarioList(W)
	for _, h in hits do
		note("%-26s %s  %s %s", h.id, h.label, if h.sphere then "구 r=" .. h.radius else "상자 " .. fmtV(h.size), fmtV(h.center))
	end
	print("")
	printHitHeader()
	local invalid = problems()
	local contract = problems()
	local notRestored = problems()
	local empty = problems()
	local overshoot = problems()
	local times = {}
	for _, h in hits do
		writeDump(W, h, "before")
		local fx0 = #W.fx
		local st0 = scan(W)
		local must = mustBreak(W, st0, h)
		local stats, st = runHit(W, h, st0)
		printHit(stats)
		table.insert(report.scenarios, stats)
		table.insert(times, stats.ms)
		-- 영역과 확실히 겹친 파트는 전부 부서져야 한다. 상한(maxParts)에 걸렸으면 건너뛰고,
		-- 쪼개기 예산을 다 썼을 수도 있으면 가운데가 영역 안인 파트만 본다
		local cap = h.opts.maxParts or S.MaxPartsPerCall
		local mayExhaust = stats.created + stats.sentPieces >= S.MaxSplitsPerCall * 0.9 or stats.sentPieces >= S.MaxDebrisSent
		if stats.affected < cap then
			for _, m in must do
				if st.all[m.id] and (m.centreInside or not mayExhaust) then
					bad(empty, "%s: 영역과 겹치는데 안 부서짐 %s", h.id, (string.gsub(m.name, "^Workspace%.Map%.", "")))
				end
			end
		end
		if stats.splitRemoved > stats.bound + 1 then
			bad(
				overshoot,
				"%s: 영역 한도 %.0f 인데 %.0f 없앰 (%.0f배, 대부분 %s %.0f)",
				h.id,
				stats.bound,
				stats.splitRemoved,
				stats.splitRemoved / stats.bound,
				stats.worst,
				stats.worstVolume
			)
		end
		for _, s in stats.contract.list do
			bad(contract, "%s: %s", h.id, s)
		end
		local P = validate(W, st)
		if P.n > 0 then
			bad(invalid, "%s: %s", h.id, describe(P))
		end
		if h.dump then
			local debris = {}
			for i = fx0 + 1, #W.fx do
				if W.fx[i].name == "Shatter" then
					for _, g in W.fx[i].payload.groups do
						for _, p in g.pieces do
							table.insert(debris, { cframe = { p.cf:GetComponents() }, size = { p.size.X, p.size.Y, p.size.Z } })
						end
					end
				end
			end
			writeDump(W, h, "after", debris)
		end
		local info = restoreByHeartbeat(W)
		local R = compareToSnapshot(W)
		if R.n > 0 or info.contract.n > 0 then
			bad(notRestored, "%s: %s %s", h.id, describe(R), describe(info.contract))
		end
	end
	check("C1", "영역과 확실히 겹치는 등록 파트는 전부 부서짐 (색인·조회에서 빠지는 파트 없음)", empty.n == 0, describe(empty))
	check("C2", "부순 뒤 상태 일관성 (고정·부모·등록·원본 상자 안·안 겹침·pieceCount·색인)", invalid.n == 0, describe(invalid))
	check("C3", "Shatter 형식·조각 수 ≤ MaxDebrisSent·보낸 부피 ≤ 없어진 부피", contract.n == 0, describe(contract))
	check("C4", "각 시나리오 뒤 Heartbeat 복구로 처음 상태와 완전히 같아짐", notRestored.n == 0, describe(notRestored))
	check(
		"C5",
		"쪼갤 수 있는 파트는 영역(+결 대각선) 안쪽만 없어짐 — 작은 타격이 큰 파트를 통째로 지우지 않음",
		overshoot.n == 0,
		describe(overshoot)
	)
	report.perf.scenarioMs = { p50 = percentile(times, 0.5), p95 = percentile(times, 0.95), max = percentile(times, 1) }
end)

----------------------------------------------------------------------
-- D. 복구
----------------------------------------------------------------------
runSection("D", function()
	section("D. 복구 — 누적 파괴 뒤 Heartbeat 만으로 원래대로")
	local W = newWorld()
	local hits = scenarioList(W)
	local ult: Hit? = nil
	local st = scan(W)
	for _, h in hits do
		if h.id == "plaza_ult_r60" then
			ult = h
			continue
		end
		local _s
		_s, st = runHit(W, h, st)
	end
	local P = validate(W, st)
	check("D1", "작은 파괴 누적 뒤 상태 일관성", P.n == 0, describe(P))
	note("누적: 조각 %d, 보관 폴더 %d, 원본 빠짐 %d", W.D.pieceCount(), #W.holding:GetChildren(), #st.missing)

	-- 복구 시간 전에는 아무것도 돌아오지 않아야 한다 (조각 수 상한 아래일 때)
	local pc0, held0 = W.D.pieceCount(), #W.holding:GetChildren()
	advance(W, S.RestoreTime - 5)
	if pc0 <= S.MaxPieces then
		check(
			"D2",
			"RestoreTime 전에는 복구되지 않음",
			W.D.pieceCount() == pc0 and #W.holding:GetChildren() == held0,
			string.format("조각 %d→%d, 보관 %d→%d", pc0, W.D.pieceCount(), held0, #W.holding:GetChildren())
		)
	else
		note("조각 %d > MaxPieces 라 조기 복구가 정상 — D2 생략", pc0)
	end
	-- 궁극기까지
	local stU
	local ultStats
	ultStats, stU = runHit(W, ult :: Hit)
	printHitHeader()
	printHit(ultStats)
	local P2 = validate(W, stU)
	check("D3", "궁극기 누적 뒤 상태 일관성", P2.n == 0, describe(P2))

	local info = restoreByHeartbeat(W)
	note("복구: 가상 %.1f초, Rebuild %d번 (한 번에 최대 %d개), 0.5초당 최대 %d개 복구", info.seconds, info.rebuilds, info.maxPerEvent, info.maxPerTick)
	check("D4", "Rebuild 형식 (positions/sizes, 1~24개)", info.contract.n == 0, describe(info.contract))
	check("D5", "0.5초에 RestorePerTick 이하로 복구", info.maxPerTick <= S.RestorePerTick, string.format("최대 %d / %d", info.maxPerTick, S.RestorePerTick))
	local R = compareToSnapshot(W)
	check("D6", "Heartbeat 만으로 처음 상태와 완전히 같아짐 (파트·속성·부모·보관 폴더·pieceCount·색인)", R.n == 0, describe(R))

	-- 캐릭터가 서 있으면 미룬다
	do
		local W2 = newWorld()
		local sites = findSites(W2)
		local noodle = sites[1]
		-- 구멍 셋: 광장 바닥 한쪽, 국수집 서쪽 벽(안쪽), 찻집 정면 아래쪽
		local teahouse = find(W2, "Decor.NorthShopRow.TeahouseBody")
		local tlo, thi = boundsOf(teahouse)
		local tc = Vector3.new((tlo.X + thi.X) / 2, 5, thi.Z + 0.3)
		runHit(W2, sphereHit({ id = "plaza_floor", label = "광장 바닥", center = Vector3.new(20, 1.3, 20), from = Vector3.new(20, 8, 20), dir = Vector3.new(0, -1, 0) }, 3))
		runHit(W2, sphereHit(noodle, 6))
		runHit(W2, sphereHit({ id = "teahouse", label = "찻집 정면", center = tc, from = tc + Vector3.new(0, 0, 10), dir = Vector3.new(0, 0, -1) }, 4))
		-- 캐릭터 1: 벽 구멍 바로 앞(가게 안) — 미뤄야 한다
		-- 캐릭터 2: 광장 바닥 구멍에서 60 스터드 떨어진 바닥 위, 캐릭터 3: 찻집 구멍에서 55 스터드 떨어진 찻집 지붕 위 — 막으면 안 된다
		addCharacter(W2, Vector3.new(noodle.center.X + 1.7, 0.6, noodle.center.Z))
		addCharacter(W2, Vector3.new(-30, 1.3, -30))
		addCharacter(W2, Vector3.new(tc.X, thi.Y, tlo.Z + 10))
		advance(W2, S.RestoreTime + 15)
		local stillBroken = {}
		for _, id in scan(W2).missing do
			table.insert(stillBroken, (string.gsub(W2.snap.byId[id].full, "^Workspace%.Map%.", "")))
		end
		table.sort(stillBroken)
		note("캐릭터 3명이 있을 때 %d초 뒤에도 안 돌아온 원본: %s", S.RestoreTime + 15, table.concat(stillBroken, ", "))
		local wallDeferred = false
		local farDeferred = {}
		for _, n in stillBroken do
			if string.find(n, "ShopWallWest", 1, true) then
				wallDeferred = true
			elseif string.find(n, "Plaza", 1, true) or string.find(n, "TeahouseBody", 1, true) then
				table.insert(farDeferred, n)
			end
		end
		check("D7", "구멍 바로 앞에 캐릭터가 있으면 그 파트 복구를 미룸", wallDeferred, "")
		check(
			"D8",
			"구멍에서 먼 캐릭터(같은 큰 파트 위)는 복구를 막지 않음",
			#farDeferred == 0,
			if #farDeferred > 0
				then string.format("55~60 스터드 떨어진 캐릭터 때문에 안 돌아옴: %s (원본 상자 전체로 겹침 검사)", table.concat(farDeferred, ", "))
				else ""
		)
		note("겹침 조회 %d번", W2.occupancyQueries)
		table.clear(W2.chars)
		restoreByHeartbeat(W2)
		local R2 = compareToSnapshot(W2)
		check("D9", "캐릭터가 비킨 뒤 전부 복구", R2.n == 0, describe(R2))
	end
end)

----------------------------------------------------------------------
-- E. 반복 파괴 (조각의 조각)
----------------------------------------------------------------------
runSection("E", function()
	section("E. 반복 파괴 — 같은 벽을 겹치게·붙여서")
	local W = newWorld()
	local wall = find(W, "Decor.NoodleShop_LinJi.ShopWallWest")
	local lo, hi = boundsOf(wall)
	local x = hi.X + 0.2 -- 가게 안쪽 면
	local zc = (lo.Z + hi.Z) / 2
	local base: Site = { id = "wall", label = "국수집 서쪽 벽", center = Vector3.new(x, 6, zc), from = Vector3.new(x + 20, 6, zc), dir = Vector3.new(-1, 0, 0) }
	local function at(dz: number, dy: number): Site
		return { id = base.id, label = base.label, center = base.center + Vector3.new(0, dy, dz), from = base.from, dir = base.dir }
	end
	local seq: { Hit } = {
		sphereHit(at(0, 0), 4),
		sphereHit(at(0, 0), 4), -- 똑같은 자리 한 번 더 → 아무것도 안 부서져야 한다
		sphereHit(at(2, 0), 4), -- 겹치게
		sphereHit(at(8, 0), 4), -- 붙여서
		sphereHit(at(-6, 3), 3),
		sphereHit(at(1, 1), 7), -- 크게 덮기
		boxHit(
			"slash",
			"비스듬한 참격",
			CFrame.new(base.center + Vector3.new(-0.5, 2, -2)) * CFrame.Angles(0, 0, math.rad(30)),
			Vector3.new(2.5, 3, 22),
			{ dir = Vector3.new(1, 0, 0) }
		),
		boxHit("props", "평타 (조각 부수기)", CFrame.new(base.center + Vector3.new(-0.5, -2, 5)), Vector3.new(3, 4, 6), { propsOnly = true }),
		sphereHit(at(-3, -2), 2.5, { grain = 0.8 }), -- 아주 잘게
	}
	for i, h in seq do
		h.id = string.format("E%d_%s", i, h.id)
	end
	printHitHeader()
	local st = scan(W)
	local P = problems()
	local nested = problems()
	local volP = problems()
	local repeatOk = true
	local wallId = wall:GetDebugId()
	for i, h in seq do
		-- 부수기 전 이 벽의 조각들 (원본이 맵에 있으면 원본 하나)
		local prev: { LocalBox } = {}
		local origBox = W.snap.byId[wallId].box
		if st.originals[wallId] then
			table.insert(prev, localAABB(origBox, origBox))
		else
			for _, pc in st.pieces do
				if pc.origin == wallId then
					table.insert(prev, localAABB(origBox, pc.box))
				end
			end
		end
		local volBefore = st.volume
		local stats
		stats, st = runHit(W, h, st)
		printHit(stats)
		if i == 2 and (stats.affected ~= 0 or stats.shatters ~= 0) then
			repeatOk = false
		end
		local V = validate(W, st)
		if V.n > 0 then
			bad(P, "%s: %s", h.id, describe(V))
		end
		for _, s in stats.contract.list do
			bad(P, "%s: %s", h.id, s)
		end
		if st.volume > volBefore + 1e-3 then
			bad(volP, "%s: 맵 부피가 늘어남 %.3f → %.3f", h.id, volBefore, st.volume)
		end
		-- 새 조각은 전부 이전 조각(또는 원본) 하나 안에 들어가야 한다 → 한 번 뚫린 구멍은 다시 메워지지 않는다
		local scale = math.max(origBox.h[1], origBox.h[2], origBox.h[3])
		for _, pc in st.pieces do
			if pc.origin == wallId then
				local lb = localAABB(origBox, pc.box)
				local inside = false
				for _, q in prev do
					if containedIn(lb, q, 1e-4 * scale + 1e-4) then
						inside = true
						break
					end
				end
				if not inside then
					bad(nested, "%s: 이전 조각 밖에 생긴 조각 (구멍이 메워짐)", h.id)
				end
			end
		end
	end
	check("E1", "반복 파괴 중 상태 일관성·Shatter 형식", P.n == 0, describe(P))
	check("E2", "똑같은 자리를 다시 치면 아무것도 안 부서짐 (Shatter 없음)", repeatOk, "")
	check("E3", "남은 조각은 항상 이전 조각 안 (구멍이 다시 메워지지 않음)", nested.n == 0, describe(nested))
	check("E4", "맵 부피는 줄기만 함", volP.n == 0, describe(volP))
	local info = restoreByHeartbeat(W)
	local R = compareToSnapshot(W)
	check("E5", "반복 파괴 뒤 복구하면 처음과 완전히 같음", R.n == 0 and info.contract.n == 0, describe(R) .. describe(info.contract))
end)

----------------------------------------------------------------------
-- F. 예산
----------------------------------------------------------------------
runSection("F", function()
	section("F. 예산 — 큰 폭발 연속, 작은 타격 " .. opt.stress .. "번, 조각 수 상한")
	local W = newWorld()
	local ult = sphereHit({ id = "plaza", label = "광장", center = Vector3.new(0, 3, 0), from = Vector3.new(0, 12, 0), dir = Vector3.zero }, 60, { force = 2.4, maxParts = 1500 })
	printHitHeader()
	local s1, st = runHit(W, ult)
	s1.id = "ult_1"
	printHit(s1)
	W.now += 0.2
	local s2
	s2, st = runHit(W, ult, st)
	s2.id = "ult_2"
	printHit(s2)
	report.perf.ult = { first = s1, second = s2 }
	local P = validate(W, st)
	check("F1", "r=60 두 번 연속 뒤 상태 일관성", P.n == 0, describe(P))
	check("F2", "두 번째 r=60 은 첫 번째보다 싸다 (이미 비었음)", s2.ms <= s1.ms * 1.5 + 5, string.format("%.1fms → %.1fms", s1.ms, s2.ms))
	local info = restoreByHeartbeat(W)
	local R = compareToSnapshot(W)
	check("F3", "r=60 두 번 뒤 복구하면 처음과 같음", R.n == 0, describe(R))

	-- 작은 타격 200번: 부서지는 파트 표면 근처를 무작위로 (몸 박힘·평타·참격 섞어서)
	local targets: { Instance } = {}
	for _, rec in W.snap.byId do
		if rec.destructible then
			table.insert(targets, rec.inst)
		end
	end
	table.sort(targets, function(a, b)
		return a:GetDebugId() < b:GetDebugId()
	end)
	math.randomseed(opt.seed + 1)
	local times = {}
	local maxCount = 0
	local SP = problems()
	for i = 1, opt.stress do
		local p = targets[math.random(#targets)]
		local b = boxOf(p.CFrame, p.Size)
		local l = { (math.random() * 2 - 1) * b.h[1], (math.random() * 2 - 1) * b.h[2], (math.random() * 2 - 1) * b.h[3] }
		local w = toWorld(b, l)
		local c = Vector3.new(w[1], w[2], w[3])
		local roll = math.random()
		local h: Hit
		if roll < 0.55 then
			h = sphereHit({ id = "s", label = "", center = c, from = c + Vector3.new(0, 0, -6), dir = Vector3.new(0, 0, 1) }, 2 + math.random() * 6)
		elseif roll < 0.8 then
			local yaw = math.random() * math.pi * 2
			h = boxHit("slash", "", CFrame.new(c) * CFrame.Angles(0, yaw, 0), Vector3.new(3 + math.random() * 6, 3 + math.random() * 5, 8 + math.random() * 20), {})
		else
			h = boxHit("m1", "", CFrame.new(c), Vector3.new(5, 5, 6), { propsOnly = true })
		end
		h.id = string.format("stress_%d", i)
		local _, ms, C = runHitLight(W, h)
		table.insert(times, ms)
		local n = W.D.pieceCount()
		maxCount = math.max(maxCount, n)
		for _, s in C.list do
			bad(SP, "%s", s)
		end
		-- 게임처럼 시간이 흐른다 (0.05 ~ 0.5초)
		advance(W, 0.05 + math.random() * 0.45, 1 / 30)
	end
	local V = validate(W, scan(W))
	note(
		"작은 타격 %d번: 호출당 p50 %.2fms, p95 %.2fms, 최대 %.2fms / 조각 수 최대 %d, 끝 %d",
		opt.stress,
		percentile(times, 0.5),
		percentile(times, 0.95),
		percentile(times, 1),
		maxCount,
		W.D.pieceCount()
	)
	report.perf.stress = { p50 = percentile(times, 0.5), p95 = percentile(times, 0.95), max = percentile(times, 1), maxPieces = maxCount }
	check("F4", "작은 타격 뒤 상태 일관성·Shatter 형식", V.n == 0 and SP.n == 0, describe(V) .. describe(SP))

	restoreByHeartbeat(W)

	-- 날아가는 몸이 건물을 관통: Combat 처럼 0.05초마다 r=5 구를 2.5 스터드씩 앞으로 (속도 50) — 1초 동안의 부담
	do
		local body = find(W, "Decor.NorthShopRow.TeahouseBody")
		local lo, hi = boundsOf(body)
		local start = Vector3.new((lo.X + hi.X) / 2, 6, hi.Z + 2)
		local st = scan(W)
		local created, destroyed, sent, bytes, worstMs = 0, 0, 0, 0, 0
		for i = 0, 19 do
			local c = start + Vector3.new(0, 0, -2.5 * i)
			local stats
			stats, st = runHit(W, sphereHit({ id = "crash", label = "", center = c, from = c + Vector3.new(0, 0, 3), dir = Vector3.new(0, 0, -1) }, 5, { force = 1.4 }), st)
			created += stats.created
			destroyed += stats.piecesDestroyed + stats.originalsBroken
			sent += stats.sentPieces
			bytes += stats.sentBytes
			worstMs = math.max(worstMs, stats.ms)
			W.now += 0.05
			;(W.hb :: (number) -> ())(0.05)
		end
		note(
			"몸이 찻집을 1초 관통 (20번): 새 조각 %d개 생성 + %d개 제거 (복제되는 인스턴스 변화 ~%d/초), 잔해 %d개 ~%.0fKB/초, 호출당 최대 %.1fms",
			created,
			destroyed,
			created + destroyed,
			sent,
			bytes / 1024,
			worstMs
		)
		report.perf.bodyTrail = { created = created, destroyed = destroyed, sentPieces = sent, kb = bytes / 1024, maxMs = worstMs }
		restoreByHeartbeat(W)
	end

	-- 조각 수 상한 (MaxPieces): 큰 건물 몸통에 결이 고운(grain 1.25, 참격 투사체와 비슷) r=8~10 구를
	-- 0.05초 간격으로 연달아 부딪쳐서 상한을 넘긴 뒤, 더 치지 않아도 복구 시간 전에 조기 복구로 상한 아래로 내려오는지 본다.
	-- (결이 굵으면 0.75×MaxPieces 에서 결이 두 배가 되고 35초 복구가 따라잡아서 상한까지 잘 안 간다)
	local bodies: { Rec } = {}
	for _, rec in W.snap.byId do
		local longest = 0
		local sz = rec.inst.Size
		for _, a in rec.axes do
			longest = math.max(longest, if a == 1 then sz.X elseif a == 2 then sz.Y else sz.Z)
		end
		if rec.destructible and longest > 8 and volume(rec.box) > 2000 then
			table.insert(bodies, rec)
		end
	end
	table.sort(bodies, function(a, b)
		return a.full < b.full
	end)

	local function barrage(label: string, stopAbove: number, maxHits: number): (number, number, { number })
		local peak, hits = 0, 0
		local ms = {}
		while hits < maxHits and W.D.pieceCount() <= stopAbove do
			hits += 1
			local rec = bodies[math.random(#bodies)]
			-- 무작위 면 위의 무작위 점
			local l = { (math.random() * 2 - 1) * rec.box.h[1], (math.random() * 2 - 1) * rec.box.h[2], (math.random() * 2 - 1) * rec.box.h[3] }
			local k = math.random(3)
			l[k] = (if math.random() < 0.5 then -1 else 1) * rec.box.h[k]
			local w = toWorld(rec.box, l)
			local c = Vector3.new(w[1], w[2], w[3])
			local h = sphereHit({ id = label, label = label, center = c, from = c, dir = Vector3.zero }, 8 + math.random() * 2, { grain = 1.25 })
			h.id = string.format("%s_%d", label, hits)
			local _, t, C = runHitLight(W, h)
			table.insert(ms, t)
			for _, msg in C.list do
				bad(SP, "%s", msg)
			end
			peak = math.max(peak, W.D.pieceCount())
			W.now += 0.05
			;(W.hb :: (number) -> ())(0.05)
		end
		return peak, hits, ms
	end

	-- 상한을 넘긴 뒤 더 치지 않고 기다린다 (RestoreTime 보다 짧게)
	local function waitBelowCap(): number
		local t = 0
		while W.D.pieceCount() > S.MaxPieces and t < S.RestoreTime - 5 do
			advance(W, 0.5, 0.1)
			t += 0.5
		end
		return t
	end

	math.randomseed(opt.seed + 2)
	local peakA, hitsA, msA = barrage("barrage", S.MaxPieces + 100, 300)
	local afterA = W.D.pieceCount()
	local tA = waitBelowCap()
	note(
		"연속 충돌 %d번(큰 몸통 %d개 중): 조각 최고 %d (MaxPieces %d), 호출당 p50 %.2fms p95 %.2fms 최대 %.2fms",
		hitsA,
		#bodies,
		peakA,
		S.MaxPieces,
		percentile(msA, 0.5),
		percentile(msA, 0.95),
		percentile(msA, 1)
	)
	if peakA > S.MaxPieces then
		check(
			"F5",
			"MaxPieces 를 넘으면 더 안 쳐도 복구 시간 전에 상한 아래로 내려옴",
			W.D.pieceCount() <= S.MaxPieces,
			string.format("마지막 %d → %.1f초 뒤 %d", afterA, tA, W.D.pieceCount())
		)
	else
		check("F5", "MaxPieces 를 넘기는 상황을 만들었음", false, string.format("최고 %d ≤ %d", peakA, S.MaxPieces))
	end
	report.perf.barrage = { hits = hitsA, peak = peakA, p50 = percentile(msA, 0.5), p95 = percentile(msA, 0.95), max = percentile(msA, 1), earlyRestoreSeconds = tA }
	restoreByHeartbeat(W)

	-- 큰 폭발 두 번(광장 궁극기 + 야시장 r=40: 부서진 파트 수백 개, 대부분 통째로라 조각 0개) 바로 뒤에 같은 연속 충돌.
	-- 상한을 넘은 만큼(over)보다 조각 없는 오래된 가족이 많으면, 그 가족들만 조기 복구로 예약돼서 조각 수가 안 준다
	math.randomseed(opt.seed + 2)
	local ultStats = runHit(W, ult)
	W.now += 0.2
	local marketStats = runHit(W, sphereHit({ id = "market", label = "야시장", center = Vector3.new(0, 5, -80), from = Vector3.new(0, 12, -80), dir = Vector3.zero }, 40, { force = 2, maxParts = 1500 }))
	W.now += 0.5
	local peakB, hitsB = barrage("after_ult", S.MaxPieces + 100, 300)
	local afterB = W.D.pieceCount()
	local tB = waitBelowCap()
	note("큰 폭발 두 번(파트 %d + %d개) 뒤 연속 충돌 %d번: 조각 최고 %d", ultStats.affected, marketStats.affected, hitsB, peakB)
	if peakB > S.MaxPieces then
		check(
			"F6",
			"큰 폭발 직후에도 MaxPieces 를 넘으면 복구 시간 전에 상한 아래로 내려옴",
			W.D.pieceCount() <= S.MaxPieces,
			string.format("마지막 %d → %.1f초 뒤 %d", afterB, tB, W.D.pieceCount())
				.. (if W.D.pieceCount() > S.MaxPieces then " (조각 없는 오래된 가족만 복구 예약돼서 조각 수가 안 줄어듦)" else "")
		)
	else
		check("F6", "궁극기 뒤 MaxPieces 를 넘기는 상황을 만들었음", false, string.format("최고 %d ≤ %d", peakB, S.MaxPieces))
	end
	report.perf.peakPieces = math.max(peakA, peakB)
	restoreByHeartbeat(W)
	local R3 = compareToSnapshot(W)
	check("F7", "예산 시험 뒤 복구하면 처음과 같음", R3.n == 0, describe(R3))
	check("F8", "작은 타격·연속 충돌 모두 Shatter 형식·조각 수 상한 지킴", SP.n == 0, describe(SP))
end)

----------------------------------------------------------------------
-- G. 경계 사례
----------------------------------------------------------------------
runSection("G", function()
	section("G. 경계 사례 — 빈 곳, 반지름 0, NaN, 아주 큰 영역, 기본 옵션, propsOnly")
	local W = newWorld()
	local sites = findSites(W)
	local wall = sites[1]
	local P = problems()
	local function try(label: string, fn: () -> number): number?
		local ok, res = pcall(fn)
		if not ok then
			bad(P, "%s: 오류 %s", label, tostring(res))
			return nil
		end
		return res
	end
	local fx0 = #W.fx
	local n1 = try("빈 하늘", function()
		return W.D.destroySphere(Vector3.new(0, 500, 0), 5)
	end)
	check("G1", "아무것도 없는 곳: 0 을 돌려주고 Shatter 를 보내지 않음", n1 == 0 and #W.fx == fx0, string.format("affected %s, FX %d", tostring(n1), #W.fx - fx0))
	local n2 = try("반지름 0", function()
		return W.D.destroySphere(wall.center + Vector3.new(0.3, 0, 0), 0)
	end)
	local n3 = try("크기 0 상자", function()
		return W.D.destroyBox(CFrame.new(wall.center + Vector3.new(0.3, 0, 0)), Vector3.zero)
	end)
	local n4 = try("NaN 가운데", function()
		return W.D.destroySphere(Vector3.new(0 / 0, 0 / 0, 0 / 0), 5)
	end)
	local n5 = try("음수 반지름", function()
		return W.D.destroySphere(wall.center, -3)
	end)
	check(
		"G2",
		"반지름 0 / 크기 0 / NaN / 음수 반지름에서 오류 없음",
		P.n == 0,
		string.format("affected %s/%s/%s/%s %s", tostring(n2), tostring(n3), tostring(n4), tostring(n5), describe(P))
	)
	local V = validate(W, scan(W))
	check("G3", "경계 사례 뒤 상태 일관성", V.n == 0, describe(V))

	-- 아주 큰 영역: maxParts 기본값(MaxPartsPerCall)에서 멈추는지
	restoreByHeartbeat(W)
	local huge = sphereHit({ id = "huge", label = "", center = Vector3.new(0, 10, 0), from = Vector3.new(0, 10, 0), dir = Vector3.zero }, 400)
	huge.opts = {}
	local hs = runHit(W, huge)
	note("r=400 (기본 옵션): 파트 %d, 조각 보냄 %d, %.1fms", hs.affected, hs.sentPieces, hs.ms)
	check("G4", "아주 큰 영역도 MaxPartsPerCall 에서 멈춤", hs.affected <= S.MaxPartsPerCall, string.format("%d ≤ %d", hs.affected, S.MaxPartsPerCall))
	check("G5", "아주 큰 영역도 보낸 조각 ≤ MaxDebrisSent", hs.sentPieces <= S.MaxDebrisSent and hs.contract.n == 0, describe(hs.contract))
	restoreByHeartbeat(W)

	-- 기본 옵션: from = 가운데, dir = 0, force = 1, ash = false, sound = true / dir 은 단위 벡터로
	local fxA = #W.fx
	W.D.destroySphere(wall.center, 3)
	local a = W.fx[#W.fx]
	local okA = #W.fx == fxA + 1
		and a.payload.from == wall.center
		and a.payload.dir == Vector3.zero
		and a.payload.force == 1
		and a.payload.ash == false
		and a.payload.sound == true
	restoreByHeartbeat(W)
	local fxB = #W.fx
	W.D.destroySphere(wall.center, 3, { dir = Vector3.new(0, 0, 5), ash = true, sound = false, force = 2, from = Vector3.new(1, 2, 3) })
	local b = W.fx[#W.fx]
	local okB = #W.fx == fxB + 1
		and (b.payload.dir - Vector3.new(0, 0, 1)).Magnitude < 1e-5
		and b.payload.ash == true
		and b.payload.sound == false
		and b.payload.force == 2
		and b.payload.from == Vector3.new(1, 2, 3)
	check("G6", "Shatter 기본값(from=가운데, dir=0, force=1, ash=false, sound=true)과 dir 정규화", okA and okB, "")
	restoreByHeartbeat(W)

	-- propsOnly: 큰 건물(> 8 스터드)은 안 부서지고 Breakable 이 아닌 작은 파트는 통째로
	local st0 = scan(W)
	local big = problems()
	for _, s in sites do
		W.D.destroyBox(CFrame.new(s.center), Vector3.new(10, 10, 10), { propsOnly = true })
	end
	local st1 = scan(W)
	for _, id in st1.missing do
		local rec = W.snap.byId[id]
		local sz = rec.inst.Size
		if math.max(sz.X, sz.Y, sz.Z) > 8 and not rec.breakable then
			bad(big, "%s", rec.full)
		end
	end
	check("G7", "propsOnly 는 8 스터드 넘는 파트를 부수지 않음", big.n == 0, describe(big))
	check("G8", "propsOnly 는 조각을 남기지 않음 (통째로)", #st1.pieces == #st0.pieces, string.format("조각 %d → %d", #st0.pieces, #st1.pieces))
	restoreByHeartbeat(W)

	-- 잔해 상한: 결이 고운 큰 구로 건물 여러 채를 한 번에 → 없앤 조각이 MaxDebrisSent 를 넘어 잘려서 가야 한다
	local cutHit = sphereHit({ id = "debris_cap", label = "", center = Vector3.new(-20, 10, -114), from = Vector3.new(-20, 10, -100), dir = Vector3.new(0, 0, -1) }, 16, { grain = 1.25, maxParts = 1500 })
	local cs = runHit(W, cutHit)
	note("잔해 상한 시험: 파트 %d, 보냄 %d/%d, 없앤 부피 %.0f 중 %.0f 만 보냄", cs.affected, cs.sentPieces, S.MaxDebrisSent, cs.removedVolume, cs.sentVolume)
	check(
		"G10",
		"없앤 조각이 많으면 정확히 MaxDebrisSent 개까지만 보냄 (자르는 경로)",
		cs.sentPieces == S.MaxDebrisSent and cs.contract.n == 0 and cs.sentVolume < cs.removedVolume,
		string.format("보냄 %d %s", cs.sentPieces, describe(cs.contract))
	)
	local VC = validate(W, scan(W))
	check("G11", "잔해를 자른 뒤에도 상태 일관성", VC.n == 0, describe(VC))
	restoreByHeartbeat(W)
	local R = compareToSnapshot(W)
	check("G9", "경계 사례 뒤 복구하면 처음과 같음", R.n == 0, describe(R))
end)

----------------------------------------------------------------------
-- 요약
----------------------------------------------------------------------
section("요약")
local passed, failed = 0, 0
for _, r in results do
	if r.ok then
		passed += 1
	else
		failed += 1
		print(string.format("  FAIL %-5s %s — %s", r.id, r.name, r.detail))
	end
end
print(string.format("\n  %d 통과, %d 실패 (전체 %d)", passed, failed, #results))
if opt.report then
	fs.writeFile(opt.report, serde.encode("json", report, true))
end
process.exit(if failed > 0 then 1 else 0)
