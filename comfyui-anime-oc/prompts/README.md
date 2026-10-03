# Anima 프롬프트 가이드 (자캐 외형 디자인용)

Anima(Aesthetic v1.1 / Turbo v1.1 / Base v1.0)에서 자캐 외형을 안정적으로 뽑기 위한 프롬프트 작성법과 **복사해서 바로 쓰는 템플릿 10종**입니다.
한국어 표현을 영어 태그로 바꾸는 표는 [tag_cheatsheet_ko.md](tag_cheatsheet_ko.md)에 있습니다.

---

## 1. 기본 규칙

| 규칙 | 예 |
|---|---|
| **영어만** 씁니다 (텍스트 인코더 Qwen3-0.6B가 영어 캡션으로 학습됨) | 한국어 → [치트시트](tag_cheatsheet_ko.md)로 변환 |
| 태그는 **소문자 + 띄어쓰기** | `long hair` (O) / `long_hair`, `Long Hair` (X) |
| 밑줄은 **score 태그에만** | `score_7` (Base 전용) |
| 태그와 **자연어 문장을 섞어** 씁니다 | 태그 뒤에 영어 문장 1~2개 |
| 가중치는 **SDXL보다 세게** (공식 예시 `(chibi:2)`) | `(twintails:1.5)` ~ `(chibi:2)` |
| 작가 태그는 **`@` 접두사, 한 명만** | `@fkey` |
| Danbooru와 Gelbooru 표기가 다르면 **Gelbooru 표기 우선** (공식 카드). 두 곳 모두에서 **폐기(deprecated)된 태그는 쓰지 않기** | `light blue hair` → `blue hair`, `brown footwear` → `brown shoes` |

---

## 2. 태그 순서

```text
[품질 / 메타 / 연도 / 안전] → [1girl · 1boy] → [캐릭터] → [작품] → [@작가] → [일반 태그] → 자연어 문장
```

자캐는 기존 캐릭터·작품 태그가 없으니 실제로는 이렇게 됩니다.

```text
masterpiece, best quality, highres, safe, newest, 1girl, solo, @작가(선택), [구도·포즈·표정], [외형 블록], [배경], anime coloring. [자연어 문장 1~2개]
```

---

## 3. 버전별 품질 태그 · 네거티브

| 버전 | 쓰는 곳 | Positive 앞부분 | Negative | 설정 |
|---|---|---|---|---|
| **Aesthetic v1.1** | 01 · 03 · 04 · 05 | 품질 태그는 선택. **score 태그 쓰지 않기** (공식 권장) | 아래 Aesthetic용. **score 태그 쓰지 않기** | 30스텝, CFG 3.5, er_sde/simple |
| **Turbo v1.1** | 02 | 품질 태그 선택. score 태그는 필요 없어 생략 권장 (공식 규칙은 Aesthetic만 해당. 공식 Turbo LoRA 설명: 증류로 네거티브가 내장되어 품질 태그가 크게 필요 없음) | CFG 1이라 **무시됨** (노드 연결용으로만 둠) | 8스텝, CFG 1, euler/simple |
| **Base v1.0** | LoRA 학습 · 05 대체 | `score_7` 포함 | `score_1, score_2, score_3` 포함 | 30~50스텝, CFG 4~5, er_sde/simple |

**Aesthetic v1.1 — Positive 앞부분**
```text
masterpiece, best quality, highres, safe, newest,
```

**Aesthetic v1.1 — Negative (단일 캐릭터 디자인용)**
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, multiple views, watermark, signature, english text, feet out of frame
```

**Turbo v1.1 — Positive 앞부분**
```text
masterpiece, best quality, safe,
```

**Base v1.0 — Positive 앞부분 / Negative**
```text
masterpiece, best quality, score_7, highres, safe, newest,
```
```text
worst quality, low quality, score_1, score_2, score_3, artist name, blurry, jpeg artifacts, chromatic aberration, multiple views, watermark, signature, english text, feet out of frame
```

> 3면도·표정 시트처럼 **여러 시점이 한 장에 들어가는 그림**은 Negative에서 `multiple views`를 빼고, 대신 `2girls, multiple girls`를 넣습니다. Positive에서도 `solo`를 뺍니다.

---

## 4. 외형 블록 만들기

"외형 블록"은 내 캐릭터의 생김새를 정의하는 태그 묶음입니다. **이 블록을 고정해 두고 구도·배경·조명만 바꾸는 것이 OC 일관성의 핵심**입니다.

**순서:** 머리 길이 → 머리색 → 헤어스타일/장식 → 앞머리 → 눈 → 피부/얼굴 → 상의 → 하의 → 다리 → 신발 → 액세서리

**요령**
- 옷마다 **색을 붙이면** 디자인이 안정됩니다: `black jacket`, `blue necktie`, `brown shoes` (NovelAI 공식 캐릭터 제작 튜토리얼과 같은 원리).
- 이너컬러 위치, 리본 위치처럼 태그로 표현하기 어려운 부분은 끝에 **영어 문장**으로 설명합니다.
- 한 번에 한 가지만 바꾸고 seed를 고정해 비교하세요. 화면의 seed는 실행 직후 이미 다음 값으로 바뀌어 있으므로, 마음에 든 PNG를 ComfyUI 빈 화면에 끌어다 놓아 당시 seed를 복원한 뒤 `control_after_generate`(생성 후 제어)를 `fixed`(고정)로 바꾸세요 ([README 8장](../README.md#공통-사용법) 참고).

**예시: 한국어 설명 → 외형 블록**

> 어깨까지 오는 분홍 머리 트윈테일, 일자 앞머리, 보라색 처진 눈, 덧니. 흰 세일러복에 파란 세일러 칼라와 빨간 스카프, 검은 니삭스, 갈색 로퍼, 분홍 머리 리본.

```text
medium hair, pink hair, twintails, pink ribbon, hair ribbon, blunt bangs, purple eyes, tareme, fang, white serafuku, blue sailor collar, red neckerchief, black thighhighs, brown shoes, loafers
```

이 블록을 템플릿 A의 `long hair ~ x hair ornament` 자리에 넣고, 끝의 문장도 내 캐릭터에 맞게 바꾸면 됩니다.

---

## 5. 자연어 문장 섞기

- Anima는 태그와 자연어를 섞어 학습했습니다. 태그 뒤에 **영어 문장 1~2개**를 붙이면 구도·위치·색 배치를 더 잘 따릅니다.
- 자연어만 쓸 때는 **최소 2문장 이상**이 공식 권장입니다 (템플릿 G).
- 텍스트 인코더가 0.6B로 작아서 너무 길고 복잡한 문장은 일부 무시될 수 있습니다. 짧은 문장 여러 개로 나누세요.

좋은 문장 예:
```text
Her long white hair has light blue inner coloring and is tied in a half updo with a small black ribbon.
```

---

## 6. 작가 태그 (그림체)

- 작가 이름 앞에 **`@`** 를 붙입니다: `@fkey`, `@nnn yryr`. `@`가 없으면 효과가 매우 약합니다.
- 위치는 `1girl, solo,` 바로 뒤.
- **한 명만** 쓰세요. 2명 이상 섞으면 특징이 사라집니다.
- 너무 세면 `(@작가명:0.6)`처럼 0.5~0.7로 낮춥니다.
- 작가 화풍 미리보기: animastyles.thetacursed.com
- 그림체 자유도는 Base v1.0이 가장 크고, Aesthetic은 기본 화풍이 강한 편입니다.

---

## 7. 가중치

| 쓰는 법 | 의미 |
|---|---|
| `(tag:1.5)` ~ `(tag:2)` | 권장 범위. 공식 카드: SDXL보다 세게, 예 `(chibi:2)`. ComfyUI는 가중치를 LLM 어댑터 출력에 곱하는 구조입니다 |
| `(tag:1.1)` ~ `(tag:1.3)` | 효과가 약하다는 경험담이 많음 (공식 기준 아님) |
| `(tag:4)` 이상 | 피하기 (그림이 무너지기 쉽다는 경험담, 공식 기준 아님) |
| `(@작가:0.6)` | 낮추기 |
| `\(` `\)` | 이름에 괄호가 들어간 태그는 이스케이프 |

---

## 8. 메타 · 연도 · 안전 태그

| 종류 | 태그 |
|---|---|
| 품질 | `masterpiece`, `best quality` (Base는 `score_7`도) |
| 메타 | `highres`, `absurdres`, `official art` |
| 연도/시기 | `year 2025`, `newest`, `recent` |
| 안전 | `safe`, `sensitive`, `nsfw`, `explicit` |

---

## 9. ComfyUI 문법 주의 (NovelAI에서 넘어온 분)

| NovelAI | ComfyUI (Anima) |
|---|---|
| `{tag}` / `{{tag}}` | 중괄호 1겹마다 x1.05 → `(tag:1.05)` / `(tag:1.1)`. 단 Anima는 약한 가중치가 잘 안 먹으므로 실제로는 `(tag:1.5)`~`(tag:2)` |
| `1.5::tag::` | `(tag:1.5)` |
| `[tag]` | 대괄호 1겹마다 ÷1.05 → `(tag:0.95)` |
| BREAK | 없음 (동작하지 않음) |
| `very aesthetic`, `no text`, `location`, `rating:general` | 빼기 (NovelAI 전용 태그) |

- ComfyUI에서 **`{a|b|c}`는 강조가 아니라 랜덤 선택**입니다. 실행할 때마다 하나가 골라집니다 (02 워크플로에서 활용).
- `very aesthetic`은 **Masterpiece v5.1 LoRA를 켰을 때만** 그 LoRA의 트리거로 맨 앞에 넣습니다.

---

## 10. 템플릿 10종

각 템플릿의 Positive와 Negative를 그대로 복사해 해당 워크플로의 초록(Positive)·빨강(Negative) 노드에 붙여넣으세요. 외형 블록(예시 캐릭터: 흰 머리 + 하늘색 이너컬러, 반묶음, 파란 눈)을 내 캐릭터로 바꾸면 됩니다.

| | 템플릿 | 버전 / 워크플로 | 해상도 |
|---|---|---|---|
| A | 단일 전신 정면 디자인 (기본) | Aesthetic v1.1 · 01 기본값 | 832x1216 |
| B | 같은 디자인을 Base v1.0으로 (score 태그 버전) | Base v1.0 | 832x1216 |
| C | Turbo 랜덤 외형 탐색 | Turbo v1.1 · 02 기본값 | 832x1216 |
| D | 3면도 레퍼런스 시트 | Aesthetic v1.1 · 03 기본값 | 1536x1024 |
| E | 표정 시트 (3x2) | Aesthetic v1.1 · 03에서 프롬프트만 교체 | 1216x832 / 1024x1024 |
| F | 상반신 키 비주얼 (배경 포함) | Aesthetic v1.1 · 01 | 896x1152 / 1216x832 |
| G | 자연어 중심 버전 | 모든 버전 | 832x1216 |
| H | 남성 OC 전신 디자인 | Aesthetic v1.1 · 01 | 832x1216 |
| I | 얼굴 디테일러 프롬프트 | Aesthetic v1.1 · 04 기본값 | (입력 이미지) |
| J | 스케치/선화 채색 (LLLite) | Aesthetic v1.1 + LLLite · 05 기본값 | (입력 비율 ~1MP) |

### A. 단일 전신 정면 디자인 (기본)

버전: `anima-aesthetic-v1.1` (01 워크플로 기본값) · 832x1216 · CFG 3.5 · 30스텝 · er_sde/simple

Positive
```text
masterpiece, best quality, highres, safe, newest, 1girl, solo, full body, standing, straight-on, looking at viewer, arms at sides, light smile, closed mouth, long hair, white hair, colored inner hair, blue hair, half updo, black ribbon, hair between eyes, sidelocks, blue eyes, tsurime, pale skin, petite, mole under eye, white shirt, collared shirt, blue necktie, black jacket, cropped jacket, long sleeves, black skirt, pleated skirt, black thighhighs, zettai ryouiki, brown shoes, loafers, black choker, x hair ornament, white background, simple background, anime coloring. Full-body character design of an original anime girl standing upright and facing the viewer on a plain white background, her whole figure visible from the top of her head to her shoes. Her long white hair has light blue inner coloring and is tied in a half updo with a small black ribbon.
```

Negative
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, multiple views, watermark, signature, english text, feet out of frame
```

- 외형 블록(`long hair` ~ `x hair ornament`)만 내 OC로 바꾸세요. 순서는 머리 길이, 머리색, 헤어스타일, 앞머리, 눈, 피부/얼굴, 상의, 하의, 다리, 신발, 액세서리입니다.
- 그림체를 바꾸려면 `1girl, solo,` 뒤에 `@작가명` 하나만 넣으세요.
- Aesthetic에는 score 태그를 쓰지 않습니다. `very aesthetic`, `no text`, `location` 같은 NovelAI 전용 품질 태그도 넣지 않습니다.
- NovelAI처럼 매끈하고 광택 있는 마감을 원하면 Positive 끝에 다음 문장을 붙여 A/B 테스트해 보세요 (Anima에서 효과는 미검증):
  ```text
  The image is a highly finished digital illustration in anime style with smooth, shiny shading.
  ```

### B. 같은 디자인을 Base v1.0으로 (score 태그 버전)

버전: `anima-base-v1.0` · CFG 4~4.5 · 30~40스텝 · er_sde/simple

Positive
```text
masterpiece, best quality, score_7, highres, safe, newest, 1girl, solo, full body, standing, straight-on, looking at viewer, arms at sides, light smile, closed mouth, long hair, white hair, colored inner hair, blue hair, half updo, black ribbon, hair between eyes, sidelocks, blue eyes, tsurime, pale skin, petite, mole under eye, white shirt, collared shirt, blue necktie, black jacket, cropped jacket, long sleeves, black skirt, pleated skirt, black thighhighs, zettai ryouiki, brown shoes, loafers, black choker, x hair ornament, white background, simple background, anime coloring. Full-body character design of an original anime girl standing upright and facing the viewer on a plain white background. Her long white hair has light blue inner coloring and is tied in a half updo with a small black ribbon.
```

Negative
```text
worst quality, low quality, score_1, score_2, score_3, artist name, blurry, jpeg artifacts, chromatic aberration, multiple views, watermark, signature, english text, feet out of frame
```

- Base는 기본 화풍이 밋밋하므로 `@작가` 태그나 스타일 LoRA와 함께 쓰는 것을 권장합니다. 화풍 자유도는 가장 큽니다.
- score 태그는 밑줄을 그대로 둡니다 (`score_7`). OC LoRA를 학습할 때도 이 모델을 씁니다.

### C. Turbo 랜덤 외형 탐색

버전: `anima-turbo-v1.1` (02 워크플로 기본값) · 8스텝 · CFG 1 · euler/simple

Positive
```text
masterpiece, best quality, safe, 1girl, solo, full body, standing, straight-on, looking at viewer, {long hair|medium hair|short hair}, {white hair|pink hair|black hair|blonde hair|blue hair}, {half updo|twintails|ponytail|hime cut}, {blue eyes|red eyes|purple eyes|yellow eyes}, {school uniform|hoodie|dress|serafuku}, white background, simple background, anime coloring. Full-body character design of an original anime girl standing on a plain white background.
```

Negative (CFG 1에서는 무시되지만 노드 연결을 위해 그대로 둡니다)
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, multiple views, watermark, signature, english text, feet out of frame
```

- `{a|b|c}`는 실행할 때마다 하나를 랜덤으로 고릅니다 (NovelAI의 강조 기호가 아님). 선택지를 내 마음대로 늘리거나 줄여도 됩니다.
- 마음에 드는 조합은 중괄호를 지우고 A 템플릿으로 옮기세요.
- 결과에 AI 느낌이 강하면 `masterpiece, best quality`를 빼 보세요.

### D. 3면도 레퍼런스 시트 (정면/옆/뒤)

버전: `anima-aesthetic-v1.1` (03 워크플로 기본값) · 1536x1024

Positive
```text
masterpiece, best quality, highres, safe, newest, 1girl, reference sheet, character sheet, turnaround, multiple views, full body, standing, straight-on, from side, from behind, arms at sides, long hair, white hair, colored inner hair, blue hair, half updo, black ribbon, hair between eyes, sidelocks, blue eyes, tsurime, pale skin, petite, mole under eye, white shirt, collared shirt, blue necktie, black jacket, cropped jacket, long sleeves, black skirt, pleated skirt, black thighhighs, zettai ryouiki, brown shoes, loafers, black choker, x hair ornament, white background, simple background. A character turnaround sheet of one original anime girl drawn three times side by side on a plain white background: front view on the left, side view in the middle, back view on the right. She keeps the same neutral standing pose, the same hairstyle and exactly the same outfit in every view. Her long white hair has light blue inner coloring and is tied in a half updo with a small black ribbon.
```

Negative
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, signature, english text, 2girls, multiple girls
```

- 시트에서는 `solo`를 쓰지 않고, Negative에 `multiple views`를 넣지 않습니다.
- `front view`, `back view`, `side view`는 Danbooru에 없는(사용되지 않는) 표기이므로 `straight-on`, `from behind`, `from side`를 쓰고, 배치는 자연어 문장으로 지정합니다.
- 레이아웃이 무너지면 Character Sheet for Anima LoRA를 0.6~0.8로 켜세요 (트리거가 이미 프롬프트에 들어 있음).

### E. 표정 시트 (3x2)

버전: `anima-aesthetic-v1.1` (03 워크플로에서 프롬프트만 교체) · 1216x832 또는 1024x1024

Positive
```text
masterpiece, best quality, highres, safe, newest, 1girl, multiple expressions, expression chart, multiple views, portrait, white hair, colored inner hair, blue hair, half updo, black ribbon, hair between eyes, sidelocks, blue eyes, tsurime, mole under eye, collared shirt, blue necktie, black choker, x hair ornament, smile, angry, sad, tears, surprised, open mouth, embarrassed, blush, smug, white background, simple background. An expression sheet of the same anime girl's face, drawn as six head-and-shoulders portraits in a neat 3 by 2 grid on a white background: happy smile, angry frown, sad with tears, surprised with open mouth, embarrassed blush, smug grin.
```

Negative
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, signature, english text, 2girls, multiple girls
```

- 표정이 서로 섞이면 시트 대신 `solo, portrait`에 표정 태그를 하나씩만 넣고, seed를 고정한 채 한 장씩 뽑는 편이 확실합니다.
- 얼굴만 바꾸고 싶다면 04 디테일러나 LLLite inpainting을 쓰세요.

### F. 상반신 키 비주얼 (배경 포함)

버전: `anima-aesthetic-v1.1` · 896x1152(세로) 또는 1216x832(가로) · 01의 하이레즈 그대로 사용

Positive
```text
masterpiece, best quality, highres, absurdres, safe, newest, 1girl, solo, upper body, looking at viewer, light smile, head tilt, long hair, white hair, colored inner hair, blue hair, half updo, black ribbon, hair between eyes, sidelocks, blue eyes, tsurime, pale skin, mole under eye, white shirt, collared shirt, blue necktie, black jacket, cropped jacket, long sleeves, black choker, x hair ornament, outdoors, cherry blossoms, petals, wind, floating hair, sunset, backlighting, depth of field, light particles, official art. A polished key visual of the girl framed from the waist up in the right half of the image, turning slightly toward the viewer. Warm sunset light from behind outlines her hair, pink cherry blossom petals drift across the frame, and the street behind her is softly blurred.
```

Negative
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, signature, english text, multiple views
```

- 외형 블록은 그대로 두고 구도, 배경, 조명만 바꾸는 것이 OC 일관성의 핵심입니다.

### G. 자연어 중심 버전

버전: 모든 버전 (Base는 `best quality` 뒤에 `score_7` 추가)

Positive
```text
masterpiece, best quality, safe, A highly finished digital anime illustration of an original character. She is a petite girl with long white hair that has light blue inner coloring, tied in a half updo with a small black ribbon, sharp upturned blue eyes and a small mole under her left eye. She wears a white collared shirt with a blue necktie under a cropped black jacket, a black pleated skirt, black thighhighs and brown loafers, with a black choker and an X-shaped hairclip. She stands facing the viewer with her arms relaxed at her sides, shown in full body against a plain white background, drawn with clean lineart and soft cel shading.
```

Negative
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, multiple views, watermark, signature, english text
```

- 자연어만 쓸 때는 최소 2문장 이상 쓰는 것이 공식 권장입니다. 위치나 좌우처럼 태그로 표현하기 어려운 정보에 강합니다.
- 텍스트 인코더가 0.6B로 작아서 너무 복잡한 문장은 일부 무시될 수 있습니다.

### H. 남성 OC 전신 디자인

버전: `anima-aesthetic-v1.1` · 832x1216

Positive
```text
masterpiece, best quality, highres, safe, newest, 1boy, solo, male focus, full body, standing, straight-on, looking at viewer, serious, closed mouth, short hair, black hair, messy hair, hair between eyes, red eyes, tsurime, scar on face, single earring, white shirt, red necktie, black coat, open coat, high collar, black gloves, black pants, belt, boots, white background, simple background, anime coloring. Full-body character design of an original young man in a long black coat, standing upright and facing the viewer on a plain white background, his whole figure visible from head to boots.
```

Negative
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, multiple views, watermark, signature, english text, feet out of frame
```

- `1girl` 대신 `1boy`와 `male focus`를 씁니다. 키 큰 체형은 `tall male`, 근육질은 `muscular male`처럼 성별을 붙인 태그를 쓰세요.
- 3면도는 D 템플릿에서 `1girl`을 `1boy`로, She/her를 He/his로 바꾸면 됩니다.

### I. 얼굴 디테일러 프롬프트

버전: `anima-aesthetic-v1.1` (04 워크플로 기본값) · denoise 0.35~0.45

Positive
```text
masterpiece, best quality, highres, safe, 1girl, solo, portrait, looking at viewer, light smile, closed mouth, white hair, colored inner hair, blue hair, hair between eyes, sidelocks, blue eyes, tsurime, pale skin, mole under eye, black choker, x hair ornament, anime coloring
```

Negative
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, signature
```

- 얼굴에 보이는 요소(머리색, 앞머리, 눈색, 눈 모양, 점, 표정, 목/머리 액세서리)만 원본과 똑같이 넣습니다. 옷이나 배경 태그는 빼세요.
- 04의 손 디테일러용 Positive는 워크플로에 따로 들어 있습니다:
  ```text
  masterpiece, best quality, safe, A clean, well-drawn anime hand with five fingers and natural joints.
  ```

### J. 스케치/선화 채색 (LLLite)

버전: `anima-aesthetic-v1.1` + `anima-lllite-any-test-like-v2` (05 워크플로 기본값) · euler/simple · 30스텝 · CFG 4

Positive
```text
masterpiece, best quality, highres, safe, newest, 1girl, solo, full body, standing, looking at viewer, long hair, white hair, colored inner hair, blue hair, half updo, black ribbon, hair between eyes, sidelocks, blue eyes, tsurime, pale skin, petite, mole under eye, white shirt, collared shirt, blue necktie, black jacket, cropped jacket, long sleeves, black skirt, pleated skirt, black thighhighs, zettai ryouiki, brown shoes, loafers, black choker, x hair ornament, white background, simple background, anime coloring. A finished full-color anime illustration of an original girl that follows the pose and outline of the sketch. Her long white hair has light blue inner coloring and is tied in a half updo with a small black ribbon.
```

Negative
```text
worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, signature, english text, monochrome, greyscale, sketch
```

- Negative의 `monochrome, greyscale, sketch`는 선화 느낌이 그대로 남지 않고 컬러로 완성되게 돕습니다.
- 스케치의 포즈와 맞지 않는 태그(`standing` 등)는 상황에 맞게 바꾸세요.

---

## 11. 자주 하는 실수 체크리스트

- [ ] 한국어를 섞어 쓰지 않았나요? (영어만)
- [ ] 폐기된 태그(`light blue hair`, `brown footwear` 등)를 쓰지 않았나요? (`blue hair`, `brown shoes`로)
- [ ] 밑줄을 쓰지 않았나요? (`long_hair` → `long hair`)
- [ ] Aesthetic에 `score_7` 같은 score 태그를 넣지 않았나요? (Turbo에서도 필요 없음)
- [ ] 작가 태그에 `@`를 붙였나요? 작가를 2명 이상 넣지 않았나요?
- [ ] 가중치를 1.1~1.2로 주고 효과가 없다고 하지 않았나요? (1.5~2로 올려 보기)
- [ ] 3면도/표정 시트에 `solo`를 넣거나 Negative에 `multiple views`를 넣지 않았나요?
- [ ] Turbo(CFG 1)에서 Negative로 뭔가를 빼려고 하지 않았나요? (Positive에서 해결)
- [ ] `{a|b}`를 NovelAI식 강조로 쓰지 않았나요? (ComfyUI에서는 랜덤 선택)
- [ ] 외형 블록을 매번 조금씩 다르게 쓰지 않았나요? (복사해서 그대로 재사용)
- [ ] 04 얼굴용 Positive의 얼굴 태그가 01과 똑같나요?
