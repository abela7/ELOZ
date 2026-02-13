# Flutter Build Runner Script
# This script checks for Flutter and runs build_runner

Write-Host "Checking for Flutter installation..." -ForegroundColor Cyan

# Step 1: Check if Flutter is already in PATH
try {
    $flutterVersion = flutter --version 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "SUCCESS: Flutter found in PATH!" -ForegroundColor Green
        Write-Host $flutterVersion -ForegroundColor Gray
        $flutterFound = $true
    }
} catch {
    $flutterFound = $false
}

# Step 2: If not found, check common locations
if (-not $flutterFound) {
    Write-Host "Flutter not found in PATH. Searching common locations..." -ForegroundColor Yellow
    
    $commonPaths = @(
        "C:\src\flutter\bin\flutter.bat",
        "C:\flutter\bin\flutter.bat",
        "$env:USERPROFILE\flutter\bin\flutter.bat",
        "C:\tools\flutter\bin\flutter.bat",
        "C:\Program Files\flutter\bin\flutter.bat",
        "C:\Program Files (x86)\flutter\bin\flutter.bat"
    )
    
    $flutterPath = $null
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            $flutterPath = Split-Path $path -Parent
            Write-Host "Found Flutter at: $flutterPath" -ForegroundColor Green
            break
        }
    }
    
    # Step 3: Check in current directory and parent directories
    if (-not $flutterPath) {
        Write-Host "Checking current directory structure..." -ForegroundColor Yellow
        $currentDir = Get-Location
        $checkPaths = @(
            "$currentDir\flutter\bin\flutter.bat",
            "$currentDir\..\flutter\bin\flutter.bat",
            "$currentDir\..\..\flutter\bin\flutter.bat"
        )
        
        foreach ($path in $checkPaths) {
            if (Test-Path $path) {
                $flutterPath = Split-Path $path -Parent
                Write-Host "Found Flutter at: $flutterPath" -ForegroundColor Green
                break
            }
        }
    }
    
    # Step 4: Add Flutter to PATH if found
    if ($flutterPath) {
        Write-Host "Adding Flutter to PATH for this session..." -ForegroundColor Cyan
        $env:PATH = "$flutterPath;$env:PATH"
        
        # Verify it works
        try {
            $flutterVersion = flutter --version 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "SUCCESS: Flutter is now accessible!" -ForegroundColor Green
                $flutterFound = $true
            }
        } catch {
            Write-Host "ERROR: Failed to access Flutter even after adding to PATH" -ForegroundColor Red
            $flutterFound = $false
        }
    } else {
        Write-Host "ERROR: Flutter not found in any common locations." -ForegroundColor Red
        Write-Host ""
        Write-Host "Please:" -ForegroundColor Yellow
        Write-Host "1. Install Flutter from https://flutter.dev/docs/get-started/install/windows" -ForegroundColor White
        Write-Host "2. Or tell me where Flutter is installed, and I'll add it to PATH" -ForegroundColor White
        Write-Host "3. Or use Android Studio/VS Code terminal (Flutter is usually configured there)" -ForegroundColor White
        $flutterFound = $false
    }
}

# Step 5: Run build_runner if Flutter is found
if ($flutterFound) {
    Write-Host ""
    Write-Host "Running build_runner..." -ForegroundColor Cyan
    Write-Host ""
    
    # Make sure we're in the life_manager directory
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Set-Location $scriptDir
    
    # Run build_runner
    flutter pub run build_runner build --delete-conflicting-outputs
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "SUCCESS: Build runner completed successfully!" -ForegroundColor Green
        Write-Host "Generated files:" -ForegroundColor Cyan
        Write-Host "  - lib/data/models/task_type.g.dart" -ForegroundColor Gray
        Write-Host "  - lib/data/models/category.g.dart" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "ERROR: Build runner failed. Check the error messages above." -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "WARNING: Cannot run build_runner without Flutter." -ForegroundColor Yellow
}
