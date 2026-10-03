#!/usr/bin/env python3
"""ComfyUI 자캐(OC) 세팅용 모델/LoRA 자동 다운로더.

표준 라이브러리만 사용하므로 ComfyUI에 딸린 파이썬으로도 바로 실행됩니다.

사용 예:
  python download_models.py --comfy "C:/ComfyUI_windows_portable/ComfyUI"
  python download_models.py --comfy ~/ComfyUI --set anima
  python download_models.py --comfy ~/ComfyUI --civitai-token 내토큰

--set
  anima : Anima 워크플로우(①②)에 필요한 파일
  sdxl  : WAI-Illustrious 워크플로우(③)에 필요한 파일
  all   : 전부 (기본값)
"""
import argparse
import hashlib
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HF_ANIMA = "https://huggingface.co/circlestone-labs/Anima/resolve/main/split_files"
HF_ANIMA_LORA = "https://huggingface.co/circlestone-labs/Anima-Official-LoRAs/resolve/main"
CIVITAI = "https://civitai.com/api/download/models"

# (세트, 하위폴더, 파일명, URL, sha256 또는 None, 설명)
FILES = [
    # ---- Anima (워크플로우 ①②) ----
    ("anima", "diffusion_models", "anima-aesthetic-v1.1.safetensors",
     f"{HF_ANIMA}/diffusion_models/anima-aesthetic-v1.1.safetensors",
     "3c1868387a3a1ff504bbb87c33678321965ead381fcf87afbd0264daa600c082", "Anima Aesthetic v1.1 (메인, 4.2GB)"),
    ("anima", "diffusion_models", "anima-turbo-v1.1.safetensors",
     f"{HF_ANIMA}/diffusion_models/anima-turbo-v1.1.safetensors",
     "fba11953276b57edf59d1dc4f1857ac05aa079c56f982b4d7c20298d57d3f7eb", "Anima Turbo v1.1 (시안용, 4.2GB)"),
    ("anima", "text_encoders", "qwen_3_06b_base.safetensors",
     f"{HF_ANIMA}/text_encoders/qwen_3_06b_base.safetensors",
     "cd2a512003e2f9f3cd3c32a9c3573f820bb28c940f73c57b1ddaa983d9223eba", "Qwen3 0.6B 텍스트 인코더 (1.2GB)"),
    ("anima", "vae", "qwen_image_vae.safetensors",
     f"{HF_ANIMA}/vae/qwen_image_vae.safetensors",
     "a70580f0213e67967ee9c95f05bb400e8fb08307e017a924bf3441223e023d1f", "Qwen-Image VAE (254MB)"),
    ("anima", "loras", "anima-rl-v0.1.safetensors",
     f"{HF_ANIMA_LORA}/anima-rl-v0.1.safetensors",
     "68ed0aec6ff4ebc3add1180e191797adb5aa6b69dd8b0fc8aa9e680145f65aac", "LoRA: Anima RL v0.1 (공식, 디테일·미감)"),
    ("anima", "loras", "anima-base-1-masterpiece-v51.safetensors",
     f"{CIVITAI}/2961717?fileId=2841058",
     "b330b46df1c71e4409d7b60ecf45df4ee26310fa914c398226c7800cc2912936", "LoRA: Aesthetic Masterpiece v5.1 [Anima]"),
    # ---- WAI-Illustrious SDXL (워크플로우 ③) ----
    ("sdxl", "checkpoints", "waiIllustriousSDXL_v170.safetensors",
     f"{CIVITAI}/2883731?fileId=2763986",
     "f116b0c78ff441467b0cdc8f1936e1ed18ea31e9997c7b132b1b8db533f0bd04", "WAI-Illustrious-SDXL v17 (6.9GB)"),
    ("sdxl", "loras", "illustrious_masterpieces_v3.safetensors",
     f"{CIVITAI}/2247497?fileId=2139998",
     "8d9ee4bd2a16c2c72c1e176d247d379c59312585ea3d154e55492ca34d0313fe", "LoRA: Aesthetic Masterpiece v3 [Illustrious]"),
    ("sdxl", "loras", "DetailerILv2-000008.safetensors",
     f"{CIVITAI}/1736373?fileId=1636985",
     "528277aedc0e3bd8a350b66e4f5af0488a10e0eba99c9974db0b43d17145ce01", "LoRA: Detailer IL v2"),
    # ---- 공용 (워크플로우 ②③) ----
    ("common", "upscale_models", "RealESRGAN_x4plus_anime_6B.pth",
     "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.2.4/RealESRGAN_x4plus_anime_6B.pth",
     None, "업스케일러: R-ESRGAN 4x+ Anime6B"),
    ("common", os.path.join("ultralytics", "bbox"), "face_yolov8m.pt",
     "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt",
     None, "얼굴 감지 YOLOv8m (FaceDetailer용)"),
]

UA = "Mozilla/5.0 (ComfyUI-OC-setup downloader)"
CHUNK = 1024 * 1024


def resolve_models_dir(path):
    path = os.path.abspath(os.path.expanduser(path))
    if os.path.basename(path.rstrip("\\/")) == "models":
        return path
    if os.path.isdir(os.path.join(path, "models")):
        return os.path.join(path, "models")
    sys.exit(f"[오류] '{path}' 안에서 models 폴더를 찾을 수 없습니다. ComfyUI 폴더(또는 models 폴더) 경로를 지정하세요.")


def sha256_of(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(CHUNK * 8), b""):
            h.update(block)
    return h.hexdigest()


def with_token(url, token):
    if not token or "civitai.com" not in url:
        return url
    sep = "&" if "?" in url else "?"
    return f"{url}{sep}token={urllib.parse.quote(token)}"


def fmt_size(n):
    for unit in ("B", "KB", "MB", "GB"):
        if n < 1024:
            return f"{n:.1f}{unit}"
        n /= 1024
    return f"{n:.1f}TB"


def download(url, dest, retries=4):
    part = dest + ".part"
    for attempt in range(1, retries + 1):
        have = os.path.getsize(part) if os.path.exists(part) else 0
        req = urllib.request.Request(url, headers={"User-Agent": UA})
        if have:
            req.add_header("Range", f"bytes={have}-")
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                if have and resp.status != 206:  # 서버가 이어받기를 지원하지 않음
                    have = 0
                total = resp.headers.get("Content-Length")
                total = int(total) + have if total else None
                mode = "ab" if have else "wb"
                done, t0, last = have, time.time(), 0.0
                with open(part, mode) as f:
                    while True:
                        chunk = resp.read(CHUNK)
                        if not chunk:
                            break
                        f.write(chunk)
                        done += len(chunk)
                        now = time.time()
                        if now - last > 0.5:
                            last = now
                            speed = (done - have) / max(now - t0, 1e-6)
                            pct = f"{done * 100 / total:5.1f}%" if total else "  ?  "
                            print(f"\r    {pct}  {fmt_size(done)}  {fmt_size(speed)}/s   ", end="", flush=True)
                print(f"\r    완료  {fmt_size(done)}                    ")
                if total and done < total:
                    raise IOError(f"받은 크기 {done} < 예상 {total}")
            os.replace(part, dest)
            return True
        except urllib.error.HTTPError as e:
            print()
            if e.code in (401, 403) and "civitai.com" in url:
                print("    [실패] Civitai 로그인이 필요한 파일입니다. --civitai-token 옵션에 API 키를 넣어 다시 실행하세요.")
                print("           (Civitai → 프로필 → Settings → API Keys 에서 발급)")
                return False
            if e.code == 416:  # 이미 다 받은 .part
                os.replace(part, dest)
                return True
            print(f"    [재시도 {attempt}/{retries}] HTTP {e.code}")
        except (urllib.error.URLError, IOError, TimeoutError) as e:
            print()
            print(f"    [재시도 {attempt}/{retries}] {e}")
        time.sleep(2 ** attempt)
    return False


def main():
    ap = argparse.ArgumentParser(description="ComfyUI 자캐 세팅용 모델 다운로더")
    ap.add_argument("--comfy", required=True, help="ComfyUI 폴더 경로 (models 폴더가 들어있는 곳) 또는 models 폴더 경로")
    ap.add_argument("--set", choices=["all", "anima", "sdxl"], default="all", help="받을 세트 (기본: all)")
    ap.add_argument("--no-turbo", action="store_true", help="Anima Turbo(시안용 4.2GB) 건너뛰기")
    ap.add_argument("--civitai-token", default=os.environ.get("CIVITAI_TOKEN"),
                    help="Civitai API 키 (환경변수 CIVITAI_TOKEN 으로도 가능)")
    ap.add_argument("--skip-verify", action="store_true", help="SHA256 검증 생략")
    args = ap.parse_args()

    models = resolve_models_dir(args.comfy)
    print(f"모델 폴더: {models}\n")

    wanted = []
    for entry in FILES:
        group, sub, name = entry[0], entry[1], entry[2]
        if args.set != "all" and group not in (args.set, "common"):
            continue
        if args.no_turbo and name.startswith("anima-turbo"):
            continue
        wanted.append(entry)

    failed = []
    for group, sub, name, url, sha, desc in wanted:
        folder = os.path.join(models, sub)
        os.makedirs(folder, exist_ok=True)
        dest = os.path.join(folder, name)
        print(f"■ {desc}\n    → {os.path.relpath(dest, models)}")
        if os.path.exists(dest):
            print("    이미 있음, 건너뜀")
            continue
        if not download(with_token(url, args.civitai_token), dest):
            failed.append(name)
            continue
        if sha and not args.skip_verify:
            print("    SHA256 확인 중...", end="", flush=True)
            got = sha256_of(dest)
            if got.lower() != sha.lower():
                print(" 불일치! 파일을 삭제합니다.")
                os.remove(dest)
                failed.append(name)
                continue
            print(" OK")

    print()
    if failed:
        print("다운로드 실패:", ", ".join(failed))
        print("README.md 의 '수동 다운로드' 표에서 링크를 직접 받아 같은 폴더에 넣어도 됩니다.")
        sys.exit(1)
    print("완료! ComfyUI를 재시작(또는 R 키로 새로고침)한 뒤 workflows 폴더의 JSON을 끌어다 놓으세요.")


if __name__ == "__main__":
    main()
