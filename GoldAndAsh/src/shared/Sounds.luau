--!strict
-- 사운드 재생기 (클라이언트용)
--  · SoundIds.sprite 에 업로드한 "사운드 스프라이트" ID가 있으면 그 파일의 구간(PlaybackRegion)을 잘라 재생한다.
--    → 효과음 40여 개를 오디오 1개로 업로드할 수 있다 (업로드 횟수 제한 대응).
--  · ID가 0이면 Roblox 클라이언트에 내장된 소리(rbxasset://)로 대신 재생한다.

local SoundService = game:GetService("SoundService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")

local SoundManifest = require(script.Parent.SoundManifest)
local SoundIds = require(script.Parent.SoundIds)

local Sounds = {}

type Fallback = { id: string, speed: number, volume: number, length: number? }

local JUMP = "rbxasset://sounds/action_jump.mp3"
local LAND = "rbxasset://sounds/action_jump_land.mp3"
local GETUP = "rbxasset://sounds/action_get_up.mp3"
local WATER = "rbxasset://sounds/impact_water.mp3"
local DIE = "rbxasset://sounds/uuhhh.mp3"
local FALL = "rbxasset://sounds/action_falling.mp3"

local FALLBACK: { [string]: Fallback } = {
	m1_swing = { id = JUMP, speed = 1.9, volume = 0.5 },
	m1_hit = { id = LAND, speed = 1.35, volume = 1 },
	m1_hit_heavy = { id = LAND, speed = 0.7, volume = 1.4 },
	block_hit = { id = LAND, speed = 1.7, volume = 0.7 },
	guard_break = { id = LAND, speed = 0.55, volume = 1.5 },
	parry = { id = GETUP, speed = 2.2, volume = 1 },
	dash = { id = JUMP, speed = 1.4, volume = 0.6 },
	evasive = { id = JUMP, speed = 1.2, volume = 0.7 },
	land_heavy = { id = LAND, speed = 0.8, volume = 1 },
	ragdoll_fall = { id = LAND, speed = 1.0, volume = 0.8 },
	ground_crack = { id = LAND, speed = 0.5, volume = 1.4 },
	explosion = { id = LAND, speed = 0.4, volume = 1.6 },
	knockback_whoosh = { id = FALL, speed = 1.6, volume = 0.6, length = 0.5 },
	death = { id = DIE, speed = 1, volume = 0.8 },
	break_prop = { id = LAND, speed = 1.1, volume = 1 },
	lin_chi_charge = { id = FALL, speed = 0.8, volume = 0.5, length = 1.0 },
	lin_palm_impact = { id = LAND, speed = 0.62, volume = 1.4 },
	lin_staff_swing = { id = JUMP, speed = 1.3, volume = 0.6 },
	lin_staff_hit = { id = LAND, speed = 1.6, volume = 1 },
	lin_redirect = { id = FALL, speed = 1.3, volume = 0.6, length = 0.6 },
	lin_dragon_roar = { id = FALL, speed = 0.5, volume = 1, length = 1.6 },
	lin_dragon_whoosh = { id = FALL, speed = 1.0, volume = 0.8, length = 0.9 },
	lin_gong = { id = LAND, speed = 0.35, volume = 1.5 },
	lin_awaken = { id = FALL, speed = 0.6, volume = 1, length = 2.0 },
	ren_unsheathe = { id = GETUP, speed = 1.8, volume = 0.8 },
	ren_sheathe = { id = GETUP, speed = 2.4, volume = 0.8 },
	ren_slash = { id = JUMP, speed = 2.2, volume = 0.6 },
	ren_slash_hit = { id = LAND, speed = 1.5, volume = 1 },
	ren_ash_gain = { id = WATER, speed = 1.8, volume = 0.3 },
	ren_ash_wave = { id = FALL, speed = 1.8, volume = 0.8, length = 0.6 },
	ren_smoke = { id = WATER, speed = 0.55, volume = 0.8 },
	ren_seal_tick = { id = GETUP, speed = 3, volume = 0.6 },
	ren_max_output = { id = LAND, speed = 0.35, volume = 1.8 },
	ren_awaken = { id = FALL, speed = 0.45, volume = 1, length = 2.0 },
}

local function spriteId(): number
	return SoundIds.sprite
end

local function applyEffects(sound: Sound, name: string)
	-- 큰 기술엔 약간의 울림을 준다
	if string.find(name, "max_output") or string.find(name, "awaken") or name == "explosion" or name == "lin_gong" then
		local reverb = Instance.new("ReverbSoundEffect")
		reverb.DecayTime = 1.8
		reverb.WetLevel = -8
		reverb.Parent = sound
	end
end

export type PlayOptions = {
	at: Instance?, -- BasePart 또는 Attachment
	position: Vector3?,
	volume: number?,
	pitch: number?,
	random: number?,
}

local fxFolder: Folder? = nil
local function positionHolder(pos: Vector3): Attachment
	local folder = fxFolder
	if not folder or not folder.Parent then
		local f = Instance.new("Folder")
		f.Name = "SoundHolders"
		f.Parent = workspace
		fxFolder = f
		folder = f
	end
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = pos
	part.Parent = folder
	local att = Instance.new("Attachment")
	att.Parent = part
	Debris:AddItem(part, 6)
	return att
end

function Sounds.play(name: string, opts: PlayOptions): Sound?
	local o = opts
	local sound = Instance.new("Sound")
	sound.Name = name
	local speed = o.pitch or 1
	if o.random then
		speed *= 1 + (math.random() * 2 - 1) * o.random
	end
	local volume = o.volume or 1
	local length: number

	local region = SoundManifest.sprite[name]
	local id = spriteId()
	if id ~= 0 and region then
		sound.SoundId = "rbxassetid://" .. tostring(id)
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(region.start, region.start + region.length)
		sound.Volume = volume
		sound.PlaybackSpeed = speed
		length = region.length
	else
		local fb = FALLBACK[name]
		if not fb then
			sound:Destroy()
			return nil
		end
		sound.SoundId = fb.id
		sound.Volume = volume * fb.volume
		sound.PlaybackSpeed = speed * fb.speed
		if fb.length then
			sound.PlaybackRegionsEnabled = true
			sound.PlaybackRegion = NumberRange.new(0, fb.length)
		end
		length = fb.length or 2
	end

	applyEffects(sound, name)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = 12
	sound.RollOffMaxDistance = 260

	local parent: Instance
	if o.at then
		parent = o.at
	elseif o.position then
		parent = positionHolder(o.position)
	else
		parent = SoundService
	end
	sound.Parent = parent
	sound:Play()
	Debris:AddItem(sound, length / math.max(sound.PlaybackSpeed, 0.05) + 0.5)
	return sound
end

----------------------------------------------------------------------
-- 배경음악
----------------------------------------------------------------------
local musicSound: Sound? = nil
local musicKey: string? = nil
Sounds.MusicVolume = 0.45

local function fadeOutAndDestroy(s: Sound)
	local tw = TweenService:Create(s, TweenInfo.new(1.2), { Volume = 0 })
	tw:Play()
	tw.Completed:Connect(function()
		s:Destroy()
	end)
end

function Sounds.playMusic(key: string?)
	if key == musicKey then
		return
	end
	musicKey = key
	local old = musicSound
	musicSound = nil
	if old then
		fadeOutAndDestroy(old)
	end
	if not key then
		return
	end
	local idKey = "music_" .. key
	local id = (SoundIds :: any)[idKey] :: number?
	if not id or id == 0 then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Music"
	s.SoundId = "rbxassetid://" .. tostring(id)
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	s:Play()
	TweenService:Create(s, TweenInfo.new(1.5), { Volume = Sounds.MusicVolume }):Play()
	musicSound = s
end

function Sounds.setMusicVolume(v: number)
	Sounds.MusicVolume = v
	local s = musicSound
	if s then
		s.Volume = v
	end
end

return Sounds
