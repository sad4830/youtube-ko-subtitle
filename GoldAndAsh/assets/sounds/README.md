# 금빛과 재 (Gold & Ash) — 사운드 에셋

이 폴더의 모든 소리는 `tools/gen_sounds.py` 가 **코드로 합성**한 것입니다 (외부 샘플 없음, 저작권 걱정 없음).
다시 만들려면 프로젝트 루트에서:

```bash
pip install numpy scipy soundfile
python3 tools/gen_sounds.py            # 전부 다시 생성 (항상 같은 결과가 나옵니다)
python3 tools/gen_sounds.py --sfx-only # 효과음만
```

생성하면 `src/shared/SoundManifest.luau` (스프라이트 구간 정보)도 자동으로 갱신됩니다. 손으로 고치지 마세요.

## 로블록스에 올릴 파일 (5개)

미인증 계정은 한 달에 오디오를 약 10개밖에 못 올리므로, 효과음 39개를 **하나의 파일(사운드 스프라이트)** 로 합쳤습니다.

| 파일 | 내용 | 길이 |
|---|---|---|
| `sfx_sprite.ogg` | 효과음 39개를 0.25초 무음 간격으로 이어 붙인 파일 (모노) | 약 39.7초 |
| `music_lobby.ogg` | 로비/캐릭터 선택 — 따뜻한 패드 + 고쟁·고토 + 디즈·샤쿠하치, 80 BPM 24마디 | 72.0초 |
| `music_battle.ogg` | 일반 전투 — 드럼, 베이스, 아르페지오, 리드 (E 단조), 140 BPM 40마디 | 68.571초 |
| `music_lin_awaken.ogg` | 린 위안 각성 — 영웅적인 중국풍 (디즈/얼후, 타이코, 징), 120 BPM 32마디 | 64.0초 |
| `music_ren_awaken.ogg` | 칸자키 렌 각성 — 어둡고 빠른 락/드럼앤베이스 (D 단조, 디스토션 기타), 168 BPM 44마디 | 62.857초 |

음악은 모두 **이음새 없이 반복(loop)** 되도록 정확한 마디 수로 만들었습니다. `Sound.Looped = true` 로 쓰면 됩니다.

`sfx/` 폴더의 개별 효과음 파일은 **미리 듣기/편집용**입니다 (로블록스에 올릴 필요 없음).

## 효과음 목록 (`sfx/<이름>.ogg`, 스프라이트 안에도 같은 이름으로 들어 있음)

**공통**

| 이름 | 설명 | 길이 |
|---|---|---|
| `m1_swing` | 가벼운 공기 휘두름 | 0.25 |
| `m1_hit` | 묵직한 주먹 타격 (저음 쿵 + 딱) | 0.3 |
| `m1_hit_heavy` | 마무리 강타 (깊은 붐 + 크런치 + 짧은 잔향) | 0.6 |
| `block_hit` | 막았을 때 둔탁한 소리 + 가벼운 딸깍 | 0.3 |
| `guard_break` | 가드 깨짐 (파삭 부서짐 + 저음) | 0.7 |
| `parry` | 밝은 금속 "팅" + 반짝이는 여운 | 0.6 |
| `dash` | 대시 바람 + 옷자락 펄럭임 | 0.35 |
| `evasive` | 회피 "빅" (역재생 스웰 + 휙) | 0.5 |
| `land_heavy` | 무거운 착지 + 잔해 소리 | 0.5 |
| `ragdoll_fall` | 몸이 바닥에 떨어지는 소리 | 0.4 |
| `ground_crack` | 바닥 갈라짐 + 우르릉 | 0.9 |
| `explosion` | 큰 폭발 + 긴 우르릉 | 1.4 |
| `knockback_whoosh` | 날아갈 때 긴 바람 | 0.6 |
| `death` | 낮게 떨어지는 음 + 쿵 | 1.0 |
| `ui_hover` | UI 마우스 올림 (작은 틱) | 0.06 |
| `ui_select` | UI 클릭 | 0.12 |
| `ui_confirm` | UI 확인 (두 음 차임) | 0.4 |
| `cooldown_ready` | 쿨다운 완료 (아주 작은 틱) | 0.12 |
| `awaken_ready` | 각성 게이지 가득 참 (올라가는 반짝임) | 0.8 |
| `break_prop` | 나무/콘크리트 소품 부서짐 | 0.6 |

**린 위안**

| 이름 | 설명 | 길이 |
|---|---|---|
| `lin_chi_charge` | 영력(기) 모으기 — 따뜻하게 올라가는 허밍 | 1.2 |
| `lin_palm_impact` | 장타 적중 — 깊은 "훔" + 금빛 반짝임 | 0.7 |
| `lin_staff_swing` | 봉 휘두름 (둥글고 낮은 바람) | 0.3 |
| `lin_staff_hit` | 봉 타격 (단단한 나무 "딱") | 0.3 |
| `lin_redirect` | 흘려보내기/반격 — 소용돌이 바람 + 차임 | 0.6 |
| `lin_dragon_roar` | 황금 용의 포효 | 1.8 |
| `lin_dragon_whoosh` | 용이 지나가는 긴 소용돌이 바람 | 1.0 |
| `lin_gong` | 큰 중국 징 | 2.0 |
| `lin_awaken` | 각성 — 징 + 올라가는 합창 패드 | 2.5 |

**칸자키 렌**

| 이름 | 설명 | 길이 |
|---|---|---|
| `ren_unsheathe` | 발도 "샤-앙" | 0.6 |
| `ren_sheathe` | 납도 "탁" | 0.3 |
| `ren_slash` | 날카로운 칼바람 | 0.3 |
| `ren_slash_hit` | 베기 적중 | 0.35 |
| `ren_ash_gain` | 물체가 검은 재로 부서지며 흡수됨 (지글지글 바스락) | 0.5 |
| `ren_ash_wave` | 재 참격 투사체 (거친 휙) | 0.8 |
| `ren_smoke` | 재 먼지 구름 (펑 + 쉬익) | 1.2 |
| `ren_seal_tick` | 칼집 봉인선 점등 "틱" — **10번 연속, PlaybackSpeed 를 조금씩 올려서** 재생 (예: 1.0, 1.06, 1.12 … 반음씩 `2^(i/12)`) | 0.25 |
| `ren_max_output` | 최대 출력 발도술 — 짧은 정적 뒤 거대한 베기 + 붐 + 긴 여운 (앞 0.1초는 의도된 무음) | 2.0 |
| `ren_awaken` | 각성 — 낮은 디스토션 드론 + 올라가는 금속 긁힘 | 2.5 |

## 로블록스에 올리는 방법 (셋 중 하나)

1. **Studio**: 창(Window) → **에셋 관리자(Asset Manager)** → **대량 가져오기(Bulk Import)** → 위 5개 `.ogg` 선택.
   올라간 오디오를 우클릭 → *Copy Asset ID* 로 ID 복사.
2. **Creator Hub**: https://create.roblox.com → Creations → Development Items → Audio → Import 로 업로드 후 ID 복사.
3. **자동 스크립트**: Open Cloud API 키(Assets API: `asset:read`, `asset:write`)를 만든 뒤
   ```bash
   python3 tools/upload_sounds.py --api-key <키> --user-id <내 유저 ID>
   # 그룹 게임이면 --group-id <그룹 ID>, 자세한 설명은 --help
   ```
   성공하면 `src/shared/SoundIds.luau` 가 자동으로 채워집니다. 이미 ID가 있는 항목은 건너뜁니다.

1·2번으로 올렸다면 받은 숫자 ID를 `src/shared/SoundIds.luau` 에 직접 붙여 넣으세요
(`sprite`, `music_lobby`, `music_battle`, `music_lin_awaken`, `music_ren_awaken`). 0 으로 두면 게임은 내장(fallback) 사운드를 씁니다.
업로드 직후에는 로블록스 검토(moderation) 중이라 잠깐 소리가 안 날 수 있습니다.

## 스프라이트에서 효과음 하나 재생하기 (참고)

```lua
local SoundManifest = require(ReplicatedStorage.Shared.SoundManifest)
local SoundIds = require(ReplicatedStorage.Shared.SoundIds)

local region = SoundManifest.sprite.m1_hit
local s = Instance.new("Sound")
s.SoundId = "rbxassetid://" .. SoundIds.sprite
s.PlaybackRegionsEnabled = true
s.PlaybackRegion = NumberRange.new(region.start, region.start + region.length)
s.Parent = workspace
s:Play()
game:GetService("Debris"):AddItem(s, region.length / s.PlaybackSpeed + 0.2)
```

모든 효과음은 피크 -1 dBFS, 음악은 피크 -3 dBFS 로 맞춰져 있으니 게임 안에서 `Volume` 으로 크기를 조절하세요
(UI 소리는 0.3 정도, 타격음은 0.5~0.8 정도가 적당합니다).
