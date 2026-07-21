#!/usr/bin/env pwsh
# Portable smoke for Windows (and any host with PowerShell 7+).
# Behavioral coverage mirrors Scripts/smoke.sh (FileState / StoredState / keys / stats).
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$PSNativeCommandUseErrorActionPreference = $false

$root = Resolve-Path (Join-Path $PSScriptRoot '..')
Set-Location $root

function Assert-Equal {
    param([string]$Expected, [string]$Actual, [string]$Label)
    if ($Actual -ne $Expected) {
        throw "${Label}: expected '$Expected', got '$Actual'"
    }
}

function Assert-Match {
    param([string]$Text, [string]$Pattern, [string]$Label)
    if ($Text -notmatch $Pattern) {
        throw "${Label}: output did not match /$Pattern/`n$Text"
    }
}

function Invoke-ApsOutput {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ApsArgs)
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $script:Bin @ApsArgs 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previous
    }
    # Out-String adds a trailing newline; trim for scalar equality checks.
    return [pscustomobject]@{
        ExitCode = $code
        Text     = $output.TrimEnd("`r", "`n")
    }
}

function Invoke-ApsOk {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ApsArgs)
    $result = Invoke-ApsOutput @ApsArgs
    if ($result.ExitCode -ne 0) {
        throw "aps $($ApsArgs -join ' ') failed (exit $($result.ExitCode)): $($result.Text)"
    }
    return $result.Text
}

function Invoke-ApsExpectFail {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$ApsArgs)
    $result = Invoke-ApsOutput @ApsArgs
    if ($result.ExitCode -eq 0) {
        throw "expected aps $($ApsArgs -join ' ') to fail"
    }
}

function Invoke-ApsExpectExit {
    param(
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$ApsArgs
    )
    $result = Invoke-ApsOutput @ApsArgs
    if ($result.ExitCode -ne $ExitCode) {
        throw "expected aps $($ApsArgs -join ' ') exit $ExitCode, got $($result.ExitCode): $($result.Text)"
    }
}

$smokeHome = if ($env:APS_HOME) {
    $env:APS_HOME
} else {
    Join-Path ([System.IO.Path]::GetTempPath()) ("aps-smoke-" + [guid]::NewGuid().ToString('N'))
}
New-Item -ItemType Directory -Force -Path $smokeHome | Out-Null
$env:APS_HOME = $smokeHome

if (-not $env:APS_BIN) {
    & swift build -c debug
    if ($LASTEXITCODE -ne 0) { throw "swift build failed (exit $LASTEXITCODE)" }
    $candidate = Join-Path $root '.build/debug/aps'
    if ($IsWindows -or $env:OS -match 'Windows') {
        $candidate = "$candidate.exe"
    }
    $env:APS_BIN = $candidate
}
$script:Bin = $env:APS_BIN
if (-not (Test-Path -LiteralPath $script:Bin)) {
    throw "APS_BIN not found: $script:Bin"
}

$null = Invoke-ApsOk --help
Assert-equal '1.0.0' (Invoke-ApsOk --version) 'version'

$keys = Invoke-ApsOk keys
Assert-Match $keys 'counter' 'keys counter'
Assert-Match $keys 'profile' 'keys profile'
Assert-Match $keys 'secret' 'keys secret'

$keysJson = Invoke-ApsOk keys --json
Assert-Match $keysJson '"key":"profile"' 'keys json profile'
Assert-Match $keysJson '"key":"secret"' 'keys json secret'

# `set` prints the value; State is process-local so don't expect get in a new process.
Assert-Equal '11' (Invoke-ApsOk set counter 11) 'set counter'
Assert-Equal 'smoke' (Invoke-ApsOk set message smoke) 'set message'
Assert-Match (Invoke-ApsOk set counter 11 --json) '"value":11' 'set counter json'

# StoredState / FileState must survive process boundaries.
$null = Invoke-ApsOk set flag true
Assert-Equal 'true' (Invoke-ApsOk get flag) 'get flag'
Assert-Match (Invoke-ApsOk get flag --json) '"value":true' 'get flag json'

$null = Invoke-ApsOk set note smoke-note
Assert-Equal 'smoke-note' (Invoke-ApsOk get note) 'get note'

$null = Invoke-ApsOk set profile '{"name":"smoke","version":2}'
$profileJson = Invoke-ApsOk get profile --json
Assert-Match $profileJson '"name":"smoke"' 'profile name'
Assert-Match $profileJson '"version":2' 'profile version'

# Encrypted-file secret store (issue #35): key-file mode round-trip + reset.
$null = Invoke-ApsOk set secret smoke-secret
Assert-Equal 'smoke-secret' (Invoke-ApsOk get secret) 'get secret'
Assert-Match (Invoke-ApsOk get secret --json) '"storage":"EncryptedFile"' 'secret storage'
$null = Invoke-ApsOk reset secret
$after = Invoke-ApsOk get secret
if (-not [string]::IsNullOrEmpty($after)) {
    throw "expected empty secret after reset, got '$after'"
}

# --state-dir overrides APS_HOME
$other = Join-Path ([System.IO.Path]::GetTempPath()) ("aps-smoke-other-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $other | Out-Null
$null = Invoke-ApsOk set note other-root --state-dir $other
Assert-Equal 'other-root' (Invoke-ApsOk get note --state-dir $other) 'state-dir get'
Assert-Equal 'smoke-note' (Invoke-ApsOk get note) 'default home note unchanged'

Assert-Match (Invoke-ApsOk dump) '"key":"flag"' 'dump flag'
$dumpJson = Invoke-ApsOk dump --json
Assert-Match $dumpJson '"key":"profile"' 'dump json profile'
Assert-Match $dumpJson '"key":"secret"' 'dump json secret'

$null = Invoke-ApsOk reset flag
Assert-Equal 'false' (Invoke-ApsOk get flag) 'reset flag'

$null = Invoke-ApsOk reset note
$noteAfter = Invoke-ApsOk get note
if (-not [string]::IsNullOrEmpty($noteAfter)) {
    throw "expected empty note after reset, got '$noteAfter'"
}

Assert-Match (Invoke-ApsOk reset profile --json) '"reset":"key"' 'reset profile json'

$null = Invoke-ApsOk reset --all
Assert-Equal 'false' (Invoke-ApsOk get flag) 'reset all flag'
$noteAll = Invoke-ApsOk get note
if (-not [string]::IsNullOrEmpty($noteAll)) {
    throw "expected empty note after reset --all, got '$noteAll'"
}

# Root --state-dir before the subcommand.
$rootDir = Join-Path $env:TEMP ("aps-smoke-root-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $rootDir | Out-Null
try {
    $null = Invoke-ApsOk --state-dir $rootDir set note root-flag
    Assert-Equal 'root-flag' (Invoke-ApsOk --state-dir $rootDir get note) 'root state-dir get'
} finally {
    Remove-Item -Recurse -Force $rootDir -ErrorAction SilentlyContinue
}

# Bounded watch should exit.
$null = Invoke-ApsOk watch counter --count 1 --timeout 2

# ObservedDependency stats command (process-local; fresh process starts at 0).
Assert-Match (Invoke-ApsOk stats --json) '"mutationCount":0' 'stats json'
$null = Invoke-ApsOk stats --watch --count 1 --timeout 2

# Invalid values should fail clearly.
Invoke-ApsExpectFail set counter nope

# Schema contract + dynamic key round-trip
$schema = Invoke-ApsOk schema
Assert-Match $schema '"schemaVersion":4' 'schema version'
Assert-Match $schema '"userSchema"' 'userSchema meta'
Assert-Match $schema '"code":"unknown_key"' 'unknown_key error'
Assert-Match $schema '"--registered"' 'reset registered flag'
Assert-Equal '1.0.0' (Invoke-ApsOk --version) 'cli version'
if (-not (Test-Path (Join-Path $env:APS_HOME 'schema.json'))) {
    throw 'expected schema.json to materialize under APS_HOME'
}
$null = Invoke-ApsOk key add smokeNote --type String --storage FileState --path smoke-note.json --initial ''
Assert-Equal 'from-smoke' (Invoke-ApsOk set smokeNote from-smoke) 'set smokeNote'
Assert-Equal 'from-smoke' (Invoke-ApsOk get smokeNote) 'get smokeNote'
Assert-Match (Invoke-ApsOk schema) '"name":"smokeNote"' 'schema lists smokeNote'
$null = Invoke-ApsOk reset --all
Assert-Equal 'from-smoke' (Invoke-ApsOk get smokeNote) 'reset --all leaves user key'
$null = Invoke-ApsOk reset --registered
$smokeAfter = Invoke-ApsOk get smokeNote
if (-not [string]::IsNullOrEmpty($smokeAfter)) {
    throw "expected empty smokeNote after reset --registered, got '$smokeAfter'"
}
$null = Invoke-ApsOk key remove smokeNote --purge

# Schema conflict: duplicate key add without --force exits 64 (#90).
$null = Invoke-ApsOk key add race1 --type String --storage FileState --path race-1.json --initial ''
Invoke-ApsExpectExit -ExitCode 64 key add race1 --type String --storage FileState --path race-1.json --initial ''
$null = Invoke-ApsOk key remove race1 --purge

Write-Host 'smoke ok'
# Native commands leave $LASTEXITCODE set; clear so pwsh/GHA do not treat success as failure.
exit 0
