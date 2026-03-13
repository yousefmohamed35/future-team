# Force clean build directory - handles locked files
Write-Host "Force cleaning build directory..." -ForegroundColor Yellow

# Kill all processes that might lock files
Write-Host "Killing all related processes..." -ForegroundColor Cyan
$processes = @("java", "dart", "flutter", "gradle")
foreach ($proc in $processes) {
    Get-Process -Name $proc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
}

Start-Sleep -Seconds 3

# Function to force delete directory
function Force-DeleteDirectory {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        return $true
    }
    
    Write-Host "Attempting to delete: $Path" -ForegroundColor Cyan
    
    # Try to remove read-only attributes
    try {
        Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            $_.Attributes = 'Normal'
        }
    } catch {}
    
    # Try multiple deletion methods
    $methods = @(
        { Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop },
        { cmd /c "rmdir /s /q `"$Path`"" },
        { 
            # Delete files individually first
            Get-ChildItem -Path $Path -Recurse -File -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                } catch {}
            }
            # Then delete directories
            Get-ChildItem -Path $Path -Recurse -Directory -Force -ErrorAction SilentlyContinue | 
                Sort-Object -Property FullName -Descending | ForEach-Object {
                try {
                    Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue
                } catch {}
            }
            Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
        }
    )
    
    foreach ($method in $methods) {
        try {
            & $method
            if (-not (Test-Path $Path)) {
                Write-Host "Successfully deleted: $Path" -ForegroundColor Green
                return $true
            }
        } catch {
            Start-Sleep -Milliseconds 500
        }
    }
    
    Write-Host "Could not fully delete: $Path (some files may still be locked)" -ForegroundColor Yellow
    return $false
}

# Delete the specific problematic directory
$problemDir = "build\app\intermediates\flutter\debug\flutter_assets"
if (Test-Path $problemDir) {
    Write-Host "Deleting problematic directory: $problemDir" -ForegroundColor Cyan
    Force-DeleteDirectory -Path $problemDir
}

# Delete entire build directory
if (Test-Path "build") {
    Write-Host "Deleting entire build directory..." -ForegroundColor Cyan
    Force-DeleteDirectory -Path "build"
}

Write-Host ""
Write-Host "Force cleanup completed!" -ForegroundColor Green
Write-Host "Try building again now." -ForegroundColor Yellow

