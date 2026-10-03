#!/usr/bin/env bash
# =============================================================================
#  download_models.sh — Anima(DiT) 자캐 디자인 세팅용 모델 다운로더
#  Linux / macOS / Windows(Git Bash, WSL)용. Windows PowerShell은 download_models.ps1을 쓰세요.
#
#  같은 폴더의 models.json을 읽어서 ComfyUI/models/ 아래 올바른 폴더에 받습니다.
#   - 이미 있는 파일은 건너뜁니다.
#   - 중간에 끊겨도 다시 실행하면 이어받습니다 (.part 파일, curl -C - / wget -c).
#   - 기본은 필수 파일만, --include-optional 을 붙이면 선택 파일까지 받습니다.
#   - Civitai LoRA는 CIVITAI_TOKEN 환경 변수가 있을 때만 받습니다.
#   - HF_TOKEN 이 있으면 huggingface.co 요청에 붙입니다 (공식 파일은 토큰 없이도 받아집니다).
#
#  사용 예:
#    bash download_models.sh --comfy-dir ~/ComfyUI
#    bash download_models.sh -d ~/ComfyUI --include-optional
#    CIVITAI_TOKEN=xxxx bash download_models.sh -d ~/ComfyUI --include-optional
#    bash download_models.sh -d ~/ComfyUI --only lllite_any_test_v2,lora_turbo_v02
#    bash download_models.sh --list
# =============================================================================
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="${MODELS_JSON:-$SCRIPT_DIR/models.json}"

COMFY_DIR="${COMFYUI_DIR:-}"
INCLUDE_OPTIONAL=0
ONLY=""
DRY_RUN=0
LIST_ONLY=0
VERIFY=0
ASSUME_YES=0

say()  { printf '%s\n' "$*"; }
info() { printf '\033[36m[정보]\033[0m %s\n' "$*"; }
ok()   { printf '\033[32m[완료]\033[0m %s\n' "$*"; }
skip() { printf '\033[90m[건너뜀]\033[0m %s\n' "$*"; }
warn() { printf '\033[33m[주의]\033[0m %s\n' "$*" >&2; }
err()  { printf '\033[31m[오류]\033[0m %s\n' "$*" >&2; }

usage() {
  cat <<'EOF'
사용법: bash download_models.sh [옵션] [ComfyUI 폴더]

옵션
  -d, --comfy-dir DIR      ComfyUI 폴더 (models 폴더가 들어 있는 곳).
                           ComfyUI_windows_portable 폴더나 models 폴더 자체를 줘도 됩니다.
                           생략하면 COMFYUI_DIR 환경 변수, 현재 폴더, ~/ComfyUI,
                           ~/Documents/ComfyUI 등을 자동으로 찾습니다.
  -o, --include-optional   선택 파일(Base v1.0, LLLite, 추가 LoRA, 검출기 등)도 받기
      --only KEY[,KEY...]  지정한 key만 받기 (key 목록은 --list 로 확인)
      --list               파일 목록만 보여주고 끝내기
      --dry-run            실제로 받지 않고 무엇을 할지만 출력
      --verify             sha256 값이 있는 파일은 다운로드 후 해시 검사 (시간이 걸림)
  -y, --yes                자동 감지한 폴더를 묻지 않고 바로 사용
  -h, --help               도움말

환경 변수
  CIVITAI_TOKEN   Civitai API 키 (Civitai LoRA 4종에 필요)
  HF_TOKEN        Hugging Face 토큰 (선택, 공식 파일은 없어도 됨)
  COMFYUI_DIR     ComfyUI 폴더 기본값
  MODELS_JSON     models.json 경로 (기본: 스크립트와 같은 폴더)
  PYTHON          models.json을 읽을 파이썬 실행 파일 (기본: python3)
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--comfy-dir)
      [ $# -ge 2 ] || { err "$1 뒤에 폴더 경로가 필요합니다."; exit 2; }
      COMFY_DIR="$2"; shift 2 ;;
    --comfy-dir=*) COMFY_DIR="${1#*=}"; shift ;;
    -o|--include-optional) INCLUDE_OPTIONAL=1; shift ;;
    --only)
      [ $# -ge 2 ] || { err "--only 뒤에 key 목록이 필요합니다."; exit 2; }
      ONLY="$2"; shift 2 ;;
    --only=*) ONLY="${1#*=}"; shift ;;
    --list) LIST_ONLY=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --verify) VERIFY=1; shift ;;
    -y|--yes) ASSUME_YES=1; shift ;;
    -h|--help) usage; exit 0 ;;
    -*) err "알 수 없는 옵션: $1"; usage; exit 2 ;;
    *) COMFY_DIR="$1"; shift ;;
  esac
done

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# 1) models.json 읽기 (python3 → python(3.x) → jq 순서로 시도)
#    출력 형식: key|filename|url|dir|size|bytes|sha256|required|needs_token|token_env
# ---------------------------------------------------------------------------
[ -f "$MANIFEST" ] || { err "models.json을 찾을 수 없습니다: $MANIFEST"; exit 1; }

PY_PARSER='
import io, json, sys
d = json.load(io.open(sys.argv[1], encoding="utf-8"))
def s(v):
    if v is None or v == "":
        return "-"
    if isinstance(v, bool):
        return "true" if v else "false"
    return str(v)
for f in d["files"]:
    print("|".join(s(f.get(k)) for k in
        ("key", "filename", "url", "dir", "size", "bytes", "sha256",
         "required", "needs_token", "token_env")))
'

parse_manifest() {
  local py=""
  for cand in "${PYTHON:-}" python3 python; do
    [ -n "$cand" ] || continue
    if have "$cand" && "$cand" -c 'import sys; sys.exit(0 if sys.version_info[0] >= 3 else 1)' 2>/dev/null; then
      py="$cand"; break
    fi
  done
  if [ -n "$py" ]; then
    "$py" -c "$PY_PARSER" "$MANIFEST"
  elif have jq; then
    jq -r '.files[] | [.key, .filename, .url, .dir, .size, .bytes, .sha256, .required, .needs_token, .token_env]
           | map(if . == null or . == "" then "-" else tostring end) | join("|")' "$MANIFEST"
  else
    err "models.json을 읽으려면 python3 또는 jq가 필요합니다. (PYTHON=/경로/python 으로 지정 가능)"
    return 1
  fi
}

MANIFEST_ROWS="$(parse_manifest)" || exit 1
[ -n "$MANIFEST_ROWS" ] || { err "models.json에 파일 목록이 없습니다."; exit 1; }

if [ "$LIST_ONLY" -eq 1 ]; then
  printf '%-22s %-8s %-6s %-9s %s\n' "KEY" "구분" "토큰" "크기" "폴더/파일명"
  while IFS='|' read -r key filename url dir size bytes sha required needs_token token_env; do
    req="선택"; [ "$required" = "true" ] && req="필수"
    tok="-";   [ "$needs_token" = "true" ] && tok="필요"
    [ "$size" = "-" ] && size="?"
    printf '%-22s %-8s %-6s %-9s %s\n' "$key" "$req" "$tok" "$size" "$dir/$filename"
  done <<< "$MANIFEST_ROWS"
  exit 0
fi

# ---------------------------------------------------------------------------
# 2) ComfyUI models 폴더 찾기
# ---------------------------------------------------------------------------
# 주어진 경로에서 models 폴더를 찾아 출력. 못 찾으면 아무것도 출력하지 않음.
resolve_models_dir() {
  local c="$1"
  [ -n "$c" ] || return 0
  case "$c" in \~|\~/*) c="$HOME${c#\~}" ;; esac  # 따옴표로 넘어온 ~ 처리
  if [ -d "$c/models" ]; then
    (cd "$c/models" && pwd)
  elif [ -d "$c/ComfyUI/models" ]; then          # ComfyUI_windows_portable 루트
    (cd "$c/ComfyUI/models" && pwd)
  elif [ "$(basename "$c")" = "models" ]; then    # models 폴더 자체를 지정
    if [ -d "$c" ]; then (cd "$c" && pwd); else printf '%s\n' "$c"; fi
  fi
}

# 자동 감지용: models 폴더 옆에 main.py 또는 custom_nodes 가 있어야 ComfyUI로 인정
looks_like_comfy() {
  local m="$1" root
  [ -d "$m" ] || return 1
  root="$(dirname "$m")"
  [ -f "$root/main.py" ] || [ -d "$root/custom_nodes" ]
}

MODELS_DIR=""
if [ -n "$COMFY_DIR" ]; then
  MODELS_DIR="$(resolve_models_dir "$COMFY_DIR")"
  if [ -z "$MODELS_DIR" ]; then
    err "ComfyUI 폴더를 찾지 못했습니다: $COMFY_DIR"
    say "  ComfyUI 폴더(models 폴더가 있는 곳)나 models 폴더 경로를 지정하세요."
    say "  예) bash download_models.sh -d ~/ComfyUI"
    exit 1
  fi
else
  for cand in "$PWD" "$SCRIPT_DIR/.." "$SCRIPT_DIR/../.." \
              "$HOME/ComfyUI" "$HOME/Documents/ComfyUI" "$HOME/comfyui" \
              "$HOME/ComfyUI_windows_portable" "$HOME/Desktop/ComfyUI_windows_portable" \
              "/c/ComfyUI_windows_portable" "/mnt/c/ComfyUI_windows_portable"; do
    m="$(resolve_models_dir "$cand")"
    if [ -n "$m" ] && looks_like_comfy "$m"; then MODELS_DIR="$m"; break; fi
  done
  if [ -z "$MODELS_DIR" ]; then
    err "ComfyUI 폴더를 자동으로 찾지 못했습니다. --comfy-dir 로 직접 지정하세요."
    say "  예) bash download_models.sh --comfy-dir ~/ComfyUI"
    exit 1
  fi
  info "자동으로 찾은 ComfyUI models 폴더: $MODELS_DIR"
  if [ "$ASSUME_YES" -eq 0 ] && [ "$DRY_RUN" -eq 0 ] && [ -t 0 ]; then
    printf '이 폴더에 받을까요? [Y/n] '
    read -r answer || answer=""
    case "$answer" in [nN]*) say "취소했습니다. --comfy-dir 로 폴더를 지정하세요."; exit 1 ;; esac
  fi
fi
info "대상 폴더: $MODELS_DIR"

# ---------------------------------------------------------------------------
# 3) 다운로드 도구
# ---------------------------------------------------------------------------
DL_TOOL=""
if have curl; then DL_TOOL="curl"; elif have wget; then DL_TOOL="wget"; else
  err "curl 또는 wget이 필요합니다."; exit 1
fi

file_size() {
  if [ -f "$1" ]; then
    stat -c %s "$1" 2>/dev/null || stat -f %z "$1" 2>/dev/null || wc -c < "$1" | tr -d ' '
  else
    echo 0
  fi
}

sha256_of() {
  if have sha256sum; then sha256sum "$1" | awk '{print $1}'
  elif have shasum; then shasum -a 256 "$1" | awk '{print $1}'
  else echo ""; fi
}

# 받은 파일이 모델이 아니라 오류 페이지(HTML/JSON)인지 간단히 검사
looks_like_error_page() {
  local f="$1" sz first
  sz="$(file_size "$f")"
  [ "$sz" -lt 200000 ] || return 1
  first="$(head -c 1 "$f" 2>/dev/null)"
  [ "$first" = "<" ] || [ "$first" = "{" ]
}

# fetch URL PART_FILE AUTH_TOKEN(빈 문자열 가능) IS_CIVITAI(0/1)
fetch() {
  local url="$1" part="$2" token="$3" civitai="$4"
  if [ "$DL_TOOL" = "curl" ]; then
    local args=(-fL --retry 5 --retry-delay 3 --connect-timeout 30 -C - -o "$part")
    if [ -t 1 ]; then args+=(--progress-bar); else args+=(-sS); fi
    # curl은 다른 호스트로 리다이렉트될 때 Authorization 헤더를 자동으로 떼어냅니다.
    [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
    curl "${args[@]}" "$url"
  else
    local wargs=(-c -O "$part" --tries=5 --waitretry=3 --timeout=60)
    local token_in_url=0
    if [ -n "$token" ]; then
      if [ "$civitai" -eq 1 ]; then
        # wget은 리다이렉트된 저장소(서명 URL)에도 헤더를 보내서 실패할 수 있어
        # Civitai가 지원하는 token 쿼리 파라미터를 사용합니다.
        case "$url" in *\?*) url="$url&token=$token" ;; *) url="$url?token=$token" ;; esac
        token_in_url=1
      else
        case "$url" in
          *huggingface.co*) : ;;  # HF 토큰은 wget에서는 붙이지 않습니다 (공식 파일은 토큰 불필요).
          *) wargs+=(--header="Authorization: Bearer $token") ;;
        esac
      fi
    fi
    if [ "$token_in_url" -eq 1 ]; then
      # wget은 요청 주소를 화면에 그대로 찍으므로, 키가 든 주소는 -nv(간단 출력)로 받고
      # 출력에서 token=값을 ***로 가립니다. (진행 막대는 표시되지 않습니다)
      wget -nv "${wargs[@]}" "$url" 2>&1 | sed -e 's/token=[^&[:space:]"]*/token=***/g' >&2
      return "${PIPESTATUS[0]}"
    fi
    wget "${wargs[@]}" "$url"
  fi
}

# ---------------------------------------------------------------------------
# 4) 받을 목록 결정 + 다운로드
# ---------------------------------------------------------------------------
in_only_list() {
  local key="$1" k
  local IFS=','
  for k in $ONLY; do
    k="${k// /}"
    [ "$k" = "$key" ] && return 0
  done
  return 1
}

if [ -n "$ONLY" ]; then
  # 존재하지 않는 key 경고
  IFS=',' read -r -a only_keys <<< "$ONLY"
  for k in "${only_keys[@]}"; do
    k="${k// /}"
    [ -n "$k" ] || continue
    printf '%s\n' "$MANIFEST_ROWS" | cut -d'|' -f1 | grep -qx -- "$k" || warn "models.json에 없는 key: $k (--list 로 확인)"
  done
fi

n_ok=0; n_skip=0; n_fail=0; n_token=0
FAILED=()
TOKEN_SKIPPED=()

while IFS='|' read -r key filename url dir size bytes sha required needs_token token_env <&3; do
  # 대상 선택
  if [ -n "$ONLY" ]; then
    in_only_list "$key" || continue
  elif [ "$required" != "true" ] && [ "$INCLUDE_OPTIONAL" -ne 1 ]; then
    continue
  fi

  dest_dir="$MODELS_DIR/$dir"
  dest="$dest_dir/$filename"
  part="$dest.part"
  label="$dir/$filename"
  [ "$size" = "-" ] && size="크기 미상"
  [ "$bytes" = "-" ] && bytes=""
  [ "$sha" = "-" ] && sha=""

  # 토큰 결정
  token=""; civitai=0
  case "$url" in *civitai.com*) civitai=1 ;; esac
  if [ "$needs_token" = "true" ]; then
    envname="$token_env"; [ "$envname" = "-" ] && envname="CIVITAI_TOKEN"
    token="${!envname:-}"
    if [ -z "$token" ]; then
      skip "$label — $envname 환경 변수가 없어 건너뜁니다 (Civitai API 키 필요)."
      n_token=$((n_token + 1)); TOKEN_SKIPPED+=("$label"); continue
    fi
  elif [ "$civitai" -eq 1 ] && [ -n "${CIVITAI_TOKEN:-}" ]; then
    token="$CIVITAI_TOKEN"
  else
    case "$url" in *huggingface.co*) token="${HF_TOKEN:-}" ;; esac
  fi

  # 이미 있는 파일 처리
  if [ -f "$dest" ]; then
    cur="$(file_size "$dest")"
    if [ -n "$bytes" ] && [ "$cur" -lt "$bytes" ]; then
      warn "$label 이(가) 덜 받아진 것 같습니다 ($cur / $bytes 바이트). 이어받기를 시도합니다."
      if [ "$DRY_RUN" -eq 0 ]; then mv -f "$dest" "$part"; fi
    else
      if [ -n "$bytes" ] && [ "$cur" -ne "$bytes" ]; then
        warn "$label 크기가 예상과 다릅니다 ($cur / $bytes 바이트). 파일이 갱신됐을 수 있어 그대로 둡니다."
      fi
      skip "$label — 이미 있음"
      n_skip=$((n_skip + 1)); continue
    fi
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    info "(dry-run) 받을 예정: $label ($size) <- $url"
    continue
  fi

  mkdir -p "$dest_dir" || { err "폴더를 만들 수 없습니다: $dest_dir"; n_fail=$((n_fail + 1)); FAILED+=("$label"); continue; }
  info "다운로드: $label ($size)"

  success=0
  for attempt in 1 2 3; do
    # .part가 이미 끝까지 받아져 있으면 바로 완료 처리
    if [ -n "$bytes" ] && [ -f "$part" ] && [ "$(file_size "$part")" -eq "$bytes" ]; then
      success=1; break
    fi
    fetch "$url" "$part" "$token" "$civitai"
    rc=$?
    if [ "$rc" -eq 0 ]; then
      success=1; break
    fi
    # curl 22 / wget 6·8 = 서버가 인증 실패나 4xx/5xx 오류를 돌려줌 (토큰 없음·권한 없음·주소 없음 등)
    if { [ "$DL_TOOL" = "curl" ] && [ "$rc" -eq 22 ]; } || { [ "$DL_TOOL" = "wget" ] && { [ "$rc" -eq 8 ] || [ "$rc" -eq 6 ]; }; }; then
      if [ "$needs_token" = "true" ]; then
        err "서버가 요청을 거부했습니다. Civitai API 키가 맞는지, 해당 모델 페이지에 로그인 상태로 접근 가능한지 확인하세요."
      else
        err "서버가 오류를 돌려줬습니다 (파일이 옮겨졌거나 일시적인 서버 문제일 수 있음)."
      fi
      break
    fi
    warn "실패 (시도 $attempt/3, 코드 $rc). 잠시 후 이어받기로 다시 시도합니다."
    wait_sec=3; [ "$attempt" -eq 2 ] && wait_sec=10
    sleep "$wait_sec" 2>/dev/null || true
  done

  if [ "$success" -eq 1 ] && looks_like_error_page "$part"; then
    err "$label: 모델 파일 대신 오류 페이지를 받았습니다. 토큰/주소를 확인하세요."
    head -c 300 "$part" >&2; printf '\n' >&2
    rm -f "$part"; success=0
  fi
  if [ "$success" -eq 1 ] && [ -n "$bytes" ]; then
    got="$(file_size "$part")"
    if [ "$got" -ne "$bytes" ]; then
      warn "$label 크기가 예상과 다릅니다 ($got / $bytes 바이트). 다시 실행하면 이어받습니다."
      [ "$got" -lt "$bytes" ] && success=0
    fi
  fi

  if [ "$success" -eq 1 ]; then
    mv -f "$part" "$dest"
    if [ "$VERIFY" -eq 1 ] && [ -n "$sha" ]; then
      info "sha256 검사 중: $label"
      actual="$(sha256_of "$dest")"
      if [ -z "$actual" ]; then
        warn "sha256sum/shasum이 없어 해시 검사를 건너뜁니다."
      elif [ "$actual" != "$sha" ]; then
        err "$label 해시 불일치! (예상 $sha / 실제 $actual) 파일을 지우고 다시 받으세요."
        n_fail=$((n_fail + 1)); FAILED+=("$label (해시 불일치)"); continue
      else
        ok "해시 일치"
      fi
    fi
    ok "$label"
    n_ok=$((n_ok + 1))
  else
    # 비어 있는 .part는 지워서 다음 실행에 방해가 되지 않게 합니다.
    if [ -f "$part" ] && [ "$(file_size "$part")" -eq 0 ]; then rm -f "$part"; fi
    err "$label 다운로드 실패. 다시 실행하면 이어받습니다. 수동 링크: $url"
    n_fail=$((n_fail + 1)); FAILED+=("$label")
  fi
done 3<<< "$MANIFEST_ROWS"

say ""
say "=============================================="
say " 결과: 새로 받음 $n_ok / 이미 있음 $n_skip / 실패 $n_fail / 토큰 없어 건너뜀 $n_token"
say "=============================================="
if [ "${#TOKEN_SKIPPED[@]}" -gt 0 ]; then
  say "Civitai LoRA를 받으려면 Civitai 계정 설정에서 API 키를 만든 뒤:"
  say "  CIVITAI_TOKEN=발급받은키 bash download_models.sh -d \"<ComfyUI 폴더>\" --include-optional"
fi
if [ "${#FAILED[@]}" -gt 0 ]; then
  say "실패한 파일:"
  for f in "${FAILED[@]}"; do say "  - $f"; done
  exit 1
fi
if [ "$DRY_RUN" -eq 0 ]; then
  say "ComfyUI가 켜져 있다면 브라우저에서 R 키(모델 목록 새로고침)를 누르거나 ComfyUI를 재시작하세요."
fi
exit 0
