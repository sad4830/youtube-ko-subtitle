--!strict
-- 키프레임 애니메이션 데이터 (에셋 업로드 없이 Motor6D.Transform 으로 재생)
--
-- 관절 이름: Root(몸통), Neck(머리), RS/LS(오른/왼 어깨), RH/LH(오른/왼 엉덩이), W(무기 손잡이)
-- 값: { x, y, z [, px, py, pz] }  — 각도는 도(degree), 위치는 스터드
--   Root : x<0 앞으로 숙임 · y>0 왼쪽으로 몸통 회전 · z>0 왼쪽으로 기울임 · py<0 자세 낮춤
--   Neck : x<0 아래를 봄 · y>0 왼쪽을 봄
--   RS   : x>0 팔을 앞으로 듦 · z>0 바깥(오른쪽)으로 벌림 · (z=90 수평) 에서 y 로 수평 스윙
--   LS   : x>0 팔을 앞으로 듦 · z<0 바깥(왼쪽)으로 벌림
--   RH/LH: x>0 다리를 앞으로 · RH z>0 / LH z<0 바깥으로
--   W    : x>0 무기 끝이 위로 · x=-90 이면 팔과 일직선 · z>0 팔 축 기준 안쪽으로 회전
--
-- 마커: { t = 시각, sound = "사운드 이름", trail = true/false, show = {...}, hide = {...} }

export type JointValue = { number }
export type Pose = { [string]: JointValue }
export type Keyframe = { t: number, pose: Pose, ease: string? }
export type Marker = {
	t: number,
	sound: string?,
	volume: number?,
	pitch: number?,
	trail: boolean?,
	show: { string }?,
	hide: { string }?,
}
export type AnimDef = {
	length: number,
	loop: boolean?,
	hold: boolean?, -- 끝난 뒤 마지막 포즈 유지 (정지 명령이 올 때까지)
	fadeIn: number?,
	fadeOut: number?,
	keyframes: { Keyframe },
	markers: { Marker }?,
	show: { string }?, -- 재생 중에만 보이는 소품
	hide: { string }?, -- 재생 중에만 숨기는 소품
}

local A: { [string]: AnimDef } = {}

-- 함수 인자로 받아서 타입 검사기가 표 리터럴을 AnimDef / Marker 로 해석하게 한다
local function anim(def: AnimDef): AnimDef
	return def
end

local function marks(...: Marker): { Marker }
	return { ... }
end

----------------------------------------------------------------------
-- 기본 자세 (로코모션 레이어에서 사용)
----------------------------------------------------------------------
A.idle_LinYuan = anim({
	length = 2.6,
	loop = true,
	keyframes = {
		{
			t = 0,
			ease = "inout",
			pose = {
				Root = { -4, 12, 0, 0, -0.28, 0 },
				Neck = { 2, -12, 0 },
				RS = { 22, 0, 14 },
				LS = { 62, 0, -6 },
				RH = { -16, 0, 8 },
				LH = { 20, 0, -8 },
			},
		},
		{
			t = 1.3,
			ease = "inout",
			pose = {
				Root = { -2, 10, 0, 0, -0.34, 0 },
				Neck = { 4, -10, 0 },
				RS = { 26, 0, 16 },
				LS = { 66, 0, -4 },
				RH = { -17, 0, 8 },
				LH = { 21, 0, -8 },
			},
		},
		{
			t = 2.6,
			pose = {
				Root = { -4, 12, 0, 0, -0.28, 0 },
				Neck = { 2, -12, 0 },
				RS = { 22, 0, 14 },
				LS = { 62, 0, -6 },
				RH = { -16, 0, 8 },
				LH = { 20, 0, -8 },
			},
		},
	},
})

A.idle_KanzakiRen = anim({
	length = 3.0,
	loop = true,
	keyframes = {
		{
			t = 0,
			ease = "inout",
			pose = {
				Root = { -2, -14, 0, 0, -0.12, 0 },
				Neck = { -5, 12, -3 },
				RS = { 20, 0, 12 },
				LS = { 6, 0, -8 },
				RH = { 12, 0, 6 },
				LH = { -10, 0, -6 },
				W = { -18, 0, 0 },
			},
		},
		{
			t = 1.5,
			ease = "inout",
			pose = {
				Root = { -1, -12, 0, 0, -0.16, 0 },
				Neck = { -3, 14, -2 },
				RS = { 23, 0, 12 },
				LS = { 8, 0, -9 },
				RH = { 12, 0, 6 },
				LH = { -10, 0, -6 },
				W = { -14, 0, 0 },
			},
		},
		{
			t = 3.0,
			pose = {
				Root = { -2, -14, 0, 0, -0.12, 0 },
				Neck = { -5, 12, -3 },
				RS = { 20, 0, 12 },
				LS = { 6, 0, -8 },
				RH = { 12, 0, 6 },
				LH = { -10, 0, -6 },
				W = { -18, 0, 0 },
			},
		},
	},
})

A.idle_Dummy = anim({
	length = 4,
	loop = true,
	keyframes = {
		{ t = 0, ease = "inout", pose = { RS = { 0, 0, 80 }, LS = { 0, 0, -80 }, Root = { 0, 0, 1 } } },
		{ t = 2, ease = "inout", pose = { RS = { 0, 0, 78 }, LS = { 0, 0, -78 }, Root = { 0, 0, -1 } } },
		{ t = 4, pose = { RS = { 0, 0, 80 }, LS = { 0, 0, -80 }, Root = { 0, 0, 1 } } },
	},
})

----------------------------------------------------------------------
-- 공통: 피격 / 막기 / 대시 / 회피
----------------------------------------------------------------------
A.hurt_1 = anim({
	length = 0.42,
	fadeIn = 0.03,
	fadeOut = 0.15,
	keyframes = {
		{
			t = 0,
			ease = "out",
			pose = {
				Root = { 16, 18, -4, 0, -0.1, 0 },
				Neck = { 18, 10, 6 },
				RS = { -15, 0, 30 },
				LS = { 10, 0, -38 },
				RH = { 12, 0, 6 },
				LH = { -14, 0, -4 },
			},
		},
		{ t = 0.42, pose = { Root = { 6, 6, 0 }, Neck = { 6, 4, 0 }, RS = { 0, 0, 12 }, LS = { 5, 0, -12 }, RH = { 4, 0, 2 }, LH = { -4, 0, -2 } } },
	},
})

A.hurt_2 = anim({
	length = 0.42,
	fadeIn = 0.03,
	fadeOut = 0.15,
	keyframes = {
		{
			t = 0,
			ease = "out",
			pose = {
				Root = { 14, -18, 5, 0, -0.1, 0 },
				Neck = { 16, -12, -6 },
				RS = { 10, 0, 36 },
				LS = { -18, 0, -28 },
				RH = { -12, 0, 4 },
				LH = { 12, 0, -6 },
			},
		},
		{ t = 0.42, pose = { Root = { 6, -6, 0 }, Neck = { 6, -4, 0 }, RS = { 5, 0, 12 }, LS = { 0, 0, -12 }, RH = { -4, 0, 2 }, LH = { 4, 0, -2 } } },
	},
})

A.stunned = anim({
	length = 1.2,
	loop = true,
	fadeIn = 0.08,
	keyframes = {
		{ t = 0, ease = "inout", pose = { Root = { 10, 0, 6, 0, -0.2, 0 }, Neck = { -22, 0, 12 }, RS = { -5, 0, 18 }, LS = { -5, 0, -18 }, RH = { 6, 0, 8 }, LH = { -6, 0, -8 } } },
		{ t = 0.6, ease = "inout", pose = { Root = { 12, 0, -6, 0, -0.26, 0 }, Neck = { -24, 0, -12 }, RS = { -2, 0, 20 }, LS = { -2, 0, -20 }, RH = { 6, 0, 8 }, LH = { -6, 0, -8 } } },
		{ t = 1.2, pose = { Root = { 10, 0, 6, 0, -0.2, 0 }, Neck = { -22, 0, 12 }, RS = { -5, 0, 18 }, LS = { -5, 0, -18 }, RH = { 6, 0, 8 }, LH = { -6, 0, -8 } } },
	},
})

A.parried = anim({
	length = 0.9,
	fadeIn = 0.03,
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { 24, 0, 0, 0, 0, 0.3 }, Neck = { 20, 0, 0 }, RS = { 140, 0, 40 }, LS = { 140, 0, -40 }, RH = { 20, 0, 4 }, LH = { -20, 0, -4 } } },
		{ t = 0.9, pose = { Root = { 12, 0, 0 }, Neck = { 6, 0, 0 }, RS = { 40, 0, 30 }, LS = { 40, 0, -30 }, RH = { 6, 0, 4 }, LH = { -6, 0, -4 } } },
	},
	markers = marks( { t = 0, sound = "parry" } ),
})

A.block_LinYuan = anim({
	length = 0.2,
	hold = true,
	fadeIn = 0.06,
	keyframes = {
		{
			t = 0.12,
			ease = "out",
			pose = {
				Root = { -8, 6, 0, 0, -0.4, 0 },
				Neck = { -4, -6, 0 },
				RS = { 82, 0, -34 },
				LS = { 84, 0, 34 },
				RH = { -18, 0, 10 },
				LH = { 18, 0, -10 },
			},
		},
	},
})

A.block_KanzakiRen = anim({
	length = 0.2,
	hold = true,
	fadeIn = 0.06,
	keyframes = {
		{
			t = 0.12,
			ease = "out",
			pose = {
				Root = { -6, -8, 0, 0, -0.3, 0 },
				Neck = { -4, 8, 0 },
				RS = { 84, 0, -12 },
				LS = { 70, 0, 26 },
				RH = { 14, 0, 8 },
				LH = { -14, 0, -8 },
				W = { 0, 0, 92 },
			},
		},
	},
})

A.block_Dummy = anim({
	length = 0.2,
	hold = true,
	keyframes = { { t = 0.1, pose = { RS = { 82, 0, -34 }, LS = { 84, 0, 34 }, Root = { -4, 0, 0 } } } },
})

A.dash_front = anim({
	length = 0.32,
	fadeIn = 0.03,
	fadeOut = 0.12,
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { -32, 0, 0, 0, -0.3, 0 }, Neck = { 22, 0, 0 }, RS = { -55, 0, 16 }, LS = { -55, 0, -16 }, RH = { -38, 0, 0 }, LH = { 42, 0, 0 } } },
		{ t = 0.32, pose = { Root = { -22, 0, 0, 0, -0.2, 0 }, Neck = { 14, 0, 0 }, RS = { -40, 0, 14 }, LS = { -40, 0, -14 }, RH = { -20, 0, 0 }, LH = { 24, 0, 0 } } },
	},
	markers = marks( { t = 0, sound = "dash" } ),
})

-- 린 위안은 앞으로 구른다 (구르기와 낙법)
A.dash_front_LinYuan = anim({
	length = 0.36,
	fadeIn = 0.02,
	fadeOut = 0.1,
	keyframes = {
		{ t = 0, pose = { Root = { 0, 0, 0, 0, -0.6, 0 }, Neck = { -30, 0, 0 }, RS = { 70, 0, 10 }, LS = { 70, 0, -10 }, RH = { 80, 0, 0 }, LH = { 80, 0, 0 } } },
		{ t = 0.18, pose = { Root = { -180, 0, 0, 0, -1.4, 0 }, Neck = { -30, 0, 0 }, RS = { 70, 0, 10 }, LS = { 70, 0, -10 }, RH = { 95, 0, 0 }, LH = { 95, 0, 0 } } },
		{ t = 0.34, ease = "out", pose = { Root = { -355, 0, 0, 0, -0.5, 0 }, Neck = { -10, 0, 0 }, RS = { 30, 0, 14 }, LS = { 30, 0, -14 }, RH = { 20, 0, 0 }, LH = { -10, 0, 0 } } },
	},
	markers = marks( { t = 0, sound = "dash" }, { t = 0.3, sound = "land_heavy", volume = 0.4 } ),
})

A.dash_back = anim({
	length = 0.3,
	fadeIn = 0.03,
	fadeOut = 0.12,
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { 18, 0, 0, 0, -0.2, 0 }, Neck = { -10, 0, 0 }, RS = { 45, 0, 20 }, LS = { 45, 0, -20 }, RH = { 32, 0, 0 }, LH = { -8, 0, 0 } } },
		{ t = 0.3, pose = { Root = { 10, 0, 0 }, Neck = { -4, 0, 0 }, RS = { 25, 0, 15 }, LS = { 25, 0, -15 }, RH = { 15, 0, 0 }, LH = { -4, 0, 0 } } },
	},
	markers = marks( { t = 0, sound = "dash" } ),
})

A.dash_left = anim({
	length = 0.28,
	fadeIn = 0.03,
	fadeOut = 0.12,
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { -6, 12, 24, 0, -0.25, 0 }, Neck = { 0, 0, -16 }, RS = { 10, 0, 55 }, LS = { 10, 0, -18 }, RH = { 0, 0, 34 }, LH = { 0, 0, -8 } } },
		{ t = 0.28, pose = { Root = { -4, 6, 12 }, Neck = { 0, 0, -8 }, RS = { 5, 0, 30 }, LS = { 5, 0, -10 }, RH = { 0, 0, 16 }, LH = { 0, 0, -4 } } },
	},
	markers = marks( { t = 0, sound = "dash" } ),
})

A.dash_right = anim({
	length = 0.28,
	fadeIn = 0.03,
	fadeOut = 0.12,
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { -6, -12, -24, 0, -0.25, 0 }, Neck = { 0, 0, 16 }, RS = { 10, 0, 18 }, LS = { 10, 0, -55 }, RH = { 0, 0, 8 }, LH = { 0, 0, -34 } } },
		{ t = 0.28, pose = { Root = { -4, -6, -12 }, Neck = { 0, 0, 8 }, RS = { 5, 0, 10 }, LS = { 5, 0, -30 }, RH = { 0, 0, 4 }, LH = { 0, 0, -16 } } },
	},
	markers = marks( { t = 0, sound = "dash" } ),
})

A.evasive = anim({
	length = 0.5,
	fadeIn = 0.02,
	fadeOut = 0.12,
	keyframes = {
		{ t = 0, pose = { Root = { 0, 0, 0, 0, 0, 0 }, RS = { 150, 0, 30 }, LS = { 150, 0, -30 }, RH = { 40, 0, 0 }, LH = { 40, 0, 0 } } },
		{ t = 0.22, pose = { Root = { 180, 0, 0, 0, 1.2, 0 }, RS = { 90, 0, 20 }, LS = { 90, 0, -20 }, RH = { 90, 0, 0 }, LH = { 90, 0, 0 } } },
		{ t = 0.46, ease = "out", pose = { Root = { 360, 0, 0, 0, -0.3, 0 }, RS = { 20, 0, 30 }, LS = { 20, 0, -30 }, RH = { 10, 0, 0 }, LH = { -10, 0, 0 } } },
	},
	markers = marks( { t = 0, sound = "evasive" } ),
})

-- 돌진 공격 (앞대시로 상대에게 부딪혔을 때)
A.dashhit_LinYuan = anim({
	length = 0.45,
	fadeIn = 0.02,
	fadeOut = 0.16,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -28, 30, 0, 0, -0.45, 0.2 }, Neck = { 14, -26, 0 }, RS = { -30, 0, 20 }, LS = { 60, 0, -30 }, RH = { -30, 0, 8 }, LH = { 40, 0, -8 } } },
		{ t = 0.07, ease = "out", pose = { Root = { -22, -24, 0, 0, -0.55, -0.6 }, Neck = { 12, 20, 0 }, RS = { 95, 0, -6 }, LS = { -20, 0, -26 }, RH = { -44, 0, 8 }, LH = { 48, 0, -8 } } },
		{ t = 0.45, pose = { Root = { -14, -16, 0, 0, -0.45, -0.3 }, Neck = { 6, 14, 0 }, RS = { 84, 0, -2 }, LS = { -6, 0, -20 }, RH = { -32, 0, 8 }, LH = { 34, 0, -8 } } },
	},
	markers = marks({ t = 0.02, sound = "m1_swing", pitch = 0.7 }),
})

A.dashhit_KanzakiRen = anim({
	length = 0.45,
	fadeIn = 0.02,
	fadeOut = 0.16,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -26, -30, 0, 0, -0.55, 0.2 }, Neck = { 14, 26, 0 }, RS = { 40, 0, -34 }, LS = { 20, 0, -10 }, RH = { 36, 0, 6 }, LH = { -34, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.07, ease = "out", pose = { Root = { -20, 46, 0, 0, -0.55, -0.4 }, Neck = { 10, -36, 0 }, RS = { 0, 118, 86 }, LS = { 0, 0, -40 }, RH = { 40, 0, 6 }, LH = { -42, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.45, pose = { Root = { -12, 30, 0, 0, -0.4, -0.2 }, Neck = { 6, -24, 0 }, RS = { 10, 96, 78 }, LS = { 0, 0, -30 }, RH = { 26, 0, 6 }, LH = { -28, 0, -6 }, W = { -86, 0, 0 } } },
	},
	markers = marks({ t = 0, trail = true, sound = "ren_slash", pitch = 0.9 }, { t = 0.24, trail = false }),
})

----------------------------------------------------------------------
-- 린 위안: M1 (장법 연타)
----------------------------------------------------------------------
A.m1_LinYuan_1 = anim({
	length = 0.34,
	fadeIn = 0.04,
	fadeOut = 0.14,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -4, 28, 0, 0, -0.3, 0 }, Neck = { 0, -24, 0 }, RS = { 18, 0, 14 }, LS = { 30, 0, -24 }, RH = { -15, 0, 8 }, LH = { 16, 0, -8 } } },
		{ t = 0.09, ease = "out", pose = { Root = { -10, -22, 0, 0, -0.34, 0 }, Neck = { 0, 18, 0 }, RS = { 8, 0, 20 }, LS = { 94, 0, 6 }, RH = { -26, 0, 8 }, LH = { 30, 0, -8 } } },
		{ t = 0.34, pose = { Root = { -6, -10, 0, 0, -0.3, 0 }, Neck = { 0, 8, 0 }, RS = { 14, 0, 16 }, LS = { 76, 0, 0 }, RH = { -20, 0, 8 }, LH = { 24, 0, -8 } } },
	},
	markers = marks( { t = 0.02, sound = "m1_swing", pitch = 0.9 } ),
})

A.m1_LinYuan_2 = anim({
	length = 0.34,
	fadeIn = 0.04,
	fadeOut = 0.14,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -4, -26, 0, 0, -0.3, 0 }, Neck = { 0, 22, 0 }, RS = { 30, 0, 26 }, LS = { 50, 0, -10 }, RH = { 16, 0, 8 }, LH = { -15, 0, -8 } } },
		{ t = 0.09, ease = "out", pose = { Root = { -10, 24, 0, 0, -0.34, 0 }, Neck = { 0, -20, 0 }, RS = { 94, 0, -6 }, LS = { 14, 0, -20 }, RH = { 30, 0, 8 }, LH = { -26, 0, -8 } } },
		{ t = 0.34, pose = { Root = { -6, 12, 0, 0, -0.3, 0 }, Neck = { 0, -10, 0 }, RS = { 76, 0, 0 }, LS = { 30, 0, -14 }, RH = { 22, 0, 8 }, LH = { -20, 0, -8 } } },
	},
	markers = marks( { t = 0.02, sound = "m1_swing", pitch = 1.0 } ),
})

A.m1_LinYuan_3 = anim({
	length = 0.36,
	fadeIn = 0.04,
	fadeOut = 0.14,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -2, -34, 0, 0, -0.3, 0 }, Neck = { 0, 28, 0 }, RS = { 0, -30, 88 }, LS = { 40, 0, -20 }, RH = { -10, 0, 12 }, LH = { 12, 0, -12 } } },
		{ t = 0.1, ease = "out", pose = { Root = { -8, 38, 0, 0, -0.36, 0 }, Neck = { 0, -30, 0 }, RS = { 0, 118, 88 }, LS = { 10, 0, -30 }, RH = { 18, 0, 12 }, LH = { -18, 0, -12 } } },
		{ t = 0.36, pose = { Root = { -5, 22, 0, 0, -0.3, 0 }, Neck = { 0, -18, 0 }, RS = { 30, 60, 60 }, LS = { 30, 0, -20 }, RH = { 10, 0, 10 }, LH = { -10, 0, -10 } } },
	},
	markers = marks( { t = 0.02, sound = "m1_swing", pitch = 1.1 } ),
})

A.m1_LinYuan_4 = anim({
	length = 0.5,
	fadeIn = 0.04,
	fadeOut = 0.16,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { 6, 0, 0, 0, -0.3, 0 }, Neck = { -4, 0, 0 }, RS = { -24, 0, 24 }, LS = { -24, 0, -24 }, RH = { -12, 0, 8 }, LH = { 12, 0, -8 } } },
		{ t = 0.13, ease = "out", pose = { Root = { -18, 0, 0, 0, -0.5, -0.4 }, Neck = { 10, 0, 0 }, RS = { 90, 0, -12 }, LS = { 90, 0, 12 }, RH = { -36, 0, 6 }, LH = { 38, 0, -6 } } },
		{ t = 0.5, pose = { Root = { -12, 0, 0, 0, -0.45, -0.2 }, Neck = { 6, 0, 0 }, RS = { 80, 0, -8 }, LS = { 80, 0, 8 }, RH = { -30, 0, 6 }, LH = { 30, 0, -6 } } },
	},
	markers = marks( { t = 0.05, sound = "m1_swing", pitch = 0.8 } ),
})

A.m1up_LinYuan = anim({
	length = 0.5,
	fadeIn = 0.04,
	fadeOut = 0.16,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -14, 0, 0, 0, -0.6, 0 }, Neck = { -6, 0, 0 }, RS = { -30, 0, 16 }, LS = { 30, 0, -18 }, RH = { -20, 0, 6 }, LH = { 24, 0, -6 } } },
		{ t = 0.13, ease = "out", pose = { Root = { 16, 10, 0, 0, 0.2, 0 }, Neck = { 22, 0, 0 }, RS = { 172, 0, 8 }, LS = { -10, 0, -24 }, RH = { 8, 0, 6 }, LH = { -8, 0, -6 } } },
		{ t = 0.5, pose = { Root = { 8, 6, 0 }, Neck = { 10, 0, 0 }, RS = { 150, 0, 10 }, LS = { 0, 0, -20 }, RH = { 4, 0, 4 }, LH = { -4, 0, -4 } } },
	},
	markers = marks( { t = 0.05, sound = "m1_swing", pitch = 0.75 } ),
})

A.m1down_LinYuan = anim({
	length = 0.5,
	fadeIn = 0.04,
	fadeOut = 0.16,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { 14, 0, 0, 0, 0, 0 }, Neck = { 10, 0, 0 }, RS = { 170, 0, 16 }, LS = { 170, 0, -16 }, RH = { 20, 0, 0 }, LH = { -10, 0, 0 } } },
		{ t = 0.13, ease = "out", pose = { Root = { -32, 0, 0, 0, -0.4, 0 }, Neck = { -18, 0, 0 }, RS = { 40, 0, -10 }, LS = { 40, 0, 10 }, RH = { 30, 0, 0 }, LH = { -20, 0, 0 } } },
		{ t = 0.5, pose = { Root = { -20, 0, 0, 0, -0.3, 0 }, Neck = { -10, 0, 0 }, RS = { 30, 0, -6 }, LS = { 30, 0, 6 }, RH = { 20, 0, 0 }, LH = { -12, 0, 0 } } },
	},
	markers = marks( { t = 0.05, sound = "m1_swing", pitch = 0.7 } ),
})

----------------------------------------------------------------------
-- 칸자키 렌: M1 (도검 연속 베기)
----------------------------------------------------------------------
A.m1_KanzakiRen_1 = anim({
	length = 0.32,
	fadeIn = 0.03,
	fadeOut = 0.14,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -4, -36, 0, 0, -0.2, 0 }, Neck = { 0, 30, 0 }, RS = { 0, -40, 86 }, LS = { 10, 0, -20 }, RH = { 10, 0, 6 }, LH = { -10, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.08, ease = "out", pose = { Root = { -8, 40, 0, 0, -0.28, 0 }, Neck = { 0, -32, 0 }, RS = { 0, 118, 86 }, LS = { 20, 0, -30 }, RH = { 18, 0, 6 }, LH = { -18, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.32, pose = { Root = { -5, 26, 0, 0, -0.22, 0 }, Neck = { 0, -20, 0 }, RS = { 20, 90, 70 }, LS = { 14, 0, -20 }, RH = { 12, 0, 6 }, LH = { -12, 0, -6 }, W = { -80, 0, 0 } } },
	},
	markers = marks( { t = 0, trail = true, sound = "ren_slash" }, { t = 0.18, trail = false } ),
})

A.m1_KanzakiRen_2 = anim({
	length = 0.32,
	fadeIn = 0.03,
	fadeOut = 0.14,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -4, 38, 0, 0, -0.22, 0 }, Neck = { 0, -30, 0 }, RS = { 10, 128, 80 }, LS = { 20, 0, -30 }, RH = { 14, 0, 6 }, LH = { -14, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.08, ease = "out", pose = { Root = { -8, -36, 0, 0, -0.28, 0 }, Neck = { 0, 30, 0 }, RS = { 10, -36, 84 }, LS = { 10, 0, -14 }, RH = { 8, 0, 6 }, LH = { -8, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.32, pose = { Root = { -5, -22, 0, 0, -0.22, 0 }, Neck = { 0, 18, 0 }, RS = { 16, -20, 70 }, LS = { 10, 0, -14 }, RH = { 8, 0, 6 }, LH = { -8, 0, -6 }, W = { -80, 0, 0 } } },
	},
	markers = marks( { t = 0, trail = true, sound = "ren_slash", pitch = 1.08 }, { t = 0.18, trail = false } ),
})

A.m1_KanzakiRen_3 = anim({
	length = 0.34,
	fadeIn = 0.03,
	fadeOut = 0.14,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { 8, 20, 0, 0, -0.1, 0 }, Neck = { 6, -16, 0 }, RS = { 165, 0, 34 }, LS = { 30, 0, -20 }, RH = { 4, 0, 6 }, LH = { -4, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.09, ease = "out", pose = { Root = { -18, -22, 0, 0, -0.4, 0 }, Neck = { -8, 18, 0 }, RS = { 24, 0, -34 }, LS = { 10, 0, -20 }, RH = { 22, 0, 6 }, LH = { -22, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.34, pose = { Root = { -10, -14, 0, 0, -0.3, 0 }, Neck = { -4, 12, 0 }, RS = { 20, 0, -10 }, LS = { 10, 0, -14 }, RH = { 14, 0, 6 }, LH = { -14, 0, -6 }, W = { -70, 0, 0 } } },
	},
	markers = marks( { t = 0, trail = true, sound = "ren_slash", pitch = 0.95 }, { t = 0.2, trail = false } ),
})

A.m1_KanzakiRen_4 = anim({
	length = 0.5,
	fadeIn = 0.03,
	fadeOut = 0.16,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { 0, -34, 0, 0, -0.3, 0.3 }, Neck = { 0, 30, 0 }, RS = { -12, 0, 26 }, LS = { 30, 0, -10 }, RH = { -10, 0, 6 }, LH = { 10, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.13, ease = "out", pose = { Root = { -20, 10, 0, 0, -0.55, -0.5 }, Neck = { 12, -8, 0 }, RS = { 92, 0, -4 }, LS = { -20, 0, -30 }, RH = { 44, 0, 4 }, LH = { -42, 0, -4 }, W = { -90, 0, 0 } } },
		{ t = 0.5, pose = { Root = { -14, 6, 0, 0, -0.45, -0.3 }, Neck = { 8, -4, 0 }, RS = { 84, 0, -2 }, LS = { -10, 0, -24 }, RH = { 36, 0, 4 }, LH = { -34, 0, -4 }, W = { -88, 0, 0 } } },
	},
	markers = marks( { t = 0.04, trail = true, sound = "ren_slash", pitch = 0.85 }, { t = 0.26, trail = false } ),
})

A.m1up_KanzakiRen = anim({
	length = 0.5,
	fadeIn = 0.03,
	fadeOut = 0.16,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -16, -10, 0, 0, -0.6, 0 }, Neck = { -4, 8, 0 }, RS = { -24, 0, 22 }, LS = { 10, 0, -20 }, RH = { 20, 0, 6 }, LH = { -20, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.13, ease = "out", pose = { Root = { 14, 8, 0, 0, 0.2, 0 }, Neck = { 22, -4, 0 }, RS = { 176, 0, 6 }, LS = { -10, 0, -30 }, RH = { 6, 0, 6 }, LH = { -6, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.5, pose = { Root = { 8, 4, 0 }, Neck = { 10, 0, 0 }, RS = { 160, 0, 8 }, LS = { 0, 0, -24 }, RH = { 4, 0, 4 }, LH = { -4, 0, -4 }, W = { -90, 0, 0 } } },
	},
	markers = marks( { t = 0.03, trail = true, sound = "ren_slash", pitch = 0.9 }, { t = 0.25, trail = false } ),
})

A.m1down_KanzakiRen = anim({
	length = 0.5,
	fadeIn = 0.03,
	fadeOut = 0.16,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { 12, 0, 0, 0, 0, 0 }, Neck = { 10, 0, 0 }, RS = { 176, 0, 10 }, LS = { 150, 0, -10 }, RH = { 16, 0, 0 }, LH = { -10, 0, 0 }, W = { -90, 0, 0 } } },
		{ t = 0.12, ease = "out", pose = { Root = { -34, 0, 0, 0, -0.45, 0 }, Neck = { -16, 0, 0 }, RS = { 30, 0, -6 }, LS = { 30, 0, 6 }, RH = { 30, 0, 0 }, LH = { -22, 0, 0 }, W = { -90, 0, 0 } } },
		{ t = 0.5, pose = { Root = { -22, 0, 0, 0, -0.3, 0 }, Neck = { -8, 0, 0 }, RS = { 24, 0, -4 }, LS = { 24, 0, 4 }, RH = { 20, 0, 0 }, LH = { -14, 0, 0 }, W = { -80, 0, 0 } } },
	},
	markers = marks( { t = 0.03, trail = true, sound = "ren_slash", pitch = 0.8 }, { t = 0.22, trail = false } ),
})

----------------------------------------------------------------------
-- 린 위안: 기술
----------------------------------------------------------------------
A.lin_goldpalm = anim({
	length = 0.85,
	fadeIn = 0.06,
	fadeOut = 0.18,
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { -2, 40, 0, 0, -0.4, 0 }, Neck = { 0, -34, 0 }, RS = { -40, 0, 22 }, LS = { 72, 0, -6 }, RH = { -20, 0, 10 }, LH = { 24, 0, -10 } } },
		{ t = 0.32, ease = "in", pose = { Root = { 0, 44, 0, 0, -0.46, 0.2 }, Neck = { 0, -38, 0 }, RS = { -48, 0, 24 }, LS = { 76, 0, -4 }, RH = { -22, 0, 10 }, LH = { 26, 0, -10 } } },
		{ t = 0.4, ease = "out", pose = { Root = { -16, -26, 0, 0, -0.58, -0.5 }, Neck = { 6, 22, 0 }, RS = { 94, 0, -4 }, LS = { -24, 0, -22 }, RH = { -42, 0, 8 }, LH = { 46, 0, -8 } } },
		{ t = 0.85, pose = { Root = { -12, -20, 0, 0, -0.5, -0.4 }, Neck = { 4, 18, 0 }, RS = { 88, 0, -2 }, LS = { -10, 0, -18 }, RH = { -36, 0, 8 }, LH = { 38, 0, -8 } } },
	},
	markers = marks( { t = 0, sound = "lin_chi_charge", volume = 0.7 } ),
})

A.lin_redirect_stance = anim({
	length = 0.9,
	fadeIn = 0.05,
	fadeOut = 0.1,
	keyframes = {
		{ t = 0, ease = "inout", pose = { Root = { -4, 0, 0, 0, -0.5, 0 }, Neck = { 0, 0, 0 }, RS = { 60, 0, -18 }, LS = { 92, 0, 18 }, RH = { -10, 0, 24 }, LH = { 10, 0, -24 } } },
		{ t = 0.45, ease = "inout", pose = { Root = { -4, 6, 0, 0, -0.52, 0 }, Neck = { 0, -4, 0 }, RS = { 92, 0, -18 }, LS = { 60, 0, 18 }, RH = { -10, 0, 24 }, LH = { 10, 0, -24 } } },
		{ t = 0.9, pose = { Root = { -4, 0, 0, 0, -0.5, 0 }, Neck = { 0, 0, 0 }, RS = { 60, 0, -18 }, LS = { 92, 0, 18 }, RH = { -10, 0, 24 }, LH = { 10, 0, -24 } } },
	},
})

A.lin_redirect_counter = anim({
	length = 0.7,
	fadeIn = 0.02,
	fadeOut = 0.18,
	keyframes = {
		{ t = 0, pose = { Root = { -6, 0, 0, 0, -0.5, 0 }, RS = { 0, 0, 90 }, LS = { 0, 0, -90 }, RH = { 0, 0, 20 }, LH = { 0, 0, -20 } } },
		{ t = 0.3, ease = "out", pose = { Root = { -6, -360, 0, 0, -0.5, 0 }, RS = { 0, 60, 90 }, LS = { 0, -60, -90 }, RH = { 0, 0, 20 }, LH = { 0, 0, -20 } } },
		{ t = 0.42, ease = "out", pose = { Root = { -16, -380, 0, 0, -0.55, -0.4 }, RS = { 92, 0, -6 }, LS = { 92, 0, 6 }, RH = { -36, 0, 6 }, LH = { 38, 0, -6 } } },
		{ t = 0.7, pose = { Root = { -10, -370, 0, 0, -0.45, -0.2 }, RS = { 80, 0, -4 }, LS = { 80, 0, 4 }, RH = { -28, 0, 6 }, LH = { 30, 0, -6 } } },
	},
	markers = marks( { t = 0, sound = "lin_redirect" } ),
})

A.lin_staffspin = anim({
	length = 1.05,
	fadeIn = 0.05,
	fadeOut = 0.2,
	show = { "StaffHand" },
	hide = { "StaffBack" },
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -6, 30, 0, 0, -0.45, 0 }, Neck = { 0, -20, 0 }, RS = { 10, -20, 88 }, LS = { 20, 0, -40 }, RH = { 0, 0, 22 }, LH = { 0, 0, -22 }, W = { 0, 0, 0 } } },
		{ t = 0.3, pose = { Root = { -6, -330, 0, 0, -0.5, 0 }, Neck = { 0, 0, 0 }, RS = { 10, -20, 88 }, LS = { 20, 0, -60 }, RH = { 0, 0, 22 }, LH = { 0, 0, -22 }, W = { 0, 0, 0 } } },
		{ t = 0.6, pose = { Root = { -6, -690, 0, 0, -0.5, 0 }, Neck = { 0, 0, 0 }, RS = { 10, -20, 88 }, LS = { 20, 0, -60 }, RH = { 0, 0, 22 }, LH = { 0, 0, -22 }, W = { 0, 0, 0 } } },
		{ t = 0.82, ease = "out", pose = { Root = { 10, -1070, 0, 0, -0.2, 0 }, Neck = { 12, 0, 0 }, RS = { 160, 0, 20 }, LS = { 30, 0, -40 }, RH = { 6, 0, 10 }, LH = { -6, 0, -10 }, W = { 20, 0, 0 } } },
		{ t = 1.05, pose = { Root = { 4, -1080, 0, 0, -0.3, 0 }, Neck = { 4, 0, 0 }, RS = { 120, 0, 20 }, LS = { 20, 0, -30 }, RH = { 4, 0, 8 }, LH = { -4, 0, -8 }, W = { 10, 0, 0 } } },
	},
	markers = marks(
		{ t = 0, trail = true, sound = "lin_staff_swing" },
		{ t = 0.3, sound = "lin_staff_swing", pitch = 1.1 },
		{ t = 0.6, sound = "lin_staff_swing", pitch = 1.2 },
		{ t = 0.95, trail = false }
	),
})

local kneadKeys: { Keyframe } = {}
do
	local t = 0
	for i = 1, 12 do
		local right = i % 2 == 0
		local spread = ((i * 37) % 7 - 3) * 4
		table.insert(kneadKeys, {
			t = t,
			ease = "out",
			pose = {
				Root = { -10, if right then 14 else -14, 0, 0, -0.45, -0.2 },
				Neck = { 4, if right then -10 else 10, 0 },
				RS = if right then { 96, 0, -6 + spread } else { 30, 0, 20 },
				LS = if right then { 30, 0, -20 } else { 96, 0, 6 + spread },
				RH = { -30, 0, 10 },
				LH = { 32, 0, -10 },
			},
		})
		t += 0.085
	end
	table.insert(kneadKeys, {
		t = 1.12,
		ease = "in",
		pose = { Root = { 10, 10, 0, 0, -0.2, 0 }, Neck = { 12, 0, 0 }, RS = { 175, 0, 10 }, LS = { 30, 0, -30 }, RH = { 10, 0, 8 }, LH = { -10, 0, -8 }, W = { 0, 0, 0 } },
	})
	table.insert(kneadKeys, {
		t = 1.24,
		ease = "out",
		pose = { Root = { -30, -6, 0, 0, -0.55, -0.3 }, Neck = { -10, 0, 0 }, RS = { 42, 0, -6 }, LS = { 0, 0, -30 }, RH = { -30, 0, 8 }, LH = { 40, 0, -8 }, W = { -70, 0, 0 } },
	})
	table.insert(kneadKeys, {
		t = 1.6,
		pose = { Root = { -20, -4, 0, 0, -0.45, -0.2 }, Neck = { -6, 0, 0 }, RS = { 36, 0, -4 }, LS = { 0, 0, -24 }, RH = { -24, 0, 8 }, LH = { 30, 0, -8 }, W = { -60, 0, 0 } },
	})
end

A.lin_kneading = anim({
	length = 1.6,
	fadeIn = 0.05,
	fadeOut = 0.2,
	keyframes = kneadKeys,
	markers = marks(
		{ t = 1.0, show = { "StaffHand" }, hide = { "StaffBack" } },
		{ t = 1.1, trail = true, sound = "lin_staff_swing", pitch = 0.9 },
		{ t = 1.4, trail = false },
		{ t = 1.58, show = { "StaffBack" }, hide = { "StaffHand" } }
	),
})

-- 각성: 심기체일
A.lin_awaken = anim({
	length = 1.7,
	fadeIn = 0.1,
	fadeOut = 0.3,
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { -10, 0, 0, 0, -0.6, 0 }, Neck = { -20, 0, 0 }, RS = { 72, 0, -36 }, LS = { 72, 0, 36 }, RH = { -14, 0, 14 }, LH = { 14, 0, -14 } } },
		{ t = 0.9, ease = "in", pose = { Root = { -12, 0, 0, 0, -0.66, 0 }, Neck = { -24, 0, 0 }, RS = { 74, 0, -38 }, LS = { 74, 0, 38 }, RH = { -14, 0, 14 }, LH = { 14, 0, -14 } } },
		{ t = 1.15, ease = "out", pose = { Root = { 12, 0, 0, 0, 0.1, 0 }, Neck = { 18, 0, 0 }, RS = { 40, 0, 115 }, LS = { 40, 0, -115 }, RH = { 0, 0, 16 }, LH = { 0, 0, -16 } } },
		{ t = 1.7, pose = { Root = { -2, 8, 0, 0, -0.3, 0 }, Neck = { 2, -8, 0 }, RS = { 26, 0, 16 }, LS = { 64, 0, -6 }, RH = { -16, 0, 8 }, LH = { 20, 0, -8 } } },
	},
	markers = marks( { t = 0, sound = "lin_chi_charge" } ),
})

A.lin_dragonclaw = anim({
	length = 0.7,
	fadeIn = 0.04,
	fadeOut = 0.18,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -4, 34, 0, 0, -0.4, 0 }, Neck = { 0, -30, 0 }, RS = { -34, 0, 20 }, LS = { 60, 0, -10 }, RH = { -18, 0, 10 }, LH = { 22, 0, -10 } } },
		{ t = 0.14, ease = "out", pose = { Root = { -16, -24, 0, 0, -0.55, -0.5 }, Neck = { 6, 20, 0 }, RS = { 94, 0, -4 }, LS = { -20, 0, -22 }, RH = { -40, 0, 8 }, LH = { 44, 0, -8 } } },
		{ t = 0.7, pose = { Root = { -10, -16, 0, 0, -0.45, -0.3 }, Neck = { 4, 14, 0 }, RS = { 86, 0, -2 }, LS = { -6, 0, -18 }, RH = { -32, 0, 8 }, LH = { 34, 0, -8 } } },
	},
	markers = marks( { t = 0.04, sound = "m1_swing", pitch = 0.7 } ),
})

A.lin_dragoncoil = anim({
	length = 1.0,
	loop = true,
	fadeIn = 0.08,
	fadeOut = 0.2,
	keyframes = {
		{ t = 0, ease = "inout", pose = { Root = { -6, 0, 0, 0, -0.45, 0 }, Neck = { -6, 0, 0 }, RS = { 55, 0, -62 }, LS = { 55, 0, 62 }, RH = { -8, 0, 20 }, LH = { 8, 0, -20 } } },
		{ t = 0.5, ease = "inout", pose = { Root = { -8, 0, 0, 0, -0.5, 0 }, Neck = { -8, 0, 0 }, RS = { 58, 0, -64 }, LS = { 58, 0, 64 }, RH = { -8, 0, 20 }, LH = { 8, 0, -20 } } },
		{ t = 1.0, pose = { Root = { -6, 0, 0, 0, -0.45, 0 }, Neck = { -6, 0, 0 }, RS = { 55, 0, -62 }, LS = { 55, 0, 62 }, RH = { -8, 0, 20 }, LH = { 8, 0, -20 } } },
	},
})

A.lin_risingdragon = anim({
	length = 0.9,
	fadeIn = 0.05,
	fadeOut = 0.2,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -22, 0, 0, 0, -0.75, 0 }, Neck = { -10, 0, 0 }, RS = { -26, 0, 18 }, LS = { 40, 0, -20 }, RH = { -24, 0, 8 }, LH = { 30, 0, -8 } } },
		{ t = 0.22, ease = "out", pose = { Root = { 20, 12, 0, 0, 0.35, 0 }, Neck = { 26, 0, 0 }, RS = { 176, 0, 6 }, LS = { -14, 0, -28 }, RH = { 10, 0, 6 }, LH = { -30, 0, -6 } } },
		{ t = 0.9, pose = { Root = { 8, 6, 0 }, Neck = { 12, 0, 0 }, RS = { 150, 0, 10 }, LS = { 0, 0, -20 }, RH = { 4, 0, 4 }, LH = { -8, 0, -4 } } },
	},
	markers = marks( { t = 0.1, sound = "m1_swing", pitch = 0.6 } ),
})

A.lin_goldenreturn = anim({
	length = 2.3,
	fadeIn = 0.1,
	fadeOut = 0.3,
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { -8, 0, 0, 0, -0.6, 0 }, Neck = { -16, 0, 0 }, RS = { 72, 0, -36 }, LS = { 72, 0, 36 }, RH = { -14, 0, 16 }, LH = { 14, 0, -16 } } },
		{ t = 0.8, ease = "inout", pose = { Root = { -4, 0, 0, 0, -0.5, 0 }, Neck = { 0, 0, 0 }, RS = { 10, 0, 100 }, LS = { 10, 0, -100 }, RH = { -10, 0, 20 }, LH = { 10, 0, -20 } } },
		{ t = 1.3, ease = "in", pose = { Root = { 4, 20, 0, 0, -0.5, 0 }, Neck = { 0, -16, 0 }, RS = { -30, 0, 30 }, LS = { -30, 0, -30 }, RH = { -14, 0, 14 }, LH = { 14, 0, -14 } } },
		{ t = 1.45, ease = "out", pose = { Root = { -20, 0, 0, 0, -0.65, -0.5 }, Neck = { 10, 0, 0 }, RS = { 92, 0, -10 }, LS = { 92, 0, 10 }, RH = { -40, 0, 6 }, LH = { 44, 0, -6 } } },
		{ t = 2.3, pose = { Root = { -14, 0, 0, 0, -0.55, -0.3 }, Neck = { 6, 0, 0 }, RS = { 84, 0, -8 }, LS = { 84, 0, 8 }, RH = { -32, 0, 6 }, LH = { 34, 0, -6 } } },
	},
	markers = marks( { t = 0, sound = "lin_chi_charge" } ),
})

-- 탈진 (권능 종료 후)
A.exhausted = anim({
	length = 1.6,
	loop = true,
	fadeIn = 0.2,
	fadeOut = 0.3,
	keyframes = {
		{ t = 0, ease = "inout", pose = { Root = { -22, 0, 0, 0, -0.35, 0 }, Neck = { -10, 0, 0 }, RS = { 20, 0, -10 }, LS = { 20, 0, 10 } } },
		{ t = 0.8, ease = "inout", pose = { Root = { -26, 0, 0, 0, -0.42, 0 }, Neck = { -14, 0, 0 }, RS = { 24, 0, -12 }, LS = { 24, 0, 12 } } },
		{ t = 1.6, pose = { Root = { -22, 0, 0, 0, -0.35, 0 }, Neck = { -10, 0, 0 }, RS = { 20, 0, -10 }, LS = { 20, 0, 10 } } },
	},
})

----------------------------------------------------------------------
-- 칸자키 렌: 기술
----------------------------------------------------------------------
A.ren_peel = anim({
	length = 0.62,
	fadeIn = 0.04,
	fadeOut = 0.18,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -24, -24, 0, 0, -0.6, 0 }, Neck = { 12, 20, 0 }, RS = { 40, 0, -34 }, LS = { 20, 0, -10 }, RH = { 36, 0, 6 }, LH = { -34, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.12, ease = "out", pose = { Root = { -20, 44, 0, 0, -0.55, 0 }, Neck = { 10, -36, 0 }, RS = { 0, 112, 86 }, LS = { 0, 0, -40 }, RH = { 38, 0, 6 }, LH = { -40, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.62, pose = { Root = { -14, 34, 0, 0, -0.45, 0 }, Neck = { 6, -28, 0 }, RS = { 10, 100, 80 }, LS = { 0, 0, -30 }, RH = { 26, 0, 6 }, LH = { -28, 0, -6 }, W = { -86, 0, 0 } } },
	},
	markers = marks( { t = 0, sound = "ren_unsheathe" }, { t = 0.06, trail = true }, { t = 0.3, trail = false } ),
})

A.ren_ashreturn = anim({
	length = 0.55,
	fadeIn = 0.04,
	fadeOut = 0.16,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { 6, 24, 0, 0, -0.2, 0 }, Neck = { 4, -20, 0 }, RS = { 150, 0, 42 }, LS = { 20, 0, -24 }, RH = { 10, 0, 6 }, LH = { -10, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.13, ease = "out", pose = { Root = { -16, -24, 0, 0, -0.4, 0 }, Neck = { -4, 20, 0 }, RS = { 16, 0, -40 }, LS = { 10, 0, -24 }, RH = { 26, 0, 6 }, LH = { -24, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.55, pose = { Root = { -10, -16, 0, 0, -0.3, 0 }, Neck = { -2, 14, 0 }, RS = { 16, 0, -14 }, LS = { 10, 0, -18 }, RH = { 16, 0, 6 }, LH = { -16, 0, -6 }, W = { -70, 0, 0 } } },
	},
	markers = marks( { t = 0.02, trail = true }, { t = 0.24, trail = false } ),
})

A.ren_sideshave = anim({
	length = 0.6,
	fadeIn = 0.04,
	fadeOut = 0.18,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -28, -34, 0, 0, -0.9, 0 }, Neck = { 20, 28, 0 }, RS = { 30, -40, 84 }, LS = { 30, 0, -40 }, RH = { 44, 0, 18 }, LH = { -40, 0, -18 }, W = { -90, 0, 0 } } },
		{ t = 0.12, ease = "out", pose = { Root = { -30, 36, 0, 0, -0.95, 0 }, Neck = { 20, -30, 0 }, RS = { 30, 116, 84 }, LS = { 30, 0, -50 }, RH = { 44, 0, 18 }, LH = { -40, 0, -18 }, W = { -90, 0, 0 } } },
		{ t = 0.6, pose = { Root = { -20, 24, 0, 0, -0.7, 0 }, Neck = { 14, -20, 0 }, RS = { 26, 96, 76 }, LS = { 20, 0, -40 }, RH = { 32, 0, 14 }, LH = { -30, 0, -14 }, W = { -84, 0, 0 } } },
	},
	markers = marks( { t = 0.02, trail = true, sound = "ren_slash", pitch = 0.9 }, { t = 0.26, trail = false } ),
})

A.ren_veil = anim({
	length = 0.7,
	fadeIn = 0.05,
	fadeOut = 0.2,
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { -4, -30, 0, 0, -0.3, 0 }, Neck = { 0, 24, 0 }, RS = { 20, 0, 20 }, LS = { 26, 0, 24 }, RH = { 10, 0, 8 }, LH = { -10, 0, -8 }, W = { -60, 0, 0 } } },
		{ t = 0.2, ease = "out", pose = { Root = { -6, 40, 0, 0, -0.35, 0 }, Neck = { 0, -30, 0 }, RS = { 10, 60, 100 }, LS = { 10, 0, -60 }, RH = { 14, 0, 8 }, LH = { -14, 0, -8 }, W = { -90, 0, 0 } } },
		{ t = 0.7, pose = { Root = { -4, 20, 0, 0, -0.25, 0 }, Neck = { 0, -16, 0 }, RS = { 20, 30, 60 }, LS = { 10, 0, -30 }, RH = { 10, 0, 8 }, LH = { -10, 0, -8 }, W = { -70, 0, 0 } } },
	},
	markers = marks( { t = 0.12, trail = true }, { t = 0.34, trail = false } ),
})

A.ren_chain = anim({
	length = 0.95,
	fadeIn = 0.04,
	fadeOut = 0.2,
	keyframes = {
		{ t = 0, ease = "in", pose = { Root = { -4, -36, 0, 0, -0.25, 0 }, Neck = { 0, 30, 0 }, RS = { 0, -40, 86 }, LS = { 10, 0, -20 }, RH = { 10, 0, 6 }, LH = { -10, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.08, ease = "out", pose = { Root = { -8, 40, 0, 0, -0.3, 0 }, Neck = { 0, -32, 0 }, RS = { 0, 118, 86 }, LS = { 20, 0, -30 }, RH = { 18, 0, 6 }, LH = { -18, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.3, ease = "in", pose = { Root = { -6, 38, 0, 0, -0.3, 0 }, Neck = { 0, -30, 0 }, RS = { 10, 128, 80 }, LS = { 20, 0, -30 }, RH = { 14, 0, 6 }, LH = { -14, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.38, ease = "out", pose = { Root = { -8, -36, 0, 0, -0.3, 0 }, Neck = { 0, 30, 0 }, RS = { 10, -36, 84 }, LS = { 10, 0, -14 }, RH = { 8, 0, 6 }, LH = { -8, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.58, ease = "in", pose = { Root = { 8, 20, 0, 0, -0.1, 0 }, Neck = { 6, -16, 0 }, RS = { 165, 0, 34 }, LS = { 30, 0, -20 }, RH = { 4, 0, 6 }, LH = { -4, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.67, ease = "out", pose = { Root = { -18, -22, 0, 0, -0.45, 0 }, Neck = { -8, 18, 0 }, RS = { 24, 0, -34 }, LS = { 10, 0, -20 }, RH = { 22, 0, 6 }, LH = { -22, 0, -6 }, W = { -90, 0, 0 } } },
		{ t = 0.95, pose = { Root = { -10, -14, 0, 0, -0.3, 0 }, Neck = { -4, 12, 0 }, RS = { 20, 0, -10 }, LS = { 10, 0, -14 }, RH = { 14, 0, 6 }, LH = { -14, 0, -6 }, W = { -70, 0, 0 } } },
	},
	markers = marks( { t = 0, trail = true }, { t = 0.85, trail = false } ),
})

A.ren_severance = anim({
	length = 0.9,
	fadeIn = 0.03,
	fadeOut = 0.2,
	keyframes = {
		{ t = 0, pose = { Root = { -30, 50, 0, 0, -0.6, 0 }, Neck = { 14, -40, 0 }, RS = { 0, 132, 86 }, LS = { -10, 0, -40 }, RH = { 42, 0, 8 }, LH = { -44, 0, -8 }, W = { -90, 0, 0 } } },
		{ t = 0.5, ease = "inout", pose = { Root = { -26, 46, 0, 0, -0.62, 0 }, Neck = { 12, -38, 0 }, RS = { 0, 128, 86 }, LS = { -10, 0, -40 }, RH = { 40, 0, 8 }, LH = { -42, 0, -8 }, W = { -90, 0, 0 } } },
		{ t = 0.62, ease = "out", pose = { Root = { -8, 10, 0, 0, -0.3, 0 }, Neck = { 0, -8, 0 }, RS = { 30, 0, 40 }, LS = { 6, 0, -14 }, RH = { 14, 0, 6 }, LH = { -14, 0, -6 }, W = { -40, 0, 0 } } },
		{ t = 0.9, pose = { Root = { -2, -10, 0, 0, -0.15, 0 }, Neck = { -4, 10, 0 }, RS = { 20, 0, 14 }, LS = { 6, 0, -8 }, RH = { 12, 0, 6 }, LH = { -10, 0, -6 }, W = { -50, 0, 0 } } },
	},
	markers = marks( { t = 0, trail = true }, { t = 0.12, trail = false }, { t = 0.55, sound = "ren_sheathe", volume = 0.6 } ),
})

A.ren_awaken = anim({
	length = 1.5,
	fadeIn = 0.08,
	fadeOut = 0.3,
	show = { "KatanaSheathed" },
	hide = { "KatanaHand" },
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { -12, -30, 0, 0, -0.5, 0 }, Neck = { -18, 26, 0 }, RS = { 36, 0, -42 }, LS = { 24, 0, -8 }, RH = { 30, 0, 8 }, LH = { -26, 0, -8 }, W = { -60, 0, 0 } } },
		{ t = 1.05, pose = { Root = { -14, -32, 0, 0, -0.55, 0 }, Neck = { -20, 28, 0 }, RS = { 38, 0, -44 }, LS = { 26, 0, -8 }, RH = { 32, 0, 8 }, LH = { -28, 0, -8 }, W = { -60, 0, 0 } } },
		{ t = 1.14, ease = "out", pose = { Root = { -10, 36, 0, 0, -0.45, 0 }, Neck = { 6, -24, 0 }, RS = { 0, -30, 96 }, LS = { 10, 0, -24 }, RH = { 28, 0, 8 }, LH = { -28, 0, -8 }, W = { -90, 0, 0 } } },
		{ t = 1.5, pose = { Root = { -4, 10, 0, 0, -0.2, 0 }, Neck = { 0, -6, 0 }, RS = { 20, -10, 60 }, LS = { 6, 0, -10 }, RH = { 14, 0, 6 }, LH = { -12, 0, -6 }, W = { -70, 0, 0 } } },
	},
	markers = marks(
		{ t = 0, sound = "ren_sheathe" },
		{ t = 1.1, show = { "KatanaHand" }, hide = { "KatanaSheathed" }, trail = true, sound = "ren_unsheathe" },
		{ t = 1.35, trail = false }
	),
})

A.ren_maxcharge = anim({
	length = 1.3,
	hold = true,
	fadeIn = 0.1,
	show = { "KatanaSheathed" },
	hide = { "KatanaHand" },
	keyframes = {
		{ t = 0, ease = "out", pose = { Root = { -12, -30, 0, 0, -0.6, 0 }, Neck = { 0, 30, 0 }, RS = { 38, 0, -44 }, LS = { 28, 0, -8 }, RH = { 34, 0, 8 }, LH = { -30, 0, -8 }, W = { -60, 0, 0 } } },
		{ t = 1.3, pose = { Root = { -16, -36, 0, 0, -0.72, 0 }, Neck = { 2, 34, 0 }, RS = { 40, 0, -46 }, LS = { 30, 0, -8 }, RH = { 38, 0, 8 }, LH = { -34, 0, -8 }, W = { -60, 0, 0 } } },
	},
	markers = marks( { t = 0, sound = "ren_sheathe" } ),
})

A.ren_maxrelease = anim({
	length = 1.2,
	fadeIn = 0.02,
	fadeOut = 0.3,
	keyframes = {
		{ t = 0, pose = { Root = { -16, -36, 0, 0, -0.72, 0 }, Neck = { 2, 34, 0 }, RS = { 40, 0, -46 }, LS = { 30, 0, -8 }, RH = { 38, 0, 8 }, LH = { -34, 0, -8 }, W = { -60, 0, 0 } } },
		{ t = 0.07, ease = "out", pose = { Root = { -14, 48, 0, 0, -0.6, -0.6 }, Neck = { 8, -36, 0 }, RS = { 0, -34, 96 }, LS = { 10, 0, -30 }, RH = { 44, 0, 8 }, LH = { -40, 0, -8 }, W = { -90, 0, 0 } } },
		{ t = 0.85, pose = { Root = { -12, 44, 0, 0, -0.58, -0.6 }, Neck = { 6, -34, 0 }, RS = { 0, -30, 94 }, LS = { 10, 0, -30 }, RH = { 42, 0, 8 }, LH = { -38, 0, -8 }, W = { -90, 0, 0 } } },
		{ t = 1.2, ease = "inout", pose = { Root = { -24, 10, 0, 0, -0.4, 0 }, Neck = { -14, -6, 0 }, RS = { 20, 0, 20 }, LS = { 20, 0, -10 }, RH = { 14, 0, 6 }, LH = { -12, 0, -6 }, W = { -60, 0, 0 } } },
	},
	markers = marks(
		{ t = 0, show = { "KatanaHand" }, hide = { "KatanaSheathed" }, trail = true },
		{ t = 0.3, trail = false }
	),
})

return A
