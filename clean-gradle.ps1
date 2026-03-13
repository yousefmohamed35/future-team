# PowerShell script to clean all Gradle caches
Write-Host "🧹 Cleaning Gradle caches..." -ForegroundColor Yellow

# Stop all Gradle daemons
Write-Host "Stopping Gradle daemons..." -ForegroundColor Cyan
cd android
if (Test-Path ".\gradlew.bat") {
    .\gradlew.bat --stop 2>&1 | Out-Null
}
cd ..

# Kill any Java processes that might be locking files
Write-Host "Killing Java processes..." -ForegroundColor Cyan
Get-Process -Name "java" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name "dart" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Get-Process -Name "flutter" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

# Wait a bit for processes to release files
Start-Sleep -Seconds 3

# Clear global Gradle cache (corrupted metadata)
Write-Host "Clearing global Gradle cache..." -ForegroundColor Cyan
$gradleCache = "$env:USERPROFILE\.gradle\caches"

# Clear specific corrupted directories
if (Test-Path "$gradleCache\8.7") {
    Remove-Item -Path "$gradleCache\8.7\kotlin-dsl" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$gradleCache\8.7\scripts" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$gradleCache\8.7\accessors" -Recurse -Force -ErrorAction SilentlyContinue
}

# Clear transforms-4 cache (where corrupted metadata.bin files are)
if (Test-Path "$gradleCache\transforms-4") {
    Write-Host "Clearing transforms-4 cache (corrupted metadata files)..." -ForegroundColor Cyan
    Remove-Item -Path "$gradleCache\transforms-4" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ transforms-4 cache cleared" -ForegroundColor Green
}

# Clear all caches for Gradle 8.7 if still having issues
Write-Host "Clearing all Gradle 8.7 caches..." -ForegroundColor Cyan
if (Test-Path "$gradleCache\8.7") {
    Remove-Item -Path "$gradleCache\8.7" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ All Gradle 8.7 caches cleared" -ForegroundColor Green
}

Write-Host "✅ Global Gradle cache cleared" -ForegroundColor Green

# Clear local project Gradle cache
Write-Host "Clearing local Gradle cache..." -ForegroundColor Cyan
if (Test-Path "android\.gradle") {
    Remove-Item -Path "android\.gradle" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Local Gradle cache cleared" -ForegroundColor Green
}

# Clear build directories (with retry for locked files)
Write-Host "Clearing build directories..." -ForegroundColor Cyan
$buildDirs = @("android\app\build", "android\build", "build")
foreach ($dir in $buildDirs) {
    if (Test-Path $dir) {
        # Try multiple times to delete locked files
        $maxRetries = 3
        $retryCount = 0
        $deleted = $false
        
        while ($retryCount -lt $maxRetries -and -not $deleted) {
            try {
                # Force close any handles to files in this directory
                Get-ChildItem -Path $dir -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                    try {
                        $_.Attributes = 'Normal'
                    } catch {}
                }
                
                Remove-Item -Path $dir -Recurse -Force -ErrorAction Stop
                $deleted = $true
                Write-Host "✅ Cleared $dir" -ForegroundColor Green
            } catch {
                $retryCount++
                if ($retryCount -lt $maxRetries) {
                    Write-Host "⚠️  Retry $retryCount/$maxRetries for $dir..." -ForegroundColor Yellow
                    Start-Sleep -Seconds 2
                    # Kill processes that might be locking files
                    Get-Process -Name "java","dart","flutter" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                } else {
                    Write-Host "⚠️  Could not fully delete $dir (some files may be locked)" -ForegroundColor Yellow
                }
            }
        }
    }
}

# Clear Flutter SDK gradle build cache (where the locked files are)
Write-Host "Clearing Flutter SDK gradle build cache..." -ForegroundColor Cyan
$flutterSdkPath = "I:\fvm\cache.git\packages\flutter_tools\gradle\build"
if (Test-Path $flutterSdkPath) {
    Remove-Item -Path "$flutterSdkPath\kotlin" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -Path "$flutterSdkPath" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "✅ Flutter SDK gradle cache cleared" -ForegroundColor Green
}

Write-Host "`n✅ Gradle cleanup completed!" -ForegroundColor Green
Write-Host "You can now run: flutter pub get" -ForegroundColor Yellow

