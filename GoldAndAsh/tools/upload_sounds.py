#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Upload Gold & Ash audio (sfx_sprite.ogg + 4 music loops) to Roblox via the Open Cloud Assets API
and write the resulting asset IDs into src/shared/SoundIds.luau.

Standard library only (urllib). Run `python3 tools/upload_sounds.py --help` for usage.
"""
from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOUNDS_DIR = ROOT / "assets" / "sounds"
SOUND_IDS_PATH = ROOT / "src" / "shared" / "SoundIds.luau"

ASSETS_URL = "https://apis.roblox.com/assets/v1/assets"
OPERATION_URL = "https://apis.roblox.com/assets/v1/operations/{}"

# (key in SoundIds.luau, file in assets/sounds, displayName (<= 50 chars), description)
ITEMS = [
    ("sprite", "sfx_sprite.ogg", "GoldAndAsh SFX Sprite",
     "Gold & Ash - all sound effects in one sprite (use Sound.PlaybackRegion)."),
    ("music_lobby", "music_lobby.ogg", "GoldAndAsh Music Lobby", "Gold & Ash - lobby / character select loop."),
    ("music_battle", "music_battle.ogg", "GoldAndAsh Music Battle", "Gold & Ash - battle music loop."),
    ("music_lin_awaken", "music_lin_awaken.ogg", "GoldAndAsh Music Lin Awaken",
     "Gold & Ash - Lin Yuan awakening theme loop."),
    ("music_ren_awaken", "music_ren_awaken.ogg", "GoldAndAsh Music Ren Awaken",
     "Gold & Ash - Kanzaki Ren awakening theme loop."),
]
KEYS = [k for k, *_ in ITEMS]

HELP = """\
금빛과 재 (Gold & Ash) 오디오 업로드 도구 / audio upload helper
=====================================================================
[한국어]
  assets/sounds/ 의 sfx_sprite.ogg 와 음악 4개(총 5개 파일)를 Roblox Open Cloud
  Assets API 로 업로드하고, 받은 에셋 ID 를 src/shared/SoundIds.luau 에 자동으로 써 넣습니다.

  준비:
    1) https://create.roblox.com/dashboard/credentials 에서 API 키 생성
       - 권한(Access Permissions): "Assets API" 추가 -> asset:read, asset:write
       - 그룹 게임이라면 그룹 소유로 키를 만들거나 그룹 권한이 있는 키를 사용
       - Accepted IP Addresses 에 현재 IP(또는 0.0.0.0/0) 추가
    2) 본인 User ID(프로필 URL 의 숫자) 또는 Group ID 확인
  실행 예:
    python3 tools/upload_sounds.py --api-key <키> --user-id 12345678
    ROBLOX_API_KEY=<키> python3 tools/upload_sounds.py --group-id 987654
    python3 tools/upload_sounds.py --user-id 123 --only sprite       (스프라이트만)
    python3 tools/upload_sounds.py --user-id 123 --dry-run           (업로드 없이 확인)
  참고:
    - 이미 SoundIds.luau 에 0 이 아닌 ID 가 있는 항목은 건너뜁니다 (--force 로 재업로드).
      본인인증 안 된 계정은 한 달에 오디오 업로드 수가 적으니(약 10개) 아껴 쓰세요.
    - 업로드 후 오디오가 검토(moderation) 중이면 잠시 뒤에 소리가 납니다.
    - 성공한 항목은 바로바로 SoundIds.luau 에 저장되므로 중간에 실패해도 다시 실행하면 됩니다.

[English]
  Uploads assets/sounds/sfx_sprite.ogg + the 4 music loops (5 files) through the Roblox Open Cloud
  Assets API and writes the new asset IDs into src/shared/SoundIds.luau.

  Setup:
    1) Create an API key at https://create.roblox.com/dashboard/credentials
       with the "Assets API" permission (asset:read + asset:write) and your IP allowed.
    2) Find your numeric User ID (profile URL) or the Group ID that should own the audio.
  Examples:
    python3 tools/upload_sounds.py --api-key <KEY> --user-id 12345678
    ROBLOX_API_KEY=<KEY> python3 tools/upload_sounds.py --group-id 987654
    python3 tools/upload_sounds.py --user-id 123 --only sprite music_battle
    python3 tools/upload_sounds.py --user-id 123 --dry-run
  Notes:
    - Entries that already have a non-zero ID in SoundIds.luau are skipped unless --force is given
      (unverified accounts only get ~10 audio uploads per month).
    - Each successful upload is saved to SoundIds.luau immediately, so re-running resumes safely.
"""


class ApiError(RuntimeError):
    pass


def _rel(p: Path) -> Path:
    try:
        return p.resolve().relative_to(ROOT)
    except ValueError:
        return p


# ---------------------------------------------------------------------------------------------
#  HTTP helpers
# ---------------------------------------------------------------------------------------------

def _multipart(fields: list[tuple[str, bytes, str | None, str]]) -> tuple[bytes, str]:
    """fields: (name, data, filename or None, content_type) -> (body, content-type header)."""
    boundary = "----GoldAndAsh" + uuid.uuid4().hex
    out = bytearray()
    for name, data, filename, ctype in fields:
        out += f"--{boundary}\r\n".encode()
        disp = f'Content-Disposition: form-data; name="{name}"'
        if filename:
            disp += f'; filename="{filename}"'
        out += (disp + "\r\n").encode()
        out += f"Content-Type: {ctype}\r\n\r\n".encode()
        out += data
        out += b"\r\n"
    out += f"--{boundary}--\r\n".encode()
    return bytes(out), f"multipart/form-data; boundary={boundary}"


def _request(method: str, url: str, api_key: str, body: bytes | None = None, content_type: str | None = None,
             retries: int = 5, timeout: float = 120.0) -> dict:
    headers = {"x-api-key": api_key, "Accept": "application/json", "User-Agent": "GoldAndAsh-upload/1.0"}
    if content_type:
        headers["Content-Type"] = content_type
    delay = 2.0
    for attempt in range(1, retries + 1):
        req = urllib.request.Request(url, data=body, method=method, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                raw = resp.read().decode("utf-8", "replace")
                return json.loads(raw) if raw.strip() else {}
        except urllib.error.HTTPError as e:
            text = e.read().decode("utf-8", "replace")
            retryable = e.code == 429 or 500 <= e.code < 600
            if retryable and attempt < retries:
                wait = delay
                ra = e.headers.get("Retry-After") if e.headers else None
                if ra and ra.strip().isdigit():
                    wait = max(wait, float(ra))
                print(f"    HTTP {e.code}; retrying in {wait:.0f}s ...")
                time.sleep(wait)
                delay = min(delay * 2, 60.0)
                continue
            hint = ""
            if e.code == 401:
                hint = " (API key invalid / expired, or your IP is not in the key's allowed list)"
            elif e.code == 403:
                hint = " (key lacks asset:write permission for this user/group, or upload quota reached)"
            raise ApiError(f"HTTP {e.code} for {method} {url}{hint}\n{text}") from None
        except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
            if attempt < retries:
                print(f"    network error ({e}); retrying in {delay:.0f}s ...")
                time.sleep(delay)
                delay = min(delay * 2, 60.0)
                continue
            raise ApiError(f"network error for {method} {url}: {e}") from None
    raise ApiError("unreachable")


def _operation_id(op: dict) -> str | None:
    if op.get("operationId"):
        return str(op["operationId"])
    path = op.get("path") or ""
    if path.startswith("operations/"):
        return path.split("/", 1)[1]
    return None


def _asset_id_from(op: dict) -> str | None:
    resp = op.get("response") or {}
    if resp.get("assetId"):
        return str(resp["assetId"])
    path = resp.get("path") or ""
    m = re.match(r"assets/(\d+)", path)
    return m.group(1) if m else None


def upload_one(path: Path, display: str, desc: str, creator: dict, api_key: str,
               poll_timeout: float, poll_interval: float) -> tuple[str, str]:
    request = {
        "assetType": "Audio",
        "displayName": display[:50],
        "description": desc[:1000],
        "creationContext": {"creator": creator},
    }
    body, ctype = _multipart([
        ("request", json.dumps(request).encode("utf-8"), None, "application/json"),
        ("fileContent", path.read_bytes(), path.name, "audio/ogg"),
    ])
    op = _request("POST", ASSETS_URL, api_key, body, ctype)
    t0 = time.time()
    while True:
        if op.get("error"):
            raise ApiError(f"upload failed: {json.dumps(op['error'])}")
        if op.get("done"):
            asset_id = _asset_id_from(op)
            if not asset_id:
                raise ApiError(f"operation finished without an assetId: {json.dumps(op)}")
            state = ((op.get("response") or {}).get("moderationResult") or {}).get("moderationState", "unknown")
            return asset_id, state
        op_id = _operation_id(op)
        if not op_id:
            raise ApiError(f"unexpected response (no operation id): {json.dumps(op)}")
        if time.time() - t0 > poll_timeout:
            raise ApiError(f"timed out waiting for operation {op_id}; check it later with\n"
                           f"  GET {OPERATION_URL.format(op_id)}")
        time.sleep(poll_interval)
        op = _request("GET", OPERATION_URL.format(op_id), api_key)
        if not op.get("path") and not op.get("done"):
            op["operationId"] = op_id


# ---------------------------------------------------------------------------------------------
#  SoundIds.luau
# ---------------------------------------------------------------------------------------------

def read_ids() -> dict[str, int]:
    ids = {k: 0 for k in KEYS}
    if SOUND_IDS_PATH.exists():
        for key, val in re.findall(r"^\s*([A-Za-z_]\w*)\s*=\s*(\d+)", SOUND_IDS_PATH.read_text(encoding="utf-8"),
                                   flags=re.M):
            if key in ids:
                ids[key] = int(val)
    return ids


def write_ids(ids: dict[str, int]) -> None:
    lines = [
        "--!strict",
        "-- 로블록스에 업로드한 오디오 에셋 ID를 여기에 넣으세요. 0이면 내장(fallback) 사운드를 씁니다.",
        "-- tools/upload_sounds.py 를 실행하면 자동으로 채워집니다.",
        "local SoundIds = {",
        f"\tsprite = {ids['sprite']}, -- assets/sounds/sfx_sprite.ogg",
        f"\tmusic_lobby = {ids['music_lobby']},",
        f"\tmusic_battle = {ids['music_battle']},",
        f"\tmusic_lin_awaken = {ids['music_lin_awaken']},",
        f"\tmusic_ren_awaken = {ids['music_ren_awaken']},",
        "}",
        "return SoundIds",
        "",
    ]
    SOUND_IDS_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = SOUND_IDS_PATH.with_suffix(".luau.tmp")
    tmp.write_text("\n".join(lines), encoding="utf-8")
    os.replace(tmp, SOUND_IDS_PATH)


# ---------------------------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(prog="upload_sounds.py", description=HELP,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--api-key", default=os.environ.get("ROBLOX_API_KEY"),
                    help="Open Cloud API key (기본값: 환경변수 ROBLOX_API_KEY)")
    who = ap.add_mutually_exclusive_group(required=True)
    who.add_argument("--user-id", type=int, help="업로드할 본인 User ID / creator user id")
    who.add_argument("--group-id", type=int, help="업로드할 그룹 ID / creator group id")
    ap.add_argument("--only", nargs="+", choices=KEYS, metavar="KEY",
                    help=f"이 항목만 업로드 / only these entries: {', '.join(KEYS)}")
    ap.add_argument("--force", action="store_true", help="이미 ID가 있어도 다시 업로드 / re-upload even if an ID exists")
    ap.add_argument("--dry-run", action="store_true", help="업로드하지 않고 계획만 출력 / print the plan only")
    ap.add_argument("--timeout", type=float, default=300.0, help="항목당 처리 대기 최대 초 / max seconds to wait per upload")
    ap.add_argument("--poll-interval", type=float, default=2.0, help="상태 확인 간격(초) / operation poll interval")
    args = ap.parse_args()

    if not args.api_key and not args.dry_run:
        ap.error("API 키가 필요합니다: --api-key 또는 ROBLOX_API_KEY / an API key is required")
    creator = {"userId": str(args.user_id)} if args.user_id is not None else {"groupId": str(args.group_id)}

    ids = read_ids()
    todo = []
    for key, fname, display, desc in ITEMS:
        if args.only and key not in args.only:
            continue
        path = SOUNDS_DIR / fname
        if not path.exists():
            print(f"[skip] {key}: {_rel(path)} 없음 / missing -- run tools/gen_sounds.py first")
            continue
        if ids.get(key, 0) and not args.force:
            print(f"[skip] {key}: 이미 ID {ids[key]} 있음 / already uploaded (use --force to re-upload)")
            continue
        size_mb = path.stat().st_size / 1e6
        if size_mb > 20:
            print(f"[warn] {key}: {size_mb:.1f} MB -- Roblox audio uploads are limited to 20 MB")
        todo.append((key, path, display, desc))

    if not todo:
        print("업로드할 항목이 없습니다 / nothing to upload.")
        return 0
    print(f"업로드 대상 / to upload ({len(todo)}): " + ", ".join(k for k, *_ in todo))
    if args.dry_run:
        for key, path, display, _ in todo:
            print(f"  {key:<18s} {_rel(path)}  ({path.stat().st_size / 1e6:.2f} MB) as '{display}'")
        return 0

    failures = 0
    for key, path, display, desc in todo:
        print(f"-> {key}: uploading {path.name} ({path.stat().st_size / 1e6:.2f} MB) ...")
        try:
            asset_id, state = upload_one(path, display, desc, creator, args.api_key, args.timeout, args.poll_interval)
        except ApiError as e:
            failures += 1
            print(f"   실패 / FAILED: {e}")
            continue
        ids[key] = int(asset_id)
        write_ids(ids)
        note = "" if state.lower() in ("approved", "unknown") else f"  (moderation: {state})"
        print(f"   OK  rbxassetid://{asset_id}{note}")

    print(f"\nSoundIds.luau: {_rel(SOUND_IDS_PATH)}")
    for key in KEYS:
        print(f"  {key:<18s} {ids[key]}")
    if failures:
        print(f"\n{failures}개 실패 / {failures} upload(s) failed -- 다시 실행하면 남은 것만 올립니다 / re-run to retry.")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
