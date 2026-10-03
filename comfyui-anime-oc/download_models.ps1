<#
.SYNOPSIS
    Anima(DiT) 자캐 디자인 세팅용 모델 다운로더 (Windows PowerShell 5.1 이상 / PowerShell 7)

.DESCRIPTION
    같은 폴더의 models.json을 읽어서 ComfyUI\models\ 아래 올바른 폴더에 파일을 받습니다.
      - 이미 있는 파일은 건너뜁니다.
      - 중간에 끊겨도 다시 실행하면 이어받습니다 (.part 파일).
      - 기본은 필수 파일만 받고, -IncludeOptional 을 붙이면 선택 파일까지 받습니다.
      - Civitai LoRA는 $env:CIVITAI_TOKEN 이 있을 때만 받습니다.
      - $env:HF_TOKEN 이 있으면 huggingface.co 요청에 붙입니다 (공식 파일은 토큰 없이 받아집니다).
    다운로드 방식(-Downloader Auto): Windows 10/11에 기본 포함된 curl.exe를 먼저 쓰고,
    실패하거나 없으면 .NET HttpWebRequest(이어받기 지원)로 다시 시도합니다.
    -Downloader Bits 로 BITS(Start-BitsTransfer)를 강제할 수도 있습니다 (토큰 필요한 파일 제외).

.PARAMETER ComfyDir
    ComfyUI 폴더 (models 폴더가 들어 있는 곳). ComfyUI_windows_portable 폴더나 models 폴더 자체를 줘도 됩니다.
    생략하면 $env:COMFYUI_DIR, 현재 폴더, ComfyUI Desktop 설정, 흔한 설치 위치를 자동으로 찾습니다.

.PARAMETER IncludeOptional
    선택 파일(Base v1.0, LLLite, 추가 LoRA, 검출기, 대체 업스케일러)도 받습니다.

.PARAMETER Only
    지정한 key만 받습니다. 예: -Only anima_base_v10,lllite_any_test_v2  (key 목록은 -List)

.PARAMETER List
    파일 목록만 보여주고 끝냅니다.

.PARAMETER DryRun
    실제로 받지 않고 무엇을 할지만 출력합니다.

.PARAMETER VerifyHash
    sha256 값이 있는 파일은 다운로드 후 해시를 검사합니다 (4GB 파일은 1분 정도 걸릴 수 있음).

.PARAMETER Yes
    자동으로 찾은 폴더를 묻지 않고 바로 사용합니다.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable"

.EXAMPLE
    $env:CIVITAI_TOKEN = "발급받은키"
    powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "$([Environment]::GetFolderPath('MyDocuments'))\ComfyUI" -IncludeOptional
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string]$ComfyDir,
    [switch]$IncludeOptional,
    [string[]]$Only,
    [switch]$List,
    [switch]$DryRun,
    [switch]$VerifyHash,
    [switch]$Yes,
    [ValidateSet('Auto', 'Curl', 'Bits', 'WebRequest')]
    [string]$Downloader = 'Auto',
    [string]$ManifestPath
)

# ---------------------------------------------------------------------------
# 출력 도우미
# ---------------------------------------------------------------------------
function Write-Info([string]$Msg) { Write-Host "[정보] $Msg" -ForegroundColor Cyan }
function Write-Done([string]$Msg) { Write-Host "[완료] $Msg" -ForegroundColor Green }
function Write-Skip([string]$Msg) { Write-Host "[건너뜀] $Msg" -ForegroundColor DarkGray }
function Write-Caution([string]$Msg) { Write-Host "[주의] $Msg" -ForegroundColor Yellow }
function Write-Fail([string]$Msg) { Write-Host "[오류] $Msg" -ForegroundColor Red }

# PowerShell 5.1은 기본 TLS 설정이 낮을 수 있어 TLS 1.2를 켭니다.
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
} catch { }  # 실패해도 계속 진행 (선택 기능)

$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) { $ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path }

# ---------------------------------------------------------------------------
# 1) models.json 읽기
# ---------------------------------------------------------------------------
if (-not $ManifestPath) { $ManifestPath = Join-Path $ScriptRoot 'models.json' }
if (-not (Test-Path -LiteralPath $ManifestPath -PathType Leaf)) {
    Write-Fail "models.json을 찾을 수 없습니다. ($ManifestPath)"
    Write-Host "  download_models.ps1과 models.json을 같은 폴더에 두고 실행하세요."
    exit 1
}
try {
    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
} catch {
    Write-Fail "models.json을 읽지 못했습니다. $($_.Exception.Message)"
    exit 1
}
$entries = @($manifest.files)
if ($entries.Count -eq 0) { Write-Fail "models.json에 파일 목록이 없습니다."; exit 1 }

# -Only a,b 를 cmd/-File 로 넘기면 "a,b" 한 덩어리로 들어오므로 다시 쪼갭니다.
$onlyKeys = @()
if ($Only) {
    foreach ($o in $Only) { foreach ($k in ($o -split ',')) { $k = $k.Trim(); if ($k) { $onlyKeys += $k } } }
    $knownKeys = @($entries | ForEach-Object { $_.key })
    foreach ($k in $onlyKeys) {
        if ($knownKeys -notcontains $k) { Write-Caution "models.json에 없는 key입니다. ($k)  -List 로 확인하세요." }
    }
}

if ($List) {
    $entries | ForEach-Object {
        [pscustomobject]@{
            'Key'  = $_.key
            '구분' = $(if ($_.required) { '필수' } else { '선택' })
            '토큰' = $(if ($_.needs_token) { '필요' } else { '-' })
            '크기' = $(if ($_.size) { $_.size } else { '?' })
            '경로' = "$($_.dir)/$($_.filename)"
        }
    } | Format-Table -AutoSize | Out-String -Width 4096 | Write-Host
    exit 0
}

# ---------------------------------------------------------------------------
# 2) ComfyUI models 폴더 찾기
# ---------------------------------------------------------------------------
function Resolve-ModelsDir([string]$Path) {
    if (-not $Path) { return $null }
    $p = [Environment]::ExpandEnvironmentVariables($Path.Trim().Trim('"'))
    if ($p.Length -gt 3) { $p = $p.TrimEnd('\', '/') }
    if ($p.StartsWith('~')) { $p = $HOME + $p.Substring(1) }
    # 상대 경로를 절대 경로로 (.NET/curl은 PowerShell의 현재 위치를 모르기 때문)
    try { $p = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($p) } catch { }  # 실패해도 계속 진행 (선택 기능)
    if (-not (Test-Path -LiteralPath $p -PathType Container)) {
        # 아직 없는 models 폴더를 직접 지정한 경우에는 그대로 사용 (나중에 생성)
        if ((Split-Path -Leaf $p) -ieq 'models') { return $p }
        return $null
    }
    $full = (Resolve-Path -LiteralPath $p).ProviderPath
    $m1 = [IO.Path]::Combine($full, 'models')
    $m2 = [IO.Path]::Combine($full, 'ComfyUI', 'models')   # ComfyUI_windows_portable 루트
    if (Test-Path -LiteralPath $m1 -PathType Container) { return $m1 }
    if (Test-Path -LiteralPath $m2 -PathType Container) { return $m2 }
    if ((Split-Path -Leaf $full) -ieq 'models') { return $full }
    return $null
}

# 자동 감지용: models 옆에 main.py 또는 custom_nodes 가 있어야 ComfyUI로 인정
function Test-ComfyRoot([string]$ModelsDir) {
    if (-not $ModelsDir -or -not (Test-Path -LiteralPath $ModelsDir -PathType Container)) { return $false }
    $root = Split-Path -Parent $ModelsDir
    return (Test-Path -LiteralPath (Join-Path $root 'main.py')) -or (Test-Path -LiteralPath (Join-Path $root 'custom_nodes') -PathType Container)
}

$ModelsDir = $null
if ($ComfyDir) {
    $ModelsDir = Resolve-ModelsDir $ComfyDir
    if (-not $ModelsDir) {
        Write-Fail "ComfyUI 폴더를 찾지 못했습니다. ($ComfyDir)"
        Write-Host "  ComfyUI 폴더(models 폴더가 있는 곳)나 models 폴더 경로를 지정하세요."
        Write-Host '  예) -ComfyDir "C:\ComfyUI_windows_portable"  또는  -ComfyDir "$([Environment]::GetFolderPath(''MyDocuments''))\ComfyUI"'
        exit 1
    }
} else {
    $candidates = New-Object System.Collections.Generic.List[string]
    if ($env:COMFYUI_DIR) { $candidates.Add($env:COMFYUI_DIR) }
    $candidates.Add((Get-Location).ProviderPath)
    $candidates.Add($ScriptRoot)
    $parent = Split-Path -Parent $ScriptRoot
    if ($parent) {
        $candidates.Add($parent)
        $grand = Split-Path -Parent $parent
        if ($grand) { $candidates.Add($grand) }
    }
    # ComfyUI Desktop은 설치 위치(basePath)를 %APPDATA%\ComfyUI\config.json에 저장합니다.
    try {
        if ($env:APPDATA) {
            $desktopCfg = Join-Path $env:APPDATA 'ComfyUI\config.json'
            if (Test-Path -LiteralPath $desktopCfg) {
                $cfg = Get-Content -LiteralPath $desktopCfg -Raw -Encoding UTF8 | ConvertFrom-Json
                if ($cfg.basePath) { $candidates.Add([string]$cfg.basePath) }
            }
        }
    } catch { }  # 실패해도 계속 진행 (선택 기능)
    # '문서' 폴더는 OneDrive로 옮겨져 있을 수 있으므로 실제 위치(MyDocuments)를 먼저 확인합니다.
    $myDocs = $null
    try { $myDocs = [Environment]::GetFolderPath('MyDocuments') } catch { $myDocs = $null }
    if ($myDocs) { $candidates.Add((Join-Path $myDocs 'ComfyUI')) }
    foreach ($c in @(
            (Join-Path $HOME 'Documents\ComfyUI'),
            (Join-Path $HOME 'ComfyUI'),
            (Join-Path $HOME 'ComfyUI_windows_portable'),
            (Join-Path $HOME 'Desktop\ComfyUI_windows_portable'),
            (Join-Path $HOME 'Downloads\ComfyUI_windows_portable'),
            'C:\ComfyUI_windows_portable', 'D:\ComfyUI_windows_portable', 'E:\ComfyUI_windows_portable',
            'C:\ComfyUI', 'D:\ComfyUI', 'E:\ComfyUI')) { $candidates.Add($c) }

    foreach ($c in $candidates) {
        $m = $null
        try { $m = Resolve-ModelsDir $c } catch { $m = $null }
        if ($m -and (Test-ComfyRoot $m)) { $ModelsDir = $m; break }
    }
    if (-not $ModelsDir) {
        Write-Fail "ComfyUI 폴더를 자동으로 찾지 못했습니다. -ComfyDir 로 직접 지정하세요."
        Write-Host '  예) powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "C:\ComfyUI_windows_portable"'
        exit 1
    }
    Write-Info "자동으로 찾은 ComfyUI models 폴더: $ModelsDir"
    if (-not $Yes -and -not $DryRun) {
        try {
            $answer = Read-Host '이 폴더에 받을까요? [Y/n]'
            if ($answer -match '^[nN]') { Write-Host '취소했습니다. -ComfyDir 로 폴더를 지정하세요.'; exit 1 }
        } catch { }  # 실패해도 계속 진행 (선택 기능)
    }
}
Write-Info "대상 폴더: $ModelsDir"

# ---------------------------------------------------------------------------
# 3) 다운로드 함수
# ---------------------------------------------------------------------------
function Get-CurlPath {
    foreach ($n in @('curl.exe', 'curl')) {
        $cmd = Get-Command $n -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($cmd) { return $cmd.Path }
    }
    return $null
}
$CurlPath = Get-CurlPath
$HasBits = [bool](Get-Command Start-BitsTransfer -ErrorAction SilentlyContinue)

if ($Downloader -eq 'Curl' -and -not $CurlPath) { Write-Fail 'curl.exe를 찾을 수 없습니다. -Downloader Auto 로 실행하세요.'; exit 1 }
if ($Downloader -eq 'Bits' -and -not $HasBits) { Write-Fail 'BITS(Start-BitsTransfer)를 사용할 수 없습니다. -Downloader Auto 로 실행하세요.'; exit 1 }

function Get-FileLength([string]$Path) {
    if (Test-Path -LiteralPath $Path -PathType Leaf) { return [int64](Get-Item -LiteralPath $Path).Length }
    return [int64]0
}

function Format-Bytes([double]$Bytes) {
    if ($Bytes -ge 1GB) { return ('{0:N2} GB' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N1} MB' -f ($Bytes / 1MB)) }
    return ('{0:N0} KB' -f ($Bytes / 1KB))
}

# curl.exe: -C - 로 이어받기. 다른 호스트로 리다이렉트되면 Authorization 헤더는 자동으로 빠집니다.
# 반환값: curl 종료 코드 (0 = 성공, 22 = 서버가 4xx/5xx 오류 반환)
function Invoke-CurlDownload([string]$Url, [string]$OutFile, [string]$Token) {
    $curlArgs = @('-fL', '--retry', '5', '--retry-delay', '3', '--connect-timeout', '30', '--progress-bar', '-C', '-', '-o', $OutFile)
    if ($Token) { $curlArgs += @('-H', "Authorization: Bearer $Token") }
    $curlArgs += $Url
    & $CurlPath @curlArgs | Out-Host
    return $LASTEXITCODE
}

# .NET HttpWebRequest: Range 헤더로 이어받기 (PowerShell 5.1의 Invoke-WebRequest는 이어받기를 못 해서 직접 구현).
# 리다이렉트 시 Authorization 헤더는 .NET이 자동으로 제거합니다.
# 반환값: 0 = 성공, 22 = 서버가 4xx 오류 반환 (재시도 무의미), 1 = 기타 실패
function Invoke-HttpDownload([string]$Url, [string]$OutFile, [string]$Token, [string]$Label) {
    $maxTry = 5
    for ($try = 1; $try -le $maxTry; $try++) {
        $existing = Get-FileLength $OutFile
        $resp = $null; $stream = $null; $fs = $null
        try {
            $req = [System.Net.WebRequest]::Create($Url)   # http(s) 주소면 HttpWebRequest가 반환됨
            $req.UserAgent = 'comfyui-anime-oc-downloader/1.0'
            $req.AllowAutoRedirect = $true
            $req.Timeout = 60000
            $req.ReadWriteTimeout = 300000
            if ($Token) { $req.Headers.Add('Authorization', "Bearer $Token") }
            if ($existing -gt 0) { $req.AddRange([int64]$existing) }
            try {
                $resp = $req.GetResponse()
            } catch [System.Net.WebException] {
                $r = $_.Exception.Response
                if ($r) {
                    $code = [int]$r.StatusCode
                    $r.Close()
                    if ($code -eq 416 -and $existing -gt 0) { return 0 }   # 이미 끝까지 받음
                    if ($code -ge 400 -and $code -lt 500 -and $code -ne 408 -and $code -ne 429) {
                        Write-Fail "서버 응답 HTTP $code"
                        return 22
                    }
                }
                throw
            }
            $status = [int]$resp.StatusCode
            $append = ($existing -gt 0 -and $status -eq 206)
            $done = [int64]0
            if ($append) { $done = $existing }
            $total = [int64]-1
            if ($resp.ContentLength -ge 0) { $total = $resp.ContentLength + $done }
            if ($append) { $mode = [System.IO.FileMode]::Append } else { $mode = [System.IO.FileMode]::Create }
            $fs = New-Object System.IO.FileStream($OutFile, $mode, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)
            $stream = $resp.GetResponseStream()
            $buf = New-Object byte[] (1MB)
            $sw = [System.Diagnostics.Stopwatch]::StartNew()
            $lastShow = 0; $startDone = $done
            while (($n = $stream.Read($buf, 0, $buf.Length)) -gt 0) {
                $fs.Write($buf, 0, $n)
                $done += $n
                if ($sw.ElapsedMilliseconds - $lastShow -ge 500) {
                    $lastShow = $sw.ElapsedMilliseconds
                    $speed = ($done - $startDone) / [Math]::Max($sw.Elapsed.TotalSeconds, 0.001)
                    if ($total -gt 0) {
                        $pct = [int][Math]::Min(100, ($done * 100 / $total))
                        Write-Progress -Activity "다운로드: $Label" -Status ("{0} / {1}  ({2}/s)" -f (Format-Bytes $done), (Format-Bytes $total), (Format-Bytes $speed)) -PercentComplete $pct
                    } else {
                        Write-Progress -Activity "다운로드: $Label" -Status ("{0}  ({1}/s)" -f (Format-Bytes $done), (Format-Bytes $speed))
                    }
                }
            }
            Write-Progress -Activity "다운로드: $Label" -Completed
            return 0
        } catch {
            Write-Caution ("연결 문제 (시도 {0}/{1}) {2}" -f $try, $maxTry, $_.Exception.Message)
            Start-Sleep -Seconds ([Math]::Min(30, 3 * $try))
        } finally {
            if ($fs) { $fs.Close() }
            if ($stream) { $stream.Close() }
            if ($resp) { $resp.Close() }
        }
    }
    return 1
}

function Invoke-BitsDownload([string]$Url, [string]$OutFile, [string]$Label) {
    try {
        if (Test-Path -LiteralPath $OutFile) { Remove-Item -LiteralPath $OutFile -Force }
        Start-BitsTransfer -Source $Url -Destination $OutFile -DisplayName $Label -Description 'comfyui-anime-oc' -ErrorAction Stop
        return 0
    } catch {
        Write-Caution "BITS 실패: $($_.Exception.Message)"
        return 1
    }
}

# 받은 파일이 모델이 아니라 오류 페이지(HTML/JSON)인지 간단히 검사
function Test-ErrorPage([string]$Path) {
    $len = Get-FileLength $Path
    if ($len -eq 0 -or $len -ge 200000) { return $false }
    $f = [System.IO.File]::OpenRead($Path)
    try { $b = $f.ReadByte() } finally { $f.Close() }
    return ($b -eq 60 -or $b -eq 123)   # '<' 또는 '{'
}

# ---------------------------------------------------------------------------
# 4) 받을 목록 결정 + 다운로드
# ---------------------------------------------------------------------------
$nOk = 0; $nSkip = 0; $nFail = 0; $nToken = 0
$failed = New-Object System.Collections.Generic.List[string]

foreach ($e in $entries) {
    if ($onlyKeys.Count -gt 0) {
        if ($onlyKeys -notcontains $e.key) { continue }
    } elseif (-not $e.required -and -not $IncludeOptional) {
        continue
    }

    $relDir = ([string]$e.dir) -replace '/', [IO.Path]::DirectorySeparatorChar
    $destDir = Join-Path $ModelsDir $relDir
    $dest = Join-Path $destDir ([string]$e.filename)
    $part = "$dest.part"
    $label = "$($e.dir)/$($e.filename)"
    $sizeText = '크기 미상'
    if ($e.size) { $sizeText = [string]$e.size }
    $expected = [int64]-1
    if ($null -ne $e.bytes) { $expected = [int64]$e.bytes }
    $url = [string]$e.url
    $isCivitai = $url -like '*civitai.com*'

    # 토큰 결정
    $token = $null
    if ($e.needs_token) {
        $tokenEnv = 'CIVITAI_TOKEN'
        if ($e.token_env) { $tokenEnv = [string]$e.token_env }
        $token = [Environment]::GetEnvironmentVariable($tokenEnv)
        if (-not $token) {
            Write-Skip "$label  ($tokenEnv 환경 변수가 없어 건너뜁니다. Civitai API 키 필요)"
            $nToken++
            continue
        }
    } elseif ($isCivitai -and $env:CIVITAI_TOKEN) {
        $token = $env:CIVITAI_TOKEN
    } elseif ($url -like '*huggingface.co*' -and $env:HF_TOKEN) {
        $token = $env:HF_TOKEN
    }

    # 이미 있는 파일 처리
    if (Test-Path -LiteralPath $dest -PathType Leaf) {
        $cur = Get-FileLength $dest
        if ($expected -gt 0 -and $cur -lt $expected) {
            Write-Caution "$label 이(가) 덜 받아진 것 같습니다 ($cur / $expected 바이트). 이어받기를 시도합니다."
            if (-not $DryRun) { Move-Item -LiteralPath $dest -Destination $part -Force }
        } else {
            if ($expected -gt 0 -and $cur -ne $expected) {
                Write-Caution "$label 크기가 예상과 다릅니다 ($cur / $expected 바이트). 파일이 갱신됐을 수 있어 그대로 둡니다."
            }
            Write-Skip "$label  (이미 있음)"
            $nSkip++
            continue
        }
    }

    if ($DryRun) {
        Write-Info "(dry-run) 받을 예정: $label ($sizeText) <- $url"
        continue
    }

    try {
        if (-not (Test-Path -LiteralPath $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
    } catch {
        Write-Fail "폴더를 만들 수 없습니다. ($destDir)"
        $nFail++; $failed.Add($label); continue
    }

    Write-Info "다운로드: $label ($sizeText)"

    $rc = 1
    if ($expected -gt 0 -and (Get-FileLength $part) -eq $expected) {
        $rc = 0   # .part가 이미 끝까지 받아져 있음
    } else {
        $method = $Downloader
        if ($method -eq 'Auto') { if ($CurlPath) { $method = 'Curl' } else { $method = 'WebRequest' } }
        if ($method -eq 'Bits' -and $token) { $method = 'WebRequest' }   # BITS로는 인증 헤더를 안전하게 보내기 어려움

        switch ($method) {
            'Curl' {
                for ($attempt = 1; $attempt -le 3; $attempt++) {
                    $rc = Invoke-CurlDownload -Url $url -OutFile $part -Token $token
                    if ($rc -eq 0 -or $rc -eq 22) { break }
                    Write-Caution "curl 실패 (시도 $attempt/3, 코드 $rc). 이어받기로 다시 시도합니다."
                    Start-Sleep -Seconds (3 * $attempt)
                }
                if ($rc -ne 0 -and $rc -ne 22 -and $Downloader -eq 'Auto') {
                    Write-Caution 'curl.exe로 받지 못해 .NET 다운로드 방식으로 다시 시도합니다.'
                    $rc = Invoke-HttpDownload -Url $url -OutFile $part -Token $token -Label $label
                }
            }
            'Bits' { $rc = Invoke-BitsDownload -Url $url -OutFile $part -Label $label }
            default { $rc = Invoke-HttpDownload -Url $url -OutFile $part -Token $token -Label $label }
        }
        if ($rc -eq 22) {
            if ($e.needs_token) {
                Write-Fail '서버가 요청을 거부했습니다. Civitai API 키가 맞는지, 모델 페이지에 로그인 상태로 접근 가능한지 확인하세요.'
            } else {
                Write-Fail '서버가 오류를 돌려줬습니다 (파일이 옮겨졌거나 일시적인 서버 문제일 수 있음).'
            }
        }
    }

    $success = ($rc -eq 0)
    if ($success -and (Test-ErrorPage $part)) {
        Write-Fail "$label  모델 파일 대신 오류 페이지를 받았습니다. 토큰이나 주소를 확인하세요."
        try {
            $txt = [string](Get-Content -LiteralPath $part -Raw -Encoding UTF8)
            if ($txt.Length -gt 300) { $txt = $txt.Substring(0, 300) }
            Write-Host $txt
        } catch { }  # 실패해도 계속 진행 (선택 기능)
        Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
        $success = $false
    }
    if ($success -and $expected -gt 0) {
        $got = Get-FileLength $part
        if ($got -ne $expected) {
            Write-Caution "$label 크기가 예상과 다릅니다 ($got / $expected 바이트). 다시 실행하면 이어받습니다."
            if ($got -lt $expected) { $success = $false }
        }
    }

    if ($success) {
        Move-Item -LiteralPath $part -Destination $dest -Force
        if ($VerifyHash -and $e.sha256) {
            Write-Info "sha256 검사 중: $label"
            $actual = (Get-FileHash -LiteralPath $dest -Algorithm SHA256).Hash.ToLowerInvariant()
            if ($actual -ne ([string]$e.sha256).ToLowerInvariant()) {
                Write-Fail "$label 해시 불일치! (예상 $($e.sha256) / 실제 $actual) 파일을 지우고 다시 받으세요."
                $nFail++; $failed.Add("$label (해시 불일치)"); continue
            }
            Write-Done '해시 일치'
        }
        Write-Done $label
        $nOk++
    } else {
        if ((Test-Path -LiteralPath $part) -and (Get-FileLength $part) -eq 0) { Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue }
        Write-Fail "$label 다운로드 실패. 다시 실행하면 이어받습니다. 수동 링크: $url"
        $nFail++; $failed.Add($label)
    }
}

Write-Host ''
Write-Host '=============================================='
Write-Host " 결과: 새로 받음 $nOk / 이미 있음 $nSkip / 실패 $nFail / 토큰 없어 건너뜀 $nToken"
Write-Host '=============================================='
if ($nToken -gt 0) {
    Write-Host 'Civitai LoRA를 받으려면 Civitai 계정 설정에서 API 키를 만든 뒤 같은 창에서:'
    Write-Host '  $env:CIVITAI_TOKEN = "발급받은키"'
    Write-Host '  powershell -ExecutionPolicy Bypass -File .\download_models.ps1 -ComfyDir "<ComfyUI 폴더>" -IncludeOptional'
}
if ($failed.Count -gt 0) {
    Write-Host '실패한 파일:'
    foreach ($f in $failed) { Write-Host "  - $f" }
    exit 1
}
if (-not $DryRun) {
    Write-Host 'ComfyUI가 켜져 있다면 브라우저에서 R 키(모델 목록 새로고침)를 누르거나 ComfyUI를 재시작하세요.'
}
exit 0
