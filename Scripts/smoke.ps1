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

# Always isolate smoke in a fresh root. Agents/CI often export APS_HOME for
# dogfooding; reusing that root makes key-count assertions flake. Override with
# APS_SMOKE_HOME when needed.
$smokeHome = if ($env:APS_SMOKE_HOME) {
    $env:APS_SMOKE_HOME
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

# Schema-controlled paths cannot alias the state root or endanger unrelated files.
$sentinel = Join-Path $env:APS_HOME 'path-safety-sentinel.txt'
Set-Content -LiteralPath $sentinel -Value 'must-survive'
$unsafePaths = @(
    '.',
    './',
    '../escape.json',
    'nested/../escape.json',
    '/tmp/aps-escape.json',
    'C:/escape.json',
    'nested\escape.json',
    'schema.json',
    'secret.key',
    'unsafe.lock',
    'CON'
)
$unsafeIndex = 0
foreach ($unsafePath in $unsafePaths) {
    $unsafeIndex += 1
    Invoke-ApsExpectFail key add "unsafePath$unsafeIndex" `
        --type String `
        --storage EncryptedFile `
        --path $unsafePath `
        --initial ''
}
if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
    throw 'unsafe schema path removed the state-root sentinel'
}

$unsafeDirectory = Join-Path $env:APS_HOME 'unsafe-directory'
New-Item -ItemType Directory -Force -Path $unsafeDirectory | Out-Null
$directorySentinel = Join-Path $unsafeDirectory 'sentinel.txt'
Set-Content -LiteralPath $directorySentinel -Value 'directory-sentinel'
Invoke-ApsExpectFail key add unsafeDirectory `
    --type String `
    --storage FileState `
    --path unsafe-directory `
    --initial ''
if (-not (Test-Path -LiteralPath $directorySentinel -PathType Leaf)) {
    throw 'directory path validation removed nested contents'
}

$null = Invoke-ApsOk key add collisionOne `
    --type String `
    --storage FileState `
    --path collision.json `
    --initial ''
Invoke-ApsExpectFail key add collisionTwo `
    --type String `
    --storage EncryptedFile `
    --path COLLISION.JSON `
    --initial ''
$null = Invoke-ApsOk key remove collisionOne --purge

$symlinkTarget = Join-Path ([System.IO.Path]::GetTempPath()) (
    'aps-smoke-symlink-target-' + [guid]::NewGuid().ToString('N')
)
New-Item -ItemType Directory -Force -Path $symlinkTarget | Out-Null
$externalLeaf = Join-Path $symlinkTarget 'leaf.json'
Set-Content -LiteralPath $externalLeaf -Value 'external-leaf'
$leafLinkCreated = $false
try {
    $unsafeLeaf = Join-Path $env:APS_HOME 'unsafe-leaf.json'
    New-Item -ItemType SymbolicLink -Path $unsafeLeaf -Target $externalLeaf -ErrorAction Stop | Out-Null
    $leafLinkCreated = $true
} catch {
    Write-Host "symlink leaf smoke skipped: $($_.Exception.Message)"
}
if ($leafLinkCreated) {
    Invoke-ApsExpectFail key add unsafeLeaf `
        --type String `
        --storage FileState `
        --path unsafe-leaf.json `
        --initial ''
    Assert-Equal 'external-leaf' (Get-Content -Raw $externalLeaf).Trim() 'symlink leaf target'
}
$parentLinkCreated = $false
try {
    $unsafeParent = Join-Path $env:APS_HOME 'unsafe-parent'
    New-Item -ItemType SymbolicLink -Path $unsafeParent -Target $symlinkTarget -ErrorAction Stop | Out-Null
    $parentLinkCreated = $true
} catch {
    Write-Host "symlink ancestor smoke skipped: $($_.Exception.Message)"
}
if ($parentLinkCreated) {
    Invoke-ApsExpectFail key add unsafeParent `
        --type String `
        --storage FileState `
        --path unsafe-parent/leaf.json `
        --initial ''
    Assert-Equal 'external-leaf' (Get-Content -Raw $externalLeaf).Trim() 'symlink ancestor target'
}

# Malicious hand-edits are rejected before reset or purge can touch a path.
$schemaPath = Join-Path $env:APS_HOME 'schema.json'
$null = Invoke-ApsOk key add blockedReset `
    --type String `
    --storage FileState `
    --path blocked-reset.json `
    --initial ''
$null = Invoke-ApsOk set blockedReset changed
$resetSchema = Get-Content -Raw -LiteralPath $schemaPath
Set-Content -LiteralPath $schemaPath -NoNewline -Value (
    $resetSchema.Replace('blocked-reset.json', 'unsafe-directory')
)
Invoke-ApsExpectFail reset blockedReset
if (-not (Test-Path -LiteralPath $directorySentinel -PathType Leaf)) {
    throw 'blocked reset removed directory contents'
}
if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
    throw 'blocked reset removed the state-root sentinel'
}
Set-Content -LiteralPath $schemaPath -NoNewline -Value $resetSchema
$null = Invoke-ApsOk key remove blockedReset --purge

$null = Invoke-ApsOk key add blockedPurge `
    --type String `
    --storage FileState `
    --path blocked-purge.json `
    --initial ''
$null = Invoke-ApsOk set blockedPurge changed
$purgeSchema = Get-Content -Raw -LiteralPath $schemaPath
Set-Content -LiteralPath $schemaPath -NoNewline -Value (
    $purgeSchema.Replace('blocked-purge.json', 'unsafe-directory')
)
Invoke-ApsExpectFail key remove blockedPurge --purge
if (-not (Test-Path -LiteralPath $directorySentinel -PathType Leaf)) {
    throw 'blocked purge removed directory contents'
}
if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
    throw 'blocked purge removed the state-root sentinel'
}
Set-Content -LiteralPath $schemaPath -NoNewline -Value $purgeSchema
$null = Invoke-ApsOk key remove blockedPurge --purge

# Reset and purge operate only on their verified regular leaf.
$null = Invoke-ApsOk key add resetLeaf `
    --type String `
    --storage FileState `
    --path reset-leaf.json `
    --initial seed
$null = Invoke-ApsOk set resetLeaf changed
$null = Invoke-ApsOk reset resetLeaf
Assert-Equal 'seed' (Invoke-ApsOk get resetLeaf) 'reset verified FileState leaf'
if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
    throw 'FileState reset removed the state-root sentinel'
}
$null = Invoke-ApsOk key remove resetLeaf --purge
if (Test-Path -LiteralPath (Join-Path $env:APS_HOME 'reset-leaf.json')) {
    throw 'resetLeaf data survived purge'
}

$null = Invoke-ApsOk key add purgeLeaf `
    --type String `
    --storage FileState `
    --path purge-leaf.json `
    --initial ''
$null = Invoke-ApsOk set purgeLeaf changed
$null = Invoke-ApsOk key remove purgeLeaf --purge
if (Test-Path -LiteralPath (Join-Path $env:APS_HOME 'purge-leaf.json')) {
    throw 'purgeLeaf data survived purge'
}

$null = Invoke-ApsOk key add resetSecret `
    --type String `
    --storage EncryptedFile `
    --path reset-secret.enc `
    --initial ''
$null = Invoke-ApsOk set resetSecret changed
$null = Invoke-ApsOk reset resetSecret
if (Test-Path -LiteralPath (Join-Path $env:APS_HOME 'reset-secret.enc')) {
    throw 'resetSecret ciphertext survived reset'
}
$null = Invoke-ApsOk key remove resetSecret

$null = Invoke-ApsOk key add purgeSecret `
    --type String `
    --storage EncryptedFile `
    --path purge-secret.enc `
    --initial ''
$null = Invoke-ApsOk set purgeSecret changed
$null = Invoke-ApsOk key remove purgeSecret --purge
if (Test-Path -LiteralPath (Join-Path $env:APS_HOME 'purge-secret.enc')) {
    throw 'purgeSecret ciphertext survived purge'
}
if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
    throw 'destructive schema operations removed the state-root sentinel'
}

$null = Invoke-ApsOk reset --all
Assert-Equal 'from-smoke' (Invoke-ApsOk get smokeNote) 'reset --all leaves user key'
$null = Invoke-ApsOk reset --registered
$smokeAfter = Invoke-ApsOk get smokeNote
if (-not [string]::IsNullOrEmpty($smokeAfter)) {
    throw "expected empty smokeNote after reset --registered, got '$smokeAfter'"
}
$null = Invoke-ApsOk key remove smokeNote --purge

Write-Host 'smoke ok'
# Native commands leave $LASTEXITCODE set; clear so pwsh/GHA do not treat success as failure.
exit 0
