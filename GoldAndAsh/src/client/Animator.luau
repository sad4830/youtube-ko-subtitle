--!strict
-- 절차적 애니메이터: 모든 캐릭터의 Motor6D.Transform 을 매 프레임 직접 계산한다.
-- (애니메이션 에셋 업로드 없이 동작. Transform 은 복제되지 않으므로 각 클라이언트가 모두를 애니메이트한다.)
--
-- 레이어: [기본 자세(idle) ↔ 달리기 ↔ 공중] 위에 [액션 애니메이션] 을 가중치로 덮어쓴다.

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Animations = require(Shared.Animations)
local Sounds = require(Shared.Sounds)

local Animator = {}

type Vec6 = { number }
type PoseN = { [string]: Vec6 }

type CompiledKey = { t: number, ease: string, pose: PoseN }
type Compiled = {
	name: string,
	def: Animations.AnimDef,
	length: number,
	keys: { CompiledKey },
	joints: { string },
}

type Track = {
	anim: Compiled,
	time: number,
	speed: number,
	weight: number,
	fadeIn: number,
	fadeOut: number,
	stopping: boolean,
	stopTimer: number,
	stopFrom: number,
	markerIndex: number,
	touchedProps: { [string]: boolean },
}

type Rig = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid?,
	charId: string,
	motors: { [string]: Motor6D },
	jointRot: { [string]: CFrame }, -- 관절 C0 의 회전 (기본 R6 아바타는 C0 가 돌아가 있다)
	jointRotInv: { [string]: CFrame },
	idle: Compiled?,
	idleTime: number,
	runPhase: number,
	moveBlend: number,
	airBlend: number,
	airUp: boolean,
	current: Track?,
	fading: Track?,
	props: { [string]: { BasePart } },
	propDefault: { [string]: boolean },
	trails: { Trail },
	freezeUntil: number,
	groundCheckT: number,
	grounded: boolean,
	manual: boolean,
}

local JOINT_MOTORS: { [string]: string } = {
	Root = "RootJoint",
	Neck = "Neck",
	RS = "Right Shoulder",
	LS = "Left Shoulder",
	RH = "Right Hip",
	LH = "Left Hip",
	W = "Weapon",
}
local JOINT_ORDER = { "Root", "Neck", "RS", "LS", "RH", "LH", "W" }
local PROP_NAMES = { "StaffHand", "StaffBack", "KatanaHand", "KatanaSheathed" }

local rigs: { [Model]: Rig } = {}
local watched: { [Model]: boolean } = {}
local compiledCache: { [string]: Compiled } = {}

local ZERO6: Vec6 = { 0, 0, 0, 0, 0, 0 }

local function to6(v: { number }): Vec6
	return { v[1] or 0, v[2] or 0, v[3] or 0, v[4] or 0, v[5] or 0, v[6] or 0 }
end

local function compile(name: string): Compiled?
	local cached = compiledCache[name]
	if cached then
		return cached
	end
	local def = (Animations :: any)[name] :: Animations.AnimDef?
	if not def then
		return nil
	end
	-- 등장하는 관절 모으기
	local jointSet: { [string]: boolean } = {}
	for _, k in def.keyframes do
		for j in k.pose do
			jointSet[j] = true
		end
	end
	local joints: { string } = {}
	for _, j in JOINT_ORDER do
		if jointSet[j] then
			table.insert(joints, j)
		end
	end
	-- 키프레임마다 빠진 관절은 이전 값(없으면 다음 값)으로 채운다
	local keys: { CompiledKey } = {}
	for i, k in def.keyframes do
		keys[i] = { t = k.t, ease = k.ease or "linear", pose = {} }
	end
	for _, j in joints do
		local last: Vec6? = nil
		for i, k in def.keyframes do
			local v = k.pose[j]
			if v then
				last = to6(v)
			end
			if last then
				keys[i].pose[j] = last
			end
		end
		local nextV: Vec6? = nil
		for i = #def.keyframes, 1, -1 do
			local v = keys[i].pose[j]
			if v then
				nextV = v
			elseif nextV then
				keys[i].pose[j] = nextV
			end
		end
	end
	local c: Compiled = { name = name, def = def, length = def.length, keys = keys, joints = joints }
	compiledCache[name] = c
	return c
end

local function ease(kind: string, a: number): number
	if kind == "out" then
		return 1 - (1 - a) * (1 - a)
	elseif kind == "in" then
		return a * a
	elseif kind == "inout" then
		return if a < 0.5 then 2 * a * a else 1 - (-2 * a + 2) ^ 2 / 2
	elseif kind == "expo" then
		return if a >= 1 then 1 else 1 - 2 ^ (-10 * a)
	elseif kind == "back" then
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (a - 1) ^ 3 + c1 * (a - 1) ^ 2
	end
	return a
end

local function lerp6(a: Vec6, b: Vec6, t: number): Vec6
	return {
		a[1] + (b[1] - a[1]) * t,
		a[2] + (b[2] - a[2]) * t,
		a[3] + (b[3] - a[3]) * t,
		a[4] + (b[4] - a[4]) * t,
		a[5] + (b[5] - a[5]) * t,
		a[6] + (b[6] - a[6]) * t,
	}
end

-- 레이어를 섞을 때 360도 이상 회전값이 반대로 풀리지 않도록, base 에 가장 가까운 동치 각도로 맞춘다
local function wrapNear(a: number, base: number): number
	return base + ((a - base + 180) % 360 - 180)
end

local function blendLayer(base: Vec6, top: Vec6, w: number): Vec6
	if w >= 0.999 then
		return top
	end
	local t = {
		wrapNear(top[1], base[1]),
		wrapNear(top[2], base[2]),
		wrapNear(top[3], base[3]),
		top[4],
		top[5],
		top[6],
	}
	return lerp6(base, t, w)
end

local function sample(c: Compiled, time: number): PoseN
	local keys = c.keys
	local n = #keys
	if n == 1 or time <= keys[1].t then
		return keys[1].pose
	end
	if time >= keys[n].t then
		return keys[n].pose
	end
	for i = 1, n - 1 do
		local k0, k1 = keys[i], keys[i + 1]
		if time >= k0.t and time < k1.t then
			local span = k1.t - k0.t
			local a = if span > 0 then (time - k0.t) / span else 1
			a = ease(k0.ease, a)
			local out: PoseN = {}
			for _, j in c.joints do
				local v0 = k0.pose[j] or ZERO6
				local v1 = k1.pose[j] or v0
				out[j] = lerp6(v0, v1, a)
			end
			return out
		end
	end
	return keys[n].pose
end

local rad = math.rad
local function toCFrame(v: Vec6): CFrame
	return CFrame.new(v[4], v[5], v[6]) * CFrame.Angles(rad(v[1]), rad(v[2]), rad(v[3]))
end

----------------------------------------------------------------------
-- 소품(목봉/칼) 표시 전환 · 무기 트레일
----------------------------------------------------------------------
local function setProp(rig: Rig, name: string, visible: boolean)
	local parts = rig.props[name]
	if not parts then
		return
	end
	for _, p in parts do
		if visible then
			local showT = p:GetAttribute("ShowT")
			p.Transparency = if typeof(showT) == "number" then showT else 0
		else
			p.Transparency = 1
		end
	end
end

local function restoreProps(rig: Rig, track: Track)
	for name in track.touchedProps do
		setProp(rig, name, rig.propDefault[name] == true)
	end
	table.clear(track.touchedProps)
end

local function applyShowHide(rig: Rig, track: Track, show: { string }?, hide: { string }?)
	if show then
		for _, n in show do
			track.touchedProps[n] = true
			setProp(rig, n, true)
		end
	end
	if hide then
		for _, n in hide do
			track.touchedProps[n] = true
			setProp(rig, n, false)
		end
	end
end

local function setTrails(rig: Rig, on: boolean)
	for _, t in rig.trails do
		t.Enabled = on
	end
end

local function endTrack(rig: Rig, track: Track)
	restoreProps(rig, track)
	setTrails(rig, false)
end

----------------------------------------------------------------------
-- 등록
----------------------------------------------------------------------
function Animator.register(model: Model): Rig?
	local existing = rigs[model]
	if existing then
		return existing
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local motors: { [string]: Motor6D } = {}
	local jointRot: { [string]: CFrame } = {}
	local jointRotInv: { [string]: CFrame } = {}
	for key, motorName in JOINT_MOTORS do
		local m = model:FindFirstChild(motorName, true)
		if m and m:IsA("Motor6D") then
			motors[key] = m
			-- 포즈 값은 "부모 파트 기준 회전"으로 적혀 있으므로, C0 의 회전으로 켤레 변환해서 Transform 에 넣는다
			--   Transform = R0⁻¹ · Pose · R0   (R0 = C0 의 회전)
			local r = m.C0.Rotation
			jointRot[key] = r
			jointRotInv[key] = r:Inverse()
		end
	end
	if not motors.Root then
		return nil
	end
	local charId = model:GetAttribute("CharId")
	local cid = if typeof(charId) == "string" then charId else "Dummy"

	local props: { [string]: { BasePart } } = {}
	local propDefault: { [string]: boolean } = {}
	for _, pname in PROP_NAMES do
		local pm = model:FindFirstChild(pname, true)
		if pm then
			local list: { BasePart } = {}
			for _, d in pm:GetDescendants() do
				if d:IsA("BasePart") then
					table.insert(list, d)
					if d:GetAttribute("ShowT") == nil then
						d:SetAttribute("ShowT", d.Transparency)
					end
				end
			end
			props[pname] = list
			propDefault[pname] = #list > 0 and list[1].Transparency < 1
		end
	end
	local trails: { Trail } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Trail") and d.Name == "WeaponTrail" then
			table.insert(trails, d)
		end
	end

	local hum = model:FindFirstChildOfClass("Humanoid")
	local rig: Rig = {
		model = model,
		root = root,
		humanoid = hum,
		charId = cid,
		motors = motors,
		jointRot = jointRot,
		jointRotInv = jointRotInv,
		idle = compile("idle_" .. cid) or compile("idle_Dummy"),
		idleTime = math.random() * 2,
		runPhase = 0,
		moveBlend = 0,
		airBlend = 0,
		airUp = false,
		current = nil,
		fading = nil,
		props = props,
		propDefault = propDefault,
		trails = trails,
		freezeUntil = 0,
		groundCheckT = 0,
		grounded = true,
		manual = false,
	}
	rigs[model] = rig
	if not watched[model] then
		watched[model] = true
		model.AncestryChanged:Connect(function(_, parent)
			if parent == nil then
				rigs[model] = nil
				watched[model] = nil
			end
		end)
		-- 캐릭터(무기)를 바꾸면 관절·소품을 다시 찾는다
		model:GetAttributeChangedSignal("GearVersion"):Connect(function()
			task.delay(0.15, function()
				if model.Parent then
					Animator.refresh(model)
				end
			end)
		end)
	end
	return rig
end

function Animator.refresh(model: Model)
	local old = rigs[model]
	if old then
		local cur = old.current
		if cur then
			endTrack(old, cur)
		end
	end
	rigs[model] = nil
	local rig = Animator.register(model)
	if rig and old then
		rig.manual = old.manual
		rig.grounded = old.grounded
	end
end

function Animator.play(model: Model, name: string, speed: number?)
	local rig = rigs[model] or Animator.register(model)
	if not rig then
		return
	end
	local anim = compile(name)
	if not anim then
		return
	end
	local old = rig.current
	if old then
		endTrack(rig, old)
		-- 이전 액션은 새 액션의 fadeIn 동안 사라진다
		old.stopping = true
		old.stopTimer = 0
		old.stopFrom = old.weight
		old.fadeOut = anim.def.fadeIn or 0.06
		rig.fading = old
	end
	local track: Track = {
		anim = anim,
		time = 0,
		speed = speed or 1,
		weight = 0,
		fadeIn = anim.def.fadeIn or 0.06,
		fadeOut = anim.def.fadeOut or 0.15,
		stopping = false,
		stopTimer = 0,
		stopFrom = 1,
		markerIndex = 1,
		touchedProps = {},
	}
	rig.current = track
	applyShowHide(rig, track, anim.def.show, anim.def.hide)
end

function Animator.stop(model: Model, name: string?)
	local rig = rigs[model]
	if not rig then
		return
	end
	local cur = rig.current
	if cur and (name == nil or cur.anim.name == name) and not cur.stopping then
		cur.stopping = true
		cur.stopTimer = 0
		cur.stopFrom = cur.weight
		endTrack(rig, cur)
	end
end

function Animator.currentName(model: Model): string?
	local rig = rigs[model]
	local cur = rig and rig.current
	if cur and not cur.stopping then
		return cur.anim.name
	end
	return nil
end

function Animator.freeze(model: Model, duration: number)
	local rig = rigs[model]
	if rig then
		rig.freezeUntil = os.clock() + duration
	end
end

----------------------------------------------------------------------
-- 기본 레이어 (idle / 달리기 / 공중)
----------------------------------------------------------------------
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true

local function basePose(rig: Rig, dt: number): PoseN
	local root = rig.root
	local vel = root.AssemblyLinearVelocity
	local horiz = Vector3.new(vel.X, 0, vel.Z)
	local speed = horiz.Magnitude

	-- 착지 판정 (가끔만 레이캐스트)
	rig.groundCheckT -= dt
	if rig.groundCheckT <= 0 and not rig.manual then
		rig.groundCheckT = 0.08
		rayParams.FilterDescendantsInstances = { rig.model }
		local hit = workspace:Raycast(root.Position, Vector3.new(0, -3.6, 0), rayParams)
		rig.grounded = hit ~= nil
	end

	local moving = if rig.grounded then math.clamp((speed - 0.5) / 6, 0, 1) else 0
	rig.moveBlend += (moving - rig.moveBlend) * math.min(1, dt * 10)
	local airTarget = if rig.grounded then 0 else 1
	rig.airBlend += (airTarget - rig.airBlend) * math.min(1, dt * 8)
	rig.airUp = vel.Y > 1

	-- idle
	local idlePose: PoseN = {}
	local idle = rig.idle
	if idle then
		rig.idleTime = (rig.idleTime + dt) % idle.length
		idlePose = sample(idle, rig.idleTime)
	end

	local s = math.clamp(speed / 16, 0, 1.5)
	rig.runPhase = (rig.runPhase + dt * speed * 0.55) % (math.pi * 2)
	local sw = math.sin(rig.runPhase)
	local bob = math.abs(math.cos(rig.runPhase))
	local sprint = rig.charId == "KanzakiRen" and speed > 17.5

	local run: PoseN
	if sprint then
		-- 칸자키 렌: 팔을 뒤로 젖히고 낮게 파고드는 달리기
		run = {
			Root = { -24, 0, 0, 0, -0.35 - bob * 0.12, 0 },
			Neck = { 18, 0, 0 },
			RS = { -68, 0, 12 },
			LS = { -64, 0, -12 },
			RH = { sw * 55 * s, 0, 2 },
			LH = { -sw * 55 * s, 0, -2 },
			W = { 30, 0, 0 },
		}
	else
		local lean = if rig.charId == "LinYuan" then -6 else -10
		run = {
			Root = { lean * s, sw * 6 * s, 0, 0, -bob * 0.16 * s, 0 },
			Neck = { 4 * s, -sw * 5 * s, 0 },
			RS = { -sw * 42 * s, 0, 8 },
			LS = { sw * 42 * s, 0, -8 },
			RH = { sw * 48 * s, 0, 2 },
			LH = { -sw * 48 * s, 0, -2 },
		}
		if rig.charId == "KanzakiRen" then
			run.W = { -40, 0, 0 }
		end
	end

	local air: PoseN
	if rig.airUp then
		air = {
			Root = { -6, 0, 0 },
			Neck = { 6, 0, 0 },
			RS = { 30, 0, 26 },
			LS = { 30, 0, -26 },
			RH = { 36, 0, 4 },
			LH = { -22, 0, -4 },
		}
	else
		air = {
			Root = { 6, 0, 0 },
			Neck = { -4, 0, 0 },
			RS = { 14, 0, 62 },
			LS = { 14, 0, -62 },
			RH = { 20, 0, 8 },
			LH = { -12, 0, -8 },
		}
	end

	local out: PoseN = {}
	for _, j in JOINT_ORDER do
		local v = to6(idlePose[j] or ZERO6)
		local r = run[j]
		if r then
			v = lerp6(v, to6(r), rig.moveBlend)
		end
		local a = air[j]
		if a then
			v = lerp6(v, to6(a), rig.airBlend)
		end
		out[j] = v
	end
	return out
end

----------------------------------------------------------------------
-- 액션 레이어
----------------------------------------------------------------------
local function fireMarkers(rig: Rig, track: Track, toT: number)
	local markers = track.anim.def.markers
	if not markers then
		return
	end
	while track.markerIndex <= #markers do
		local m = markers[track.markerIndex] :: Animations.Marker
		if m.t > toT then
			break
		end
		if m.sound and not rig.manual then
			Sounds.play(m.sound, { at = rig.root, volume = m.volume, pitch = m.pitch, random = 0.05 })
		end
		if m.trail ~= nil then
			setTrails(rig, m.trail)
		end
		if m.show or m.hide then
			applyShowHide(rig, track, m.show, m.hide)
		end
		track.markerIndex += 1
	end
end

local function stepTrack(rig: Rig, track: Track, dt: number, frozen: boolean): boolean
	-- 반환값: 트랙이 계속 살아 있는지
	local def = track.anim.def
	if track.stopping then
		track.stopTimer += dt
		local f = if track.fadeOut > 0 then track.stopTimer / track.fadeOut else 1
		track.weight = track.stopFrom * (1 - math.clamp(f, 0, 1))
		return track.weight > 0.001
	end
	if not frozen then
		track.time += dt * track.speed
		if def.loop then
			if track.time >= track.anim.length then
				track.time %= track.anim.length
				track.markerIndex = 1
				fireMarkers(rig, track, track.time)
			else
				fireMarkers(rig, track, track.time)
			end
		else
			fireMarkers(rig, track, track.time)
			if track.time >= track.anim.length and not def.hold then
				track.stopping = true
				track.stopTimer = 0
				track.stopFrom = track.weight
				endTrack(rig, track)
			end
		end
	end
	if track.fadeIn > 0 then
		track.weight = math.min(1, track.weight + dt / track.fadeIn)
	else
		track.weight = 1
	end
	return true
end

local function applyTrack(pose: PoseN, track: Track)
	if track.weight <= 0 then
		return
	end
	local t = math.min(track.time, track.anim.length)
	local p = sample(track.anim, t)
	for _, j in track.anim.joints do
		local v = p[j]
		if v then
			pose[j] = blendLayer(pose[j] or ZERO6, v, track.weight)
		end
	end
end

local function stepRig(rig: Rig, dt: number, now: number)
	local model = rig.model
	if not model.Parent then
		return
	end
	local frozen = now < rig.freezeUntil
	local pose = basePose(rig, if frozen then 0 else dt)

	local fading = rig.fading
	if fading then
		if stepTrack(rig, fading, dt, frozen) then
			applyTrack(pose, fading)
		else
			rig.fading = nil
		end
	end
	local cur = rig.current
	if cur then
		if stepTrack(rig, cur, dt, frozen) then
			applyTrack(pose, cur)
		else
			rig.current = nil
		end
	end

	for j, motor in rig.motors do
		if motor.Enabled then
			local cf = toCFrame(pose[j] or ZERO6)
			local r = rig.jointRot[j]
			motor.Transform = if r then rig.jointRotInv[j] * cf * r else cf
		end
	end
end

function Animator.start()
	for _, child in workspace:GetChildren() do
		if child:IsA("Model") and child:FindFirstChildOfClass("Humanoid") then
			Animator.register(child)
		end
	end
	workspace.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Model") then
			local model = child :: Model
			task.defer(function()
				if model.Parent and model:FindFirstChildOfClass("Humanoid") then
					Animator.register(model)
				end
			end)
		end
	end)
	RunService:BindToRenderStep("OCAnimator", Enum.RenderPriority.Character.Value, function(dt)
		local now = os.clock()
		for _, rig in rigs do
			if not rig.manual then
				stepRig(rig, math.min(dt, 0.1), now)
			end
		end
	end)
end

-- 선택 화면 미리보기(ViewportFrame) 처럼 workspace 밖의 모델도 직접 돌릴 수 있게
function Animator.stepModel(model: Model, dt: number)
	local rig = rigs[model] or Animator.register(model)
	if rig then
		rig.manual = true
		rig.grounded = true
		stepRig(rig, dt, os.clock())
	end
end

return Animator
