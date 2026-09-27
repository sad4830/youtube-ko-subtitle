--!strict
-- 공통 입력 처리: M1 연타, 막기, 대시/회피, 각성, 기술 슬롯 1~4

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Combat = require(script.Parent.Combat)
local MapService = require(script.Parent.MapService)

type Entity = Combat.Entity

local Actions = {}

local UP = Vector3.new(0, 1, 0)

local function flat(v: Vector3, fallback: Vector3): Vector3
	local f = Vector3.new(v.X, 0, v.Z)
	if f.Magnitude < 0.05 then
		return fallback
	end
	return f.Unit
end

function Actions.readAim(ent: Entity, payload: any): Vector3
	local look = flat(ent.root.CFrame.LookVector, Vector3.new(0, 0, -1))
	if typeof(payload) == "table" then
		local aim = payload.aim
		if typeof(aim) == "Vector3" and aim.Magnitude > 0.1 and aim.Magnitude < 1000 then
			return flat(aim, look)
		end
	end
	return look
end

-- 서버가 물리를 소유한 봇/허수아비는 서버에서 직접 방향을 돌린다
function Actions.face(ent: Entity, aim: Vector3)
	if not ent.player then
		local pos = ent.root.Position
		ent.root.CFrame = CFrame.lookAt(pos, pos + aim)
	end
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

function Actions.airborne(ent: Entity): boolean
	rayParams.FilterDescendantsInstances = { ent.model, Combat.fxFolder }
	local hit = workspace:Raycast(ent.root.Position, Vector3.new(0, -4.5, 0), rayParams)
	return hit == nil
end

----------------------------------------------------------------------
-- M1
----------------------------------------------------------------------
function Actions.m1(ent: Entity, payload: any)
	if not Combat.canAct(ent) or ent.blocking then
		return
	end
	local t = os.clock()
	if t < ent.m1Ready then
		return
	end
	if t - ent.lastM1 > Config.M1.ComboReset then
		ent.combo = 0
	end
	ent.combo += 1
	local n = ent.combo
	ent.lastM1 = t
	local finisher = n >= Config.M1.Count
	local variant = "normal"
	if finisher then
		if Actions.airborne(ent) then
			variant = "down"
		elseif typeof(payload) == "table" and payload.jump == true then
			variant = "up"
		end
		ent.combo = 0
		ent.m1Ready = t + Config.M1.Endlag
	else
		ent.m1Ready = t + Config.M1.Interval
	end

	local cid = ent.charId
	local aim = Actions.readAim(ent, payload)
	Actions.face(ent, aim)
	local token = Combat.beginMove(ent, "M1", if finisher then 0.45 else Config.M1.Interval - 0.04, Config.AttackWalkSpeed, variant == "down")
	local animName = if variant == "up"
		then "m1up_" .. cid
		elseif variant == "down" then "m1down_" .. cid
		else "m1_" .. cid .. "_" .. n
	Combat.anim(ent, animName)
	Combat.push(ent, aim * 11, 0.1)

	local mod = Combat.Moves[cid]
	task.delay(Config.M1.HitDelay, function()
		if not Combat.valid(ent, token) then
			return
		end
		if mod and mod.onM1Swing then
			mod.onM1Swing(ent, n, finisher, aim)
		end
		local range = Config.M1.Range + (if ent.awakened and cid == "LinYuan" then 4.5 else 0)
		local hits, props = Combat.front(ent, range / 2 + 0.2, Vector3.new(Config.M1.Width, 6, range), aim)
		local blade = cid == "KanzakiRen"
		for _, tgt in hits do
			local info: Combat.HitInfo
			if not finisher then
				info = {
					damage = Config.M1.Damage,
					stun = Config.M1.Stun,
					fx = if blade then "slash" else "palm",
					sound = if blade then "ren_slash_hit" else "m1_hit",
					melee = true,
				}
			elseif variant == "up" then
				info = {
					damage = Config.M1.FinisherDamage,
					stun = 1.2,
					knock = UP * 78 + aim * 6,
					knockTime = 0.22,
					ragdoll = 1.4,
					fx = if blade then "slash_heavy" else "palm_heavy",
					sound = "m1_hit_heavy",
					hitstop = 0.09,
					shake = 0.35,
					melee = true,
				}
			elseif variant == "down" then
				info = {
					damage = Config.M1.FinisherDamage,
					stun = 1.2,
					knock = UP * -90 + aim * 10,
					knockTime = 0.2,
					ragdoll = 1.4,
					fx = "slam",
					sound = "ground_crack",
					hitstop = 0.09,
					shake = 0.45,
					melee = true,
				}
			else
				info = {
					damage = Config.M1.FinisherDamage,
					stun = 1.0,
					knock = aim * Config.M1.FinisherKnockback + UP * 20,
					knockTime = 0.24,
					ragdoll = Config.M1.FinisherRagdoll,
					fx = if blade then "slash_heavy" else "palm_heavy",
					sound = "m1_hit_heavy",
					hitstop = 0.09,
					shake = 0.35,
					melee = true,
				}
			end
			local res = Combat.hit(ent, tgt, info)
			if res == "hit" then
				if not finisher then
					-- 연타가 이어지도록 상대를 살짝 같이 민다
					Combat.push(tgt, aim * 11, 0.12)
				end
				if blade then
					Combat.addAsh(ent, Config.Ash.PerM1Hit)
				end
				if mod and mod.onM1Hit then
					mod.onM1Hit(ent, tgt, n, finisher)
				end
			end
		end
		local cutAny = false
		for _, prop in props do
			if MapService.breakPart(prop, ent.root.Position, aim, blade) then
				cutAny = true
			end
		end
		if cutAny and blade then
			Combat.addAsh(ent, Config.Ash.PerPropCut)
		end
	end)
end

----------------------------------------------------------------------
-- 막기
----------------------------------------------------------------------
function Actions.block(ent: Entity, on: boolean)
	if on then
		if not ent.alive or ent.blocking or Combat.isStunned(ent) or Combat.isBusy(ent) then
			return
		end
		ent.blocking = true
		ent.blockStart = os.clock()
		local name = "block_" .. ent.charId
		Combat.anim(ent, name)
	elseif ent.blocking then
		ent.blocking = false
		Combat.anim(ent, nil)
	end
end

----------------------------------------------------------------------
-- 대시 / 회피
----------------------------------------------------------------------
local DASH_DIRS = { front = true, back = true, left = true, right = true }

function Actions.dashVelocity(ent: Entity, dir: string, aim: Vector3): (Vector3, number)
	local right = aim:Cross(UP)
	if dir == "front" then
		return aim * Config.Dash.FrontSpeed, Config.Dash.FrontTime
	elseif dir == "back" then
		return -aim * Config.Dash.SideSpeed, Config.Dash.SideTime
	elseif dir == "left" then
		return -right * Config.Dash.SideSpeed, Config.Dash.SideTime
	end
	return right * Config.Dash.SideSpeed, Config.Dash.SideTime
end

function Actions.dash(ent: Entity, payload: any)
	if not ent.alive or ent.isDummy then
		return
	end
	local dir = if typeof(payload) == "table" and typeof(payload.dir) == "string" and DASH_DIRS[payload.dir] then payload.dir else "front"
	local aim = Actions.readAim(ent, payload)

	if Combat.isStunned(ent) then
		-- 회피: 게이지가 가득 차 있으면 경직/래그돌을 끊고 빠져나온다
		if ent.evasive >= Config.Evasive.Max then
			ent.evasive = 0
			Combat.unragdoll(ent)
			ent.stunUntil = 0
			ent.token += 1
			ent.busyUntil = 0
			ent.iframeUntil = os.clock() + Config.Evasive.IFrames
			Combat.anim(ent, "evasive")
			Combat.push(ent, -aim * 62 + UP * 32, 0.18)
			Combat.fx("Evasive", { model = ent.model, pos = ent.root.Position })
		else
			Combat.notify(ent, "회피 게이지가 부족하다", "warn")
		end
		return
	end
	if Combat.isBusy(ent) or ent.blocking then
		return
	end
	local key = if dir == "front" then "DashFront" else "DashSide"
	if Combat.onCooldown(ent, key) then
		return
	end
	Combat.setCooldown(ent, key, if dir == "front" then Config.Dash.FrontCooldown else Config.Dash.SideCooldown)
	local animName = if dir == "front" and ent.charId == "LinYuan" then "dash_front_LinYuan" else "dash_" .. dir
	local vel, time = Actions.dashVelocity(ent, dir, aim)
	local def = ent.def
	Combat.beginMove(ent, "Dash", time * 0.8, if def then def.walkSpeed else 16, true)
	if ent.player then
		-- 플레이어는 클라이언트가 먼저 움직였다 (반응성). 다른 사람에게만 모션을 보낸다.
		Combat.anim(ent, animName, nil, true)
	else
		Actions.face(ent, aim)
		Combat.anim(ent, animName)
		Combat.push(ent, vel, time)
	end
	Combat.fx("Dash", { model = ent.model, dir = vel.Unit, exceptOwner = ent.player })
end

----------------------------------------------------------------------
-- 각성
----------------------------------------------------------------------
function Actions.startAwakening(ent: Entity)
	local def = ent.def
	ent.awakened = true
	ent.awakening = Config.Awakening.Max
	ent.awakenEnd = os.clock() + Config.Awakening.Duration
	ent.cooldowns = {}
	if def then
		local hum = ent.humanoid
		hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * Config.Awakening.HealFraction)
		Combat.setHighlight(ent, def.color)
	end
	if ent.player then
		Remotes.Cooldown:FireClient(ent.player, "*", 0, 0)
	end
	Combat.syncAttributes(ent, true)
end

function Actions.awaken(ent: Entity)
	if ent.awakened or ent.isDummy or ent.awakening < Config.Awakening.Max then
		if not ent.awakened and ent.awakening < Config.Awakening.Max then
			Combat.notify(ent, "각성 게이지가 아직 부족하다", "warn")
		end
		return
	end
	if not Combat.canAct(ent) or ent.blocking then
		return
	end
	local mod = Combat.Moves[ent.charId]
	if mod and mod.onAwaken then
		mod.onAwaken(ent)
	end
end

----------------------------------------------------------------------
-- 기술
----------------------------------------------------------------------
function Actions.skill(ent: Entity, payload: any)
	if typeof(payload) ~= "table" then
		return
	end
	local slot = tonumber(payload.slot)
	local def = ent.def
	if not slot or not def or slot < 1 or slot > 4 then
		return
	end
	local list = if ent.awakened then def.awakenedMoves else def.moves
	local mv = list[math.floor(slot)]
	if not mv then
		return
	end
	if not Combat.canAct(ent) or ent.blocking then
		return
	end
	if ent.noSkillUntil > os.clock() then
		Combat.notify(ent, "지금은 이능을 쓸 수 없다", "warn")
		return
	end
	if Combat.onCooldown(ent, mv.id) then
		return
	end
	local mod = Combat.Moves[ent.charId]
	local fn = mod and mod[mv.id]
	if typeof(fn) ~= "function" then
		return
	end
	local aim = Actions.readAim(ent, payload)
	Actions.face(ent, aim)
	local ok = fn(ent, { aim = aim, slot = slot, jump = payload.jump == true })
	if ok and mv.cooldown > 0 then
		Combat.setCooldown(ent, mv.id, mv.cooldown)
	end
end

----------------------------------------------------------------------
function Actions.handle(ent: Entity, action: string, payload: any)
	if action == "M1" then
		Actions.m1(ent, payload)
	elseif action == "Block" then
		Actions.block(ent, typeof(payload) == "table" and payload.on == true)
	elseif action == "Dash" then
		Actions.dash(ent, payload)
	elseif action == "Awaken" then
		Actions.awaken(ent)
	elseif action == "Skill" then
		Actions.skill(ent, payload)
	end
end

return Actions
