--!strict
-- 한국어 / 영어 문자열 표.
-- 서버는 문자열 대신 "키 + 인자"를 보내고, 각 클라이언트가 자기 언어로 바꿔 보여 준다.
-- 인자 값은 문자열/숫자이거나 { ko = ..., en = ... } 표(캐릭터 이름처럼 언어마다 다른 값)일 수 있다.
-- 표에 없는 키는 그대로 보여 준다.

export type Lang = "ko" | "en"
export type Text = string | { ko: string, en: string }

local Locale = {}
Locale.lang = "ko" :: Lang

local changed = Instance.new("BindableEvent")
Locale.Changed = changed.Event

local S: { [string]: { ko: string, en: string } } = {
	-- 제목
	["game.title"] = { ko = "금빛과 재", en = "GOLD & ASH" },
	["game.subtitle"] = { ko = "WACA 배틀그라운드", en = "WACA BATTLEGROUNDS" },
	["lang.toggle"] = { ko = "🌐 English", en = "🌐 한국어" },

	-- 선택 화면
	["select.sub"] = { ko = "내 아바타로 싸울 캐릭터(기술)를 고르세요", en = "Pick a moveset to fight with your own avatar" },
	["select.close"] = { ko = "✕  닫기", en = "✕  Close" },
	["select.pick"] = { ko = "이 캐릭터로 싸운다", en = "FIGHT AS THIS CHARACTER" },
	["select.loading"] = { ko = "불러오는 중...", en = "Loading..." },
	["select.using"] = { ko = "사용 중 ✓", en = "In use ✓" },
	["select.timeout"] = {
		ko = "서버 응답이 없어요 — 다시 눌러 주세요 (화면 아래 빨간 글씨가 있으면 캡처해 주세요)",
		en = "No response from the server — press again (screenshot any red text at the bottom)",
	},
	["select.hint"] = {
		ko = "노션 「WACA // 기밀 인물 도감」의 두 요원 · 혼자라면 선택 후 왼쪽 위에서 봇을 소환하세요",
		en = "Two agents from the WACA classified files · Playing solo? Spawn bots from the top-left menu",
	},
	["stat.power"] = { ko = "파워", en = "Power" },
	["stat.speed"] = { ko = "속도", en = "Speed" },
	["stat.range"] = { ko = "사거리", en = "Range" },
	["stat.difficulty"] = { ko = "난이도", en = "Difficulty" },

	-- HUD
	["hud.ash"] = { ko = "회분", en = "Ash" },
	["hud.awaken_pct"] = { ko = "각성 {n}%", en = "Awakening {n}%" },
	["hud.awaken_ready"] = { ko = "각성 가능! [G]", en = "AWAKEN READY! [G]" },
	["hud.awakened"] = { ko = "{name} 중", en = "{name} — ACTIVE" },
	["hud.evasive"] = { ko = "회피 [Q]", en = "Evasive [Q]" },
	["hud.guard"] = { ko = "가드 [F]", en = "Guard [F]" },
	["hud.dash_front"] = { ko = "앞 대시", en = "F-Dash" },
	["hud.dash_side"] = { ko = "옆 대시", en = "S-Dash" },
	["hud.tip"] = { ko = "스턴 중 Q = 회피", en = "Q while stunned = Evasive" },
	["hud.change"] = { ko = "캐릭터 변경", en = "Change Character" },
	["hud.bot"] = { ko = "봇 소환 · {char}", en = "Spawn Bot · {char}" },
	["hud.clear_bots"] = { ko = "봇 모두 제거", en = "Clear Bots" },
	["hud.help"] = { ko = "조작법 [H]", en = "Controls [H]" },
	["hud.exhausted"] = { ko = "탈진", en = "DRAINED" },
	["death.title"] = { ko = "쓰러졌다", en = "YOU FELL" },
	["death.sub"] = { ko = "잠시 후 다시 일어섭니다", en = "Getting back up shortly..." },
	["mobile.attack"] = { ko = "공격", en = "Attack" },
	["mobile.block"] = { ko = "막기", en = "Block" },
	["mobile.dash"] = { ko = "대시", en = "Dash" },
	["mobile.awaken"] = { ko = "각성", en = "Awaken" },
	["error.header"] = { ko = "⚠ 오류 (이 부분을 캡처해서 보내 주세요)", en = "⚠ Error (please screenshot this and send it)" },
	["error.client"] = { ko = "클라이언트: ", en = "Client: " },
	["error.server"] = { ko = "서버: ", en = "Server: " },

	-- 조작법
	["help.title"] = { ko = "조작법", en = "Controls" },
	["help.close"] = { ko = "닫기", en = "Close" },
	["help.1"] = { ko = "좌클릭 (누르고 있기)  ·  M1 연타 (4타)", en = "Left click (hold)  ·  M1 combo (4 hits)" },
	["help.2"] = { ko = "4타에서 Space 누른 채  ·  띄우기 / 공중 4타  ·  내려찍기", en = "Hold Space on hit 4  ·  Uppercut / in air  ·  Downslam" },
	["help.3"] = { ko = "F (누르고 있기)  ·  막기  —  맞기 직전에 누르면 패리", en = "F (hold)  ·  Block  —  press right before a hit to Parry" },
	["help.4"] = { ko = "Q + 방향키  ·  대시 (앞/뒤/좌/우)", en = "Q + direction  ·  Dash (front/back/side)" },
	["help.5"] = { ko = "앞 대시로 적에게 파고들면  ·  대시 타격", en = "Front-dash into an enemy  ·  Dash Strike" },
	["help.6"] = { ko = "스턴 중 Q  ·  회피 (회피 게이지 가득일 때)", en = "Q while stunned  ·  Evasive (when the meter is full)" },
	["help.7"] = { ko = "1 ~ 4  ·  기술", en = "1 ~ 4  ·  Skills" },
	["help.8"] = { ko = "G  ·  각성 (각성 게이지 100%)", en = "G  ·  Awaken (meter at 100%)" },
	["help.9"] = { ko = "Shift  ·  시점 고정 (Shift Lock)", en = "Shift  ·  Shift Lock" },
	["help.10"] = { ko = "H  ·  이 창 열기/닫기", en = "H  ·  Open/close this window" },
	["help.11"] = { ko = "칸자키 렌: 칼로 적/소품을 베면 회분이 쌓인다", en = "Kanzaki Ren: cutting enemies/props builds Ash" },
	["help.12"] = { ko = "린 위안: 2번 《유전》으로 공격·투사체를 되돌린다", en = "Lin Yuan: skill 2 (Flow Reversal) turns attacks back" },

	-- 서버 알림
	["n.evasive_low"] = { ko = "회피 게이지가 부족하다", en = "Evasive meter isn't full" },
	["n.awaken_low"] = { ko = "각성 게이지가 아직 부족하다", en = "Awakening meter isn't full yet" },
	["n.skills_locked"] = { ko = "지금은 이능을 쓸 수 없다", en = "Abilities are locked right now" },
	["n.combat_lock"] = { ko = "전투 중에는 캐릭터를 바꿀 수 없다 ({n}초)", en = "Can't switch characters mid-fight ({n}s)" },
	["n.respawn_as"] = { ko = "{char}(으)로 부활합니다", en = "Respawning as {char}" },
	["n.streak"] = { ko = "{player} — {n}연속 처치!", en = "{player} — {n} KO STREAK!" },
	["n.awaken_ready"] = { ko = "각성 준비 완료 — [G]", en = "Awakening ready — [G]" },
	["n.guard_break"] = { ko = "가드 브레이크!", en = "GUARD BREAK!" },
	["n.parry"] = { ko = "패리!", en = "PARRY!" },
	["n.ash_scatter"] = { ko = "회분이 흩어졌다", en = "Your Ash scattered" },
	["n.ash_low"] = { ko = "회분이 부족하다 — 칼로 적이나 주변 물건을 베어 모아라", en = "Not enough Ash — cut enemies or nearby objects" },
	["n.ash_none"] = { ko = "회분이 없다 — 칼로 적이나 주변 물건을 베어 모아라", en = "No Ash — cut enemies or nearby objects" },
	["n.lung_damage"] = { ko = "폐포 손상 — 4초 동안 이능 사용 불가", en = "Lung damage — abilities locked for 4s" },
	["n.awaken_end"] = { ko = "각성 종료", en = "Awakening ended" },
	["n.exhausted"] = { ko = "탈진 — {n}초 동안 영력을 쓸 수 없다", en = "Exhausted — no spirit energy for {n}s" },
	["n.bot_limit"] = { ko = "봇은 최대 {n}명까지 소환할 수 있다", en = "You can spawn up to {n} bots" },
	["n.server_error"] = {
		ko = "서버 오류가 났어요 — 화면 아래 빨간 글씨를 캡처해 주세요",
		en = "Server error — please screenshot the red text at the bottom",
	},

	-- 이름표 / 킬 피드
	["plate.bot"] = { ko = "[봇] {char}", en = "[Bot] {char}" },
	["plate.dummy"] = { ko = "훈련용 허수아비", en = "Training Dummy" },
	["plate.dummy_block"] = { ko = "훈련용 허수아비 (막기)", en = "Training Dummy (Block)" },
	["feed.bot"] = { ko = "봇", en = "Bot" },
	["feed.dummy"] = { ko = "허수아비", en = "Dummy" },
	["feed.env"] = { ko = "환경", en = "Environment" },
}

-- 값 하나를 현재 언어로 (문자열은 그대로)
function Locale.pick(v: any, lang: string?): string
	local l: string = lang or Locale.lang
	if typeof(v) == "table" then
		return tostring(v[l] or v.ko or v.en or "")
	end
	return tostring(v)
end

function Locale.t(key: string, args: { [string]: any }?, lang: string?): string
	local l: string = lang or Locale.lang
	local entry = S[key]
	local text = if entry then (if l == "en" then entry.en else entry.ko) else key
	if args then
		text = string.gsub(text, "{(%w+)}", function(name: string): string
			local v = args[name]
			if v == nil then
				return "{" .. name .. "}"
			end
			return Locale.pick(v, l)
		end)
	end
	return text
end

-- 두 언어 버전을 한꺼번에 ({ ko, en }) — 서버가 이름표처럼 모두에게 보이는 글자를 만들 때
function Locale.both(key: string, args: { [string]: any }?): { ko: string, en: string }
	return { ko = Locale.t(key, args, "ko"), en = Locale.t(key, args, "en") }
end

function Locale.has(key: string): boolean
	return S[key] ~= nil
end

function Locale.set(lang: Lang)
	if lang == Locale.lang then
		return
	end
	Locale.lang = lang
	changed:Fire(lang)
end

function Locale.toggle()
	Locale.set(if Locale.lang == "ko" then "en" else "ko")
end

-- 로블록스 언어 설정이 한국어면 한국어, 아니면 영어로 시작
function Locale.detect(): Lang
	local id = ""
	pcall(function()
		id = game:GetService("LocalizationService").RobloxLocaleId
	end)
	if id == "" then
		local lp = game:GetService("Players").LocalPlayer
		if lp then
			id = lp.LocaleId
		end
	end
	return if string.sub(string.lower(id), 1, 2) == "ko" then "ko" else "en"
end

return Locale
