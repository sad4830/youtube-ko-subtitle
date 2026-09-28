--!strict
-- 칸자키 렌 — 애시마크
--  《무염박리》: 칼날이 직접 닿은 비생체 물질을 검은 회분으로 (적의 장비, 주변 소품)
--  칼집 저장 : 회분 최대 10단위, 마지막 획득 후 일정 시간 지나면 소실
--  《회류반송》: 저장한 회분을 소모해 직선 참격 (휘거나 추적하지 않음)
--  파생 운용 : 《회막》 시야 차단 / 《측면삭》 낮은 절단
--  10단위 최대 출력: 칼을 넣고 봉인선 열 개가 붉게 빛난 뒤 발도. 이후 잠시 이능 불가 (폐 손상)

local RunService = game:GetService("RunService")

local Combat = require(script.Parent.Parent.Combat)
local Actions = require(script.Parent.Parent.Actions)

type Entity = Combat.Entity
type Ctx = { aim: Vector3, slot: number, jump: boolean }

local Ren = {}

local UP = Vector3.new(0, 1, 0)

local function rotateY(v: Vector3, deg: number): Vector3
	return CFrame.Angles(0, math.rad(deg), 0):VectorToWorldSpace(v)
end

local function needAsh(ent: Entity, amount: number): boolean
	if Combat.useAsh(ent, amount) then
		return true
	end
	Combat.notify(ent, "n.ash_low", "warn")
	return false
end

----------------------------------------------------------------------
-- 회막 (분진막) 존
----------------------------------------------------------------------
type Veil = { owner: Entity, pos: Vector3, radius: number, untilT: number, boost: number }
local veils: { Veil } = {}

local function addVeil(owner: Entity, pos: Vector3, radius: number, duration: number, boost: number)
	table.insert(veils, { owner = owner, pos = pos, radius = radius, untilT = os.clock() + duration, boost = boost })
	Combat.fx("AshVeil", { pos = pos, radius = radius, duration = duration, owner = owner.model })
end

RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for i = #veils, 1, -1 do
		if veils[i].untilT <= t then
			table.remove(veils, i)
		end
	end
	for model, ent in Combat.entities do
		local inside = false
		local boost = 1
		for _, v in veils do
			local d = (ent.root.Position - v.pos) * Vector3.new(1, 0.5, 1)
			if d.Magnitude <= v.radius then
				if v.owner == ent then
					boost = math.max(boost, v.boost)
				else
					inside = true
				end
			end
		end
		if model:GetAttribute("InVeil") ~= inside then
			model:SetAttribute("InVeil", inside)
		end
		if ent.charId == "KanzakiRen" then
			ent.data.speedMul = boost
		end
	end
end)

----------------------------------------------------------------------
-- 1. 무염박리 — 파고들며 발도, 벤 만큼 회분을 얻는다
----------------------------------------------------------------------
function Ren.Peel(ent: Entity, ctx: Ctx): boolean
	local aim = ctx.aim
	local token = Combat.beginMove(ent, "Peel", 0.62, 0)
	Combat.anim(ent, "ren_peel")
	if not Combat.sleep(ent, token, 0.09) then
		return true
	end
	local start = ent.root.Position
	local dist = 17
	local finish = start + aim * dist
	local mid = (start + finish) / 2
	local lineCF = CFrame.lookAt(mid, finish)
	-- 돌진하기 전에 길을 먼저 벤다 (구멍과 돌진이 같은 순간 도착해야 벽에 막히지 않고 베어 지나간다).
	-- 칼날이 지나간 자리의 비생체 물질(벽·사물)은 전부 재가 된다.
	local cut = Combat.smash(ent, { cf = lineCF, size = Vector3.new(7, 7, dist + 4) }, { from = start, dir = aim, ash = true, force = 1.2 })
	Combat.push(ent, aim * 100, 0.17)
	ent.iframeUntil = os.clock() + 0.15
	if not Combat.sleep(ent, token, 0.14) then
		return true
	end
	Combat.fx("SlashLine", { from = start, to = finish, color = "red" })
	local hits = Combat.box(ent, lineCF, Vector3.new(7, 7, dist + 4))
	local gained = cut > 0
	for _, tgt in hits do
		local res = Combat.hit(ent, tgt, {
			damage = 9,
			stun = 0.95,
			knock = aim * 26 + UP * 8,
			knockTime = 0.15,
			fx = "slash_heavy",
			sound = "ren_slash_hit",
			hitstop = 0.08,
			shake = 0.35,
			melee = true,
		})
		if res == "hit" or res == "blocked" then
			gained = true
		end
	end
	if gained then
		Combat.addAsh(ent, 2)
	end
	return true
end

----------------------------------------------------------------------
-- 2. 회류반송 — 회분(최대 3)을 소모하는 직선 참격
----------------------------------------------------------------------
local RETURN_TABLE = {
	{ range = 46, width = 3.2, damage = 8, knock = 22 },
	{ range = 62, width = 5, damage = 11, knock = 34 },
	{ range = 80, width = 7.5, damage = 15, knock = 55 },
}

type AshExtra = { ragdoll: number?, kind: string?, height: number?, low: boolean? }

local function fireAsh(ent: Entity, aim: Vector3, units: number, extra: AshExtra?)
	local row = RETURN_TABLE[math.clamp(units, 1, 3)]
	local e: AshExtra = extra or {}
	local origin = ent.root.Position + aim * 2 + (if e.low then UP * -2.2 else Vector3.zero)
	Combat.projectile(ent, {
		origin = origin,
		dir = aim,
		speed = 165,
		range = row.range,
		width = row.width,
		height = e.height or 4.5,
		kind = e.kind or "ash",
		groundSkim = e.low == true,
		pierce = units >= 2, -- 회분 2 이상이면 건물을 베어 가르며 계속 날아간다
		info = {
			damage = row.damage,
			stun = 0.85,
			knock = aim * row.knock + UP * 10,
			knockTime = 0.16,
			ragdoll = e.ragdoll or (if units >= 3 then 1.0 else nil),
			fx = "ash",
			sound = "ren_slash_hit",
			hitstop = 0.05,
			shake = 0.2 + units * 0.08,
		},
	})
end

function Ren.AshReturn(ent: Entity, ctx: Ctx): boolean
	local units = if ent.awakened then 3 else math.min(ent.ash, 3)
	if units < 1 then
		Combat.notify(ent, "n.ash_none", "warn")
		return false
	end
	Combat.useAsh(ent, units)
	local aim = ctx.aim
	local token = Combat.beginMove(ent, "AshReturn", 0.55, 2)
	Combat.anim(ent, "ren_ashreturn")
	Combat.fx("AshVent", { model = ent.model, amount = units })
	if not Combat.sleep(ent, token, 0.13) then
		return true
	end
	fireAsh(ent, aim, units)
	return true
end

----------------------------------------------------------------------
-- 3. 측면삭 — 지면을 스치는 낮은 참격 (맞으면 넘어짐)
----------------------------------------------------------------------
function Ren.SideShave(ent: Entity, ctx: Ctx): boolean
	if not needAsh(ent, 1) then
		return false
	end
	local aim = ctx.aim
	local token = Combat.beginMove(ent, "SideShave", 0.6, 0)
	Combat.anim(ent, "ren_sideshave")
	if not Combat.sleep(ent, token, 0.12) then
		return true
	end
	Combat.projectile(ent, {
		origin = ent.root.Position + aim * 2 - UP * 2.3,
		dir = aim,
		speed = 145,
		range = 58,
		width = 7,
		height = 2.6,
		kind = "ash_low",
		groundSkim = true,
		pierce = true, -- 지면을 스치며 사물의 밑동을 베어 낸다
		info = {
			damage = 7,
			stun = 1.0,
			knock = UP * 28 + aim * 8,
			knockTime = 0.12,
			ragdoll = 1.3,
			fx = "ash",
			sound = "ren_slash_hit",
			hitstop = 0.05,
			shake = 0.25,
		},
	})
	return true
end

----------------------------------------------------------------------
-- 4. 회막 — 검은 분진막
----------------------------------------------------------------------
function Ren.AshVeil(ent: Entity, _ctx: Ctx): boolean
	if not needAsh(ent, 1) then
		return false
	end
	local token = Combat.beginMove(ent, "AshVeil", 0.7, 0)
	Combat.anim(ent, "ren_veil")
	if not Combat.sleep(ent, token, 0.2) then
		return true
	end
	addVeil(ent, ent.root.Position, 22, 7, 1.2)
	return true
end

----------------------------------------------------------------------
-- 각성: 무염재단 · 전력 발도 (게임용 각성 모드)
----------------------------------------------------------------------
function Ren.onAwaken(ent: Entity)
	local token = Combat.beginMove(ent, "Awaken", 1.5, 0)
	ent.iframeUntil = os.clock() + 1.5
	Combat.anim(ent, "ren_awaken")
	Combat.fx("AwakenStart", { model = ent.model, charId = ent.charId })
	task.delay(1.1, function()
		if ent.token ~= token or not ent.alive then
			return
		end
		Actions.startAwakening(ent)
		ent.ash = 10
		Combat.fx("AshAura", { model = ent.model, on = true })
		local center = ent.root.Position
		local hits = Combat.box(ent, CFrame.new(center), Vector3.new(20, 10, 20))
		Combat.smash(ent, { cf = CFrame.new(center + UP * 1.5), size = Vector3.new(22, 12, 22) }, { ash = true, force = 1.4 })
		for _, tgt in hits do
			local out = (tgt.root.Position - center) * Vector3.new(1, 0, 1)
			local dir = if out.Magnitude > 0.1 then out.Unit else ent.root.CFrame.LookVector
			Combat.hit(ent, tgt, {
				damage = 4,
				stun = 0.8,
				knock = dir * 60 + UP * 20,
				knockTime = 0.2,
				ragdoll = 0.9,
				unblockable = true,
				noCounter = true,
				fx = "ash",
			})
		end
	end)
end

function Ren.onAwakenEnd(ent: Entity, reason: string?)
	Combat.fx("AshAura", { model = ent.model, on = false })
	ent.ash = 0
	-- 대량 사출의 대가: 이능 사용 불가 + 기관지 손상
	local dur = if reason == "finisher" then 4 else 2
	ent.noSkillUntil = os.clock() + dur
	ent.exhaustedUntil = os.clock() + dur
	Combat.notify(ent, if reason == "finisher" then "n.lung_damage" else "n.awaken_end", "warn")
	if reason == "finisher" then
		Combat.fx("Cough", { model = ent.model })
	end
end

----------------------------------------------------------------------
-- 각성 기술
----------------------------------------------------------------------
function Ren.ChainReturn(ent: Entity, ctx: Ctx): boolean
	local aim = ctx.aim
	local token = Combat.beginMove(ent, "ChainReturn", 0.95, 3)
	Combat.anim(ent, "ren_chain")
	local plan = { { 0.08, -10 }, { 0.38, 10 }, { 0.67, 0 } }
	local last = 0
	for i, p in plan do
		if not Combat.sleep(ent, token, p[1] - last) then
			return true
		end
		last = p[1]
		Combat.fx("AshVent", { model = ent.model, amount = 1 })
		fireAsh(ent, rotateY(aim, p[2]), if i == 3 then 3 else 2, { ragdoll = if i == 3 then 1.0 else nil })
	end
	return true
end

function Ren.Severance(ent: Entity, ctx: Ctx): boolean
	local aim = ctx.aim
	local token = Combat.beginMove(ent, "Severance", 0.95, 0)
	local start = ent.root.Position
	local dist = 28
	local finish = start + aim * dist
	local mid = (start + finish) / 2
	local lineCF = CFrame.lookAt(mid, finish)
	-- 돌진 전에 길을 먼저 벤다 (벽에 막히지 않고 베어 지나가도록)
	Combat.smash(ent, { cf = lineCF, size = Vector3.new(8, 8, dist + 4) }, { from = start, dir = aim, ash = true, force = 1.2 })
	Combat.push(ent, aim * 170, 0.16)
	ent.iframeUntil = os.clock() + 0.3
	Combat.anim(ent, "ren_severance")
	Combat.fx("SeveranceDash", { model = ent.model, from = start, to = start + aim * dist })
	if not Combat.sleep(ent, token, 0.16) then
		return true
	end
	local hits = Combat.box(ent, lineCF, Vector3.new(8, 8, dist + 4))
	for _, tgt in hits do
		Combat.stun(tgt, 0.7, "stunned")
	end
	Combat.fx("SeveranceLine", { from = start, to = finish, delay = 0.45 })
	task.delay(0.45, function()
		if not ent.alive then
			return
		end
		Combat.fx("Shockwave", { pos = mid, radius = 8, color = "ash" })
		-- 절단선이 한 박자 늦게 터지며 더 넓게 무너뜨린다
		Combat.smash(ent, { cf = lineCF, size = Vector3.new(12, 12, dist + 4) }, { from = mid, dir = UP, ash = true, force = 1.6 })
		for _, tgt in hits do
			if tgt.alive then
				Combat.hit(ent, tgt, {
					damage = 16,
					stun = 1.0,
					knock = aim * 30 + UP * 45,
					knockTime = 0.2,
					ragdoll = 1.3,
					unblockable = true,
					fx = "ash_heavy",
					sound = "ren_slash_hit",
					hitstop = 0.12,
					shake = 0.6,
				})
			end
		end
	end)
	return true
end

function Ren.VeilHunt(ent: Entity, _ctx: Ctx): boolean
	local token = Combat.beginMove(ent, "VeilHunt", 0.7, 0)
	Combat.anim(ent, "ren_veil")
	if not Combat.sleep(ent, token, 0.2) then
		return true
	end
	addVeil(ent, ent.root.Position, 30, 9, 1.45)
	return true
end

function Ren.MaxOutput(ent: Entity, ctx: Ctx): boolean
	local aim = ctx.aim
	local CHARGE = 1.3
	local token = Combat.beginMove(ent, "MaxOutput", CHARGE + 1.1, 0)
	ent.armorUntil = os.clock() + CHARGE
	ent.armorScale = 0.5
	Combat.anim(ent, "ren_maxcharge")
	for i = 1, 10 do
		Combat.fx("SealTick", { model = ent.model, index = i })
		if not Combat.sleep(ent, token, CHARGE / 10) then
			ent.armorUntil = 0
			Combat.fx("SealReset", { model = ent.model })
			Combat.endAwakening(ent, "finisher")
			return true
		end
	end
	ent.armorUntil = 0
	ent.iframeUntil = os.clock() + 0.6
	Combat.anim(ent, "ren_maxrelease")
	local origin = ent.root.Position
	local length = 125
	Combat.fx("MaxOutput", { model = ent.model, origin = origin, dir = aim, length = length, width = 16 })
	local mid = origin + aim * (length / 2 + 2)
	local hits = Combat.box(ent, CFrame.lookAt(mid, mid + aim), Vector3.new(16, 14, length))
	for _, tgt in hits do
		Combat.hit(ent, tgt, {
			damage = 30,
			stun = 1.8,
			knock = aim * 125 + UP * 42,
			knockTime = 0.3,
			ragdoll = 2.3,
			unblockable = true,
			noCounter = true,
			fx = "ash_heavy",
			sound = "ren_slash_hit",
			hitstop = 0.16,
			shake = 1,
		})
	end
	-- 거대한 발도 참격: 앞쪽 일직선의 건물이 통째로 재가 되어 무너진다
	local cutMid = mid + UP * 10
	Combat.smash(ent, { cf = CFrame.lookAt(cutMid, cutMid + aim), size = Vector3.new(18, 34, length) }, { from = origin, dir = aim, ash = true, force = 2.2, maxParts = 1200 })
	task.delay(0.9, function()
		Combat.fx("SealReset", { model = ent.model })
		Combat.endAwakening(ent, "finisher")
	end)
	return true
end

Combat.Moves.KanzakiRen = Ren :: any
return Ren
