# 모델 · LoRA 파일 목록 (MODELS.md)

이 세팅에서 쓰는 모든 파일의 목록입니다. 같은 내용이 기계용으로 [`models.json`](models.json)에 들어 있고,
[`download_models.ps1`](download_models.ps1)(Windows)과 [`download_models.sh`](download_models.sh)(Linux/macOS)가 이 파일을 그대로 읽어서 받습니다.

- **폴더**는 모두 `ComfyUI/models/` 아래 기준입니다.
  - ComfyUI Desktop: 설치할 때 고른 폴더 안의 `models` (기본값은 보통 `문서\ComfyUI\models`)
  - 포터블: `ComfyUI_windows_portable\ComfyUI\models`
  - git 설치: `ComfyUI/models`
- **파일명은 표에 적힌 그대로** 두세요. 워크플로가 이 이름으로 파일을 찾습니다. 특히 Civitai에서 브라우저로 받으면 이름이 달라질 수 있으니 꼭 바꿔 주세요. (`Character Sheet for Anima.safetensors`처럼 공백이 들어간 이름도 그대로 둡니다.)
- 예전 폴더 이름인 `models/unet`(= `diffusion_models`), `models/clip`(= `text_encoders`)에 넣어도 ComfyUI가 인식합니다.
- 필수 파일 합계는 약 **10GB**(9.98GB)입니다. 선택 파일 중 토큰이 필요 없는 것을 모두 더하면 약 4.6GB, Civitai LoRA 4종을 더하면 약 0.44GB가 늘어납니다.

## 한눈에 보는 폴더 구조

```text
ComfyUI/
└─ models/
   ├─ diffusion_models/
   │   ├─ anima-aesthetic-v1.1.safetensors     ← 필수 (메인)
   │   ├─ anima-turbo-v1.1.safetensors         ← 필수 (02 빠른 시안)
   │   └─ anima-base-v1.0.safetensors          ← 선택 (LoRA 학습 / 05 대체)
   ├─ text_encoders/
   │   └─ qwen_3_06b_base.safetensors          ← 필수
   ├─ vae/
   │   └─ qwen_image_vae.safetensors           ← 필수
   ├─ loras/
   │   ├─ anima-rl-v0.1.safetensors            ← 필수 (01/03에서 기본 ON)
   │   ├─ anima-highres-aesthetic-boost.safetensors      (선택)
   │   ├─ anima-turbo-lora-v0.2.safetensors              (선택)
   │   ├─ Character Sheet for Anima.safetensors          (선택, Civitai)
   │   ├─ anima-base-1-masterpiece-v51.safetensors       (선택, Civitai)
   │   ├─ anima_context_detailer_base10.safetensors      (선택, Civitai)
   │   └─ BlueArchiveStyleB1.safetensors                 (선택, Civitai)
   ├─ upscale_models/
   │   ├─ RealESRGAN_x4plus_anime_6B.pth       ← 필수
   │   └─ 2x-AnimeSharpV4_RCAN.safetensors               (선택, 비상업 라이선스)
   ├─ model_patches/
   │   └─ anima-lllite-any-test-like-v2.safetensors      (선택, 05)
   └─ ultralytics/
       ├─ bbox/
       │   ├─ face_yolov8m.pt                            (선택, 04 · Manager로 Subpack 설치 시 자동)
       │   └─ hand_yolov8s.pt                            (선택, 04 · Manager로 Subpack 설치 시 자동)
       └─ segm/
           └─ Anzhc Face seg 640 v4 y11n.pt              (선택, 04 대체 검출기)
```

## 파일 표

### 필수 (기본 다운로드)

| key | 파일명 (이 이름 그대로) | 넣을 폴더 | 크기 | 사용 워크플로 | 링크 |
|---|---|---|---|---|---|
| `anima_aesthetic_v11` | `anima-aesthetic-v1.1.safetensors` | `models/diffusion_models/` | 4.18 GB | 01, 03, 04, 05 | [직접 받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-aesthetic-v1.1.safetensors) · [페이지](https://huggingface.co/circlestone-labs/Anima/tree/main/split_files/diffusion_models) |
| `anima_turbo_v11` | `anima-turbo-v1.1.safetensors` | `models/diffusion_models/` | 4.18 GB | 02 | [직접 받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-turbo-v1.1.safetensors) · [페이지](https://huggingface.co/circlestone-labs/Anima/tree/main/split_files/diffusion_models) |
| `qwen3_te` | `qwen_3_06b_base.safetensors` | `models/text_encoders/` | 1.19 GB | 01, 02, 03, 04, 05 | [직접 받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/text_encoders/qwen_3_06b_base.safetensors) · [페이지](https://huggingface.co/circlestone-labs/Anima) |
| `qwen_image_vae` | `qwen_image_vae.safetensors` | `models/vae/` | 254 MB | 01, 02, 03, 04, 05 | [직접 받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/vae/qwen_image_vae.safetensors) · [페이지](https://huggingface.co/circlestone-labs/Anima) |
| `realesrgan_anime6b` | `RealESRGAN_x4plus_anime_6B.pth` | `models/upscale_models/` | 17.9 MB | 01, 03, 04 | [직접 받기](https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth) · [페이지](https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.2.4) |
| `lora_anima_rl_v01` | `anima-rl-v0.1.safetensors` | `models/loras/` | 148.9 MB | 01, 03 | [직접 받기](https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main/anima-rl-v0.1.safetensors) · [페이지](https://civitai.com/models/2583128) |

<details><summary>각 파일 설명</summary>

- **anima-aesthetic-v1.1.safetensors** — 메인 고퀄리티 모델 (01/03/04/05 워크플로). Anima Aesthetic v1.1 공식 DiT, bf16.
- **anima-turbo-v1.1.safetensors** — 빠른 시안용 증류 모델 (02 워크플로). CFG 1, 8~12스텝.
- **qwen_3_06b_base.safetensors** — Anima 전 버전 공통 텍스트 인코더 (Qwen3 0.6B base). CLIPLoader type stable_diffusion.
- **qwen_image_vae.safetensors** — Anima 공통 VAE (Qwen-Image VAE, Wan2.1 계열 16ch).
- **RealESRGAN_x4plus_anime_6B.pth** — 하이레즈 2차 패스(01/03)와 최종 2배 업스케일(04)용 애니 업스케일러 (4x, BSD-3 라이선스로 상업 이용 무난).
- **anima-rl-v0.1.safetensors** — CircleStone 공식 강화학습 LoRA. 전반적인 미감과 디테일 향상. 01/03 워크플로 슬롯 1에 기본 ON(0.5)이라 필수로 분류. (트리거: 없음 / 권장 가중치: 0.5 (0.3~1.0; 공식 권장 1.0, Aesthetic 계열에서는 1 이상도 언급됨) / 기본 ON / 학습 기준: Anima preview3 (공식))

</details>

### 선택 · 토큰 불필요 (`-IncludeOptional` / `--include-optional`)

| key | 파일명 (이 이름 그대로) | 넣을 폴더 | 크기 | 사용 워크플로 | 링크 |
|---|---|---|---|---|---|
| `anima_base_v10` | `anima-base-v1.0.safetensors` | `models/diffusion_models/` | 4.18 GB | 05(대체), LoRA 학습 | [직접 받기](https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files/diffusion_models/anima-base-v1.0.safetensors) · [페이지](https://huggingface.co/circlestone-labs/Anima) |
| `lllite_any_test_v2` | `anima-lllite-any-test-like-v2.safetensors` | `models/model_patches/` | 16.4 MB | 05 | [직접 받기](https://huggingface.co/Comfy-Org/Anima-LLLite/resolve/main/model_patches/anima-lllite-any-test-like-v2.safetensors) · [페이지](https://huggingface.co/Comfy-Org/Anima-LLLite) |
| `lora_highres_boost` | `anima-highres-aesthetic-boost.safetensors` | `models/loras/` | 138.7 MB | 01 | [직접 받기](https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main/anima-highres-aesthetic-boost.safetensors) · [페이지](https://civitai.com/models/2540444) |
| `lora_turbo_v02` | `anima-turbo-lora-v0.2.safetensors` | `models/loras/` | 148.9 MB | 05 | [직접 받기](https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main/anima-turbo-lora-v0.2.safetensors) · [페이지](https://civitai.com/models/2560840) |
| `face_yolov8m` | `face_yolov8m.pt` | `models/ultralytics/bbox/` | 52.0 MB | 04 | [직접 받기](https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt) · [페이지](https://huggingface.co/Bingsu/adetailer) |
| `hand_yolov8s` | `hand_yolov8s.pt` | `models/ultralytics/bbox/` | 22.5 MB | 04 | [직접 받기](https://huggingface.co/Bingsu/adetailer/resolve/main/hand_yolov8s.pt) · [페이지](https://huggingface.co/Bingsu/adetailer) |
| `anzhc_face_seg` | `Anzhc Face seg 640 v4 y11n.pt` | `models/ultralytics/segm/` | 6.0 MB | 04(대체) | [직접 받기](https://huggingface.co/Anzhc/Anzhcs_YOLOs/resolve/main/Anzhc%20Face%20seg%20640%20v4%20y11n.pt) · [페이지](https://huggingface.co/Anzhc/Anzhcs_YOLOs) |
| `animesharp_v4_rcan` | `2x-AnimeSharpV4_RCAN.safetensors` | `models/upscale_models/` | 31.1 MB | 대체 업스케일러 | [직접 받기](https://github.com/Kim2091/Kim2091-Models/releases/download/2x-AnimeSharpV4/2x-AnimeSharpV4_RCAN.safetensors) · [페이지](https://github.com/Kim2091/Kim2091-Models/releases/tag/2x-AnimeSharpV4) |

<details><summary>각 파일 설명</summary>

- **anima-base-v1.0.safetensors** — 선택. OC LoRA 학습용 기준 모델, 공식 LLLite 학습 기준(05에서 결과가 이상할 때 교체), @작가 태그로 화풍 자유도가 가장 큰 모델.
- **anima-lllite-any-test-like-v2.safetensors** — 선택 (05 워크플로). 스케치/선화/그레이스케일 컨트롤용 Anima LLLite v2 (Base v1.0 학습). 코어 ModelPatchLoader + AnimaLLLiteApply로 사용.
- **anima-highres-aesthetic-boost.safetensors** — 1536~2048px 고해상도 안정화 + 약한 미감 향상. 01 슬롯 2, 기본 OFF. 1536px 이상 1차 생성 시에만 켜기. (트리거: 없음 / 권장 가중치: 0.5~1.0 / 기본 OFF / 학습 기준: Anima preview3 (공식))
- **anima-turbo-lora-v0.2.safetensors** — Base/Aesthetic 등 일반 Anima 모델을 8스텝 모드로 바꾸는 증류 LoRA. 05 워크플로에 기본 OFF 슬롯. Turbo v1.1 체크포인트와는 절대 같이 쓰지 않기. (트리거: 없음 / 권장 가중치: 1.0 (0.7~1.0), 켜면 CFG 1, 8~12스텝, euler/simple / 기본 OFF / 학습 기준: Anima Base v1.0 (공식))
- **face_yolov8m.pt** — 선택 (04 워크플로). FaceDetailer 얼굴 검출기. ComfyUI-Manager로 Impact Subpack을 설치하면 자동으로 받아짐 (수동 설치했다면 이 스크립트로 받기).
- **hand_yolov8s.pt** — 선택 (04 워크플로 손 디테일러, 기본 OFF). ComfyUI-Manager로 Impact Subpack을 설치하면 자동으로 받아짐 (수동 설치했다면 이 스크립트로 받기).
- **Anzhc Face seg 640 v4 y11n.pt** — 선택 대안 (04). 일러스트/애니 얼굴 세그멘테이션 검출기(box mAP50 0.835). face_yolov8m이 애니 얼굴을 놓칠 때 교체. 미검증, Subpack whitelist 필요할 수 있음.
- **2x-AnimeSharpV4_RCAN.safetensors** — 선택 대안 업스케일러 (2x, 선명한 애니 라인). UpscaleModelLoader에서 교체 가능. 라이선스 CC BY-NC-SA 4.0(비상업)이라 기본값에서 제외.

</details>

### 선택 · Civitai API 토큰 필요 (`CIVITAI_TOKEN`)

| key | 파일명 (이 이름 그대로) | 넣을 폴더 | 크기 | 사용 워크플로 | 링크 |
|---|---|---|---|---|---|
| `lora_character_sheet` | `Character Sheet for Anima.safetensors` | `models/loras/` | 69.5 MB | 03 | [직접 받기](https://civitai.com/api/download/models/2923778?fileId=2802360) · [페이지](https://civitai.com/models/2603848) |
| `lora_masterpiece_v51` | `anima-base-1-masterpiece-v51.safetensors` | `models/loras/` | 138.7 MB | 01 | [직접 받기](https://civitai.com/api/download/models/2961717?fileId=2841058) · [페이지](https://civitai.com/models/929497) |
| `lora_detail_tweaker` | `anima_context_detailer_base10.safetensors` | `models/loras/` | 91.9 MB | 01(슬롯 3 교체) | [직접 받기](https://civitai.com/api/download/models/2945421?fileId=2824598) · [페이지](https://civitai.com/models/2620171) |
| `lora_bluearchive_b1` | `BlueArchiveStyleB1.safetensors` | `models/loras/` | 137.7 MB | 02 | [직접 받기](https://civitai.com/api/download/models/2949191?fileId=2828479) · [페이지](https://civitai.com/models/2530730) |

<details><summary>각 파일 설명</summary>

- **Character Sheet for Anima.safetensors** — 화풍에 영향 없이 3면도/턴어라운드 레이아웃만 잡아주는 시트 LoRA. 03 워크플로 슬롯 2, 기본 OFF. 파일명에 공백 포함, 그대로 저장. (트리거: 1girl, multiple views, standing, full body, reference sheet, turnaround / 권장 가중치: 0.7 (0.6~0.8) / 기본 OFF / 학습 기준: Anima preview3 (작성자 샘플 메타데이터 기준))
- **anima-base-1-masterpiece-v51.safetensors** — 손으로 고른 386장 걸작으로 학습한 품질 부스터 (Civitai Anima 품질 LoRA 중 인기 상위, Anima 버전 좋아요 약 1.5천). 01 슬롯 3(LoraLoader), 기본 OFF. (트리거: masterpiece, very aesthetic (프롬프트 맨 앞) / 권장 가중치: 0.6 (0.5~1.0) / 기본 OFF / 학습 기준: Anima Base v1.0 (diffusion-pipe, rank 32))
- **anima_context_detailer_base10.safetensors** — 옷·장식 등 내용 디테일 슬라이더. 워크플로에는 기본 슬롯 없음 — 01의 슬롯 3에서 lora_name만 바꿔 사용. (트리거: 없음 / 권장 가중치: 0.3~0.5 (범위 -0.75~0.75, 양수 = 디테일 증가) / 기본 OFF / 학습 기준: Anima Base v1.0)
- **BlueArchiveStyleB1.safetensors** — 깔끔한 가챠/모바일게임 애니 화풍 예시 스타일 LoRA (원작 외 OC에도 적용됨). 02 워크플로 스타일 슬롯, 기본 OFF. 스타일 LoRA는 한 번에 하나만. (트리거: @BlueArchStyle (선택) / 권장 가중치: 0.8 (최대 1.0) / 기본 OFF / 학습 기준: Anima Base v1.0)

</details>

## 수동으로 받을 때

1. 위 표의 **직접 받기** 링크를 브라우저로 열면 바로 다운로드가 시작됩니다 (Hugging Face, GitHub 파일은 로그인 불필요).
2. 받은 파일을 표의 **넣을 폴더**로 옮깁니다. 폴더가 없으면 직접 만들어도 됩니다.
3. ComfyUI가 켜져 있다면 브라우저 화면에서 `R` 키를 눌러 모델 목록을 새로고침하거나 ComfyUI를 재시작합니다.

**Civitai 파일 (토큰 필요)**
- 브라우저로 받을 때: Civitai에 로그인한 상태에서 표의 **페이지** 링크를 열고 Download 버튼을 누릅니다. 받은 뒤 **파일명을 표와 똑같이** 바꾸세요.
- 스크립트로 받을 때: Civitai 계정 설정(Account Settings)의 API Keys 항목에서 키를 만든 뒤 `CIVITAI_TOKEN` 환경 변수에 넣고 실행합니다. 스크립트는 `Authorization: Bearer <키>` 헤더로 요청합니다.
  - 직접 curl로 받는 예: `curl -L -H "Authorization: Bearer $CIVITAI_TOKEN" -o "Character Sheet for Anima.safetensors" "https://civitai.com/api/download/models/2923778?fileId=2802360"`

## 체크섬 (sha256)

받은 파일이 깨졌는지 확인할 때 씁니다. 스크립트에 `-VerifyHash`(PowerShell) / `--verify`(bash)를 붙이면 자동으로 검사합니다.
Hugging Face 파일은 저장소의 LFS 정보, Civitai 파일은 Civitai API(model-versions)의 SHA256, GitHub 파일은 2026-10-03에 실제로 받아서 계산한 값입니다. 모든 파일에 sha256이 있어 `-VerifyHash`/`--verify`로 전부 검사할 수 있습니다.

- Windows: `Get-FileHash "파일경로" -Algorithm SHA256`
- Linux: `sha256sum 파일` / macOS: `shasum -a 256 파일`

| 파일명 | 바이트 | sha256 |
|---|---|---|
| `anima-aesthetic-v1.1.safetensors` | 4,182,230,656 | `3c1868387a3a1ff504bbb87c33678321965ead381fcf87afbd0264daa600c082` |
| `anima-turbo-v1.1.safetensors` | 4,182,230,656 | `fba11953276b57edf59d1dc4f1857ac05aa079c56f982b4d7c20298d57d3f7eb` |
| `qwen_3_06b_base.safetensors` | 1,192,135,096 | `cd2a512003e2f9f3cd3c32a9c3573f820bb28c940f73c57b1ddaa983d9223eba` |
| `qwen_image_vae.safetensors` | 253,806,246 | `a70580f0213e67967ee9c95f05bb400e8fb08307e017a924bf3441223e023d1f` |
| `RealESRGAN_x4plus_anime_6B.pth` | 17,938,799 | `f872d837d3c90ed2e05227bed711af5671a6fd1c9f7d7e91c911a61f155e99da` |
| `anima-rl-v0.1.safetensors` | 148,902,616 | `a5594421702cb50696b8ac9422273110eaaaa050aa7d98cc4fbbf5918aa5064f` |
| `anima-base-v1.0.safetensors` | 4,182,218,328 | `bd43b7cffe1ed1153d9c41e7beb2f18cb1273eafbaa3af3edd6a173dc90a006e` |
| `anima-lllite-any-test-like-v2.safetensors` | 16,403,008 | `8863424f04a2445815a827b22cbda557a085d2752e05fab54a2b303821a9e3b2` |
| `anima-highres-aesthetic-boost.safetensors` | 138,662,176 | `db5b2dcc4e1afa215058b7a85fb9377124c2e9aabd48c25e595af7199207c299` |
| `anima-turbo-lora-v0.2.safetensors` | 148,902,616 | `1b55e40bdb1d0e5a78cb498f245fccfdaae97823265db957d2aabdcf4cd3caf1` |
| `face_yolov8m.pt` | 52,026,019 | `717923c19b3f4bbf5250b728f1fa6b2cb72a33aed1d236ea9caf0e21ad943e5f` |
| `hand_yolov8s.pt` | 22,507,643 | `70b540063fbc385736d8258970744a4afbc4cbf7932134bae3b24cdadeadec06` |
| `Anzhc Face seg 640 v4 y11n.pt` | 6,020,644 | `1e77ad7bd349babd8a4a90478bfc965348642b63a8d95d3b43ee13db42fd0a64` |
| `2x-AnimeSharpV4_RCAN.safetensors` | 31,053,198 | `6470bb91d6622d6acdff81132c1a8615b961b919ce2b9a01ce993378500cfbe1` |
| `Character Sheet for Anima.safetensors` | 69,485,048 | `01521d0b8ecfec8448d705175c99cf2e148275f5a60589d7a0c235bd76906959` |
| `anima-base-1-masterpiece-v51.safetensors` | 138,662,176 | `b330b46df1c71e4409d7b60ecf45df4ee26310fa914c398226c7800cc2912936` |
| `anima_context_detailer_base10.safetensors` | 91,851,400 | `aaaca6107e97bf98d03482464583a0d89fbf14acec8e01685682f11a02915d22` |
| `BlueArchiveStyleB1.safetensors` | 약 137.7 MB (정확한 바이트 미공개) | `05eaec899cf03412dea811f9e7820e898056774f8e65fb24e64fed79d99875e7` |

## 라이선스 메모

- **Anima 모델(Base/Aesthetic/Turbo)과 공식 LoRA**: CircleStone Labs 비상업 라이선스(+NVIDIA Open Model License). 모델을 유료 API·유료 생성 서비스로 제공하거나 유료 제품에 내장하는 것은 금지입니다(별도 라이선스 필요). 단, 라이선스 2.c의 예외로 개인이 파생 가중치(예: 직접 학습한 LoRA)를 판매하는 것은 허용됩니다. 공식 카드에 따르면 **생성한 이미지는 상업적으로 이용할 수 있습니다**.
- **Civitai LoRA**: 각 모델 페이지의 라이선스를 따로 확인하세요.
- **RealESRGAN_x4plus_anime_6B**: BSD-3 (상업 이용 무난).
- **2x-AnimeSharpV4_RCAN**: CC BY-NC-SA 4.0 (비상업). 그래서 기본값이 아니라 선택 대안으로만 넣었습니다.
