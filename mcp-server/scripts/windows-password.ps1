<#
  Windows password store for the SE63 MCP server (no extra software needed).

  The password is encrypted with Windows DPAPI: only the same Windows user on the same PC can decrypt it.
  It is never written in plain text and never put on a command line.

  Store it once (run in your own PowerShell window, input is hidden):
    powershell -NoProfile -ExecutionPolicy Bypass -File <path>\windows-password.ps1 -Store -User <SAP_USER>

  Then in mcp-server/.env (no quotes around the path; the path must not contain spaces):
    SAP_PASSWORD_CMD=powershell -NoProfile -ExecutionPolicy Bypass -File <path>\windows-password.ps1

  Without -Store the script prints the password for SAP_USER (taken from the environment / .env).
#>
param(
  [switch]$Store,
  [string]$User = $env:SAP_USER
)

$ErrorActionPreference = "Stop"
if (-not $User) {
  [Console]::Error.WriteLine("No SAP user: pass -User <SAP_USER> or set SAP_USER.")
  exit 1
}
$dir = Join-Path $env:APPDATA "sap-se63-mcp"
$file = Join-Path $dir ("{0}.pwd" -f $User.ToUpper())

if ($Store) {
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $secure = Read-Host "SAP password for $($User.ToUpper())" -AsSecureString
  if ($secure.Length -eq 0) {
    [Console]::Error.WriteLine("Empty password - nothing stored.")
    exit 1
  }
  ConvertFrom-SecureString -SecureString $secure | Set-Content -Path $file -Encoding Ascii
  Write-Host "Stored, encrypted for this Windows user: $file"
  exit 0
}

if (-not (Test-Path $file)) {
  [Console]::Error.WriteLine("No stored password for $($User.ToUpper()). Run this script once with -Store -User $User.")
  exit 1
}
$secure = Get-Content -Path $file | ConvertTo-SecureString
# Node reads stdout as UTF-8; the console default (OEM code page) would garble characters such as é or §
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
  [Console]::Out.Write([Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr))
} finally {
  [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}
