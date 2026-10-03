# ComfyUI 자캐(OC) 외형 디자인 세팅 — Anima (DiT)

ComfyUI에서 **NovelAI V4.5에 가까운 고퀄리티 애니 그림체**로 자캐 외형을 만들기 위한 세팅 모음입니다.
요청하신 대로 **DiT(Diffusion Transformer) 모델**인 **Anima**를 중심으로 모델, LoRA, 워크플로 5개, 프롬프트 템플릿, 다운로드 스크립트까지 한 번에 준비했습니다.

- 메인 모델: **Anima Aesthetic v1.1** (`anima-aesthetic-v1.1.safetensors`)
- 빠른 시안 모델: **Anima Turbo v1.1** (`anima-turbo-v1.1.safetensors`, 8스텝 · CFG 1)
- 둘 다 CircleStone Labs와 Comfy Org가 만든 공식 모델이고, Hugging Face([circlestone-labs/Anima](https://huggingface.co/circlestone-labs/Anima))에서 로그인 없이 받을 수 있습니다.
- 워크플로 1·2·3·5는 **ComfyUI 기본 노드만** 씁니다. 커스텀 노드는 04(얼굴 보정)에만 필요합니다.

> 대상: Windows에서 ComfyUI를 처음 써 보거나 조금 써 본 분. Linux/macOS 방법도 같이 적었습니다.
> 기준: 2026-10-03, ComfyUI v0.38.0 이후 master `e9027f2`. 필요 버전: 01~04는 v0.11.0 이상(권장 v0.14.1 이상), 05는 v0.29.0 이상.

---

## 목차

1. [빠른 시작 (5단계)](#1-빠른-시작-5단계)
2. [왜 Anima인가 (DiT 모델 선택 이유)](#2-왜-anima인가-dit-모델-선택-이유)
3. [NovelAI와 솔직한 비교](#3-novelai와-솔직한-비교)
4. [요구 사양 / VRAM](#4-요구-사양--vram)
5. [ComfyUI 설치 · 업데이트](#5-comfyui-설치--업데이트)
6. [모델 다운로드](#6-모델-다운로드)
7. [커스텀 노드 (선택)](#7-커스텀-노드-선택)
8. [워크플로 사용법](#8-워크플로-사용법)
9. [핵심 세팅 표](#9-핵심-세팅-표)
10. [프롬프트 작성법 요약](#10-프롬프트-작성법-요약)
11. [자캐 디자인 단계별 루틴](#11-자캐-디자인-단계별-루틴)
12. [LoRA 목록과 권장 가중치](#12-lora-목록과-권장-가중치)
13. [문제 해결 (FAQ)](#13-문제-해결-faq)
14. [검증 범위와 한계](#14-검증-범위와-한계)
15. [라이선스 주의](#15-라이선스-주의)
16. [폴더 구성](#16-폴더-구성)

---

## 1. 빠른 시작 (5단계)

1. **ComfyUI를 최신 버전으로 설치하거나 업데이트합니다.** Anima는 비교적 최근에 추가된 모델이라 구버전에서는 인식되지 않습니다. 설정(톱니바퀴) → About(정보)에서 버전이 **v0.29.0 이상**이면 워크플로 5개를 모두 쓸 수 있습니다. → [5장](#5-comfyui-설치--업데이트)
2. **이 폴더(`comfyui-anime-oc`)를 PC에 내려받습니다.** (ZIP으로 받아 압축을 풀거나 git clone)
3. **모델을 받습니다.** Windows라면 이 폴더에서 PowerShell을 열고 아래처럼 실행합니다. 경로는 내 ComfyUI 위치로 바꾸세요.
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable"
   ```
   필수 파일 약 10GB를 받습니다. 중간에 끊겨도 다시 실행하면 이어받습니다. → [6장](#6-모델-다운로드)
4. **ComfyUI를 실행하고 `workflows/02_fast_draft_anima_turbo.json`을 화면에 끌어다 놓은 뒤 Run(한국어 화면: 실행, `Ctrl+Enter`)을 누릅니다.** 몇 번 돌려 보며 외형 아이디어를 고릅니다.
5. **마음에 드는 조합을 `workflows/01_oc_design_anima_aesthetic.json`의 Positive에 옮겨 최종본을 만듭니다.** 이어서 03(3면도), 04(얼굴 보정·업스케일) 순서로 진행합니다. → [11장](#11-자캐-디자인-단계별-루틴)

결과 이미지는 `ComfyUI/output/AnimaOC/` 아래에 워크플로별로 저장됩니다.

---

## 2. 왜 Anima인가 (DiT 모델 선택 이유)

**DiT(Diffusion Transformer)** 는 SDXL 계열이 쓰던 U-Net 대신 트랜스포머로 그림을 만드는 구조입니다. Flux, SD3, Qwen-Image 같은 최신 모델이 이 방식을 씁니다.

**Anima**는 애니메이션 그림에 특화된 DiT 모델입니다.

| 항목 | 내용 |
|---|---|
| 구조 | NVIDIA Cosmos-Predict2-2B 기반 2B 파라미터 DiT |
| 텍스트 인코더 | Qwen3-0.6B (`qwen_3_06b_base.safetensors`) |
| VAE | Qwen-Image VAE (`qwen_image_vae.safetensors`, Wan2.1 계열 16채널) |
| 프롬프트 | Danbooru 태그 + 자연어 문장을 섞어서 사용 |
| ComfyUI 지원 | 최신 master에서 **커스텀 노드 없이 기본 지원**, shift 3.0 내장 (따로 설정할 필요 없음) |
| 애니 데이터 기준 시점 | 2025년 9월까지 |

**고른 이유**

- 요청하신 대로 DiT 모델입니다.
- 2026년 10월 기준 애니 특화 DiT 중 사용자와 생태계가 가장 큽니다. Hugging Face 월 다운로드가 약 106만, 파인튜닝 모델이 100개 이상이고 Civitai에도 Anima 전용 LoRA가 많습니다.
- 커뮤니티 비교 테스트 결과:
  - 대만 8개 모델 비교(Anima 4종, NoobAI-XL, NetaYume v4, Z-Image-Anime, Krea2)에서는 Anima-Aesthetic · Anima-Turbo · NetaYume v4가 상위 3개였고, Anima 계열 안에서는 Aesthetic이 빛과 그림자 표현, 자연어 이해가 가장 좋았습니다. NetaYume v4는 '가장 정석적인 예쁜 애니 일러스트'라는 평을 받았습니다.
  - 일본 3개 모델 비교에서는 Aesthetic v1.1이 구도·조명·자연어 이해가 가장 좋았습니다.
- 일본 리뷰어는 OC(자캐) 탐색 용도에서 GPT-Image 2, Nano Banana 2 같은 클라우드 모델과의 격차가 예상보다 작다고 평가했습니다.

**버전을 고른 이유**

| 버전 | 역할 | 이유 |
|---|---|---|
| **Aesthetic v1.1** | 메인 (01/03/04/05) | 작성자가 "대부분의 사람이 선호할 버전"이라고 했고, v1.0의 노이즈·아티팩트를 고친 버전입니다. |
| **Turbo v1.1** | 빠른 시안 (02) | 2026-08-24 공개. v1.0보다 덜 플랫하고 디테일과 작가 스타일 반영이 좋아졌습니다. 8스텝·CFG 1이라 매우 빠릅니다. |
| Base v1.0 | 선택 | 나중에 내 OC LoRA를 학습하거나, 공식 LLLite 기준 모델로 쓸 때 필요합니다. @작가 태그로 화풍을 바꾸는 자유도도 가장 큽니다. |

**뺀 후보와 이유**

| 후보 | 뺀 이유 |
|---|---|
| NetaYume Lumina v4 | 그림 품질은 Anima와 함께 상위권이지만, 2025-12 이후 업데이트가 없고 LoRA·파인튜닝 생태계가 작습니다. |
| NewBie | 아직 실험 단계입니다. |
| Z-Image-Anime | 2.5D 쪽으로 치우칩니다. |
| Krea-2, Qwen-Image, Flux.2 등 범용 DiT | 범용 모델이라 Danbooru 태그 기반 애니 그림에 특화되어 있지 않습니다. 위 대만 비교에서는 Krea2의 손 묘사가 무너졌습니다 (Qwen-Image, Flux.2는 그 비교에 포함되지 않음). |
| 커뮤니티 Anima-2.9B | 프리뷰 단계이고, 2B용 LoRA를 쓰려면 리매핑 노드가 필요합니다. |

---

## 3. NovelAI와 솔직한 비교

NovelAI는 2026-08-21에 **V5**를 냈습니다. V4.5보다 2.5배 큰 모델이고, 32채널 VAE를 쓰며, V4.5부터 있던 캐릭터 위치 지정(최대 22명)과 글자 렌더링을 개선했습니다.

| 항목 | NovelAI (V4.5 / V5) | 이 세팅 (Anima Aesthetic v1.1) |
|---|---|---|
| 캐릭터 1명 외형 디자인 · 설정화 | 매우 좋음 | **V4.5급의 깔끔한 애니 일러스트에 상당히 근접.** 공개 모델 중 가장 가깝다는 평가가 많음 |
| 작가 · 기존 캐릭터 재현 정확도 | 더 정확함 | 다소 약함 (작가 태그는 `@` 접두사 필요) |
| 여러 캐릭터 배치 | V4.5부터 위치 지정 지원, V5는 최대 22명으로 개선 | 약함 |
| 글자 렌더링 | V4.5부터 지원(Text: 블록), V5에서 개선 | 짧은 단어 정도만 |
| 손 안정성 | 더 안정적 | 가끔 깨짐 → 04 디테일러, seed 변경으로 보정 |
| 사용 편의성 | 별도 세팅 없이 바로 사용 | 설치·세팅 필요 (이 저장소가 그 부분을 대신함) |
| 비용 · 생성 횟수 | 유료 구독 | **무료 · 무제한** (내 GPU 사용) |
| 반복 작업 | 제한적 | **seed 고정 반복, 원하는 만큼 A/B 테스트** |
| 나만의 캐릭터 고정 | 어려움 | **내 OC LoRA 학습 가능** (Base v1.0) |
| 스케치 반영 | 제한적 | **LLLite로 스케치·선화를 반영한 생성** (05) |

정리하면, **"NovelAI 수준"은 캐릭터 1명의 외형 디자인 기준으로 근접한다는 뜻이지 똑같다는 뜻은 아닙니다.** 그 대신 무료·무제한 생성, seed 고정, LoRA 학습 같은 로컬만의 장점이 있습니다.

---

## 4. 요구 사양 / VRAM

**메모리 구성**

- 모델(DiT, bf16) 4.18GB + 텍스트 인코더 1.19GB + VAE 0.25GB
- 양자화하지 않았을 때 최대 사용량은 약 **7GB**입니다. **8GB GPU에서도 돌아가지만 빠듯하고, 12GB 이상이면 여유롭습니다.**
- 디스크: 필수 파일 약 10GB, 선택 파일까지 받으면 약 15GB 이상.

**속도 참고** (공개된 측정값. 설정이 서로 조금씩 다릅니다)

| GPU | 1장 생성 시간 | 조건 · 출처 |
|---|---|---|
| RTX 4060 Laptop 8GB | 약 55초 | Anima 파인튜닝(WAI-Anima v1), er_sde/simple, 30스텝, CFG 4 · [lilting.ch](https://lilting.ch/en/articles/wai-anima-rtx4060-laptop-comfyui-api) |
| RTX 5090 | 약 5초 | 832x1216, 30스텝, CFG 5, er_sde, bf16 + sage attention + torch.compile · [Bedovyy/Anima-FP8 모델 카드](https://huggingface.co/Bedovyy/Anima-FP8) |

- 그 밖의 GPU는 신뢰할 만한 공개 측정값을 찾지 못했습니다. 내 GPU에서는 02 Turbo로 먼저 속도를 확인해 보세요.
- Turbo(8스텝, CFG 1)는 계산량 기준으로 Aesthetic 30스텝(CFG > 1이면 스텝마다 2번 계산)의 약 1/7입니다 (추정).
- 01/03의 하이레즈 2차 패스(1264x1856, 20스텝 x denoise 0.4)는 1차보다 시간과 메모리를 더 씁니다.

**VRAM별 권장**

| VRAM | 권장 설정 |
|---|---|
| 12GB 이상 | 그대로 사용. 02의 batch_size를 4까지 올려도 됨 |
| 8GB | batch 1 유지 (02는 2). 디코딩 중 메모리 부족(OOM)이 나면 마지막 VAE Decode를 **VAE Decode (Tiled)** 로 교체(tile 512, overlap 64). ComfyUI가 자동으로 타일 디코딩으로 전환하기도 합니다. |
| 6GB 이하 | 방법 1: UNETLoader의 `weight_dtype`을 `fp8_e4m3fn`으로 변경 (모델 메모리 절반, 품질 약간 하락)<br>방법 2: [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF) + GGUF 양자화 모델 (예: HF의 `E-stick/anima-aesthetic-v1.1-GGUF` Q8_0, `vanes430/Anima-Turbo-V1.1-GGUF`). Q5_K_M보다 낮은 양자화는 권장하지 않습니다.<br>텍스트 인코더가 부담되면 `--fp8_e4m3fn-text-enc` 실행 옵션이나 CLIPLoader의 device를 `cpu`로 |

**기타 실행 옵션**

- **GTX 10xx/16xx처럼 bf16이 느린 구형 GPU는 반드시 `--fp16-unet` 옵션으로 실행하세요.** 없으면 한 장에 수 시간이 걸린 사례가 있습니다.
- 최신 ComfyUI는 Dynamic VRAM이 기본으로 켜져 있어 `--lowvram`은 효과가 없습니다.
- 속도를 높이려면 `pip install sageattention` 후 `--use-sage-attention` 옵션을 쓸 수 있습니다.
- 04의 FaceDetailer는 얼굴 부분만 768px로 다시 그리므로 추가 메모리가 적고, 업스케일 모델은 자동으로 타일 처리됩니다.

---

## 5. ComfyUI 설치 · 업데이트

> **중요:** Anima 모델과 05의 `AnimaLLLiteApply` 노드는 최근 버전에만 있습니다. 먼저 업데이트하세요.
> 현재 버전은 ComfyUI 화면의 설정(톱니바퀴) → About(정보)에서 확인할 수 있습니다.
>
> | 워크플로 | 필요한 ComfyUI 버전 |
> |---|---|
> | 01 ~ 04 (Anima 모델) | **v0.11.0 이상** (Anima 지원 추가). 2026-02의 Anima 버그 수정이 들어간 **v0.14.1 이상 권장** |
> | 05 (`AnimaLLLiteApply`) | **v0.29.0 이상** |
>
> 검증은 v0.38.0 이후 master `e9027f2`(2026-10-03)에서 했습니다.

### Windows — ComfyUI Desktop (설치형, 처음이라면 추천)

1. 공식 사이트([comfy.org](https://www.comfy.org))에서 Desktop 설치 파일을 받아 설치합니다.
2. 설치할 때 고른 폴더(보통 `문서\ComfyUI`, OneDrive를 쓰는 PC는 `OneDrive\문서\ComfyUI`일 수 있음) 안에 `models`, `custom_nodes`, `output` 폴더가 생깁니다. 다운로드 스크립트는 `-ComfyDir`를 생략하면 Desktop 설정에서 이 폴더를 자동으로 찾습니다.
3. 업데이트는 앱이 알려 줍니다. Desktop은 안정 버전을 묶어 배포하므로 최신 노드가 조금 늦게 들어올 수 있습니다. About에 표시된 버전이 위 표보다 낮거나 05 워크플로에서 노드가 빨갛게 보이면 Desktop 업데이트를 확인하거나 아래 포터블 버전을 쓰세요.
4. 실행 옵션(`--fp16-unet` 등)은 Desktop 설정의 서버 구성(Server-Config) 메뉴에서 바꿀 수 있습니다.

### Windows — 포터블 (NVIDIA GPU)

1. [ComfyUI GitHub](https://github.com/comfyanonymous/ComfyUI)의 Releases에서 Windows 포터블 압축 파일을 받아 원하는 곳에 풉니다 (예: `C:\ComfyUI_windows_portable`).
2. `run_nvidia_gpu.bat`으로 실행합니다.
3. **업데이트:** `update\update_comfyui.bat`을 실행합니다 (`update_comfyui_stable.bat`은 안정 버전으로만 업데이트하므로 최신 노드가 늦게 들어올 수 있습니다).
4. 실행 옵션은 `run_nvidia_gpu.bat`을 메모장으로 열고 `main.py` 뒤에 붙입니다. 예:
   ```bat
   .\python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build --fp16-unet
   ```
5. 모델 폴더는 `ComfyUI_windows_portable\ComfyUI\models`입니다. 스크립트에는 `ComfyUI_windows_portable` 폴더를 줘도 알아서 찾습니다.

### Linux / macOS (git 설치)

```bash
git clone https://github.com/comfyanonymous/ComfyUI.git ~/ComfyUI
cd ~/ComfyUI
python3 -m venv venv && source venv/bin/activate
# PyTorch는 내 GPU/OS에 맞는 버전을 먼저 설치하세요 (ComfyUI README 참고)
pip install -r requirements.txt
python main.py            # 구형 GPU라면: python main.py --fp16-unet
```

- **업데이트:** `cd ~/ComfyUI && git pull && pip install -r requirements.txt`
- Apple Silicon Mac에서도 ComfyUI는 돌아가지만, 이 세팅은 NVIDIA GPU 기준으로 정리했고 Mac에서는 속도가 크게 느릴 수 있습니다.

---

## 6. 모델 다운로드

### 6-1. 자동 스크립트 — Windows (PowerShell)

이 폴더에서 주소창에 `powershell`을 입력하거나, 폴더 빈 곳을 Shift+우클릭 → "PowerShell 창 열기"로 연 뒤 실행합니다.

```powershell
# 필수 파일만 (약 10GB)
powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable"

# ComfyUI Desktop 사용자: -ComfyDir를 생략하면 Desktop 설정(%APPDATA%\ComfyUI\config.json)에서 설치 폴더를 찾고 확인을 묻습니다
powershell -ExecutionPolicy Bypass -File .\download_models.ps1
# 직접 지정하려면 (OneDrive로 옮겨진 '문서' 폴더도 올바르게 찾는 형태)
powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "$([Environment]::GetFolderPath('MyDocuments'))\ComfyUI"

# 선택 파일까지 (Base v1.0, LLLite, 공식 LoRA 추가분, 얼굴/손 검출기, 대체 업스케일러)
powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable" -IncludeOptional

# Civitai LoRA 4종까지 (API 키 필요, 같은 창에서)
$env:CIVITAI_TOKEN = "발급받은키"
powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable" -IncludeOptional

# 특정 파일만 / 목록 보기 / 미리 보기
powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable" -Only lllite_any_test_v2
powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -List
powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable" -DryRun
```

| 옵션 | 설명 |
|---|---|
| `-ComfyDir` | ComfyUI 폴더(models가 있는 곳), 포터블 루트, 또는 models 폴더 자체. 생략하면 `COMFYUI_DIR` 환경 변수, 현재 폴더, Desktop 설정, 흔한 설치 위치를 자동으로 찾고 확인을 묻습니다. |
| `-IncludeOptional` | 선택 파일도 받기 |
| `-Only key1,key2` | 지정한 파일만 받기 (key는 `-List`나 [MODELS.md](MODELS.md)에서 확인) |
| `-List` / `-DryRun` | 목록만 보기 / 실제로 받지 않고 할 일만 출력 |
| `-VerifyHash` | sha256이 알려진 파일은 받은 뒤 해시 검사 |
| `-Yes` | 자동으로 찾은 폴더를 묻지 않고 사용 |
| `-Downloader` | `Auto`(기본: Windows 내장 curl.exe → 실패 시 .NET 이어받기), `Curl`, `WebRequest`, `Bits` |

- 이미 있는 파일은 건너뛰고, 끊긴 파일은 `.part`로 남아 있다가 **다시 실행하면 이어받습니다.**
- 공식 파일은 모두 토큰이 필요 없습니다. `$env:HF_TOKEN`이 있으면 Hugging Face 요청에 함께 붙입니다.
- "스크립트를 실행할 수 없습니다" 오류가 나면 위처럼 반드시 `powershell -ExecutionPolicy Bypass -File ...` 형태로 실행하세요.

### 6-2. 자동 스크립트 — Linux / macOS / Git Bash / WSL

```bash
bash download_models.sh --comfy-dir ~/ComfyUI                     # 필수 파일만
bash download_models.sh -d ~/ComfyUI --include-optional            # 선택 파일까지
CIVITAI_TOKEN=발급받은키 bash download_models.sh -d ~/ComfyUI --include-optional
bash download_models.sh -d ~/ComfyUI --only lllite_any_test_v2
bash download_models.sh --list
```

옵션은 PowerShell과 같습니다 (`--dry-run`, `--verify`, `-y`). `curl`(없으면 `wget`)과, models.json을 읽기 위한 `python3`(없으면 `jq`)가 필요합니다.
Windows에서 git으로 받은 경우에도 `.gitattributes`가 `.sh` 파일을 LF 줄바꿈으로 유지하므로 Git Bash/WSL에서 그대로 실행됩니다. (ZIP으로 받았거나 `$'\r': command not found` 오류가 나면 `sed -i 's/\r$//' download_models.sh` 후 다시 실행하세요.)

### 6-3. 수동 다운로드 표

브라우저로 링크를 열면 바로 받아집니다. **파일명은 그대로** 두고 표의 폴더(`ComfyUI/models/` 아래)에 넣으세요. 전체 목록, 체크섬, 용도 설명은 [MODELS.md](MODELS.md)에 있습니다.

| 파일 | 폴더 | 크기 | 구분 | 링크 |
|---|---|---|---|---|
| `anima-aesthetic-v1.1.safetensors` | `diffusion_models` | 4.18 GB | **필수** (메인) | [받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-aesthetic-v1.1.safetensors) |
| `anima-turbo-v1.1.safetensors` | `diffusion_models` | 4.18 GB | **필수** (02) | [받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-turbo-v1.1.safetensors) |
| `qwen_3_06b_base.safetensors` | `text_encoders` | 1.19 GB | **필수** | [받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors) |
| `qwen_image_vae.safetensors` | `vae` | 254 MB | **필수** | [받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors) |
| `anima-rl-v0.1.safetensors` | `loras` | 148.9 MB | **필수** (01/03 기본 ON) | [받기](https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main/anima-rl-v0.1.safetensors) |
| `RealESRGAN_x4plus_anime_6B.pth` | `upscale_models` | 17.9 MB | **필수** (01/03/04) | [받기](https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth) |
| `anima-base-v1.0.safetensors` | `diffusion_models` | 4.18 GB | 선택 (LoRA 학습 · 05 대체) | [받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-base-v1.0.safetensors) |
| `anima-lllite-any-test-like-v2.safetensors` | `model_patches` | 16.4 MB | 선택 (05) | [받기](https://huggingface.co/Comfy-Org/Anima-LLLite/resolve/main/model_patches/anima-lllite-any-test-like-v2.safetensors) |
| `anima-highres-aesthetic-boost.safetensors` | `loras` | 138.7 MB | 선택 (01 슬롯 2) | [받기](https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main/anima-highres-aesthetic-boost.safetensors) |
| `anima-turbo-lora-v0.2.safetensors` | `loras` | 148.9 MB | 선택 (05) | [받기](https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main/anima-turbo-lora-v0.2.safetensors) |
| `face_yolov8m.pt` | `ultralytics/bbox` | 52.0 MB | 선택 (04, Manager로 Subpack을 설치하면 자동으로 받아짐) | [받기](https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt) |
| `hand_yolov8s.pt` | `ultralytics/bbox` | 22.5 MB | 선택 (04, Manager로 Subpack을 설치하면 자동으로 받아짐) | [받기](https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt) |
| `Anzhc Face seg 640 v4 y11n.pt` | `ultralytics/segm` | 6.0 MB | 선택 (04 대체 검출기) | [받기](https://huggingface.co/Anzhc/Anzhcs_YOLOs/resolve/main/Anzhc%20Face%20seg%20640%20v4%20y11n.pt) |
| `2x-AnimeSharpV4_RCAN.safetensors` | `upscale_models` | 31.1 MB | 선택 (대체 업스케일러, 비상업) | [받기](https://github.com/Kim2091/Kim2091-Models/releases/download/2x-AnimeSharpV4/2x-AnimeSharpV4_RCAN.safetensors) |
| `Character Sheet for Anima.safetensors` | `loras` | 69.5 MB | 선택 · Civitai 토큰 (03) | [페이지](https://civitai.com/models/2603848) |
| `anima-base-1-masterpiece-v51.safetensors` | `loras` | 138.7 MB | 선택 · Civitai 토큰 (01 슬롯 3) | [페이지](https://civitai.com/models/929497) |
| `anima_context_detailer_base10.safetensors` | `loras` | 91.9 MB | 선택 · Civitai 토큰 | [페이지](https://civitai.com/models/2620171) |
| `BlueArchiveStyleB1.safetensors` | `loras` | 137.7 MB | 선택 · Civitai 토큰 (02) | [페이지](https://civitai.com/models/2530730) |

- 예전 폴더 이름인 `models/unet`, `models/clip`에 넣어도 인식됩니다.
- 넣은 뒤에는 ComfyUI 화면에서 `R` 키(모델 목록 새로고침)를 누르거나 재시작하세요.
- 모델 없이 워크플로를 열면 "N errors found" 알림 → 자세히 보기(View details) → 누락된 모델(Missing Models) 창에서 바로 받을 수도 있습니다. 이 경우에도 폴더와 파일명이 위 표와 같은지 확인하세요.
  - **단, `RealESRGAN_x4plus_anime_6B.pth`(업스케일러, GitHub 배포)는 이 창에 Download 버튼이 나오지 않아 "Download all"로도 받아지지 않습니다.** 다운로드 스크립트를 쓰거나 https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.2.4 에서 직접 받아 `models/upscale_models/`에 넣으세요. 이 파일이 없으면 01/03/04를 실행할 때 `model_name: 'RealESRGAN_x4plus_anime_6B.pth' not in []` 오류가 납니다.
  - Civitai LoRA는 기본으로 꺼져 있어(우회) 이 창에 나오지 않습니다.

### 6-4. Civitai API 키 만들기

Civitai LoRA 4종은 로그인한 계정의 API 키가 있어야 스크립트로 받을 수 있습니다.

1. Civitai에 로그인 → 계정 설정(Account Settings) → **API Keys**에서 새 키를 만듭니다.
2. Windows: `$env:CIVITAI_TOKEN = "키"` / Linux·macOS: `export CIVITAI_TOKEN=키`
3. `-IncludeOptional`(또는 `--include-optional`)을 붙여 스크립트를 실행합니다.

키는 비밀번호처럼 다루세요. 스크립트는 키를 화면에 출력하지 않습니다 (curl은 `Authorization` 헤더로 보내고, curl이 없어 wget을 쓸 때는 화면에 찍히는 주소에서 키를 `***`로 가립니다).

---

## 7. 커스텀 노드 (선택)

**01 · 02 · 03 · 05 워크플로는 커스텀 노드가 전혀 필요 없습니다.** 04를 쓸 때만 Impact Pack과 Subpack을 설치하세요.

| 이름 | 필요한 곳 | 설명 |
|---|---|---|
| [ComfyUI-Impact-Pack](https://github.com/ltdrdata/ComfyUI-Impact-Pack) | 04 | FaceDetailer 노드 (얼굴/손 자동 검출 후 확대 재생성). Anima + Qwen VAE에서 동작 검증 (v8.28.3) |
| [ComfyUI-Impact-Subpack](https://github.com/ltdrdata/ComfyUI-Impact-Subpack) | 04 | UltralyticsDetectorProvider 노드 (YOLO 검출기). **Manager로 설치하면** `face_yolov8m.pt`, `hand_yolov8s.pt`가 자동으로 받아집니다 (설치 스크립트 `install.py`가 받음). `ultralytics>=8.3.162` 필요 |
| [ComfyUI-Autocomplete-Plus](https://github.com/newtextdoc1111/ComfyUI-Autocomplete-Plus) | 선택 (전체) | Danbooru 태그 자동완성 (한국어 별칭 검색 지원). 설정에서 작가 태그 앞에 붙일 문자열(String to add before artist tags)을 `@`로, 밑줄을 공백으로 바꾸는 옵션을 켜 두세요. |
| [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF) | 선택 (저사양) | VRAM 6GB 이하에서 GGUF 양자화 모델(Q8_0/Q5_K_M)을 쓸 때만. `Unet Loader (GGUF)`로 UNETLoader를 대체 |

### 설치 방법 (ComfyUI-Manager 권장)

ComfyUI-Manager의 노드 관리 화면(Custom Nodes Manager)에서 이름으로 검색 → Install → ComfyUI 재시작.

- **ComfyUI Desktop:** Manager가 기본으로 들어 있습니다. 바로 위 방법대로 설치하세요.
- **Windows 포터블:** 최신 포터블은 Manager가 **별도 패키지이고 기본으로 꺼져 있어** 화면에 Manager 버튼이 없습니다. 한 번만 아래처럼 켜 주세요.
  1. `ComfyUI_windows_portable` 폴더에서 PowerShell을 열고 Manager 패키지를 설치합니다.
     ```powershell
     .\python_embeded\python.exe -m pip install -r ComfyUI\manager_requirements.txt
     ```
  2. `run_nvidia_gpu.bat`을 메모장으로 열어 `main.py` 줄 끝에 ` --enable-manager`를 붙이고 저장합니다.
     ```bat
     .\python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build --enable-manager
     ```
  3. 다시 실행하면 Manager 버튼이 생깁니다. 이후 위 방법대로 Impact Pack과 Impact Subpack을 설치하고 재시작합니다.
- **Linux/macOS (git 설치):** `pip install -r manager_requirements.txt` 후 `python main.py --enable-manager`로 실행합니다.

**수동 설치(고급):** `ComfyUI/custom_nodes` 폴더에서 `git clone <저장소 주소>` 후 해당 폴더의 `requirements.txt`를 ComfyUI가 쓰는 파이썬으로 설치합니다 (포터블: `python_embeded\python.exe -m pip install -r requirements.txt`). git이 PC에 설치되어 있어야 하고(포터블에는 들어 있지 않음, Impact Pack의 requirements에도 git 주소가 포함됨), **수동 설치는 YOLO 검출기를 자동으로 받지 않습니다.** 검출기는 다운로드 스크립트로 받으세요.

```powershell
powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable" -Only face_yolov8m,hand_yolov8s
```
```bash
bash download_models.sh -d ~/ComfyUI --only face_yolov8m,hand_yolov8s
```

검출기가 없으면 04를 실행할 때 `Value not in list: model_name: 'bbox/face_yolov8m.pt'` 오류가 납니다.

> kohya의 ComfyUI-Anima-LLLite 커스텀 노드는 **필요 없습니다.** 05는 코어 노드(ModelPatchLoader + AnimaLLLiteApply)만 쓰며, 그 커스텀 노드를 설치하면 구버전 워크플로와 노드 이름이 겹칠 수 있습니다.

---

## 8. 워크플로 사용법

### 공통 사용법

> 한국어 화면에서는 버튼과 위젯 이름이 번역되어 보입니다: Run = **실행**, `control_after_generate` = **생성 후 제어**, `randomize` = 값 무작위화, `fixed` = 고정 값, Bypass = **우회**, Mute = **음소거**, Load Image의 "choose file to upload" = **업로드할 파일 선택**.

- **여는 법:** `workflows/` 폴더의 JSON 파일을 ComfyUI 빈 화면에 끌어다 놓거나, 메뉴에서 Workflow → Open. ComfyUI가 만든 PNG를 빈 화면에 끌어다 놓아도 그때의 워크플로와 프롬프트, seed가 그대로 복원됩니다 (지금 열린 워크플로 대신 그 PNG의 워크플로가 열립니다).
- **실행:** Run(실행) 버튼 또는 `Ctrl+Enter`.
- **노드 켜기/끄기:** 노드를 클릭하고 **`Ctrl+B`**(우회/Bypass). 보라색으로 변하면 꺼진 상태입니다. LoRA 슬롯은 이 방법으로 켜고 끕니다.
- **그룹 단위 끄기:** 그룹 안의 노드를 `Ctrl`+드래그로 모두 선택한 뒤 **`Ctrl+M`**(음소거/Mute). 다시 누르면 복구됩니다.
- **seed 고정 (중요):** 화면의 seed 값은 실행하자마자 **다음 실행용 값으로 이미 바뀌어** 있습니다 (기본 설정 "위젯 제어 모드 = 다음(after)"). 그래서 그림이 마음에 든 뒤에 `control_after_generate`(생성 후 제어)만 `fixed`(고정)로 바꾸면 **그 그림이 아니라 새 seed가 고정됩니다.** 대신 이렇게 하세요.
  1. 마음에 든 PNG(`ComfyUI/output/AnimaOC/...`)를 ComfyUI 빈 화면에 끌어다 놓아 그 그림을 만든 워크플로(당시 seed 포함)를 복원합니다.
  2. KSampler의 `control_after_generate`(생성 후 제어)를 `fixed`(고정)로 바꿉니다.
  3. 프롬프트를 **한 번에 한 가지씩만** 고치며 비교합니다.
  - 매번 이렇게 하기 번거로우면 설정(톱니바퀴) → Comfy → 노드 위젯(Node Widget) → **위젯 제어 모드(Widget control mode)를 `이전`(before)으로** 바꾸세요. 그러면 실행 직전에 seed가 바뀌므로, 화면에 보이는 seed가 방금 그림의 seed가 됩니다.
- 각 워크플로 왼쪽에 **한국어 안내 노트**가 들어 있습니다. 워크플로에서 수정할 곳은 초록색 Positive 노드(그룹 3)입니다.
- `workflows/api/`에는 같은 그래프의 API 형식 JSON이 있습니다 (스크립트·자동화용, 일반 사용자는 신경 쓰지 않아도 됩니다).

| 파일 | 하는 일 | 모델 | 커스텀 노드 | 해상도 |
|---|---|---|---|---|
| `01_oc_design_anima_aesthetic.json` | OC 전신 디자인 + 하이레즈 | Aesthetic v1.1 + RL LoRA | 없음 | 832x1216 → 1264x1856 |
| `02_fast_draft_anima_turbo.json` | 랜덤 조합으로 빠른 시안 | Turbo v1.1 | 없음 | 832x1216 x 2장 |
| `03_character_sheet_anima.json` | 정면/옆/뒤 3면도 설정화 | Aesthetic v1.1 + RL LoRA | 없음 | 1536x1024 → 1888x1248 |
| `04_face_detail_upscale_impact.json` | 얼굴·손 보정 + 최종 2배 | Aesthetic v1.1 | Impact Pack + Subpack | 입력 이미지의 2배 |
| `05_sketch_to_oc_lllite.json` | 스케치/선화 → 완성 일러스트 | Aesthetic v1.1 + LLLite | 없음 | 입력 비율에 맞춰 약 1MP |

### 01. OC 외형 디자인 — Aesthetic v1.1 + 하이레즈 2패스 (메인)

`01_oc_design_anima_aesthetic.json`

- **필요한 파일:** `anima-aesthetic-v1.1`, `qwen_3_06b_base`, `qwen_image_vae`, `anima-rl-v0.1`(LoRA), `RealESRGAN_x4plus_anime_6B`
- **흐름:** [1] 모델 로드 → [2] LoRA 체인 → [3] 프롬프트 → [4] 1차 생성 832x1216 (30스텝, CFG 3.5, er_sde/simple) → [5] RealESRGAN 4배 → 약 2.25MP(16의 배수)로 축소 → denoise 0.40으로 2차 생성(20스텝) → **1264x1856 완성본**
- **고칠 곳:**
  1. **Positive(초록):** 외형 태그 블록만 내 캐릭터로 바꿉니다. 순서는 머리 길이 → 머리색 → 헤어스타일/장식 → 앞머리 → 눈 → 피부/얼굴 → 상의 → 하의 → 다리 → 신발 → 액세서리. 옷마다 색을 붙이면(`black jacket`) 디자인이 안정됩니다. 끝의 영어 문장 1~2개는 태그로 표현하기 어려운 부분(이너컬러 위치 등)을 설명합니다.
  2. **그림체:** `1girl, solo,` 뒤에 `@작가명` 하나만 추가 (예: `@fkey`). 2명 이상 섞으면 화풍이 흐려지고, 너무 세면 `(@작가명:0.6)`.
  3. **해상도([4] Empty Latent):** 전신 832x1216 / 반신 896x1152 / 바스트업 1024x1024. 32의 배수를 권장합니다.
- **LoRA 슬롯:** 슬롯 1 RL(기본 ON, 0.5) / 슬롯 2 Highres Boost(OFF, 1536px 이상 1차 생성 때만) / 슬롯 3 LoraLoader(OFF, Masterpiece v5.1 또는 나중에 학습한 내 OC LoRA).
- **하이레즈 팁:**
  - denoise 0.35(원본 유지) ~ 0.45(디테일 추가). 0.5 이상이면 얼굴·옷 디자인이 바뀔 수 있습니다.
  - 한 번에 약 1.5배 넘게 키우지 않는 것을 권장합니다 (커뮤니티 경험칙: 2배 이상을 한 번에 다시 그리면 불안정해지기 쉬움).
  - **Rebatch Images 노드는 지우지 마세요.** Qwen-Image VAE는 여러 장을 한 번에 인코딩하면 1장으로 합쳐 버립니다.
  - 하이레즈를 끄려면 [5] 그룹 노드를 모두 선택하고 `Ctrl+M`. 1차 결과는 따로 저장됩니다.
- **저장 위치:** `output/AnimaOC/01_base`(1차), `output/AnimaOC/01_hires`(완성본)

### 02. 빠른 시안 — Anima Turbo v1.1 (8스텝)

`02_fast_draft_anima_turbo.json`

- **필요한 파일:** `anima-turbo-v1.1` + 01과 같은 텍스트 인코더/VAE
- **설정 (가급적 그대로):** 8스텝(8~12), **CFG 1**, euler/simple, batch 2 (12GB 이상이면 4). er_sde는 지저분해질 수 있고, CFG를 올리면 그림이 타기 쉽습니다(올려도 1.5~2까지).
- **사용법:** Positive의 `{long hair|medium hair|short hair}`처럼 중괄호로 묶은 부분은 **실행할 때마다 하나씩 랜덤으로 선택**됩니다. Run(실행)을 여러 번 눌러 외형 조합을 탐색하세요. 고정하려면 중괄호를 지우고 하나만 남기세요.
- **뽑힌 조합 확인:** 결과 그림을 보고 판단하는 것이 가장 쉽습니다. 정확한 문구가 필요하면 PNG를 메모장으로 열어 `"prompt"` 부분에서 CLIPTextEncode의 `"text"` 값을 찾으세요. PNG를 화면에 다시 끌어다 놓으면 뽑힌 문구가 아니라 **중괄호 템플릿이 그대로** 복원됩니다.
- **주의:**
  - **CFG 1에서는 Negative가 아예 계산되지 않습니다.** 빼고 싶은 요소는 Positive에서 지우거나 다르게 표현하세요.
  - Turbo 체크포인트에는 Turbo LoRA를 **추가로 걸지 마세요** (이미 증류된 모델).
  - 결과가 뭉개지거나 AI 느낌이 강하면 `masterpiece, best quality`를 빼 보세요 (`anime coloring`은 유지).
  - 스타일 LoRA 슬롯(BlueArchiveStyleB1, Civitai)은 기본 OFF입니다.
- 마음에 드는 조합은 01의 Positive로 옮겨 최종본을 만드세요. 모델이 달라서 같은 seed라도 그림은 달라집니다.
- **저장 위치:** `output/AnimaOC/02_draft`

### 03. 캐릭터 레퍼런스 시트 — 정면/옆/뒤 3면도

`03_character_sheet_anima.json`

- **필요한 파일:** 01과 같음. 선택으로 `Character Sheet for Anima.safetensors`(Civitai).
- **사용법:**
  1. 01에서 확정한 **외형 태그 블록과 색 설명 문장**을 Positive의 같은 위치에 붙여넣습니다. 시트 관련 태그와 앞쪽 설명 문장은 그대로 둡니다.
  2. 1536x1024 가로 캔버스에 같은 캐릭터를 세 번 그립니다. 3면도는 seed 운이 크므로 **먼저 [5] 하이레즈 그룹을 `Ctrl+M`으로 끄고 여러 장 뽑으세요.**
  3. 마음에 드는 1차 결과 PNG(`output/AnimaOC/03_sheet_base`)를 빈 화면에 끌어다 놓아 그때의 seed가 든 워크플로를 복원하고, `control_after_generate`(생성 후 제어)를 `fixed`(고정)로 바꾼 뒤 [5] 그룹을 `Ctrl+M`으로 다시 켜고 실행합니다. (화면에 보이던 seed는 이미 다음 값으로 바뀌어 있어서, 복원하지 않고 바로 `fixed`로 바꾸면 다른 그림이 나옵니다.)
  4. 레이아웃이 자주 무너지면 LoRA 2(Character Sheet for Anima)를 `Ctrl+B`로 켜고 0.6~0.8로 씁니다. 트리거 태그는 이미 프롬프트에 들어 있습니다.
- **01과 다른 점:**
  - 시트에는 **`solo`를 쓰지 않습니다** (Danbooru 규칙상 여러 시점 그림은 solo가 아님).
  - Negative에 **`multiple views`를 넣지 않습니다.** 대신 `2girls, multiple girls`로 다른 인물이 섞이는 것을 막습니다.
  - 2차 패스 denoise를 0.35로 낮춰 세 시점의 디자인이 서로 달라지지 않게 했습니다 (1888x1248).
- **표정 시트:** Positive를 [프롬프트 가이드](prompts/README.md)의 E 템플릿으로 바꾸고 해상도를 1216x832 또는 1024x1024로 바꿉니다.
- **저장 위치:** `output/AnimaOC/03_sheet_base`, `output/AnimaOC/03_sheet_hires`

### 04. 얼굴·손 디테일 + 최종 2배 업스케일 (Impact Pack 필요)

`04_face_detail_upscale_impact.json`

- **준비:** [7장](#7-커스텀-노드-선택)대로 Impact Pack과 Impact Subpack 설치 후 재시작. **Windows 포터블은 Manager를 먼저 켜야 합니다** (7장 참고). 업스케일러 `RealESRGAN_x4plus_anime_6B.pth`도 필요합니다.
- **사용법:**
  1. **Load Image** 노드의 "choose file to upload"(업로드할 파일 선택) 버튼으로 01/03의 하이레즈 결과 PNG를 1장 고릅니다. 끌어다 놓을 때는 PNG를 **Load Image 노드 위에 정확히** 놓으세요. 빈 화면에 놓으면 그 PNG에 저장된 01 워크플로가 열려 04가 사라집니다.
  2. **Positive(얼굴용)** 에는 얼굴에 보이는 요소(머리색, 앞머리, 눈색, 눈 모양, 점, 표정, 목/머리 액세서리)를 01과 똑같이 넣습니다. 다르면 얼굴이 다른 사람처럼 바뀝니다. 옷·배경 태그는 빼세요.
  3. FaceDetailer: guide_size 768, denoise 0.40(0.35~0.45), 20스텝, CFG 3.5, er_sde/simple. guide_size는 낮추지 않는 것을 권장합니다 (경험칙: 얼굴을 512px보다 작게 다시 그리면 뭉개지기 쉬움).
  4. **손 디테일러(FaceDetailer - Hands)** 는 기본 OFF입니다. 손이 깨졌을 때만 `Ctrl+B`로 켜세요 (guide 512, denoise 0.35). 그래도 안 되면 seed를 바꿔 다시 생성하는 편이 빠릅니다.
  5. 마지막은 RealESRGAN 4배 → 0.5배 = **최종 2배 순수 확대**입니다 (다시 그리지 않음). 1264x1856 입력이면 2528x3712가 됩니다.
- 오른쪽 Preview는 FaceDetailer가 다시 그린 얼굴 크롭입니다.
- 애니 얼굴을 잘 못 찾으면 `Anzhc Face seg 640 v4 y11n.pt`를 `models/ultralytics/segm/`에 넣고 Face Detector를 `segm/` 항목으로 바꿔 보세요 (이 환경에서는 미검증, Subpack 화이트리스트 설정이 필요할 수 있음).
- **저장 위치:** `output/AnimaOC/04_detail_upscale`

### 05. 스케치/선화 → OC 완성 일러스트 (Anima LLLite, 선택)

`05_sketch_to_oc_lllite.json`

- **필요한 파일:** `model_patches/anima-lllite-any-test-like-v2.safetensors` (+ 01의 기본 파일). 선택으로 `anima-turbo-lora-v0.2`. 이 두 개만 받으려면:
  ```powershell
  powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable" -Only lllite_any_test_v2,lora_turbo_v02
  ```
  ```bash
  bash download_models.sh -d ~/ComfyUI --only lllite_any_test_v2,lora_turbo_v02
  ```
- **사용법:**
  1. **Load Image** 노드의 "choose file to upload"(업로드할 파일 선택) 버튼으로 러프 스케치, 포즈 낙서, 선화를 고릅니다. 끌어다 놓을 때는 Load Image 노드 위에 정확히 놓으세요 (ComfyUI가 만든 PNG를 빈 화면에 놓으면 그 PNG의 워크플로가 열립니다). 입력 비율에 맞춰 약 1MP(16의 배수) 해상도가 자동으로 정해집니다.
  2. 기본 경로는 Canny(0.17/0.45) → Invert = 흰 바탕에 검은 선 컨트롤 이미지입니다 (공식 템플릿과 같음). **이미 깔끔한 흑백 선화(흰 바탕/검은 선)라면 Canny와 Invert Image를 `Ctrl+B`로 끄세요.**
  3. Positive에는 01의 외형 블록을 넣습니다. 형태는 스케치가, 색과 디테일은 프롬프트가 결정합니다. 스케치 포즈와 맞지 않는 태그(`standing` 등)는 바꾸세요.
  4. strength 1.0이 기본입니다. 선을 너무 그대로 따라가면 0.6~0.8로 낮추거나 end_percent를 0.5~0.7로 바꾸세요.
- **설정:** euler/simple, 30스텝, CFG 4 (공식 템플릿과 같음).
- **참고:**
  - LLLite는 공식적으로 **Anima Base v1.0**으로 학습되었습니다. 여기서는 Aesthetic v1.1에 적용했으며(비공식 사용), 결과가 이상하면 Load Diffusion Model을 `anima-base-v1.0`으로 바꾸세요. 그때는 Positive에 `score_7`, Negative에 `score_1, score_2, score_3`을 추가하고 CFG 4~5로 씁니다.
  - 빠르게 확인하려면 Turbo LoRA를 `Ctrl+B`로 켜고 KSampler를 steps 8, cfg 1로 바꾸세요.
  - 포즈 전용 pose-1 모델은 공식 문서에서도 약하다고 되어 있어 넣지 않았습니다. 간단한 사람 실루엣이나 선화를 이 any-test 모델에 넣는 방식을 권장합니다.
- **저장 위치:** `output/AnimaOC/05_lllite`

---

## 9. 핵심 세팅 표

| 항목 | 값 | 메모 |
|---|---|---|
| 메인 모델 | `anima-aesthetic-v1.1.safetensors` (UNETLoader, weight_dtype default) | VRAM 6GB 이하라면 weight_dtype을 `fp8_e4m3fn`으로 |
| 시안 모델 | `anima-turbo-v1.1.safetensors` | CFG 1, 8~12스텝 전용. Turbo LoRA를 추가로 걸지 않기 |
| 텍스트 인코더 | `qwen_3_06b_base.safetensors` / CLIPLoader type `stable_diffusion` / device default | 공식 블루프린트와 같은 설정 |
| VAE | `qwen_image_vae.safetensors` | 여러 장을 VAEEncode하면 1장으로 합쳐지므로 RebatchImages(1)을 앞에 둠 |
| Shift / ModelSampling | 노드 불필요 (shift 3.0 내장) | 바꾸고 싶다면 ModelSamplingAuraFlow(shift 3.0)만. ModelSamplingSD3는 배율이 1000이라 Anima와 맞지 않음 |
| 1차 해상도 | 전신 832x1216 / 반신 896x1152 / 바스트업 1024x1024 / 시트 1536x1024 | 학습 범위는 512²~1536² 면적. 32의 배수로 두면 1.5배 확대해도 16의 배수 유지 |
| Aesthetic 스텝 | 30 (30~40) | 공식 샘플은 30스텝 |
| Aesthetic CFG | **3.5** (3~4.5) | 작성자는 CFG 3 근처가 더 좋아 보이는 경우가 많다고 함. 공식 샘플은 4. 6 이상은 타기 쉬움 |
| Aesthetic 샘플러 / 스케줄러 | `er_sde` / `simple` | 플랫한 색과 선명한 선(셀 채색 느낌). 더 부드럽게 하려면 `euler_ancestral`. CFG++ 계열 샘플러는 그림이 탐 |
| Turbo 설정 | steps 8, CFG 1.0, `euler`, `simple` | CFG 1에서는 Negative 무시. er_sde는 지저분해질 수 있음 |
| Base v1.0 설정 | 30~50스텝, CFG 4~5, er_sde/simple, Positive에 `score_7` / Negative에 `score_1, score_2, score_3` | LoRA 학습과 공식 LLLite의 기준 모델 |
| 하이레즈 업스케일 | RealESRGAN_x4plus_anime_6B → ImageScaleToTotalPixels(lanczos, 2.25, 16) → RebatchImages(1) → VAEEncode | 832x1216 → 1264x1856, 1536x1024 → 1888x1248 |
| 하이레즈 KSampler | 20스텝, CFG 3.5, er_sde/simple, denoise 0.40 (시트는 0.35) | 0.35 원본 유지 ~ 0.45 디테일 추가. 0.5 이상은 디자인이 바뀔 위험 |
| 패스당 최대 배율 | 약 1.5배 (경험칙) | 더 크게 하려면 04처럼 모델 업스케일만 |
| 프롬프트 가중치 | `(tag:1.5)` ~ `(tag:2)` | 공식 카드: SDXL보다 세게, 예 `(chibi:2)`. ComfyUI는 가중치를 LLM 어댑터 출력에 곱하므로 1.1~1.3은 효과가 약하고 4 이상은 그림이 무너지기 쉽다는 경험담이 많음(공식 기준 아님). 괄호가 든 이름은 `\(` `\)`로 이스케이프 |
| 작가 태그 | `@` 접두사, 1명만 (예: `@fkey`) | `@`가 없으면 효과가 매우 약함. 너무 세면 `(@작가:0.5~0.7)`. 작가 화풍 미리보기: animastyles.thetacursed.com |
| 태그 형식 | 소문자 + 띄어쓰기, 영어만 | 밑줄은 `score_N`에만. Danbooru와 Gelbooru 표기가 다르면 Gelbooru 우선 |
| score 태그 | **Base에서만** 사용 | Aesthetic: Positive/Negative 모두 쓰지 않기(공식 권장). Turbo: 필요 없어 생략 권장(공식 Turbo LoRA 설명: 품질 태그가 크게 필요 없음) |
| LoRA 기본 가중치 | RL 0.5 (ON) / Highres Boost 0.5~1.0 / Character Sheet 0.7 / Masterpiece 0.6 / Turbo LoRA 1.0 | 동시에 켜는 LoRA는 3개 이하. SDXL/Illustrious용 LoRA는 호환 안 됨 |
| FaceDetailer (04) | guide 768, max 1024, 20스텝, CFG 3.5, er_sde/simple, denoise 0.40, bbox 0.5 / dilation 10 / crop_factor 3.0 | 손 디테일러는 guide 512, denoise 0.35, 기본 OFF |
| LLLite (05) | strength 1.0, start 0, end 1 / Canny 0.17·0.45 + Invert / euler, simple, 30스텝, CFG 4 | 선을 너무 따라가면 strength 0.6~0.8 또는 end_percent 0.5~0.7 |
| 구형 GPU 실행 옵션 | `--fp16-unet` | GTX 10xx/16xx 필수 |
| 회화풍 질감 (선택) | beta57 스케줄러 (RES4LYF 커스텀 노드) | 공식 카드 제안. 코어만으로는 BetaSamplingScheduler(alpha 0.5, beta 0.7) + KSamplerSelect(er_sde) + SamplerCustom |

---

## 10. 프롬프트 작성법 요약

자세한 내용과 복사해서 쓰는 템플릿 10종은 **[prompts/README.md](prompts/README.md)**, 한국어→영어 태그 표는 **[prompts/tag_cheatsheet_ko.md](prompts/tag_cheatsheet_ko.md)** 에 있습니다.

**기본 규칙**

- **영어만** 씁니다. 텍스트 인코더(Qwen3-0.6B)가 영어 캡션으로 학습되었습니다.
- 태그는 **소문자 + 띄어쓰기** (`long hair`, `looking at viewer`). 밑줄은 쓰지 않습니다. 예외는 `score_7` 같은 score 태그뿐입니다.
- 태그 순서: **[품질/메타/연도/안전] → [1girl/1boy] → [캐릭터] → [작품] → [@작가] → [일반 태그(외형·구도·배경)]**, 그 뒤에 자연어 문장 1~2개.
- 가중치는 SDXL보다 세게 (공식 예시 `(chibi:2)`): `(twintails:1.5)` ~ `(chibi:2)`.
- 작가 태그는 반드시 `@`를 붙입니다: `@fkey`. 한 번에 한 명만.

**버전별 품질 태그 차이**

| 버전 | Positive 앞부분 | Negative |
|---|---|---|
| **Aesthetic v1.1** (01/03/04/05) | `masterpiece, best quality, highres, safe, newest,` (품질 태그는 선택, **score 태그 쓰지 않기** — 공식 권장) | `worst quality, low quality, artist name, blurry, jpeg artifacts, chromatic aberration, watermark, signature, ...` (**score 태그 쓰지 않기**) |
| **Turbo v1.1** (02) | `masterpiece, best quality, safe,` (score 태그는 필요 없어 생략 권장) | CFG 1이라 무시됨 (노드 연결용으로만 둠) |
| **Base v1.0** | `masterpiece, best quality, score_7, safe,` | `worst quality, low quality, score_1, score_2, score_3, artist name, blurry, jpeg artifacts, chromatic aberration` |

**예시 (01 기본값, Aesthetic)**

```text
masterpiece, best quality, highres, safe, newest, 1girl, solo, full body, standing, straight-on, looking at viewer, arms at sides, light smile, closed mouth, long hair, white hair, colored inner hair, blue hair, half updo, black ribbon, hair between eyes, sidelocks, blue eyes, tsurime, pale skin, petite, mole under eye, white shirt, collared shirt, blue necktie, black jacket, cropped jacket, long sleeves, black skirt, pleated skirt, black thighhighs, zettai ryouiki, brown shoes, loafers, black choker, x hair ornament, white background, simple background, anime coloring. Full-body character design of an original anime girl standing upright and facing the viewer on a plain white background, her whole figure visible from the top of her head to her shoes. Her long white hair has light blue inner coloring and is tied in a half updo with a small black ribbon.
```

**NovelAI에서 넘어왔다면**

| NovelAI | ComfyUI (Anima) |
|---|---|
| `{tag}` / `{{tag}}` | 중괄호 1겹마다 x1.05 → `(tag:1.05)` / `(tag:1.1)`. 단 Anima는 약한 가중치가 잘 안 먹으므로 실제로는 `(tag:1.5)`~`(tag:2)` |
| `1.5::tag::` | `(tag:1.5)` |
| `[tag]` | 대괄호 1겹마다 ÷1.05 → `(tag:0.95)` |
| `very aesthetic`, `no text`, `location`, `rating:general` | 빼기 (NovelAI 전용). 단 `very aesthetic`은 Masterpiece LoRA를 켰을 때만 트리거로 사용 |
| BREAK | 없음 |

ComfyUI에서 `{a|b}`는 강조가 아니라 **랜덤 선택** 문법입니다.

---

## 11. 자캐 디자인 단계별 루틴

### 1단계 — 컨셉을 태그로 정리

머릿속 캐릭터를 한국어로 적은 뒤 [태그 치트시트](prompts/tag_cheatsheet_ko.md)로 영어 태그로 바꿉니다. **머리 길이 → 머리색 → 헤어스타일 → 앞머리 → 눈 → 피부/얼굴 → 상의 → 하의 → 다리 → 신발 → 액세서리** 순서로, 옷에는 색을 붙입니다 (`black jacket`, `blue necktie`). 이것이 내 캐릭터의 **"외형 블록"** 입니다.

### 2단계 — 02 Turbo로 빠르게 탐색

`02_fast_draft_anima_turbo.json`에서 아직 정하지 못한 부분을 `{a|b|c}`로 묶고 Run을 여러 번 눌러 10~30장을 뽑습니다. 장당 수 초면 됩니다. 마음에 드는 조합을 골라 중괄호를 지웁니다.

### 3단계 — 01 Aesthetic으로 본 생성

`01_oc_design_anima_aesthetic.json`의 Positive에 외형 블록을 넣고 생성합니다.
- 좋은 그림이 나오면 그 PNG를 빈 화면에 끌어다 놓아 seed를 복원한 뒤 `fixed`(고정)로 바꾸고, 한 번에 한 가지만 고칩니다 ([8장 공통 사용법](#공통-사용법)의 seed 고정 참고).
- 그림체를 바꾸고 싶으면 `@작가명` 하나를 넣어 봅니다.
- 같은 seed에서 RL LoRA(슬롯 1)를 `Ctrl+B`로 껐다 켜며 비교해 보세요.
- 태그로 안 되는 디테일(이너컬러 위치, 비대칭 장식 등)은 끝의 영어 문장으로 설명합니다.

### 4단계 — 03 레퍼런스 시트

외형 블록을 `03_character_sheet_anima.json`에 그대로 옮겨 정면/옆/뒤 3면도를 만듭니다. 하이레즈를 끄고 여러 장 뽑은 뒤, 마음에 든 1차 PNG로 seed를 복원해 하이레즈로 완성하세요. 필요하면 표정 시트(E 템플릿)도 만듭니다.

### 5단계 — 04 디테일 · 업스케일

완성본을 `04_face_detail_upscale_impact.json`에 넣어 얼굴을 다시 그리고 2배로 키웁니다. 얼굴용 Positive에는 얼굴에 보이는 태그만 원본과 똑같이 넣습니다.

### 6단계 (선택) — 05 스케치로 포즈 지정

원하는 포즈나 실루엣이 있으면 대충 그린 스케치를 `05_sketch_to_oc_lllite.json`에 넣어 같은 외형 블록으로 채색 완성합니다.

### 7단계 — 일관성 유지와 OC LoRA 학습

- **외형 블록을 텍스트 파일로 보관**하세요. 구도·배경·조명만 바꾸고 외형 블록은 그대로 두는 것이 일관성의 핵심입니다 (F 템플릿 참고).
- 결과 PNG에는 프롬프트와 seed가 저장되어 있으니 버리지 말고 모아 두세요.
- **프롬프트만으로는 같은 OC가 매번 똑같이 나오지 않습니다.** 확실한 일관성이 필요하면:
  1. 03 시트(각 시점을 잘라서)와 01 결과에서 **20~40장**을 고릅니다.
  2. **Anima Base v1.0**으로 OC LoRA를 학습합니다. 방법은 diffusion-pipe(`type anima`, rank 32, LR 2e-5, `llm_adapter_lr 0`) 또는 sd-scripts의 `anima_train_network.py`.
  3. 완성된 LoRA를 `models/loras/`에 넣고 01의 **LoRA 슬롯 3**(LoraLoader)에서 선택합니다.
- 학습 없이 참조 이미지로 정체성을 유지하는 실험적 방법으로 `darask0/Anima-InContext-Character`(HF, 커스텀 노드 + LoRA)가 있지만 이번 세팅에는 포함하지 않았습니다.

---

## 12. LoRA 목록과 권장 가중치

**원칙:** 기본으로 켜 둔 것은 공식 `anima-rl-v0.1`(0.5) 하나뿐입니다. 나머지는 모두 기본 꺼짐(바이패스)이고 `Ctrl+B`로 켭니다. 동시에 켜는 LoRA는 3개 이하로 하세요. 많이 쌓으면 손·팔이 깨지기 쉽습니다.

| LoRA | 파일명 | 워크플로 / 기본 | 권장 가중치 | 트리거 | 토큰 |
|---|---|---|---|---|---|
| Anima RL v0.1 (공식, 미감·디테일) | `anima-rl-v0.1.safetensors` | 01·03 슬롯 1 / **ON** | 0.5 (0.3~1.0; 공식 권장 1.0) | 없음 | 불필요 |
| Anima Highres/Aesthetic Boost (공식) | `anima-highres-aesthetic-boost.safetensors` | 01 슬롯 2 / OFF | 0.5~1.0 | 없음 | 불필요 |
| Anima Turbo LoRA v0.2 (공식) | `anima-turbo-lora-v0.2.safetensors` | 05 / OFF | 1.0 (0.7~1.0), 켜면 CFG 1 · 8~12스텝 · euler/simple | 없음 | 불필요 |
| Character Sheet for Anima (ThetaCursed) | `Character Sheet for Anima.safetensors` | 03 슬롯 2 / OFF | 0.7 (0.6~0.8) | `1girl, multiple views, standing, full body, reference sheet, turnaround` | Civitai |
| Masterpiece v5.1 [anima-base-1] (motimalu) | `anima-base-1-masterpiece-v51.safetensors` | 01 슬롯 3 / OFF | 0.6 (0.5~1.0) | `masterpiece, very aesthetic` (프롬프트 맨 앞) | Civitai |
| Detail Tweaker - context_detailer_base10 (lse14) | `anima_context_detailer_base10.safetensors` | 기본 슬롯 없음 (01 슬롯 3에서 교체) | 0.3~0.5 (범위 -0.75~0.75, 양수 = 디테일 증가) | 없음 | Civitai |
| B1 Blue Archive Style (FlyingOyster) | `BlueArchiveStyleB1.safetensors` | 02 스타일 슬롯 / OFF | 0.8 (최대 1.0) | `@BlueArchStyle` (선택) | Civitai |

- **RL LoRA:** 전반적인 미감과 디테일 향상. 같은 seed로 켜고 끄며 비교해 보세요.
- **Highres Boost:** 1536~2048px 고해상도 안정화. v1.0 이후 모델은 이미 1536 학습이라 필수는 아니고, 1536px 이상으로 1차 생성할 때만 켭니다.
- **Turbo LoRA:** 일반 Anima 모델을 8스텝 모드로 바꿉니다. **Turbo v1.1 체크포인트와는 절대 같이 쓰지 마세요.**
- **Character Sheet:** 화풍에 영향 없이 3면도 레이아웃만 잡아 줍니다.
- **Masterpiece v5.1:** 손으로 고른 걸작 386장으로 학습한 품질 부스터 (Civitai에서 Anima 품질 LoRA 중 인기 상위, Anima 버전 좋아요 약 1.5천). 켜면 작가 화풍을 덮어쓰는지 확인하세요.
- **Blue Archive Style:** 깔끔한 가챠/모바일게임 애니 화풍 예시. 원작이 아닌 OC에도 적용됩니다. 스타일 LoRA는 한 번에 하나만.
- **Illustrious/SDXL/Pony용 LoRA는 동작하지 않습니다.** Civitai에서 Base Model이 **Anima**인 것만 쓰세요.
- 공식 RL, Highres Boost, Character Sheet LoRA는 preview3 모델로 학습되었습니다. v1.1 계열에서의 효과는 공식 검증이 없어 보수적인 가중치로 두었습니다.
- "NovelAI 스타일"을 표방하는 Anima LoRA들은 다운로드가 100~2,000회 수준이라 검증이 부족해 넣지 않았습니다.

---

## 13. 문제 해결 (FAQ)

**Q. 워크플로를 열었더니 노드가 빨갛게 나와요 / "Missing node types"가 떠요.**
- `AnimaLLLiteApply`, `ModelPatchLoader` 등 코어 노드가 빨가면 **ComfyUI가 구버전**입니다. [5장](#5-comfyui-설치--업데이트)대로 업데이트하세요.
- `FaceDetailer`, `UltralyticsDetectorProvider`가 빨가면 04용 커스텀 노드(Impact Pack, Subpack)를 설치하세요.

**Q. 실행하면 "Value not in list" 오류가 나요 / 모델이 목록에 없어요.**
- 파일이 올바른 폴더에 있는지, 파일명이 [MODELS.md](MODELS.md)와 **완전히 같은지** 확인하세요 (Civitai에서 받은 파일은 이름이 다를 수 있음).
- 넣은 뒤에는 화면에서 `R` 키를 누르거나 ComfyUI를 재시작해야 목록에 나타납니다.
- 꺼져 있는(보라색) LoRA 슬롯은 파일이 없어도 오류가 나지 않습니다. 켜 둔 노드의 파일만 있으면 됩니다.

**Q. 모델을 불러올 때 `ERROR: Could not detect model type of: ...anima-aesthetic-v1.1.safetensors` 오류가 나요.**
- ComfyUI가 Anima를 지원하지 않는 구버전입니다. 업데이트하세요. 또 받다가 끊긴 파일일 수 있으니 크기(4.18GB)를 확인하거나 `-VerifyHash`로 검사하세요.

**Q. 너무 느려요.**
- GTX 10xx/16xx라면 `--fp16-unet`을 꼭 붙이세요.
- 먼저 02 Turbo로 탐색하고, 01에서는 하이레즈 그룹을 끈 채(`Ctrl+M`) 여러 장 뽑은 뒤, 마음에 든 1차 PNG로 seed를 복원해 최종본에만 하이레즈를 켜세요.
- `--use-sage-attention`(sageattention 설치 필요)으로 속도를 올릴 수 있습니다.

**Q. 메모리 부족(OOM, CUDA out of memory)이 나요.**
- batch_size를 1로, 마지막 VAE Decode를 VAE Decode (Tiled)로 바꾸세요.
- 6GB 이하라면 UNETLoader의 weight_dtype을 `fp8_e4m3fn`으로 바꾸거나 GGUF 모델을 쓰세요. → [4장](#4-요구-사양--vram)

**Q. 그림이 타거나(과포화) 지저분해요.**
- CFG를 3~4로 낮추세요 (Turbo는 1). CFG++ 계열 샘플러는 쓰지 마세요.
- Turbo에서 er_sde를 쓰면 지저분해질 수 있습니다. euler로 두세요.
- 하이레즈 denoise가 너무 높지 않은지(0.5 이상) 확인하세요.

**Q. 하이레즈 결과가 한 장으로 합쳐지거나 이상하게 나와요.**
- **Rebatch Images 노드를 지웠다면 되살리세요.** Qwen-Image VAE는 이미지 배치를 동영상 프레임처럼 처리해 1장으로 합쳐 버립니다. Ultimate SD Upscale 같은 노드를 따로 쓸 때도 batch_size를 1로 두세요.

**Q. 프롬프트가 잘 안 먹어요.**
- 영어로만 썼는지, 밑줄 대신 띄어쓰기를 썼는지 확인하세요.
- 가중치를 1.5~2까지 올려 보세요. 1.1~1.3은 효과가 약하다는 경험담이 많습니다.
- Aesthetic에 `score_7` 같은 score 태그를 넣었다면 빼세요 (Turbo에서도 필요 없음).
- 텍스트 인코더가 0.6B로 작아서 아주 복잡한 포즈나 구도 설명은 일부 무시될 수 있습니다. 문장을 짧게 나누세요.

**Q. 작가 태그를 넣었는데 화풍이 안 바뀌어요.**
- 작가 이름 앞에 `@`를 붙였는지 확인하세요 (`@fkey`). `@`가 없으면 효과가 매우 약합니다. 작가는 한 명만 넣으세요.

**Q. Turbo(02)에서 Negative에 넣은 게 계속 나와요.**
- 정상입니다. CFG 1에서는 Negative가 계산되지 않습니다. Positive에서 해당 요소를 지우거나 다르게 표현하세요.

**Q. 전신 그림에서 얼굴이 뭉개져요 / 손이 이상해요.**
- 04 FaceDetailer로 얼굴을 다시 그리세요 (guide_size 768 유지). 손은 04의 손 디테일러를 켜거나 seed를 바꿔 보세요. Anima 전용 손 교정 LoRA는 아직 없습니다. LLLite inpainting-v2로 부분 수정하는 방법도 있습니다.

**Q. 그림에 "AI 광택" / Pony 느낌이 나요.**
- 같은 HF 폴더의 다른 버전을 써 보세요: aesthetic-v1.0(더 플랫한 전통 애니 느낌), Base v1.0 + `@작가` 태그(화풍 자유도 최대).
- 01 끝에 `The image is a highly finished digital illustration in anime style with smooth, shiny shading.` 같은 문장을 붙이거나 빼며 비교해 보는 것도 방법입니다 (효과 미검증).

**Q. LoRA를 켰더니 효과가 없거나 그림이 깨져요.**
- SDXL/Illustrious/Pony용 LoRA는 Anima와 호환되지 않습니다. Civitai에서 Base Model이 Anima인지 확인하세요.
- 동시에 켠 LoRA가 3개를 넘지 않는지, 가중치가 너무 높지 않은지 확인하세요.

**Q. 04에서 `Value not in list: model_name: 'bbox/face_yolov8m.pt'` 오류가 나요.**
- 얼굴/손 검출기가 없습니다. Impact Subpack을 Manager 없이 수동 설치하면 검출기가 자동으로 받아지지 않습니다. `-Only face_yolov8m,hand_yolov8s`(bash: `--only`)로 다운로드 스크립트를 실행하세요. → [7장](#7-커스텀-노드-선택)

**Q. 01/03/04에서 `model_name: 'RealESRGAN_x4plus_anime_6B.pth' not in [...]` 오류가 나요.**
- 업스케일러가 없습니다. "누락된 모델" 창의 "Download all"은 이 파일(GitHub 배포)을 받지 않습니다. 다운로드 스크립트를 쓰거나 [Real-ESRGAN 릴리스](https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.2.4)에서 받아 `models/upscale_models/`에 넣으세요.

**Q. 마음에 든 그림의 seed를 `fixed`로 바꿨는데 다른 그림이 나와요.**
- 화면의 seed는 실행 직후 이미 다음 값으로 바뀝니다. 마음에 든 PNG를 빈 화면에 끌어다 놓아 워크플로를 복원한 뒤 `fixed`로 바꾸세요. → [8장 공통 사용법](#공통-사용법)

**Q. 다운로드 스크립트 관련**
- "이 시스템에서 스크립트를 실행할 수 없으므로..." → `powershell -ExecutionPolicy Bypass -File .\download_models.ps1 ...` 형태로 실행하세요.
- Civitai 파일이 "건너뜀"으로 나옴 → `CIVITAI_TOKEN`을 설정하고 `-IncludeOptional`을 붙이세요. "서버가 요청을 거부" → 키가 맞는지 확인하세요.
- 끊겼어요 → 같은 명령을 다시 실행하면 이어받습니다.
- 회사/학교 네트워크에서 curl.exe가 인증서 확인 오류로 실패하면 스크립트가 자동으로 .NET 방식으로 다시 시도합니다. `-Downloader WebRequest`로 처음부터 지정할 수도 있습니다.

**Q. 글자(이름, 주석)를 시트에 넣고 싶어요.**
- Anima는 글자 렌더링이 약해 짧은 단어 정도만 됩니다. 이름이나 주석은 나중에 편집 프로그램으로 넣으세요.

---

## 14. 검증 범위와 한계

- 이 세팅을 만든 환경에는 GPU가 없고 Hugging Face/Civitai 다운로드가 막혀 있어 **실제 이미지 품질은 테스트하지 못했습니다.**
- 대신 워크플로 5개의 연결 구조는 실제 ComfyUI(`e9027f2`)에서 **실제 파일 이름을 단 구조 동일 더미 가중치**로 끝까지 실행해 검증했습니다 (LoRA 켜기/끄기, 배치 2장, FaceDetailer 포함).
- UI 워크플로 JSON은 실제 ComfyUI 프런트엔드(1.53.10)의 기본 캔버스와 Vue 노드 렌더러(Nodes 2.0) 양쪽에서 열어, 노드 누락·위젯 값·노드 겹침·처음 화면 배율(글자가 보이는 배율)을 확인하고 서버의 프롬프트 검증(`/prompt`)을 통과하는지 확인했습니다.
- 다운로드 스크립트는 로컬 테스트 서버(이어받기, 토큰, 오류 페이지 처리)와 GitHub 파일 실제 다운로드로 검증했습니다.
- CFG, denoise 같은 수치는 공식 모델 카드, 작성자 샘플 메타데이터, 커뮤니티 테스트를 근거로 한 **출발점**입니다. 내 GPU에서 seed를 고정하고 A/B로 조정하세요.
- 손과 해부학은 가끔 깨집니다 (특히 @작가 태그를 쓸 때).
- Anima의 애니 학습 데이터는 2025-09까지입니다. 그 이후에 나온 기존 캐릭터는 모르지만 OC 디자인과는 관계없습니다.
- 공식 RL/Highres Boost/Character Sheet LoRA는 preview3 기준 학습, LLLite는 Base v1.0 기준 학습이라 v1.1 계열과의 조합은 공식 검증이 없습니다.

---

## 15. 라이선스 주의

- **Anima 모델과 파생 가중치**는 CircleStone Labs 비상업 라이선스(+NVIDIA Open Model License)입니다. **모델을 유료 API·유료 생성 서비스로 제공하거나 유료 제품에 내장하는 것은 금지**입니다 (별도 라이선스 필요). 단, 라이선스 2.c의 예외로 **개인이 파생 가중치(예: 직접 학습한 OC LoRA)를 판매하는 것은 허용**됩니다.
- 공식 카드에 따르면 **생성한 이미지는 상업적으로 이용할 수 있습니다.**
- **Civitai LoRA**는 각 모델 페이지의 라이선스를 따로 확인하세요.
- **업스케일러:** RealESRGAN(BSD-3)은 상업 이용이 무난합니다. 대안인 2x-AnimeSharpV4는 CC BY-NC-SA 4.0(비상업)이라 기본값에서 뺐습니다.
- 기존 작품의 캐릭터나 특정 작가 화풍을 흉내 낸 결과물을 공개·판매할 때는 저작권과 각 플랫폼 규정을 따로 확인하세요.

---

## 16. 폴더 구성

```text
comfyui-anime-oc/
├─ README.md                 ← 이 문서
├─ MODELS.md                 ← 모델·LoRA 전체 목록, 폴더, 링크, 체크섬
├─ models.json               ← 같은 목록의 기계용 버전 (다운로드 스크립트가 읽음)
├─ download_models.ps1       ← Windows용 다운로드 스크립트
├─ download_models.sh        ← Linux/macOS/Git Bash용 다운로드 스크립트
├─ .gitattributes            ← 줄바꿈 고정 (.sh = LF, .ps1 = CRLF)
├─ prompts/
│  ├─ README.md              ← 프롬프트 가이드 + 복사용 템플릿 10종
│  └─ tag_cheatsheet_ko.md   ← 한국어 → 영어 Danbooru 태그 표
├─ workflows/
│  ├─ 01_oc_design_anima_aesthetic.json
│  ├─ 02_fast_draft_anima_turbo.json
│  ├─ 03_character_sheet_anima.json
│  ├─ 04_face_detail_upscale_impact.json
│  ├─ 05_sketch_to_oc_lllite.json
│  └─ api/                   ← 같은 그래프의 API 형식 (자동화용)
└─ tools/
   └─ build_workflows.py     ← 워크플로 JSON 생성기 (UI 형식 + API 형식)
```

### 참고 링크

- Anima 공식 모델: https://huggingface.co/circlestone-labs/Anima
- Anima 공식 LoRA: https://huggingface.co/circlestone-labs/Anima-Official-LoRAs
- Anima LLLite: https://huggingface.co/Comfy-Org/Anima-LLLite
- Real-ESRGAN 릴리스: https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.2.4
- ComfyUI: https://github.com/comfyanonymous/ComfyUI
