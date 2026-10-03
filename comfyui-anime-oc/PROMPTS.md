# 자캐 외형 프롬프트 가이드

프롬프트는 **영어**로 씁니다. 태그는 Danbooru 스타일(소문자, 밑줄 대신 띄어쓰기)이 기본입니다.

---

## 1. 외형 체크리스트 (먼저 이걸 채우세요)

| 항목 | 예시 태그 |
|---|---|
| 성별·인원 | `1girl`, `1boy`, `solo` |
| 분위기·나이대 | `mature female`, `young`, `petite`, `tall` |
| 머리 길이 | `short hair`, `medium hair`, `long hair`, `very long hair` |
| 머리 색 | `silver hair`, `black hair`, `pink hair`, `two-tone hair`, `gradient hair`, `blue inner hair`(속머리 염색), `streaked hair`(브릿지) |
| 머리 모양 | `ponytail`, `twintails`, `side ponytail`, `hair bun`, `braid`, `bob cut`, `hime cut`, `wavy hair`, `messy hair` |
| 앞머리 | `blunt bangs`(일자), `swept bangs`, `hair between eyes`, `hair over one eye` |
| 포인트 | `ahoge`(바보털), `sidelocks`, `hair ornament`, `hairclip`, `hair ribbon` |
| 눈 | `blue eyes`, `red eyes`, `heterochromia`(오드아이), `tsurime`(올라간 눈), `tareme`(처진 눈), `half-closed eyes`, `slit pupils` |
| 얼굴 특징 | `mole under eye`(눈물점), `fang`(송곳니), `freckles`, `scar on face` |
| 종족 요소 | `animal ears`, `cat ears`, `fox ears`, `fox tail`, `horns`, `pointy ears`(엘프), `wings`, `halo` |
| 상의 | `white shirt`, `hoodie`, `sailor collar`, `blazer`, `oversized jacket`, `cropped jacket`, `turtleneck` |
| 하의 | `pleated skirt`, `shorts`, `jeans`, `long skirt`, `pantyhose`, `thighhighs` |
| 신발 | `sneakers`, `boots`, `loafers`, `mary janes` |
| 액세서리 | `choker`, `earrings`, `glasses`, `headphones around neck`, `gloves`, `scarf` |
| 표정 | `smile`, `light smile`, `expressionless`, `pout`, `smug`, `open mouth`, `one eye closed` |
| 포즈·구도 | `full body`, `upper body`, `cowboy shot`(허벅지까지), `portrait`, `standing`, `sitting`, `looking at viewer`, `hand on hip`, `peace sign` |
| 배경 | `simple background`, `white background`, `gradient background`, `outdoors`, `night`, `cityscape` |

> **팁**: 자캐 디자인 단계에서는 `simple background, white background`로 배경을 비워 두면 외형이 가장 잘 보입니다.

---

## 2. Anima용 템플릿 (워크플로우 ①②)

**구조**: `[퀄리티/메타/세이프티] [인원] [외형 태그] [포즈/배경]` + **빈 줄** + **자연어 설명 2문장 이상**

Anima는 태그만 써도 되지만, 자연어를 붙이면 "누가 무엇을 입고 있는지"를 훨씬 정확히 이해합니다.

### A. 전신 캐릭터 디자인 (기본)
```
masterpiece, best quality, very aesthetic, newest, highres, safe,
1girl, solo, original, full body, standing, looking at viewer, light smile,
{머리 길이}, {머리 색}, {머리 모양}, {앞머리}, {눈 색}, {특징},
{상의}, {하의}, {신발}, {액세서리},
simple background, white background,

An original anime character design. {캐릭터 한 줄 설명}. {의상 설명}. Clean lineart, soft cel shading, bright vivid colors.
```

### B. 바스트업 프로필 (얼굴 위주)
```
masterpiece, best quality, very aesthetic, newest, highres, safe,
1girl, solo, original, upper body, portrait, looking at viewer, smile,
{외형 태그 그대로},
gradient background,

A close-up profile illustration of an original anime girl. {얼굴·머리 묘사}. Detailed eyes with soft highlights, delicate lineart.
```
해상도: `1024×1024` 추천

### C. 캐릭터 시트 (앞·옆·뒤 설정화)
```
masterpiece, best quality, newest, highres, safe,
1girl, solo, original, character sheet, reference sheet, multiple views, full body, front view, side view, back view, standing,
{외형 태그 그대로},
simple background, white background,

A character reference sheet of the same original anime girl shown from the front, the side and the back. {외형 묘사}. Consistent outfit and colors in every view.
```
해상도: **`1216×832`** (가로) — 워크플로우의 `해상도 / 장수` 노드에서 바꾸세요.

### D. 예시 — 남캐
```
masterpiece, best quality, very aesthetic, newest, highres, safe,
1boy, solo, original, cowboy shot, standing, looking at viewer, smirk,
short hair, black hair, red streaked hair, hair between eyes, red eyes, tsurime, earrings,
black leather jacket, open jacket, white t-shirt, dog tags, black pants, fingerless gloves,
simple background, grey background,

An original anime character design of a confident young man with short black hair and a red streak, wearing an open black leather jacket over a white t-shirt. Sharp lineart, cel shading, cool color palette.
```

### E. 예시 — 판타지(수인)
```
masterpiece, best quality, very aesthetic, newest, highres, safe,
1girl, solo, original, full body, standing, looking at viewer, smile,
long hair, white hair, fox ears, fox tail, fluffy tail, golden eyes, slit pupils, hair ornament, tassel,
white kimono, red hakama, wide sleeves, geta, holding paper fan,
simple background, white background,

An original anime character design of a fox girl shrine maiden with long white hair, fluffy fox ears and a large fluffy tail. She wears a white kimono with a red hakama and holds a folding paper fan.
```

### Anima 부정 프롬프트 (Aesthetic용 기본값)
```
worst quality, low quality, blurry, jpeg artifacts, chromatic aberration, artist name, signature, watermark, text, bad anatomy, bad hands, extra fingers, missing fingers, nsfw, explicit
```

### Anima 문법 메모
- **Aesthetic 버전엔 `score_*` 태그 금지** (공식 권장). Base 버전을 쓸 때만 `score_7` 등을 씁니다.
- 연도/시기 태그: `newest`, `recent`, `year 2025` 등 → 최신 그림체 쪽으로
- 가중치는 크게: `(fluffy tail:1.6)`, `(chibi:2)`
- 화풍 지정은 `@작가명` 형식 (앞에 `@` 필수)
- Turbo(워크플로우 ①)에선 퀄리티 태그를 빼고 `anime coloring`을 넣으면 덜 번들거립니다.

---

## 3. WAI-Illustrious용 템플릿 (워크플로우 ③)

**구조**: `[인원] [외형 태그] [포즈/배경]` → 마지막에 `[LoRA 트리거] [퀄리티 태그]`
WAI는 **짧고 정확한 태그**가 가장 좋습니다. 자연어 문장은 넣지 않는 걸 권장합니다.

```
1girl, solo, original, full body, standing, looking at viewer, smile,
{외형 태그},
simple background, white background,
Jeddtl02,
masterpiece, best quality, amazing quality, very aesthetic
```

### WAI 부정 프롬프트
```
bad quality, worst quality, worst detail, sketch, censor, bad hands, extra fingers, watermark, signature, text, nsfw, explicit
```

- 퀄리티 태그나 네거티브를 길게 늘이면 오히려 흐려집니다 (제작자 안내).
- 나이대가 너무 어리게 나오면 맨 앞에 `(mature female:1.2)` 또는 `(aged up:1.2)`를 넣으세요.

---

## 4. 같은 캐릭터로 계속 뽑는 법 (일관성)

1. **외형 블록 고정** — 머리·눈·의상 태그를 한 덩어리로 정해두고, 매번 **복사해서 그대로** 씁니다. 순서도 바꾸지 않는 게 좋습니다.
2. **바꾸는 건 포즈/표정/배경 블록만** — 예: `full body, standing` → `upper body, sitting, waving`
3. **시드 고정 후 미세 조정** — 1차 KSampler의 `control after generate`를 `fixed`로 두고 태그 1~2개씩만 바꾸면 비교가 쉽습니다.
4. **헷갈리는 색은 부위를 명시** — `white jacket, black skirt` 처럼 색+부위를 붙여 씁니다. Anima는 자연어로 "wearing a white jacket over a black skirt"까지 쓰면 색 번짐이 줄어듭니다.
5. **장기 사용** — 마음에 드는 결과 20~40장(여러 각도·표정)을 모아 캐릭터 LoRA를 학습하면 트리거 한 단어로 불러올 수 있습니다. (README의 "캐릭터 LoRA" 참고)
