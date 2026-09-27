--!strict
-- 플레이어블 캐릭터 정의 (노션 「WACA // 기밀 인물 도감」 기반)
--  · 린 위안   : WACA-21, 금빛 귀환자. 무예 + 《유전》 《기형》 / 권능 「심기체일 — 용의 전사」
--  · 칸자키 렌 : WACA-4, 애시마크. 《무염재단》 = 《무염박리》 + 《회류반송》 (권능 미각성)
-- 게임용으로 각색한 수치이며, 설정의 핵심(능력의 원리/한계/대가)은 최대한 살렸다.

export type MoveDef = {
	id: string,
	name: string,
	desc: string,
	cooldown: number,
}

export type CharDef = {
	id: string,
	name: string,
	nameEn: string,
	code: string,
	title: string,
	quote: string,
	blurb: string,
	color: Color3,
	accent: Color3,
	dark: Color3,
	maxHealth: number,
	walkSpeed: number,
	stats: { power: number, speed: number, range: number, difficulty: number },
	moves: { MoveDef },
	awakenedMoves: { MoveDef },
	awakening: { name: string, sub: string, desc: string, quote: string },
	music: string,
}

local LinYuan: CharDef = {
	id = "LinYuan",
	name = "린 위안",
	nameEn = "LIN YUAN",
	code = "WACA-21 · 林元",
	title = "금빛 귀환자",
	quote = "“다 같이 돌아가요. 밥 식기 전에.”",
	blurb = "국숫집에서 자란 봉술·장법의 달인. 낮은 무게중심과 몸통 회전으로 버티고, 들어오는 힘을 흘려보낸다.",
	color = Color3.fromRGB(255, 196, 74),
	accent = Color3.fromRGB(255, 232, 160),
	dark = Color3.fromRGB(92, 58, 22),
	maxHealth = 115,
	walkSpeed = 17,
	stats = { power = 4, speed = 2, range = 3, difficulty = 2 },
	moves = {
		{
			id = "GoldenPalm",
			name = "기형 · 금장",
			desc = "영력을 거대한 금빛 손바닥으로 굳혀 앞으로 내지른다. 맞은 적은 멀리 날아간다.",
			cooldown = 8,
		},
		{
			id = "Redirect",
			name = "유전",
			desc = "흐름을 받아내는 자세. 잠깐 사이에 근접 공격이나 투사체가 닿으면 그 힘을 흘려 되돌린다.",
			cooldown = 11,
		},
		{
			id = "StaffSpin",
			name = "봉술 · 회천",
			desc = "목봉을 꺼내 몸통을 회전하며 주변을 세 번 쓸어낸다. 마지막 타격은 적을 띄운다.",
			cooldown = 9,
		},
		{
			id = "Kneading",
			name = "천 번의 반죽",
			desc = "반죽을 밀던 손으로 연타를 퍼붓고, 목봉으로 마무리해 날려 보낸다.",
			cooldown = 14,
		},
	},
	awakenedMoves = {
		{
			id = "DragonClaw",
			name = "용조",
			desc = "주먹을 내지르면 황금 용의 앞발이 같은 방향으로 멀리 뻗는다.",
			cooldown = 6,
		},
		{
			id = "DragonCoil",
			name = "용권선",
			desc = "용이 몸을 휘감아 공격을 받아낸다. 끝날 때 주변을 밀쳐낸다.",
			cooldown = 12,
		},
		{
			id = "RisingDragon",
			name = "승룡",
			desc = "올려 치는 장법과 함께 용이 솟구쳐 적을 하늘로 끌어올린 뒤 내리꽂는다.",
			cooldown = 9,
		},
		{
			id = "GoldenReturn",
			name = "황금 용의 귀환",
			desc = "최대 출력. 20m 용이 원을 그리며 전장을 휩쓴다. 사용 후 권능이 끝나고 탈진한다.",
			cooldown = 0,
		},
	},
	awakening = {
		name = "심기체일",
		sub = "心氣體一 — 용의 전사",
		desc = "몸과 마음, 기가 하나에 이르러 황금 용의 외체를 실체화한다. 끝나면 잠시 영력을 쓸 수 없다.",
		quote = "“이제 알겠어요. 제가 누구인지.”",
	},
	music = "lin_awaken",
}

local KanzakiRen: CharDef = {
	id = "KanzakiRen",
	name = "칸자키 렌",
	nameEn = "KANZAKI REN",
	code = "WACA-4 · 神崎 蓮",
	title = "애시마크 · 회흔",
	quote = "“정리 대상이 남아 있는 동안, 칼은 안 넣어.”",
	blurb = "현장 종결 요원. 칼날이 닿은 비생체 물질을 검은 재로 바꿔 칼집에 모았다가, 직선 참격으로 되쏜다.",
	color = Color3.fromRGB(214, 44, 52),
	accent = Color3.fromRGB(255, 120, 110),
	dark = Color3.fromRGB(22, 20, 24),
	maxHealth = 100,
	walkSpeed = 19,
	stats = { power = 3, speed = 5, range = 4, difficulty = 4 },
	moves = {
		{
			id = "Peel",
			name = "무염박리",
			desc = "앞으로 파고들며 발도해 벤다. 적의 장비와 주변 사물을 베어 회분을 +2 얻는다.",
			cooldown = 7,
		},
		{
			id = "AshReturn",
			name = "회류반송",
			desc = "칼집의 회분(최대 3)을 소모해 직선 참격을 날린다. 많이 쓸수록 멀고 넓다.",
			cooldown = 3.5,
		},
		{
			id = "SideShave",
			name = "측면삭",
			desc = "회분 1을 소모해 지면을 스치는 낮은 참격을 날린다. 맞으면 넘어진다.",
			cooldown = 8,
		},
		{
			id = "AshVeil",
			name = "회막",
			desc = "회분 1을 흩뿌려 검은 분진막을 만든다. 안에 들어온 적의 시야를 가린다.",
			cooldown = 15,
		},
	},
	awakenedMoves = {
		{
			id = "ChainReturn",
			name = "연속 반송",
			desc = "부채꼴로 세 줄기의 회분 참격을 연달아 날린다.",
			cooldown = 7,
		},
		{
			id = "Severance",
			name = "절단선",
			desc = "적을 꿰뚫고 지나간 뒤, 남긴 절단선이 한 박자 늦게 폭발한다.",
			cooldown = 9,
		},
		{
			id = "VeilHunt",
			name = "회막 · 사냥",
			desc = "넓은 분진막을 펼치고 그 안에서 빠르게 움직인다. 분진 속 적의 위치를 짐작한다.",
			cooldown = 14,
		},
		{
			id = "MaxOutput",
			name = "10단위 최대 출력",
			desc = "칼을 넣고 봉인선 열 개를 밝힌 뒤, 거대한 발도 참격을 날린다. 사용 후 잠시 이능 불가.",
			cooldown = 0,
		},
	},
	awakening = {
		name = "무염재단 · 전력 발도",
		sub = "無炎裁斷 — 全力拔刀",
		desc = "칼집의 회분이 가득 차고 흩어지지 않는다. 게임용 각성 모드이며, 설정상 권능은 아직 미각성이다.",
		quote = "“시끄러워. 전부 정리한다.”",
	},
	music = "ren_awaken",
}

local CharacterDefs = {
	LinYuan = LinYuan,
	KanzakiRen = KanzakiRen,
	Order = { "LinYuan", "KanzakiRen" },
}

function CharacterDefs.get(id: string): CharDef?
	if id == "LinYuan" then
		return LinYuan
	elseif id == "KanzakiRen" then
		return KanzakiRen
	end
	return nil
end

function CharacterDefs.moveList(def: CharDef, awakened: boolean): { MoveDef }
	return if awakened then def.awakenedMoves else def.moves
end

return CharacterDefs
