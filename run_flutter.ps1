# Flutter Helper Script
# This script allows you to run Flutter commands even if Flutter is not in PATH

param(
    [Parameter(Mandatory=$true)]
    [string]$Command
)

$flutterPath = "C:\src\flutter\bin\flutter.bat"

if (Test-Path $flutterPath) {
    & $flutterPath $Command
} else {
    Write-Host "Error: Flutter not found at $flutterPath" -ForegroundColor Red
    Write-Host "Please update the flutterPath variable in this script if Flutter is installed elsewhere." -ForegroundColor Yellow
}

