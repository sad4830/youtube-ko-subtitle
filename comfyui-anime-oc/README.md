# ComfyUI 자캐(OC) 고퀄 애니 캐릭터 세팅

NovelAI 수준의 애니 캐릭터 외관을 **로컬 ComfyUI**로 뽑기 위한 모델·LoRA·워크플로우 세트입니다.
(2026년 10월 기준으로 조사·선정)

```
comfyui-anime-oc/
├── README.md                ← 지금 이 문서 (설치·설정)
├── PROMPTS.md               ← 자캐 외형 프롬프트 작성법 + 템플릿
├── download_models.py       ← 모델/LoRA 자동 다운로드
└── workflows/
    ├── 1_anima_turbo_draft.json            ← 빠른 시안 (4장씩)
    ├── 2_anima_hq_character.json           ← 메인 고퀄
    └── 3_wai_illustrious_hq_character.json ← 서브 고퀄 (SDXL)
```

---

## 1. 무엇을 골랐고 왜

| 역할 | 모델 | 이유 |
|---|---|---|
| **메인** | **Anima Aesthetic v1.1** (CircleStone Labs × Comfy Org, 2B DiT) | NovelAI 4.5/5와 같은 **DiT + LLM 텍스트 인코더** 구조. 긴 묘사를 이해하고 구도·조명·분위기가 SDXL보다 한 단계 위. 태그와 자연어를 섞어 쓸 수 있음. 2025년 9월까지 애니 데이터로 학습 |
| 시안용 | **Anima Turbo v1.1** | CFG 1, 10스텝 증류 모델. 4장 뽑는 데 몇 초~수십 초라 외형 아이디어 탐색에 적합 |
| **서브** | **WAI-Illustrious-SDXL v17** | Civitai 다운로드 150만+의 대표 애니 체크포인트. **태그를 정확히 따르고, 구도가 바뀌어도 얼굴·체형이 잘 유지**됨. LoRA·ControlNet 생태계가 가장 큼 |

**왜 두 개인가?** 2026년 커뮤니티 비교 결과를 요약하면 이렇습니다.
- **Anima**: 분위기 있는 한 장짜리 일러스트, 역동적인 포즈, 배경 깊이감, 2~3인 장면에서 강함. 대신 구도를 바꾸면 의상 색이나 얼굴 인상이 조금씩 흔들림
- **WAI-Illustrious**: 의상·헤어 태그 재현이 정확하고 같은 캐릭터를 여러 장 뽑을 때 안정적. 배경은 평평한 셀 셰이딩 느낌

→ **자캐 외형을 "디자인"할 때는 Anima**, **확정된 외형을 여러 포즈로 "반복 생산"할 때는 WAI**를 쓰는 걸 권장합니다.

### LoRA

| 대상 | LoRA | 강도 | 트리거 | 효과 |
|---|---|---|---|---|
| Anima | Aesthetic Quality Modifiers – Masterpiece v5.1 [anima-base-1] | 0.5 | `very aesthetic` | 수작 그림 386장으로 학습한 미감 향상 |
| Anima | Anima RL v0.1 (공식) | 0.6 | 없음 | 강화학습 기반 디테일·미감 향상 |
| SDXL | Aesthetic Quality Modifiers – Masterpiece v3 [illustrious] | 0.6 | `masterpiece, best quality, very aesthetic` (프롬프트 끝) | 미감 향상 |
| SDXL | Detailer IL v2 | 0.5 | `Jeddtl02` | 디테일 강화 |

### 후처리 (NovelAI 느낌의 핵심)
- **하이레스 픽스**: R-ESRGAN 4x+ Anime6B로 키운 뒤 1.5배 크기에서 디노이즈 0.35~0.4로 다시 그림
- **얼굴 디테일러**: YOLOv8 얼굴 감지 → 얼굴만 크게 잘라 다시 그림 (눈·속눈썹·하이라이트가 또렷해짐)

### 솔직한 기대치
- 단일 캐릭터 일러스트는 NovelAI V4.5와 **동급 또는 근접**한 결과를 기대할 수 있습니다.
- NovelAI V5의 최신 캐릭터 지식(2026년 여름까지)이나 글자 렌더링은 따라가지 못합니다. 자캐는 기존 캐릭터 지식이 필요 없으니 크게 문제되지 않습니다.

---

## 2. 필요 사양

- **GPU**: NVIDIA VRAM 8GB 이상 (12GB 이상 권장)
- **디스크**: 전체 세트 약 18GB (Anima만 약 10GB)
- **ComfyUI**: 최신 버전. Anima는 2026년 초부터 기본 지원되므로 오래된 버전이면 꼭 업데이트하세요.

---

## 3. 설치 순서

### ① ComfyUI 업데이트
- 포터블: `update/update_comfyui.bat` 실행
- Desktop 앱: 앱 내 업데이트
- 매니저가 있다면: Manager → **Update ComfyUI**

### ② 커스텀 노드 설치 (얼굴 디테일러용)
ComfyUI Manager → **Custom Nodes Manager**에서 아래 두 개를 검색해 설치하고 재시작합니다.
- `ComfyUI Impact Pack`
- `ComfyUI Impact Subpack`

> 워크플로우를 먼저 불러온 뒤 Manager → **Install Missing Custom Nodes**를 눌러도 됩니다.
> 워크플로우 ①(Turbo 시안)은 기본 노드만 써서 커스텀 노드 없이도 동작합니다.

### ③ 모델 다운로드

**자동 (권장)** — 이 폴더에서 실행:

```bash
# Windows 포터블 예시 (ComfyUI에 포함된 파이썬 사용)
C:\ComfyUI_windows_portable\python_embeded\python.exe download_models.py --comfy "C:\ComfyUI_windows_portable\ComfyUI"

# 일반 설치 / macOS / Linux
python download_models.py --comfy ~/ComfyUI

# Anima만 받기 / Turbo 빼기
python download_models.py --comfy ~/ComfyUI --set anima --no-turbo
```

- `--comfy`에는 `models` 폴더가 들어있는 ComfyUI 폴더를 지정합니다. (Desktop 앱은 설치 시 고른 폴더, 보통 `문서\ComfyUI`)
- 중간에 끊겨도 다시 실행하면 **이어받기**하고, 받은 파일은 SHA256으로 검증합니다.
- Civitai 파일이 `401/403`으로 실패하면 Civitai API 키를 넣으세요:
  `--civitai-token 키` (발급: Civitai → 프로필 → Settings → API Keys)

**수동** — 아래 링크에서 받아 `ComfyUI/models/` 아래 해당 폴더에 넣습니다.

| 파일 | 폴더 | 링크 |
|---|---|---|
| anima-aesthetic-v1.1.safetensors | `diffusion_models` | [HF](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-aesthetic-v1.1.safetensors) |
| anima-turbo-v1.1.safetensors | `diffusion_models` | [HF](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-turbo-v1.1.safetensors) |
| qwen_3_06b_base.safetensors | `text_encoders` | [HF](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors) |
| qwen_image_vae.safetensors | `vae` | [HF](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors) |
| anima-rl-v0.1.safetensors | `loras` | [HF](https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main/anima-rl-v0.1.safetensors) |
| anima-base-1-masterpiece-v51.safetensors | `loras` | [Civitai](https://civitai.com/models/929497?modelVersionId=2961717) |
| waiIllustriousSDXL_v170.safetensors | `checkpoints` | [Civitai](https://civitai.com/models/827184?modelVersionId=2883731) |
| illustrious_masterpieces_v3.safetensors | `loras` | [Civitai](https://civitai.com/models/929497?modelVersionId=2247497) |
| DetailerILv2-000008.safetensors | `loras` | [Civitai](https://civitai.com/models/1231943?modelVersionId=1736373) |
| RealESRGAN_x4plus_anime_6B.pth | `upscale_models` | [GitHub](https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth) |
| face_yolov8m.pt | `ultralytics/bbox` | [HF](https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt) |

> 파일명이 위와 다르면 워크플로우에서 빨간 테두리가 뜹니다. 그럴 땐 해당 노드에서 파일을 다시 선택하면 됩니다.

### ④ 워크플로우 불러오기
ComfyUI 재시작 → `workflows/` 폴더의 JSON 파일을 ComfyUI 화면에 **드래그 앤 드롭**.
각 워크플로우 왼쪽에 한국어 **사용법 메모**가 들어 있습니다.

---

## 4. 추천 작업 순서 (자캐 외형 만들기)

1. **컨셉 정리** — [PROMPTS.md](PROMPTS.md)의 체크리스트로 머리·눈·의상·특징을 영어 태그로 정리
2. **시안 탐색** — `1_anima_turbo_draft`로 4장씩 여러 번 생성하며 프롬프트를 다듬기
3. **고퀄 마무리** — 확정된 프롬프트를 `2_anima_hq_character`에 붙여넣고 생성
   - 마음에 드는 그림이 나오면 **1차 생성 KSampler**의 `control after generate`를 `fixed`로 → 시드 고정
   - 시드를 고정한 채로 표정·포즈·소품만 바꿔가며 다듬기
4. **같은 캐릭터 여러 장** — 외형 블록을 그대로 두고 `3_wai_illustrious_hq_character`로 포즈·구도 바리에이션
5. **캐릭터 시트** — PROMPTS.md의 "캐릭터 시트" 템플릿 + 가로 해상도(1216×832)로 앞·옆·뒤 설정화
6. (선택) 장기적으로 같은 캐릭터를 계속 쓸 거라면, 마음에 드는 결과 20~40장으로 **캐릭터 LoRA**를 학습 (아래 팁 참고)

> **빠르게 1차 결과만 보고 싶을 때**: ④ 하이레스, ⑤ 얼굴 그룹 제목을 우클릭 → *Bypass Group Nodes* (또는 그룹 선택 후 Ctrl+B). 다시 켤 때도 같은 방법.

---

## 5. 설정값 요약

| 항목 | ① Anima Turbo 시안 | ② Anima 고퀄 | ③ WAI 고퀄 |
|---|---|---|---|
| 모델 | anima-turbo-v1.1 | anima-aesthetic-v1.1 | waiIllustriousSDXL_v170 |
| 해상도 | 832×1216 ×4장 | 832×1216 | 1024×1344 |
| Steps | 10 | 30 | 28 |
| CFG | 1.0 | 4.5 | 5.5 |
| Sampler / Scheduler | euler / simple | er_sde / simple | euler_ancestral / normal |
| 하이레스 | 없음 | 1.5배, 20스텝, 디노이즈 0.35 | 1.5배, 20스텝, 디노이즈 0.4 |
| 얼굴 디테일러 | 없음 | guide 768 / max 1024, 디노이즈 0.35 | guide 768 / max 1024, 디노이즈 0.35 |
| 텍스트 인코더 | qwen_3_06b_base (`stable_diffusion` 타입) | 동일 | 체크포인트 내장 |
| VAE | qwen_image_vae | 동일 | 체크포인트 내장 |

**해상도 가이드**
- Anima: 512²~1536² 범위에서 동작. 세로 전신 `832×1216`, 정사각 `1024×1024`, 가로 `1216×832`
- WAI: 1024×1024 이상 권장. 세로 `1024×1344`, `896×1152` / 가로 `1344×1024`

**Anima 샘플러 성향** (공식 README)
- `er_sde`: 중립적, 플랫한 색, 선명한 선 (기본값)
- `euler_ancestral`: 부드럽고 얇은 선, 약간 2.5D 경향
- `dpmpp_2m_sde_gpu`: 더 다양하고 창의적이지만 가끔 과함
- `euler`: Turbo/Aesthetic에 잘 맞는 무난한 선택

---

## 6. 퀄리티를 끌어올리는 팁

- **Anima Aesthetic에는 `score_9` 같은 score 태그를 쓰지 마세요.** 공식 권장 사항이며, 과하게 '번들번들한' 그림이 됩니다. `masterpiece, best quality`는 넣어도 무방합니다.
- **Anima는 자연어를 2문장 이상** 붙이면 의도를 훨씬 잘 따릅니다. 태그와 문장을 섞어도 됩니다.
- **Anima 가중치는 크게**: SDXL에서 `(tag:1.2)` 정도라면 Anima에선 `(tag:1.5~2)`가 필요합니다.
- **Anima 화풍(작가) 태그는 앞에 `@`를 붙여야** 효과가 납니다. 예: `@작가명`
- **WAI는 짧고 정확한 태그**가 최고입니다. 퀄리티 태그·네거티브를 길게 늘이면 오히려 흐려집니다.
- **LoRA가 과하면** (색이 칙칙/번들, 얼굴이 다 비슷해짐) 강도를 0.3~0.4로 내리거나 노드를 선택해 Ctrl+B로 꺼서 비교해 보세요.
- **안전 태그**: 프롬프트에 `safe`(Anima) 또는 네거티브에 `nsfw, explicit`를 넣어 원치 않는 노출을 막습니다. (기본값에 이미 들어 있음)

### 캐릭터 LoRA를 직접 학습한다면
- Anima: **Anima-Base v1.0**으로 학습하는 것이 공식 권장. rank 32, 학습률 2e-5부터 시작, **LLM adapter는 학습하지 말 것**(diffusion-pipe의 `llm_adapter_lr = 0`)
- SDXL: Illustrious 계열 LoRA 학습 도구(kohya sd-scripts 등)로 학습하면 WAI에 그대로 적용됩니다.

---

## 7. 문제 해결

| 증상 | 해결 |
|---|---|
| 노드가 빨간색 / `UNETLoader`에서 Anima 로드 실패 | ComfyUI가 오래된 버전입니다. 업데이트하세요. |
| `FaceDetailer`, `UltralyticsDetectorProvider` 노드 없음 | Impact Pack + Impact **Subpack** 둘 다 설치 후 재시작 |
| Anima 결과가 노이즈/뭉개짐 | 텍스트 인코더가 `qwen_3_06b_base` 이고 타입이 `stable_diffusion` 인지 확인 (Qwen-Image용 다른 Qwen 파일 아님) |
| 얼굴 감지 모델 로드 시 `weights_only` 관련 에러 | `ComfyUI/user/default/ComfyUI-Impact-Subpack/model-whitelist.txt` 파일에 `face_yolov8m.pt` 한 줄 추가 후 재시작 (신뢰할 수 있는 출처의 파일만 추가하세요) |
| VRAM 부족 (OOM) | `1.5배로 축소` 노드의 `scale_by`를 0.375 → 0.3125(1.25배)로, 또는 하이레스 그룹을 Bypass. ComfyUI를 `--lowvram` 옵션으로 실행 |
| 얼굴 디테일러가 아무것도 안 바꿈 | 얼굴이 너무 작거나 감지 실패. `bbox_threshold`를 0.5 → 0.3으로 낮춰 보세요 |
| 얼굴만 그림체가 따로 놂 | 얼굴 디테일러 `denoise`를 0.35 → 0.25로 낮추기 |
| Civitai 다운로드 401/403 | `--civitai-token` 으로 API 키 지정 |

---

## 8. 라이선스 메모

- **Anima**: CircleStone Labs Non-Commercial License. 모델 자체를 유료 서비스에 올리는 등의 상업 이용은 불가하지만, **생성한 이미지는 상업적으로 사용 가능**하다고 공식 README에 명시되어 있습니다 (판매, 커미션, 게임·비주얼노벨 에셋 등).
- **WAI-Illustrious / 각 LoRA**: Civitai 각 페이지의 라이선스 표기를 확인하세요.

---

## 출처

- Anima: https://huggingface.co/circlestone-labs/Anima
- Anima 공식 LoRA: https://huggingface.co/circlestone-labs/Anima-Official-LoRAs
- ComfyUI Anima 튜토리얼: https://docs.comfy.org/tutorials/image/anima/anima
- WAI-Illustrious-SDXL: https://civitai.com/models/827184
- Aesthetic Quality Modifiers – Masterpiece: https://civitai.com/models/929497
- Detailer IL: https://civitai.com/models/1231943
- Real-ESRGAN: https://github.com/xinntao/Real-ESRGAN
- Bingsu/adetailer (face_yolov8m): https://huggingface.co/Bingsu/adetailer
- ComfyUI Impact Pack / Subpack: https://github.com/ltdrdata/ComfyUI-Impact-Pack , https://github.com/ltdrdata/ComfyUI-Impact-Subpack
