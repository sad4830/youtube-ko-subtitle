--!strict
-- 린 위안 — 금빛 귀환자
--  《기형》: 영력을 몸에 연결된 금빛 형상(거대한 손바닥)으로 굳힌다
--  《유전》: 몸에 닿는 물리적 힘을 받아 흘려보낸다 (반격 자세)
--  무예   : 봉술 · 장법, 몸통 회전, 구르기
--  권능   : 심기체일 — 황금 용 형상의 외체 (최대 출력 사용 시 권능 종료, 이후 탈진)

local Combat = require(script.Parent.Parent.Combat)
local Actions = require(script.Parent.Parent.Actions)
local MapService = require(script.Parent.Parent.MapService)

type Entity = Combat.Entity
type Ctx = { aim: Vector3, slot: number, jump: boolean }

local Lin = {}

local UP = Vector3.new(0, 1, 0)

local function flatDir(from: Vector3, to: Vector3, fallback: Vector3): Vector3
	local d = (to - from) * Vector3.new(1, 0, 1)
	if d.Magnitude < 0.1 then
		return fallback
	end
	return d.Unit
end

local function breakAll(ent: Entity, props: { BasePart }, dir: Vector3)
	for _, p in props do
		MapService.breakPart(p, ent.root.Position, dir, false)
	end
end

----------------------------------------------------------------------
-- 1. 기형 · 금장
----------------------------------------------------------------------
function Lin.GoldenPalm(ent: Entity, ctx: Ctx): boolean
	local aim = ctx.aim
	local token = Combat.beginMove(ent, "GoldenPalm", 0.85, 1.5)
	Combat.anim(ent, "lin_goldpalm")
	Combat.fx("ChiCharge", { model = ent.model, duration = 0.38 })
	if not Combat.sleep(ent, token, 0.38) then
		return true
	end
	local pos = ent.root.Position
	Combat.fx("GoldenPalm", { model = ent.model, origin = pos, dir = aim, length = 13 })
	Combat.push(ent, aim * 28, 0.12)
	local hits, props = Combat.front(ent, 7, Vector3.new(9, 8, 13), aim)
	for _, tgt in hits do
		Combat.hit(ent, tgt, {
			damage = 12,
			stun = 1.0,
			knock = aim * 88 + UP * 26,
			knockTime = 0.25,
			ragdoll = 1.3,
			guardBreak = true,
			fx = "gold_heavy",
			sound = "lin_palm_impact",
			hitstop = 0.11,
			shake = 0.6,
			melee = true,
		})
	end
	breakAll(ent, props, aim)
	return true
end

----------------------------------------------------------------------
-- 2. 유전 — 흐름을 받아 되돌린다
----------------------------------------------------------------------
function Lin.Redirect(ent: Entity, _ctx: Ctx): boolean
	local STANCE = 0.9
	local token = Combat.beginMove(ent, "Redirect", STANCE, 0)
	Combat.anim(ent, "lin_redirect_stance")
	Combat.fx("RedirectStance", { model = ent.model, duration = STANCE })
	ent.counterUntil = os.clock() + STANCE
	ent.onCounter = function(self: Entity, attacker: Entity, info: Combat.HitInfo): boolean
		if self.token ~= token then
			return false
		end
		self.counterUntil = 0
		local proj = info.projectile
		if proj then
			-- 고체 투사체 1개를 비껴 되돌려 보낸다
			local back = flatDir(self.root.Position, attacker.root.Position, -self.root.CFrame.LookVector)
			Combat.redirectProjectile(proj, self, back)
			Combat.beginMove(self, "RedirectCounter", 0.5, 0)
			Combat.anim(self, "lin_redirect_counter")
			Combat.fx("Redirect", { model = self.model, pos = self.root.Position })
			return true
		end
		-- 하나의 연속된 근접 타격: 몸을 회전시켜 힘을 흘리고, 상대를 날린다
		local counterToken = Combat.beginMove(self, "RedirectCounter", 0.7, 0)
		self.iframeUntil = os.clock() + 0.5
		Combat.stun(attacker, 0.55, "parried")
		Combat.anim(self, "lin_redirect_counter")
		Combat.fx("Redirect", { model = self.model, pos = self.root.Position })
		task.delay(0.36, function()
			if not Combat.valid(self, counterToken) or not attacker.alive then
				return
			end
			local dir = flatDir(self.root.Position, attacker.root.Position, self.root.CFrame.LookVector)
			Combat.hit(self, attacker, {
				damage = 9 + math.min(info.damage, 12) * 0.5,
				stun = 1.0,
				knock = dir * 96 + UP * 32,
				knockTime = 0.25,
				ragdoll = 1.4,
				unblockable = true,
				noCounter = true,
				fx = "gold_heavy",
				sound = "lin_palm_impact",
				hitstop = 0.12,
				shake = 0.7,
			})
		end)
		return true
	end
	task.delay(STANCE, function()
		if ent.token == token then
			ent.counterUntil = 0
			Combat.endMove(ent, token)
			Combat.anim(ent, nil)
		end
	end)
	return true
end

----------------------------------------------------------------------
-- 3. 봉술 · 회천 — 몸통 회전으로 주변을 세 번 쓸어낸다
----------------------------------------------------------------------
function Lin.StaffSpin(ent: Entity, _ctx: Ctx): boolean
	local token = Combat.beginMove(ent, "StaffSpin", 1.05, 7)
	Combat.anim(ent, "lin_staffspin")
	local times = { 0.16, 0.46, 0.8 }
	local last = 0
	for i, at in times do
		if not Combat.sleep(ent, token, at - last) then
			return true
		end
		last = at
		local center = ent.root.Position
		Combat.fx("StaffRing", { pos = center, radius = 8.5, final = i == 3 })
		local hits, props = Combat.box(ent, CFrame.new(center), Vector3.new(17, 7, 17))
		for _, tgt in hits do
			local out = flatDir(center, tgt.root.Position, ent.root.CFrame.LookVector)
			if i < 3 then
				Combat.hit(ent, tgt, {
					damage = 4.5,
					stun = 0.8,
					knock = out * 14,
					knockTime = 0.12,
					fx = "staff",
					sound = "lin_staff_hit",
					melee = true,
				})
			else
				Combat.hit(ent, tgt, {
					damage = 6,
					stun = 1.1,
					knock = out * 26 + UP * 70,
					knockTime = 0.22,
					ragdoll = 1.3,
					fx = "staff_heavy",
					sound = "lin_staff_hit",
					hitstop = 0.08,
					shake = 0.35,
					melee = true,
				})
			end
		end
		breakAll(ent, props, ent.root.CFrame.LookVector)
	end
	return true
end

----------------------------------------------------------------------
-- 4. 천 번의 반죽 — 연타 후 목봉으로 마무리
----------------------------------------------------------------------
function Lin.Kneading(ent: Entity, ctx: Ctx): boolean
	local aim = ctx.aim
	local token = Combat.beginMove(ent, "Kneading", 1.6, 2.5)
	Combat.anim(ent, "lin_kneading")
	Combat.fx("Barrage", { model = ent.model, duration = 1.0, dir = aim })
	local t = 0
	for _ = 1, 11 do
		if not Combat.sleep(ent, token, 0.085) then
			return true
		end
		t += 0.085
		local hits = Combat.front(ent, 3.8, Vector3.new(7, 6, 7.5), aim)
		for _, tgt in hits do
			local res = Combat.hit(ent, tgt, {
				damage = 1.3,
				stun = 0.5,
				fx = "palm_small",
				sound = "m1_hit",
				hitstop = 0.015,
				melee = true,
			})
			if res == "hit" then
				Combat.push(tgt, aim * 7, 0.1)
			end
		end
		Combat.push(ent, aim * 6, 0.1)
	end
	if not Combat.sleep(ent, token, 1.24 - t) then
		return true
	end
	local hits, props = Combat.front(ent, 4.5, Vector3.new(9, 8, 9), aim)
	Combat.fx("GroundCrack", { pos = ent.root.Position + aim * 5 - UP * 3, radius = 7, color = "gold" })
	for _, tgt in hits do
		Combat.hit(ent, tgt, {
			damage = 9,
			stun = 1.0,
			knock = aim * 92 + UP * 36,
			knockTime = 0.25,
			ragdoll = 1.4,
			guardBreak = true,
			fx = "staff_heavy",
			sound = "lin_staff_hit",
			hitstop = 0.12,
			shake = 0.6,
			melee = true,
		})
	end
	breakAll(ent, props, aim)
	return true
end

----------------------------------------------------------------------
-- 각성: 심기체일 — 용의 전사
----------------------------------------------------------------------
function Lin.onAwaken(ent: Entity)
	local token = Combat.beginMove(ent, "Awaken", 1.7, 0)
	ent.iframeUntil = os.clock() + 1.7
	Combat.anim(ent, "lin_awaken")
	Combat.fx("AwakenStart", { model = ent.model, charId = ent.charId })
	task.delay(1.15, function()
		if ent.token ~= token or not ent.alive then
			return
		end
		Actions.startAwakening(ent)
		Combat.fx("DragonAura", { model = ent.model, on = true })
		-- 일어서는 기세로 주변을 밀어낸다
		local center = ent.root.Position
		local hits = Combat.box(ent, CFrame.new(center), Vector3.new(22, 10, 22))
		for _, tgt in hits do
			local out = flatDir(center, tgt.root.Position, ent.root.CFrame.LookVector)
			Combat.hit(ent, tgt, {
				damage = 4,
				stun = 0.8,
				knock = out * 70 + UP * 25,
				knockTime = 0.2,
				ragdoll = 1.0,
				unblockable = true,
				noCounter = true,
				fx = "gold",
			})
		end
	end)
end

function Lin.onAwakenEnd(ent: Entity, reason: string?)
	Combat.fx("DragonAura", { model = ent.model, on = false })
	-- 권능 종료 후: 모든 영력 활용 불가 + 심한 탈진 (설정의 대가)
	local dur = if reason == "finisher" then 7 else 5
	ent.noSkillUntil = os.clock() + dur
	ent.exhaustedUntil = os.clock() + dur
	Combat.notify(ent, "n.exhausted", "warn", { n = dur })
	if ent.alive then
		Combat.anim(ent, "exhausted")
		task.delay(dur, function()
			if ent.alive and ent.exhaustedUntil <= os.clock() + 0.05 and not Combat.isBusy(ent) and not Combat.isStunned(ent) then
				Combat.anim(ent, nil)
			end
		end)
	end
end

-- 각성 중 M1: 용의 앞발이 주먹을 따라 뻗는다
function Lin.onM1Swing(ent: Entity, n: number, finisher: boolean, aim: Vector3)
	if ent.awakened then
		Combat.fx("DragonPaw", { model = ent.model, dir = aim, n = n, finisher = finisher })
	end
end

----------------------------------------------------------------------
-- 각성 기술
----------------------------------------------------------------------
function Lin.DragonClaw(ent: Entity, ctx: Ctx): boolean
	local aim = ctx.aim
	local token = Combat.beginMove(ent, "DragonClaw", 0.7, 2)
	Combat.anim(ent, "lin_dragonclaw")
	if not Combat.sleep(ent, token, 0.14) then
		return true
	end
	local origin = ent.root.Position
	Combat.fx("DragonClaw", { model = ent.model, origin = origin, dir = aim, length = 36 })
	local mid = origin + aim * 19
	local hits, props = Combat.box(ent, CFrame.lookAt(mid, mid + aim), Vector3.new(8, 9, 36))
	for _, tgt in hits do
		Combat.hit(ent, tgt, {
			damage = 13,
			stun = 1.0,
			knock = aim * 82 + UP * 26,
			knockTime = 0.25,
			ragdoll = 1.2,
			fx = "gold_heavy",
			sound = "lin_palm_impact",
			hitstop = 0.1,
			shake = 0.5,
		})
	end
	breakAll(ent, props, aim)
	return true
end

function Lin.DragonCoil(ent: Entity, _ctx: Ctx): boolean
	local DURATION = 2.0
	local token = Combat.beginMove(ent, "DragonCoil", DURATION + 0.2, 6)
	Combat.anim(ent, "lin_dragoncoil")
	ent.armorUntil = os.clock() + DURATION
	ent.armorScale = 0.25
	Combat.fx("DragonCoil", { model = ent.model, duration = DURATION })
	if not Combat.sleep(ent, token, DURATION) then
		ent.armorUntil = 0
		return true
	end
	ent.armorUntil = 0
	Combat.anim(ent, nil)
	local center = ent.root.Position
	Combat.fx("Shockwave", { pos = center, radius = 16, color = "gold" })
	local hits, props = Combat.box(ent, CFrame.new(center), Vector3.new(30, 12, 30))
	for _, tgt in hits do
		local out = flatDir(center, tgt.root.Position, ent.root.CFrame.LookVector)
		Combat.hit(ent, tgt, {
			damage = 10,
			stun = 1.0,
			knock = out * 75 + UP * 30,
			knockTime = 0.25,
			ragdoll = 1.2,
			fx = "gold_heavy",
			sound = "lin_palm_impact",
			hitstop = 0.08,
			shake = 0.5,
		})
	end
	breakAll(ent, props, ent.root.CFrame.LookVector)
	return true
end

function Lin.RisingDragon(ent: Entity, ctx: Ctx): boolean
	local aim = ctx.aim
	local token = Combat.beginMove(ent, "RisingDragon", 1.1, 0)
	Combat.anim(ent, "lin_risingdragon")
	if not Combat.sleep(ent, token, 0.22) then
		return true
	end
	local pos = ent.root.Position + aim * 4
	Combat.fx("RisingDragon", { pos = pos, dir = aim })
	local hits = Combat.front(ent, 4.5, Vector3.new(9, 12, 10), aim)
	local launched: { Entity } = {}
	for _, tgt in hits do
		local res = Combat.hit(ent, tgt, {
			damage = 8,
			stun = 1.6,
			knock = UP * 100 + aim * 4,
			knockTime = 0.28,
			fx = "gold_heavy",
			sound = "lin_palm_impact",
			hitstop = 0.08,
			shake = 0.4,
		})
		if res == "hit" then
			table.insert(launched, tgt)
		end
	end
	task.delay(0.62, function()
		for _, tgt in launched do
			if tgt.alive then
				Combat.fx("DragonDive", { pos = tgt.root.Position })
				Combat.hit(ent, tgt, {
					damage = 8,
					stun = 1.2,
					knock = UP * -150,
					knockTime = 0.16,
					ragdoll = 1.3,
					unblockable = true,
					noCounter = true,
					fx = "slam",
					sound = "ground_crack",
					hitstop = 0.1,
					shake = 0.6,
				})
			end
		end
	end)
	return true
end

function Lin.GoldenReturn(ent: Entity, _ctx: Ctx): boolean
	local token = Combat.beginMove(ent, "GoldenReturn", 2.4, 0)
	ent.iframeUntil = os.clock() + 2.3
	Combat.anim(ent, "lin_goldenreturn")
	Combat.fx("GoldenReturn", { model = ent.model, pos = ent.root.Position, radius = 60 })
	if not Combat.sleep(ent, token, 1.45) then
		Combat.endAwakening(ent, "finisher")
		return true
	end
	local center = ent.root.Position
	local hits, props = Combat.box(ent, CFrame.new(center), Vector3.new(120, 40, 120))
	for _, tgt in hits do
		local d = (tgt.root.Position - center).Magnitude
		if d <= 60 then
			local out = flatDir(center, tgt.root.Position, ent.root.CFrame.LookVector)
			Combat.hit(ent, tgt, {
				damage = 26,
				stun = 1.6,
				knock = out * 115 + UP * 50,
				knockTime = 0.3,
				ragdoll = 2.2,
				unblockable = true,
				noCounter = true,
				fx = "gold_heavy",
				sound = "lin_palm_impact",
				hitstop = 0.15,
				shake = 1,
			})
		end
	end
	for _, p in props do
		if (p.Position - center).Magnitude <= 60 then
			MapService.breakPart(p, center, (p.Position - center).Unit, false)
		end
	end
	task.delay(0.8, function()
		Combat.endAwakening(ent, "finisher")
	end)
	return true
end

Combat.Moves.LinYuan = Lin :: any
return Lin
