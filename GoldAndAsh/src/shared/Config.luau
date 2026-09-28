--!strict
-- 게임 전체 밸런스/설정 값. 숫자만 바꿔서 손쉽게 튜닝할 수 있게 한 곳에 모아 두었다.

local Config = {
	GameTitle = "금빛과 재",
	GameSubtitle = "WACA 배틀그라운드",

	RespawnDelay = 4,
	DebugHitboxes = false, -- true 로 바꾸면 서버 판정 상자가 빨갛게 보인다
	MaxBots = 3,

	-- 기본 이동
	JumpPower = 50,
	BlockWalkSpeed = 7,
	AttackWalkSpeed = 6,

	-- M1 (기본 공격)
	M1 = {
		Count = 4,
		Interval = 0.34, -- 다음 타까지 최소 간격
		ComboReset = 1.1, -- 이 시간 동안 안 치면 콤보가 1타로 돌아감
		Endlag = 1.05, -- 4타 뒤 쿨타임
		HitDelay = 0.11, -- 모션 시작 후 판정까지
		Damage = 3.5,
		FinisherDamage = 5,
		Stun = 0.62,
		Range = 5.2, -- 앞쪽 판정 박스 길이
		Width = 5.2,
		FinisherKnockback = 62,
		FinisherRagdoll = 1.15,
	},

	-- 막기
	Block = {
		GuardMax = 100,
		GuardDamageScale = 4, -- 막은 피해량 x4 만큼 가드 감소
		GuardRegenDelay = 1.5,
		GuardRegenPerSec = 30,
		ChipDamage = 0.1, -- 막아도 들어가는 피해 비율
		PerfectWindow = 0.16, -- 막기 누른 직후 이 시간 안에 맞으면 패리
		ParryStun = 1.15,
		GuardBreakStun = 1.6,
		FrontDot = -0.15, -- 이 값보다 정면이면 막기 성공 (뒤는 못 막음)
	},

	-- 대시
	Dash = {
		FrontSpeed = 105,
		FrontTime = 0.3,
		SideSpeed = 82,
		SideTime = 0.26,
		FrontCooldown = 2.2,
		SideCooldown = 1.5,
	},

	-- 회피 (스턴 중 Q)
	Evasive = {
		Max = 100,
		RegenPerSec = 4.5, -- 약 22초에 가득
		IFrames = 0.45,
	},

	-- 각성
	Awakening = {
		Max = 100,
		PerDamageDealt = 1.25,
		PerDamageTaken = 0.45,
		PerKill = 25,
		Duration = 40,
		HealFraction = 0.25,
		DamageBonus = 1.1,
	},

	-- 칸자키 렌 회분
	Ash = {
		Max = 10,
		Lifetime = 15, -- 마지막 획득 후 이 시간이 지나면 회분 전부 소실
		PerM1Hit = 1,
		PerPropCut = 2,
	},

	-- 전투에서 벗어나면 체력 회복
	Regen = {
		Delay = 7,
		PerSec = 2.5,
	},

	-- 지형 파괴 (건물·사물 전부)
	Destruction = {
		RestoreTime = 35, -- 마지막으로 부서진 뒤 이 시간이 지나면 원래대로
		MaxPieces = 4000, -- 맵에 동시에 남아 있을 수 있는 쪼개진 조각 수 (넘으면 오래된 것부터 복구)
		MaxSplitsPerCall = 900, -- 한 번의 파괴에서 쪼개기 횟수 상한
		MaxPartsPerCall = 400, -- 한 번의 파괴에서 부술 파트 수 상한
		MaxDebrisSent = 250, -- 클라이언트에 보내는 잔해 조각 수 상한 (나머지 부피는 먼지로)
		RestorePerTick = 40, -- 0.5초마다 복구하는 파트 수
		BodyCrashSpeed = 42, -- 날아가는 몸이 이 속도 이상이면 부딪힌 건물이 부서진다
	},

	-- 봇
	Bot = {
		ThinkInterval = 0.1,
		ReactionBlockChance = 0.35,
		AggroRange = 160,
	},
}

return Config
