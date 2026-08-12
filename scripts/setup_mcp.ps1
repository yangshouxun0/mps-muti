[CmdletBinding()]
param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$skillRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$mcpRoot = Join-Path $skillRoot "mcp\openai-image-mcp"
$serverPath = Join-Path $mcpRoot "scripts\server.py"
$requirementsPath = Join-Path $mcpRoot "requirements.txt"
$exampleEnvPath = Join-Path $mcpRoot ".env.example"

if (-not (Test-Path -LiteralPath $serverPath)) {
    throw "Bundled openai-image MCP server is missing: $serverPath"
}

$codexHome = if ($env:CODEX_HOME) {
    [Environment]::ExpandEnvironmentVariables($env:CODEX_HOME)
} else {
    Join-Path $HOME ".codex"
}
$runtimeRoot = Join-Path $codexHome "mps-muti-mcp-runtime"
$venvPath = Join-Path $runtimeRoot ".venv"
$venvPython = Join-Path $venvPath "Scripts\python.exe"
$userEnvPath = Join-Path $runtimeRoot ".env"
$configPath = Join-Path $codexHome "config.toml"

$pythonCommand = Get-Command py -ErrorAction SilentlyContinue
if (-not $pythonCommand) {
    $pythonCommand = Get-Command python -ErrorAction SilentlyContinue
}
if (-not $pythonCommand) {
    throw "Python 3 is required for the bundled MCP server. Install Python, then run this script again."
}

function Invoke-HostPython {
    param([string[]]$Arguments)
    if ($pythonCommand.Name -eq "py.exe" -or $pythonCommand.Name -eq "py") {
        & $pythonCommand.Source -3 @Arguments
    } else {
        & $pythonCommand.Source @Arguments
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Python command failed with exit code $LASTEXITCODE."
    }
}

if (-not (Test-Path -LiteralPath $venvPython)) {
    if ($CheckOnly) {
        Write-Output "MCP runtime is not installed: $venvPath"
        exit 2
    }
    New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
    Invoke-HostPython @("-m", "venv", $venvPath)
}

$mcpAvailable = $true
& $venvPython -c "import mcp" 2>$null
if ($LASTEXITCODE -ne 0) {
    $mcpAvailable = $false
}
if (-not $mcpAvailable) {
    if ($CheckOnly) {
        Write-Output "MCP Python dependency is not installed in $venvPath"
        exit 2
    }
    & $venvPython -m pip install --disable-pip-version-check -r $requirementsPath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not install the bundled MCP Python dependency."
    }
}

$createdEnv = $false
if (-not (Test-Path -LiteralPath $userEnvPath)) {
    if ($CheckOnly) {
        Write-Output "MCP environment file is missing: $userEnvPath"
        exit 2
    }
    New-Item -ItemType Directory -Path $runtimeRoot -Force | Out-Null
    Copy-Item -LiteralPath $exampleEnvPath -Destination $userEnvPath
    $createdEnv = $true
}

if ($CheckOnly) {
    Write-Output "Bundled openai-image MCP runtime is ready."
    exit 0
}

New-Item -ItemType Directory -Path $codexHome -Force | Out-Null
$tomlLiteral = {
    param([string]$Value)
    return "'" + ($Value -replace "'", "''") + "'"
}
$commandToml = & $tomlLiteral $venvPython
$serverToml = & $tomlLiteral $serverPath
$cwdToml = & $tomlLiteral $mcpRoot
$envToml = & $tomlLiteral $userEnvPath

$mcpBlock = @"
[mcp_servers.openai-image]
command = $commandToml
args = [$serverToml]
cwd = $cwdToml
startup_timeout_sec = 120

[mcp_servers.openai-image.env]
OPENAI_IMAGE_ENV_FILE = $envToml
"@.Trim()

$config = if (Test-Path -LiteralPath $configPath) {
    Get-Content -Raw -LiteralPath $configPath
} else {
    ""
}

# Remove only a previous openai-image table and its nested env table.
$config = [regex]::Replace($config, '(?ms)^\[mcp_servers\.openai-image\]\r?\n.*?(?=^\[|\z)', '')
if ($config -notmatch '(?m)^\[mcp_servers\]\s*$') {
    $config = $config.TrimEnd() + "`r`n`r`n[mcp_servers]`r`n"
}
$updatedConfig = $config.TrimEnd() + "`r`n`r`n" + $mcpBlock + "`r`n"

if ($config -ne $updatedConfig) {
    if (Test-Path -LiteralPath $configPath) {
        Copy-Item -LiteralPath $configPath -Destination ($configPath + ".mps-muti.bak") -Force
    }
    Set-Content -LiteralPath $configPath -Value $updatedConfig -Encoding utf8
}

Write-Output "Registered openai-image MCP using the bundled relative server path."
Write-Output "Environment file: $userEnvPath"
if ($createdEnv) {
    Write-Warning "Fill OPENAI_API_KEY, OPENAI_BASE_URL, and OPENAI_IMAGE_MODEL in the environment file, then restart Codex."
} else {
    Write-Output "Restart Codex to reload the MCP configuration."
}
