# Serves every .luau file under <project>/src/ as JSON so Roblox Studio can pull them (see tools/sync.luau).
# A minimal stand-in for `rojo serve`, which Smart App Control blocks on this machine.
#
# Usage: powershell -ExecutionPolicy Bypass -File tools\sync-server.ps1 -Project majesty_blox [-Port 34873]

param(
    [Parameter(Mandatory = $true)][string]$Project,
    [int]$Port = 34873
)

$ErrorActionPreference = 'Stop'
$projectRoot = Join-Path (Split-Path -Parent $PSScriptRoot) $Project
if (-not (Test-Path (Join-Path $projectRoot 'src'))) {
    throw "No src/ folder in $projectRoot"
}
$roots = [ordered]@{ server = 'Server'; client = 'Client'; shared = 'Shared' }

function Get-Manifest {
    $files = New-Object System.Collections.ArrayList
    foreach ($dir in $roots.Keys) {
        $base = Join-Path $projectRoot "src\$dir"
        if (-not (Test-Path $base)) { continue }
        foreach ($file in Get-ChildItem $base -Recurse -File -Filter *.luau) {
            $relative = $file.FullName.Substring($base.Length + 1) -replace '\\', '/'
            $name = $relative -replace '\.luau$', ''
            $className = 'ModuleScript'
            if ($name -match '\.server$') {
                $className = 'Script'
                $name = $name -replace '\.server$', ''
            } elseif ($name -match '\.client$') {
                $className = 'LocalScript'
                $name = $name -replace '\.client$', ''
            }
            [void]$files.Add([pscustomobject]@{
                root      = $roots[$dir]
                path      = $name
                className = $className
                source    = [IO.File]::ReadAllText($file.FullName)
            })
        }
    }
    ConvertTo-Json -InputObject @($files) -Depth 3 -Compress
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Sync server for '$Project' listening on http://localhost:$Port/manifest"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        try {
            $bytes = [Text.Encoding]::UTF8.GetBytes((Get-Manifest))
            $context.Response.ContentType = 'application/json; charset=utf-8'
            $context.Response.ContentLength64 = $bytes.Length
            $context.Response.OutputStream.Write($bytes, 0, $bytes.Length)
            Write-Host "$(Get-Date -Format HH:mm:ss) served manifest"
        } catch {
            $context.Response.StatusCode = 500
            Write-Host "Error: $_"
        } finally {
            $context.Response.Close()
        }
    }
} finally {
    $listener.Stop()
}
