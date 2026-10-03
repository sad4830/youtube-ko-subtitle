# 한국어 → 영어 태그 치트시트 (Anima용)

자캐 외형을 영어 Danbooru 태그로 바꿀 때 쓰는 표입니다. 프롬프트 작성법은 [README.md](README.md)를 보세요.

**쓰는 법**
- 태그는 **소문자 + 띄어쓰기** 그대로 씁니다 (밑줄 금지, `score_7` 같은 score 태그만 예외).
- 외형 블록 순서: **머리 길이 → 머리색 → 헤어스타일/장식 → 앞머리 → 눈 → 피부/얼굴 → 상의 → 하의 → 다리 → 신발 → 액세서리**
- 옷·소품에는 색을 붙이세요: `black` + `jacket` → `black jacket`, `blue` + `necktie` → `blue necktie`. 머리색·눈색도 같은 방식입니다 (`silver`보다는 표의 `grey hair`처럼 표준 표기 사용).
- 여기 없는 표현은 [ComfyUI-Autocomplete-Plus](https://github.com/newtextdoc1111/ComfyUI-Autocomplete-Plus)(한국어 별칭 검색 지원)로 찾으면 편합니다.
- `front view`, `back view`, `side view`는 Danbooru에 없는(사용되지 않는) 표기입니다. `straight-on`, `from behind`, `from side`를 쓰세요.
- **폐기(deprecated)된 태그는 쓰지 마세요.** Danbooru는 2025년 초에 `light blue hair`(→ `blue hair`, 청록빛이면 `aqua hair`)와 `brown footwear`(→ `brown shoes` / `brown boots`)를 폐기했고, Gelbooru도 두 태그를 폐기(deprecated)로 표시합니다. 하늘색 같은 미묘한 색은 태그는 `blue hair`로 두고 끝의 영어 문장에 `light blue`라고 적으세요.

목차: [1. 기본 표](#1-기본-표) · [2. 템플릿에 쓰인 태그](#2-템플릿에-쓰인-태그) · [3. 추가로 자주 쓰는 태그](#3-추가로-자주-쓰는-태그) · [4. 품질·메타·안전 태그](#4-품질메타안전-태그)

## 1. 기본 표

이 세팅의 템플릿과 워크플로를 기준으로 고른 핵심 태그입니다.

### 머리 길이

| 한국어 | 태그 |
|---|---|
| 짧은 머리 | `short hair` |
| 단발(보브컷) | `bob cut` |
| 중간 길이(어깨) | `medium hair` |
| 긴 머리 | `long hair` |
| 아주 긴 머리 | `very long hair` |

### 헤어스타일

| 한국어 | 태그 |
|---|---|
| 포니테일 | `ponytail` |
| 하이 포니테일 | `high ponytail` |
| 사이드 포니테일 | `side ponytail` |
| 트윈테일(양갈래) | `twintails` |
| 땋은 머리 | `braid` |
| 양 갈래 땋기 | `twin braids` |
| 똥머리(번) | `hair bun` |
| 반묶음 | `half updo` |
| 히메컷 | `hime cut` |
| 웨이브 머리 | `wavy hair` |
| 바보털(아호게) | `ahoge` |

### 앞머리/옆머리

| 한국어 | 태그 |
|---|---|
| 옆머리(사이드록) | `sidelocks` |
| 일자 앞머리 | `blunt bangs` |
| 눈 사이로 내려온 앞머리 | `hair between eyes` |
| 한쪽 눈 가린 머리 | `hair over one eye` |

### 머리색

| 한국어 | 태그 |
|---|---|
| 검은 머리 | `black hair` |
| 갈색 머리 | `brown hair` |
| 금발 | `blonde hair` |
| 은발/회색 머리 | `grey hair` |
| 백발(흰 머리) | `white hair` |
| 분홍 머리 | `pink hair` |
| 빨간 머리 | `red hair` |
| 파란 머리 | `blue hair` |
| 하늘색 머리 | `blue hair` + 문장에 `light blue` (`light blue hair`는 폐기된 태그) |
| 보라 머리 | `purple hair` |
| 투톤 머리 | `two-tone hair` |
| 브릿지(줄무늬 염색) | `streaked hair` |
| 그라데이션 머리 | `gradient hair` |
| 이너컬러 | `colored inner hair` |

### 눈

| 한국어 | 태그 |
|---|---|
| 파란 눈 | `blue eyes` |
| 빨간 눈 | `red eyes` |
| 초록 눈 | `green eyes` |
| 보라 눈 | `purple eyes` |
| 금안/노란 눈 | `yellow eyes` |
| 오드아이 | `heterochromia` |
| 올라간 눈(고양이상) | `tsurime` |
| 처진 눈(강아지상) | `tareme` |
| 반쯤 뜬 눈(게슴츠레) | `jitome` |
| 긴 속눈썹 | `long eyelashes` |

### 얼굴/피부

| 한국어 | 태그 |
|---|---|
| 눈밑 점 | `mole under eye` |
| 하얀 피부 | `pale skin` |
| 태닝 피부 | `tan` |
| 주근깨 | `freckles` |
| 송곳니(덧니) | `fang` |
| 뾰족귀(엘프귀) | `pointy ears` |

### 동물귀/판타지

| 한국어 | 태그 |
|---|---|
| 고양이 귀 | `cat ears` |
| 여우 귀 | `fox ears` |
| 뿔 | `horns` |
| 헤일로(광륜) | `halo` |

### 체형

| 한국어 | 태그 |
|---|---|
| 작은 체구 | `petite` |

### 상의/의상

| 한국어 | 태그 |
|---|---|
| 교복 | `school uniform` |
| 세일러복 | `serafuku` |
| 칼라 셔츠 | `collared shirt` |
| 넥타이 | `necktie` |
| 목 리본 | `neck ribbon` |
| 후드티 | `hoodie` |
| 가디건 | `cardigan` |
| 크롭 재킷 | `cropped jacket` |
| 원피스(드레스) | `dress` |
| 기모노 | `kimono` |
| 한복 | `hanbok` |
| 분리 소매 | `detached sleeves` |

### 하의/다리

| 한국어 | 태그 |
|---|---|
| 플리츠 스커트 | `pleated skirt` |
| 니삭스(허벅지 양말) | `thighhighs` |
| 절대영역 | `zettai ryouiki` |
| 팬티스타킹 | `pantyhose` |

### 신발

| 한국어 | 태그 |
|---|---|
| 로퍼 | `loafers` |
| 갈색 구두 | `brown shoes` (`brown footwear`는 폐기된 태그) |

### 액세서리

| 한국어 | 태그 |
|---|---|
| 머리띠 | `hairband` |
| 헤어핀 | `hairclip` |
| X자 헤어핀 | `x hair ornament` |
| 머리 리본 | `hair ribbon` |
| 머리 나비리본 | `hair bow` |
| 안경 | `glasses` |
| 동그란 안경 | `round eyewear` |
| 초커 | `choker` |

### 구도/카메라

| 한국어 | 태그 |
|---|---|
| 전신 | `full body` |
| 상반신 | `upper body` |
| 초상화(얼굴 위주) | `portrait` |
| 정면 | `straight-on` |
| 옆모습 | `from side` |
| 뒷모습 | `from behind` |
| 카메라 응시 | `looking at viewer` |

### 포즈/표정

| 한국어 | 태그 |
|---|---|
| 차렷 자세 | `arms at sides` |
| 옅은 미소 | `light smile` |

### OC 시트

| 한국어 | 태그 |
|---|---|
| 설정화(레퍼런스 시트) | `reference sheet` |
| 캐릭터 시트(Gelbooru식 태그, reference sheet와 함께) | `character sheet` |
| 턴어라운드(회전 시트) | `turnaround` |
| 여러 시점 | `multiple views` |
| 표정 모음 | `multiple expressions` |
| 표정 차트 | `expression chart` |
| 컬러 가이드(색 견본) | `color guide` |

### 배경

| 한국어 | 태그 |
|---|---|
| 흰 배경 | `white background` |
| 단색 배경 | `simple background` |

### 화풍

| 한국어 | 태그 |
|---|---|
| 애니 채색 | `anime coloring` |
| 플랫 컬러 | `flat color` |

## 2. 템플릿에 쓰인 태그

[템플릿 A~J](README.md#10-템플릿-10종)에 들어 있는 태그 중 위 표에 없는 것입니다. `/`로 나눈 것은 따로따로 쓰는 태그입니다.

| 한국어 | 태그 | 분류 |
|---|---|---|
| 이너컬러 머리색 지정 (이너컬러 + 색) | `colored inner hair, blue hair` | 머리색 |
| 검은 리본 (머리 장식) | `black ribbon` | 액세서리 |
| 부스스한 머리 | `messy hair` | 헤어스타일 |
| 얼굴 흉터 | `scar on face` | 얼굴/피부 |
| 한쪽 귀걸이 | `single earring` | 액세서리 |
| 남자 1명 | `1boy` | 인원 |
| 여자 1명 | `1girl` | 인원 |
| 혼자(1인 그림) | `solo` | 인원 |
| 남성 중심 구도 | `male focus` | 인원 |
| 키 큰 남성 / 근육질 남성 | `tall male` / `muscular male` | 체형 |
| 흰 셔츠 | `white shirt` | 상의/의상 |
| 파란 넥타이 | `blue necktie` | 상의/의상 |
| 검은 재킷 | `black jacket` | 상의/의상 |
| 긴 소매 | `long sleeves` | 상의/의상 |
| 검은 코트 / 앞이 열린 코트 | `black coat` / `open coat` | 상의/의상 |
| 높은 옷깃 | `high collar` | 상의/의상 |
| 검은 장갑 | `black gloves` | 액세서리 |
| 검은 바지 | `black pants` | 하의/다리 |
| 벨트 | `belt` | 액세서리 |
| 부츠 | `boots` | 신발 |
| 검은 스커트 | `black skirt` | 하의/다리 |
| 검은 니삭스 | `black thighhighs` | 하의/다리 |
| 갈색 신발 | `brown shoes` | 신발 |
| 검은 초커 | `black choker` | 액세서리 |
| 서 있음 | `standing` | 포즈/표정 |
| 입 다문 | `closed mouth` | 포즈/표정 |
| 진지한 표정 | `serious` | 포즈/표정 |
| 고개 갸웃 | `head tilt` | 포즈/표정 |
| 웃음 / 화남 / 슬픔 / 눈물 | `smile` / `angry` / `sad` / `tears` | 포즈/표정 |
| 놀람 / 벌린 입 | `surprised` / `open mouth` | 포즈/표정 |
| 부끄러움 / 홍조 / 의기양양 | `embarrassed` / `blush` / `smug` | 포즈/표정 |
| 야외 | `outdoors` | 배경 |
| 벚꽃 / 꽃잎 | `cherry blossoms` / `petals` | 배경 |
| 바람 / 날리는 머리 | `wind` / `floating hair` | 배경 |
| 노을 | `sunset` | 배경 |
| 역광 | `backlighting` | 배경 |
| 피사계 심도(배경 흐림) | `depth of field` | 배경 |
| 빛 입자 | `light particles` | 배경 |

## 3. 추가로 자주 쓰는 태그

자캐 디자인에 자주 쓰는 일반 Danbooru 태그입니다. 결과가 기대와 다르면 가중치를 `(tag:1.5)`까지 올리거나 자동완성으로 표기를 확인하세요.

### 머리 길이/스타일

| 한국어 | 태그 |
|---|---|
| 엄청 긴 머리 | `absurdly long hair` |
| 짧은 트윈테일 | `short twintails` |
| 낮게 묶은 트윈테일 | `low twintails` |
| 옆으로 땋은 머리 | `side braid` |
| 양쪽 똥머리 | `double bun` |
| 드릴 머리(세로 롤) | `drill hair` |
| 생머리 | `straight hair` |
| 옆으로 넘긴 앞머리 | `swept bangs` |
| 가르마 앞머리 | `parted bangs` |
| 비대칭 앞머리 | `asymmetrical bangs` |

### 머리색

| 한국어 | 태그 |
|---|---|
| 초록 머리 | `green hair` |
| 주황 머리 | `orange hair` |
| 청록(아쿠아) 머리 | `aqua hair` |
| 여러 색 머리 | `multicolored hair` |

### 눈

| 한국어 | 태그 |
|---|---|
| 갈색 눈 | `brown eyes` |
| 회색 눈 | `grey eyes` |
| 분홍 눈 | `pink eyes` |
| 주황 눈 | `orange eyes` |
| 청록 눈 | `aqua eyes` |
| 세로 동공(고양이 눈동자) | `slit pupils` |
| 빛나는 눈 | `glowing eyes` |
| 반쯤 감은 눈 | `half-closed eyes` |

### 얼굴/피부

| 한국어 | 태그 |
|---|---|
| 짙은 피부 | `dark skin` |
| 입가 점 | `mole under mouth` |
| 뾰족한 이빨 | `sharp teeth` |

### 동물귀/판타지

| 한국어 | 태그 |
|---|---|
| 동물 귀(일반) | `animal ears` |
| 늑대 귀 | `wolf ears` |
| 토끼 귀 | `rabbit ears` |
| 꼬리 | `tail` |
| 날개 | `wings` |
| 천사 날개 | `angel wings` |
| 악마 뿔 | `demon horns` |

### 상의/의상

| 한국어 | 태그 |
|---|---|
| 세일러 칼라 | `sailor collar` |
| 스카프(세일러복) | `neckerchief` |
| 나비넥타이 | `bowtie` |
| 스웨터 | `sweater` |
| 터틀넥 | `turtleneck` |
| 트레이닝 재킷 | `track jacket` |
| 메이드복 | `maid` |
| 차이나 드레스 | `china dress` |
| 군복 | `military uniform` |
| 정장 | `suit` |
| 후드 쓴 | `hood up` |
| 망토 | `cape` |

### 하의/다리

| 한국어 | 태그 |
|---|---|
| 반바지 | `shorts` |
| 미니스커트 | `miniskirt` |
| 롱스커트 | `long skirt` |
| 무릎 양말 | `kneehighs` |

### 신발

| 한국어 | 태그 |
|---|---|
| 운동화 | `sneakers` |
| 메리제인 구두 | `mary janes` |
| 하이힐 | `high heels` |
| 무릎 부츠 | `knee boots` |

### 액세서리

| 한국어 | 태그 |
|---|---|
| 귀걸이 | `earrings` |
| 목걸이 | `necklace` |
| 헤드폰 | `headphones` |
| 베레모 | `beret` |
| 마녀 모자 | `witch hat` |
| 머리 꽃 장식 | `hair flower` |
| 손가락 없는 장갑 | `fingerless gloves` |
| 안대 | `eyepatch` |

### 포즈/표정

| 한국어 | 태그 |
|---|---|
| 팔짱 | `crossed arms` |
| 뒷짐 | `arms behind back` |
| 손 흔들기 | `waving` |
| 뒤돌아보기 | `looking back` |
| 앉아 있음 | `sitting` |
| 이를 드러낸 웃음 | `grin` |
| 뾰로통 | `pout` |
| 무표정 | `expressionless` |
| 눈 감음 | `closed eyes` |
| 윙크 | `one eye closed` |

### 구도/카메라

| 한국어 | 태그 |
|---|---|
| 허벅지 위까지(카우보이 샷) | `cowboy shot` |
| 클로즈업 | `close-up` |
| 위에서 내려다봄 | `from above` |
| 아래에서 올려다봄 | `from below` |
| 기울어진 구도 | `dutch angle` |

### 배경

| 한국어 | 태그 |
|---|---|
| 실내 | `indoors` |
| 밤 | `night` |
| 별이 빛나는 하늘 | `starry sky` |
| 교실 | `classroom` |
| 도시 | `city` |

## 4. 품질·메타·안전 태그

| 종류 | 태그 | 메모 |
|---|---|---|
| 품질 | `masterpiece`, `best quality` | Aesthetic에서는 선택 |
| score (Base 전용) | `score_7` (Positive) / `score_1, score_2, score_3` (Negative) | **Aesthetic에는 쓰지 않기**(공식 권장). Turbo에서도 필요 없어 생략 권장. 밑줄 유지 |
| 메타 | `highres`, `absurdres`, `official art` | |
| 연도/시기 | `year 2025`, `newest`, `recent` | |
| 안전 | `safe`, `sensitive`, `nsfw`, `explicit` | 디자인용은 `safe` |
| 작가 | `@작가명` (예: `@fkey`) | 한 명만, 너무 세면 `(@작가명:0.6)` |
| Negative 기본 | `worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, signature` | 단일 그림이면 `multiple views` 추가, 시트면 `2girls, multiple girls` 추가 |

## 예시: 한국어 설명을 태그로

> 허리까지 오는 검은 생머리, 일자 앞머리, 빨간 고양이상 눈, 하얀 피부, 눈밑 점. 검은 세일러복에 빨간 스카프, 검은 팬티스타킹, 로퍼, 머리에 빨간 리본.

```text
very long hair, black hair, straight hair, red ribbon, hair ribbon, blunt bangs, red eyes, tsurime, pale skin, mole under eye, black serafuku, red neckerchief, black pantyhose, loafers
```
