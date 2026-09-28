--!strict
-- 전투 코어 (서버 권한)
-- 피격 판정, 막기/패리/가드 브레이크, 경직, 넉백, 래그돌, 각성 게이지, 회피, 투사체, 쿨타임을 처리한다.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local CharacterDefs = require(Shared.CharacterDefs)
local Physics = require(Shared.Physics)
local RigBuilder = require(Shared.RigBuilder)
local Locale = require(Shared.Locale)

local Destruction = require(script.Parent.Destruction)

local Combat = {}

export type HitInfo = {
	damage: number,
	stun: number?,
	knock: Vector3?,
	knockTime: number?,
	ragdoll: number?,
	guardBreak: boolean?,
	unblockable: boolean?,
	noCounter: boolean?,
	fx: string?,
	sound: string?,
	hitstop: number?,
	projectile: any?,
	melee: boolean?,
	anim: string?,
	shake: number?,
}

export type Entity = {
	model: Model,
	humanoid: Humanoid,
	root: BasePart,
	player: Player?,
	charId: string,
	def: CharacterDefs.CharDef?,
	isDummy: boolean,
	isBot: boolean,
	alive: boolean,

	stunUntil: number,
	busyUntil: number,
	iframeUntil: number,
	ragdollUntil: number,
	ragdolled: boolean,
	noSkillUntil: number,
	exhaustedUntil: number,
	moveSpeed: number,
	moveJump: boolean,

	blocking: boolean,
	blockStart: number,
	guard: number,
	lastGuardHit: number,

	combo: number,
	lastM1: number,
	m1Ready: number,
	hurtFlip: boolean,

	cooldowns: { [string]: number },

	awakening: number,
	awakened: boolean,
	awakenEnd: number,
	evasive: number,

	ash: number,
	ashExpire: number,

	counterUntil: number,
	onCounter: ((self: Entity, attacker: Entity, info: HitInfo) -> boolean)?,
	armorUntil: number,
	armorScale: number,

	token: number,
	moveName: string?,
	lastHitBy: Entity?,
	lastHitTime: number,
	comboHits: number,
	comboTarget: Entity?,

	attrTimer: number,
	data: { [string]: any },
}

local entities: { [Model]: Entity } = {}
Combat.entities = entities

-- 캐릭터별 기술 모듈: Combat.Moves[charId][moveId](ent, ctx) -> boolean
Combat.Moves = {} :: { [string]: { [string]: any } }
-- 사망 시 콜백 (CharacterService 가 등록)
Combat.onDied = nil :: ((ent: Entity) -> ())?
-- 오류 보고 콜백 (Main 이 등록 → 화면에 표시)
Combat.onError = nil :: ((where: string, err: any) -> ())?

local fxFolder = Instance.new("Folder")
fxFolder.Name = "ServerFX"
fxFolder.Parent = workspace
Combat.fxFolder = fxFolder

local function now(): number
	return os.clock()
end

----------------------------------------------------------------------
-- 등록 / 조회
----------------------------------------------------------------------
function Combat.register(model: Model, player: Player?, charId: string, opts: { dummy: boolean?, bot: boolean? }?): Entity
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local def = CharacterDefs.get(charId)
	local ent: Entity = {
		model = model,
		humanoid = humanoid,
		root = root,
		player = player,
		charId = charId,
		def = def,
		isDummy = opts ~= nil and opts.dummy == true,
		isBot = opts ~= nil and opts.bot == true,
		alive = true,

		stunUntil = 0,
		busyUntil = 0,
		iframeUntil = 0,
		ragdollUntil = 0,
		ragdolled = false,
		noSkillUntil = 0,
		exhaustedUntil = 0,
		moveSpeed = Config.AttackWalkSpeed,
		moveJump = false,

		blocking = false,
		blockStart = 0,
		guard = Config.Block.GuardMax,
		lastGuardHit = 0,

		combo = 0,
		lastM1 = 0,
		m1Ready = 0,
		hurtFlip = false,

		cooldowns = {},

		awakening = 0,
		awakened = false,
		awakenEnd = 0,
		evasive = Config.Evasive.Max,

		ash = 0,
		ashExpire = 0,

		counterUntil = 0,
		onCounter = nil,
		armorUntil = 0,
		armorScale = 1,

		token = 0,
		moveName = nil,
		lastHitBy = nil,
		lastHitTime = 0,
		comboHits = 0,
		comboTarget = nil,

		attrTimer = 0,
		data = {},
	}
	entities[model] = ent

	humanoid.Died:Connect(function()
		Combat.onDeath(ent)
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			entities[model] = nil
		end
	end)
	Combat.syncAttributes(ent, true)
	return ent
end

function Combat.get(model: Instance?): Entity?
	if model and model:IsA("Model") then
		return entities[model]
	end
	return nil
end

function Combat.fromPlayer(player: Player): Entity?
	local c = player.Character
	return if c then entities[c] else nil
end

----------------------------------------------------------------------
-- 네트워크 헬퍼
----------------------------------------------------------------------
function Combat.fx(name: string, data: { [string]: any })
	Remotes.FX:FireAllClients(name, data)
end

function Combat.anim(ent: Entity, name: string?, speed: number?, exceptOwner: boolean?)
	if exceptOwner and ent.player then
		for _, p in Players:GetPlayers() do
			if p ~= ent.player then
				Remotes.Anim:FireClient(p, ent.model, name, speed)
			end
		end
	else
		Remotes.Anim:FireAllClients(ent.model, name, speed)
	end
end

-- key 는 Locale 문자열 키 (클라이언트가 자기 언어로 바꿔 보여 준다)
function Combat.notify(ent: Entity, key: string, kind: string?, args: { [string]: any }?)
	if ent.player then
		Remotes.Notify:FireClient(ent.player, key, kind or "info", args)
	end
end

function Combat.setCooldown(ent: Entity, key: string, duration: number)
	ent.cooldowns[key] = now() + duration
	if ent.player then
		Remotes.Cooldown:FireClient(ent.player, key, workspace:GetServerTimeNow() + duration, duration)
	end
end

function Combat.onCooldown(ent: Entity, key: string): boolean
	return (ent.cooldowns[key] or 0) > now()
end

----------------------------------------------------------------------
-- 물리: 밀치기 / 래그돌
----------------------------------------------------------------------
-- 캐릭터 물리는 그 캐릭터를 소유한 쪽(플레이어 클라이언트 / 서버)이 계산한다.
-- 수평은 유한한 힘의 평면 속도, 수직은 한 번의 발사 (Shared.Physics 참고)
function Combat.push(ent: Entity, vel: Vector3, duration: number)
	if not ent.alive and not ent.ragdolled then
		return
	end
	local p = ent.player
	if p and p.Parent then
		Remotes.Push:FireClient(p, vel, duration)
	else
		Physics.push(ent.root, vel, duration)
	end
end

local RAG_JOINTS = { "Neck", "Right Shoulder", "Left Shoulder", "Right Hip", "Left Hip" }
local RAG_KEYS = { Neck = "Neck", ["Right Shoulder"] = "RS", ["Left Shoulder"] = "LS", ["Right Hip"] = "RH", ["Left Hip"] = "LH" }

local function setRagdollJoints(ent: Entity, on: boolean)
	local model = ent.model
	for _, jn in RAG_JOINTS do
		local m = model:FindFirstChild(jn, true)
		if m and m:IsA("Motor6D") then
			m.Enabled = not on
		end
		local key = RAG_KEYS[jn]
		local s = model:FindFirstChild("RagSocket_" .. key, true)
		if s and s:IsA("BallSocketConstraint") then
			s.Enabled = on
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "RagCollider" then
			d.CanCollide = on
		end
	end
	ent.humanoid.PlatformStand = on
	local p = ent.player
	if p and p.Parent then
		Remotes.Ragdoll:FireClient(p, on)
	elseif on then
		ent.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	else
		ent.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end

function Combat.ragdoll(ent: Entity, duration: number)
	local t = now()
	ent.ragdollUntil = math.max(ent.ragdollUntil, t + duration)
	ent.stunUntil = math.max(ent.stunUntil, ent.ragdollUntil + 0.35)
	if not ent.ragdolled then
		ent.ragdolled = true
		setRagdollJoints(ent, true)
		Combat.anim(ent, nil)
	end
end

function Combat.unragdoll(ent: Entity)
	if ent.ragdolled then
		ent.ragdolled = false
		ent.ragdollUntil = 0
		setRagdollJoints(ent, false)
		Physics.stop(ent.root)
		-- 넘어진 상태에서 일어설 때 몸을 세운다 (플레이어는 클라이언트가 직접 세운다)
		if not ent.player then
			local pos = ent.root.Position
			local look = ent.root.CFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude < 0.1 then
				look = Vector3.new(0, 0, -1)
			end
			ent.root.CFrame = CFrame.lookAt(pos + Vector3.new(0, 1.5, 0), pos + Vector3.new(0, 1.5, 0) + look.Unit)
		end
	end
end

----------------------------------------------------------------------
-- 상태
----------------------------------------------------------------------
function Combat.isStunned(ent: Entity): boolean
	return ent.stunUntil > now() or ent.ragdolled
end

function Combat.isBusy(ent: Entity): boolean
	return ent.busyUntil > now()
end

function Combat.canAct(ent: Entity): boolean
	return ent.alive and not Combat.isStunned(ent) and not Combat.isBusy(ent)
end

-- 기술 시작: 이전 동작 취소 토큰을 갱신하고 행동 불가 시간을 건다
function Combat.beginMove(ent: Entity, name: string, busy: number, moveSpeed: number?, allowJump: boolean?): number
	ent.token += 1
	ent.moveName = name
	ent.busyUntil = now() + busy
	ent.moveSpeed = moveSpeed or Config.AttackWalkSpeed
	ent.moveJump = allowJump == true
	ent.blocking = false
	return ent.token
end

function Combat.valid(ent: Entity, token: number): boolean
	return ent.alive and ent.token == token and not ent.ragdolled and ent.stunUntil <= now()
end

function Combat.sleep(ent: Entity, token: number, t: number): boolean
	task.wait(t)
	return Combat.valid(ent, token)
end

function Combat.endMove(ent: Entity, token: number)
	if ent.token == token then
		ent.busyUntil = 0
		ent.moveName = nil
	end
end

function Combat.stun(ent: Entity, duration: number, anim: string?)
	local t = now()
	ent.stunUntil = math.max(ent.stunUntil, t + duration)
	ent.token += 1
	ent.busyUntil = 0
	ent.moveName = nil
	ent.blocking = false
	ent.counterUntil = 0
	if not ent.ragdolled then
		local a = anim
		if not a then
			ent.hurtFlip = not ent.hurtFlip
			a = if ent.hurtFlip then "hurt_1" else "hurt_2"
		end
		Combat.anim(ent, a)
	end
end

----------------------------------------------------------------------
-- 게이지
----------------------------------------------------------------------
function Combat.addMeter(ent: Entity, amount: number)
	if ent.awakened or ent.isDummy then
		return
	end
	local before = ent.awakening
	ent.awakening = math.clamp(ent.awakening + amount, 0, Config.Awakening.Max)
	if before < Config.Awakening.Max and ent.awakening >= Config.Awakening.Max then
		Combat.notify(ent, "n.awaken_ready", "awaken")
		if ent.player then
			Remotes.FX:FireClient(ent.player, "AwakenReady", {})
		end
	end
end

function Combat.addAsh(ent: Entity, amount: number)
	if ent.charId ~= "KanzakiRen" or amount <= 0 then
		return
	end
	ent.ash = math.clamp(ent.ash + amount, 0, Config.Ash.Max)
	ent.ashExpire = now() + Config.Ash.Lifetime
	Combat.fx("AshGain", { model = ent.model, amount = amount })
end

function Combat.useAsh(ent: Entity, amount: number): boolean
	if ent.awakened then
		return true -- 각성 중에는 회분이 줄지 않는다
	end
	if ent.ash < amount then
		return false
	end
	ent.ash -= amount
	return true
end

----------------------------------------------------------------------
-- 판정
----------------------------------------------------------------------
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = false

-- 판정 상자. 맞은 캐릭터들과, 건물·사물을 부술 때 쓸 영역을 돌려준다.
export type Region = { cf: CFrame, size: Vector3 }

function Combat.box(attacker: Entity?, cf: CFrame, size: Vector3): ({ Entity }, Region)
	local exclude: { Instance } = { fxFolder }
	if attacker then
		table.insert(exclude, attacker.model)
	end
	overlap.FilterDescendantsInstances = exclude
	local parts = workspace:GetPartBoundsInBox(cf, size, overlap)
	local found: { Entity } = {}
	local seen: { [Model]: boolean } = {}
	for _, part in parts do
		local model = part:FindFirstAncestorOfClass("Model")
		while model and not entities[model] do
			model = model:FindFirstAncestorOfClass("Model")
		end
		if model and not seen[model] then
			seen[model] = true
			local e = entities[model]
			if e and e.alive then
				table.insert(found, e)
			end
		end
	end
	if Config.DebugHitboxes then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 0.7
		p.Color = Color3.new(1, 0, 0)
		p.Size = size
		p.CFrame = cf
		p.Parent = fxFolder
		Debris:AddItem(p, 0.25)
	end
	return found, { cf = cf, size = size }
end

-- 판정 영역 안의 건물·사물을 부순다. 부서진 파트 수를 돌려준다.
function Combat.smash(att: Entity?, region: Region, opts: Destruction.Opts?): number
	local o: Destruction.Opts = opts or {}
	if o.from == nil and att then
		o.from = att.root.Position
	end
	return Destruction.destroyBox(region.cf, region.size, o)
end

-- 구 모양으로 부순다 (폭발·착지 충격 등)
function Combat.smashSphere(att: Entity?, center: Vector3, radius: number, opts: Destruction.Opts?): number
	local o: Destruction.Opts = opts or {}
	if o.from == nil and att then
		o.from = att.root.Position
	end
	return Destruction.destroySphere(center, radius, o)
end

-- 캐릭터 앞쪽 상자 판정
function Combat.front(ent: Entity, forward: number, size: Vector3, dir: Vector3?): ({ Entity }, Region)
	local look = dir or ent.root.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.05 then
		flat = Vector3.new(0, 0, -1)
	end
	local pos = ent.root.Position + flat.Unit * forward
	return Combat.box(ent, CFrame.lookAt(pos, pos + flat.Unit), size)
end

----------------------------------------------------------------------
-- 피해
----------------------------------------------------------------------
local function applyDamage(att: Entity?, tgt: Entity, dmg: number)
	if dmg <= 0 then
		return
	end
	local hum = tgt.humanoid
	if tgt.isDummy then
		hum.Health = math.max(1, hum.Health - dmg)
		if hum.Health <= 1 then
			hum.Health = hum.MaxHealth
		end
	else
		hum.Health = math.max(0, hum.Health - dmg)
	end
	tgt.data.lastDamaged = now()
	if att then
		tgt.lastHitBy = att
		tgt.lastHitTime = now()
		Combat.addMeter(att, dmg * Config.Awakening.PerDamageDealt)
	end
	Combat.addMeter(tgt, dmg * Config.Awakening.PerDamageTaken)
	Combat.fx("Damage", { model = tgt.model, amount = math.floor(dmg * 10 + 0.5) / 10 })
end

local function guardBreak(att: Entity, tgt: Entity)
	tgt.blocking = false
	tgt.guard = Config.Block.GuardMax * 0.5
	Combat.stun(tgt, Config.Block.GuardBreakStun, "stunned")
	Combat.fx("GuardBreak", { model = tgt.model, pos = tgt.root.Position })
	Combat.notify(tgt, "n.guard_break", "warn")
	local _ = att
end

function Combat.hit(att: Entity, tgt: Entity, info: HitInfo): string
	if not tgt.alive or tgt == att then
		return "none"
	end
	local t = now()
	if t < tgt.iframeUntil then
		return "iframe"
	end

	-- 린 위안 《유전》: 흐름을 받아 되돌림
	if tgt.counterUntil > t and not info.noCounter and tgt.onCounter then
		local cb = tgt.onCounter
		if cb and cb(tgt, att, info) then
			return "countered"
		end
	end

	-- 막기
	local toAtt = (att.root.Position - tgt.root.Position) * Vector3.new(1, 0, 1)
	local facing = if toAtt.Magnitude > 0.05 then tgt.root.CFrame.LookVector:Dot(toAtt.Unit) else 1
	if tgt.blocking and facing > Config.Block.FrontDot and not info.unblockable then
		if info.guardBreak then
			guardBreak(att, tgt)
			applyDamage(att, tgt, info.damage * 0.5)
			return "guardbreak"
		end
		if t - tgt.blockStart <= Config.Block.PerfectWindow and info.projectile == nil then
			Combat.stun(att, Config.Block.ParryStun, "parried")
			Combat.fx("Parry", { pos = (att.root.Position + tgt.root.Position) / 2 })
			Combat.notify(tgt, "n.parry", "good")
			return "parried"
		end
		tgt.guard -= info.damage * Config.Block.GuardDamageScale
		tgt.lastGuardHit = t
		applyDamage(att, tgt, info.damage * Config.Block.ChipDamage)
		if tgt.guard <= 0 then
			guardBreak(att, tgt)
			return "guardbreak"
		end
		Combat.fx("Block", { model = tgt.model, pos = tgt.root.Position + tgt.root.CFrame.LookVector * 1.5 })
		if toAtt.Magnitude > 0.05 then
			Combat.push(tgt, -toAtt.Unit * 16, 0.12)
		end
		return "blocked"
	end

	local dmg = info.damage * (if att.awakened then Config.Awakening.DamageBonus else 1)
	local armored = tgt.armorUntil > t
	if armored then
		dmg *= tgt.armorScale
	end
	applyDamage(att, tgt, dmg)

	if not armored then
		Combat.stun(tgt, info.stun or 0.5, info.anim)
		if info.knock then
			Combat.push(tgt, info.knock, info.knockTime or 0.2)
		end
		if info.ragdoll then
			Combat.ragdoll(tgt, info.ragdoll)
		end
		-- 크게 날아가면: 바람 궤적 + 벽에 부딪히는지 검사 (벽꽝)
		local knock = info.knock
		if knock and info.ragdoll and Vector3.new(knock.X, 0, knock.Z).Magnitude > 45 then
			tgt.data.wallCheckUntil = t + 0.9
			tgt.data.wallAttacker = att
			tgt.data.crashed = false
			local ad = att.def
			Combat.fx("Knockback", { model = tgt.model, duration = 0.7, color = if ad then ad.color else nil })
		end
	end

	-- 콤보 카운터
	if att.comboTarget == tgt and t - att.lastHitTime < 1.6 then
		att.comboHits += 1
	else
		att.comboHits = 1
	end
	att.comboTarget = tgt
	att.lastHitTime = t
	if att.player then
		Remotes.FX:FireClient(att.player, "Combo", { count = att.comboHits })
	end

	Combat.fx("Hit", {
		target = tgt.model,
		attacker = att.model,
		pos = tgt.root.Position,
		kind = info.fx or "light",
		sound = info.sound,
		hitstop = info.hitstop or 0.05,
		shake = info.shake,
		armored = armored,
	})
	return "hit"
end

----------------------------------------------------------------------
-- 각성
----------------------------------------------------------------------
function Combat.setHighlight(ent: Entity, color: Color3?)
	local h = ent.model:FindFirstChild("AwakenHighlight")
	if color then
		if not h then
			local nh = Instance.new("Highlight")
			nh.Name = "AwakenHighlight"
			nh.FillTransparency = 1
			nh.OutlineTransparency = 0.15
			nh.DepthMode = Enum.HighlightDepthMode.Occluded
			nh.Parent = ent.model
			h = nh
		end
		(h :: Highlight).OutlineColor = color
	elseif h then
		h:Destroy()
	end
end

function Combat.endAwakening(ent: Entity, reason: string?)
	if not ent.awakened then
		return
	end
	ent.awakened = false
	ent.awakening = 0
	ent.cooldowns = {}
	if ent.player then
		Remotes.Cooldown:FireClient(ent.player, "*", 0, 0)
	end
	Combat.setHighlight(ent, nil)
	Combat.fx("AwakenEnd", { model = ent.model, charId = ent.charId })
	local mod = Combat.Moves[ent.charId]
	if mod and mod.onAwakenEnd then
		mod.onAwakenEnd(ent, reason)
	end
	Combat.syncAttributes(ent, true)
end

----------------------------------------------------------------------
-- 사망
----------------------------------------------------------------------
-- 킬 피드용 이름 ("표시 이름 (캐릭터)") — 두 언어로
local function feedName(e: Entity): { ko: string, en: string }
	if e.isDummy then
		return Locale.both("feed.dummy")
	end
	local who = if e.player then { ko = e.player.DisplayName, en = e.player.DisplayName } else Locale.both("feed.bot")
	local n = CharacterDefs.names(e.def)
	return { ko = who.ko .. " (" .. n.ko .. ")", en = who.en .. " (" .. n.en .. ")" }
end

function Combat.onDeath(ent: Entity)
	if not ent.alive then
		return
	end
	ent.alive = false
	ent.token += 1
	ent.blocking = false
	ent.awakened = false
	Combat.setHighlight(ent, nil)
	ent.ragdolled = true
	setRagdollJoints(ent, true)
	Combat.anim(ent, nil)
	Combat.fx("Death", { model = ent.model, pos = ent.root.Position })

	local killer = ent.lastHitBy
	local killerName: { ko: string, en: string }
	if killer and now() - ent.lastHitTime < 12 then
		Combat.addMeter(killer, Config.Awakening.PerKill)
		killerName = feedName(killer)
	else
		killerName = Locale.both("feed.env")
	end
	Remotes.Feed:FireAllClients(killerName, feedName(ent))

	local cb = Combat.onDied
	if cb then
		task.spawn(cb, ent)
	end
end

----------------------------------------------------------------------
-- 투사체 (칸자키 렌의 회분 참격 등)
----------------------------------------------------------------------
export type Projectile = {
	id: number,
	owner: Entity,
	pos: Vector3,
	dir: Vector3,
	speed: number,
	range: number,
	traveled: number,
	width: number,
	height: number,
	info: HitInfo,
	hitSet: { [Entity]: boolean },
	kind: string,
	alive: boolean,
	onHit: ((p: Projectile, target: Entity, result: string) -> ())?,
	cutProps: boolean,
	groundSkim: boolean,
	pierce: boolean, -- 부서지는 벽을 뚫고 계속 날아간다
	smash: number, -- 벽에 맞았을 때 뚫는 구멍 반지름
}

local projectiles: { Projectile } = {}
local projectileId = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function Combat.projectile(owner: Entity, opts: {
	origin: Vector3,
	dir: Vector3,
	speed: number,
	range: number,
	width: number,
	height: number?,
	info: HitInfo,
	kind: string,
	onHit: ((p: Projectile, target: Entity, result: string) -> ())?,
	cutProps: boolean?,
	groundSkim: boolean?,
	pierce: boolean?,
	smash: number?,
}): Projectile
	projectileId += 1
	local p: Projectile = {
		id = projectileId,
		owner = owner,
		pos = opts.origin,
		dir = opts.dir.Unit,
		speed = opts.speed,
		range = opts.range,
		traveled = 0,
		width = opts.width,
		height = opts.height or 4,
		info = opts.info,
		hitSet = {},
		kind = opts.kind,
		alive = true,
		onHit = opts.onHit,
		cutProps = opts.cutProps ~= false,
		groundSkim = opts.groundSkim == true,
		pierce = opts.pierce == true,
		smash = opts.smash or math.max(opts.width, opts.height or 4) * 0.55,
	}
	p.info.projectile = p
	table.insert(projectiles, p)
	Combat.fx("Projectile", {
		id = p.id,
		kind = p.kind,
		origin = p.pos,
		dir = p.dir,
		speed = p.speed,
		range = p.range,
		width = p.width,
		height = p.height,
	})
	return p
end

function Combat.redirectProjectile(p: Projectile, newOwner: Entity, newDir: Vector3)
	p.owner = newOwner
	p.dir = newDir.Unit
	p.traveled = 0
	p.range = math.max(p.range, 40)
	p.hitSet = { [newOwner] = true }
	Combat.fx("ProjectileRedirect", { id = p.id, pos = p.pos, dir = p.dir, speed = p.speed, range = p.range, kind = "gold" })
end

local function endProjectile(p: Projectile)
	if p.alive then
		p.alive = false
		Combat.fx("ProjectileEnd", { id = p.id, pos = p.pos })
	end
end

local function stepProjectiles(dt: number)
	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		if not p.alive then
			table.remove(projectiles, i)
			continue
		end
		local step = math.min(p.speed * dt, p.range - p.traveled)
		if step <= 0 then
			endProjectile(p)
			continue
		end
		-- 벽: 부서지는 건물이면 구멍을 뚫고 (관통형은 계속 날아감), 안 부서지는 벽이면 소멸
		local ignore: { Instance } = { fxFolder }
		for m in entities do
			table.insert(ignore, m)
		end
		rayParams.FilterDescendantsInstances = ignore
		local wall = workspace:Raycast(p.pos, p.dir * step, rayParams)
		local stopAt: Vector3? = nil
		-- 칸자키 렌의 회분 참격(ash, ash_low)이 닿은 물체는 재가 된다 (린 위안이 되돌려 보낸 참격은 그냥 부순다)
		local ash = string.sub(p.kind, 1, 3) == "ash" and p.owner.charId == "KanzakiRen"
		if wall and wall.Instance.CanCollide then
			local n = wall.Normal
			if not (p.groundSkim and n.Y > 0.7) then
				if p.cutProps and Destruction.isDestructible(wall.Instance) then
					Destruction.destroySphere(wall.Position + p.dir * (p.smash * 0.3), p.smash, { from = p.pos, dir = p.dir, ash = ash, force = 1.3 })
					if not p.pierce then
						stopAt = wall.Position
						step = (wall.Position - p.pos).Magnitude
					end
				else
					stopAt = wall.Position
					step = (wall.Position - p.pos).Magnitude
				end
			end
		end
		local mid = p.pos + p.dir * (step / 2)
		local cf = CFrame.lookAt(mid, mid + p.dir)
		local hits, region = Combat.box(p.owner, cf, Vector3.new(p.width, p.height, math.max(step, 1) + 1.5))
		for _, e in hits do
			if not p.hitSet[e] and p.alive then
				p.hitSet[e] = true
				local knock = p.info.knock
				if knock then
					-- 투사체 방향으로 다시 계산
					local mag = Vector3.new(knock.X, 0, knock.Z).Magnitude
					p.info.knock = p.dir * mag + Vector3.new(0, knock.Y, 0)
				end
				local result = Combat.hit(p.owner, e, p.info)
				if p.onHit then
					p.onHit(p, e, result)
				end
				if result == "countered" then
					-- 방향이 바뀌었으면 이번 스텝은 여기서 끝
					break
				end
			end
		end
		-- 지나가는 길의 사물 (관통형은 건물까지 통째로 베어 나간다)
		if p.cutProps then
			-- 한 스텝은 짧으니 조각 크기는 참격 단면에 맞춘다 (안 그러면 벽이 너무 잘게 쪼개진다)
			local grain = math.clamp(math.min(p.width, p.height) / 3, 1.5, 4)
			Destruction.destroyBox(cf, region.size, { from = p.pos, dir = p.dir, ash = ash, propsOnly = not p.pierce, force = 1.1, grain = grain })
		end
		p.pos += p.dir * step
		p.traveled += step
		if stopAt then
			endProjectile(p)
		elseif p.traveled >= p.range - 0.01 then
			endProjectile(p)
		end
	end
end

----------------------------------------------------------------------
-- 상태 동기화 (Attribute) 및 매 프레임 처리
----------------------------------------------------------------------
function Combat.syncAttributes(ent: Entity, force: boolean?)
	local m = ent.model
	local function set(name: string, v: any)
		if force or m:GetAttribute(name) ~= v then
			m:SetAttribute(name, v)
		end
	end
	local t = now()
	set("Stunned", ent.stunUntil > t or ent.ragdolled)
	set("Blocking", ent.blocking)
	set("Awakened", ent.awakened)
	set("Awakening", math.floor(ent.awakening + 0.5))
	set("Evasive", math.floor(ent.evasive + 0.5))
	set("Guard", math.floor(math.max(ent.guard, 0) + 0.5))
	set("Ash", ent.ash)
	set("Busy", ent.busyUntil > t)
	local serverNow = workspace:GetServerTimeNow()
	set("AshExpire", if ent.ash > 0 then math.floor((serverNow + (ent.ashExpire - t)) * 10) / 10 else 0)
	set("AwakenEnd", if ent.awakened then math.floor((serverNow + (ent.awakenEnd - t)) * 10) / 10 else 0)
	set("Exhausted", ent.exhaustedUntil > t)
end

local wallParams = RaycastParams.new()
wallParams.FilterType = Enum.RaycastFilterType.Exclude

-- 살아 있는 상태에서 캐릭터(무브셋) 교체: 무기를 바꿔 끼우고 게이지·쿨타임을 초기화한다
function Combat.changeCharacter(ent: Entity, charId: string)
	local def = CharacterDefs.get(charId)
	if not def then
		return
	end
	if ent.awakened then
		ent.awakened = false
		Combat.setHighlight(ent, nil)
		Combat.fx("AwakenEnd", { model = ent.model, charId = ent.charId })
	end
	ent.token += 1
	ent.busyUntil = 0
	ent.moveName = nil
	ent.blocking = false
	ent.counterUntil = 0
	ent.armorUntil = 0
	ent.charId = charId
	ent.def = def
	ent.awakening = 0
	ent.ash = 0
	ent.combo = 0
	ent.cooldowns = {}
	ent.noSkillUntil = 0
	ent.exhaustedUntil = 0
	ent.data.speedMul = nil
	RigBuilder.equip(ent.model, charId)
	ent.humanoid.MaxHealth = def.maxHealth
	ent.humanoid.Health = def.maxHealth
	Combat.anim(ent, nil)
	if ent.player then
		Remotes.Cooldown:FireClient(ent.player, "*", 0, 0)
	end
	Combat.fx("Spawn", { model = ent.model, pos = ent.root.Position })
	Combat.syncAttributes(ent, true)
end

-- 날아가는 몸이 건물·사물에 부딪히면 부수고 뚫고 지나간다 (가강전처럼).
-- 안 부서지는 벽이면 벽꽝(추가 피해 + 튕겨 나옴). 쓰러진 몸(처치 직후)도 부수며 날아간다.
local function bodyCrash(ent: Entity, t: number)
	local wallUntil = ent.data.wallCheckUntil
	local knocked = typeof(wallUntil) == "number" and wallUntil > t
	if not knocked and not ent.ragdolled then
		return
	end
	local nextCrash = ent.data.nextCrash
	if typeof(nextCrash) == "number" and t < nextCrash then
		return
	end
	local v = ent.root.AssemblyLinearVelocity
	local speed = v.Magnitude
	if speed < Config.Destruction.BodyCrashSpeed then
		return
	end
	local ignore: { Instance } = { fxFolder }
	for m in entities do
		table.insert(ignore, m)
	end
	wallParams.FilterDescendantsInstances = ignore
	-- 네트워크 지연만큼 앞을 미리 본다 (벽에 닿기 전에 부숴야 멈추지 않고 뚫고 나간다)
	local dir = v.Unit
	local reach = math.clamp(speed * 0.12, 3, 12)
	local hit = workspace:Raycast(ent.root.Position, dir * reach, wallParams)
	if not hit then
		return
	end
	if Destruction.isDestructible(hit.Instance) then
		ent.data.nextCrash = t + 0.05
		local radius = math.clamp(speed * 0.055, 3, 7)
		Destruction.destroySphere(hit.Position + dir * (radius * 0.4), radius, {
			from = ent.root.Position,
			dir = dir,
			force = math.clamp(speed / 70, 0.8, 2.2),
		})
		if knocked and ent.alive and ent.data.crashed ~= true then
			-- 첫 충돌만 피해 + 벽꽝 연출
			ent.data.crashed = true
			Combat.fx("WallSlam", { pos = hit.Position, normal = hit.Normal, model = ent.model })
			applyDamage(ent.data.wallAttacker :: Entity?, ent, 3)
		end
	elseif
		knocked
		and ent.alive
		and math.abs(hit.Normal.Y) < 0.6
		and Vector3.new(v.X, 0, v.Z).Magnitude > 30
		and hit.Distance <= math.clamp(speed * 0.08, 2.5, 6)
	then
		-- 안 부서지는 벽: 벽꽝 후 튕겨 나온다
		ent.data.wallCheckUntil = 0
		Combat.fx("WallSlam", { pos = hit.Position, normal = hit.Normal, model = ent.model })
		applyDamage(ent.data.wallAttacker :: Entity?, ent, 3)
		ent.ragdollUntil = math.max(ent.ragdollUntil, t + 0.5)
		ent.stunUntil = math.max(ent.stunUntil, ent.ragdollUntil + 0.35)
		Combat.push(ent, hit.Normal * 10 + Vector3.new(0, 12, 0), 0.1)
	end
end

local function updateEntity(ent: Entity, dt: number, t: number)
	local hum = ent.humanoid
	if not ent.alive then
		if ent.ragdolled and ent.model.Parent then
			bodyCrash(ent, t)
		end
		return
	end
	if ent.ragdolled and t >= ent.ragdollUntil then
		Combat.unragdoll(ent)
	end

	-- 게이지 회복
	if t - ent.lastGuardHit > Config.Block.GuardRegenDelay and not ent.blocking then
		ent.guard = math.min(Config.Block.GuardMax, ent.guard + Config.Block.GuardRegenPerSec * dt)
	end
	ent.evasive = math.min(Config.Evasive.Max, ent.evasive + Config.Evasive.RegenPerSec * dt)

	if ent.awakened then
		ent.awakening = math.max(0, Config.Awakening.Max * (ent.awakenEnd - t) / Config.Awakening.Duration)
		if t >= ent.awakenEnd then
			Combat.endAwakening(ent, "timeout")
		end
	end
	if ent.charId == "KanzakiRen" then
		if ent.awakened then
			ent.ash = Config.Ash.Max
			ent.ashExpire = t + Config.Ash.Lifetime
		elseif ent.ash > 0 and t >= ent.ashExpire then
			ent.ash = 0
			Combat.notify(ent, "n.ash_scatter", "info")
		end
	end

	bodyCrash(ent, t)

	-- 전투에서 벗어나 있으면 체력이 천천히 찬다
	local lastDamaged = ent.data.lastDamaged
	if not ent.isDummy and hum.Health > 0 and hum.Health < hum.MaxHealth then
		if typeof(lastDamaged) ~= "number" or t - lastDamaged > Config.Regen.Delay then
			hum.Health = math.min(hum.MaxHealth, hum.Health + Config.Regen.PerSec * dt)
		end
	end

	-- 이동 속도 / 점프
	local def = ent.def
	local baseSpeed = if def then def.walkSpeed else 0
	if ent.isDummy then
		baseSpeed = 0
	end
	local mul = ent.data.speedMul
	local speed = baseSpeed * (if typeof(mul) == "number" then mul else 1)
	local jump = Config.JumpPower
	if Combat.isStunned(ent) then
		speed = 0
		jump = 0
	elseif Combat.isBusy(ent) then
		speed = ent.moveSpeed
		jump = if ent.moveJump then Config.JumpPower else 0
	elseif ent.blocking then
		speed = Config.BlockWalkSpeed
		jump = 0
	elseif ent.exhaustedUntil > t then
		speed = baseSpeed * 0.55
		jump = Config.JumpPower * 0.6
	end
	if hum.WalkSpeed ~= speed then
		hum.WalkSpeed = speed
	end
	if hum.JumpPower ~= jump then
		hum.JumpPower = jump
	end
	local autoRotate = not (Combat.isStunned(ent) or (Combat.isBusy(ent) and ent.moveSpeed < 1))
	if hum.AutoRotate ~= autoRotate then
		hum.AutoRotate = autoRotate
	end

	-- 스턴이 풀리면 경직 애니메이션 정지
	local stunnedNow = ent.stunUntil > t or ent.ragdolled
	if ent.data.wasStunned and not stunnedNow and ent.alive then
		Combat.anim(ent, nil)
	end
	ent.data.wasStunned = stunnedNow

	ent.attrTimer -= dt
	if ent.attrTimer <= 0 then
		ent.attrTimer = 0.1
		Combat.syncAttributes(ent)
	end
end

local function reportError(where: string, err: any)
	local cb = Combat.onError
	if cb then
		cb(where, err)
	else
		warn(where, err)
	end
end

function Combat.start()
	RunService.Heartbeat:Connect(function(dt)
		local t = now()
		for _, ent in entities do
			-- 한 캐릭터에서 오류가 나도 나머지 전투는 계속 돌아가게
			local ok, err = pcall(updateEntity :: any, ent, dt, t)
			if not ok then
				reportError("전투 갱신 (" .. ent.model.Name .. ")", err)
			end
		end
		local ok, err = pcall(stepProjectiles :: any, dt)
		if not ok then
			reportError("투사체", err)
		end
	end)
end

return Combat
