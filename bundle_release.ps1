# bundle_release.ps1

Write-Host "Starting Release Build and Bundle Process..." -ForegroundColor Cyan

# 1. Clean and Build
Write-Host "Cleaning previous builds..."
flutter clean

Write-Host "Building for Windows (Release)..."
flutter build windows --release

if ($LASTEXITCODE -ne 0) {
    Write-Error "Build failed! Exiting."
    exit 1
}

# 2. Define Paths
$projectRoot = Get-Location
$buildOutput = "$projectRoot\build\windows\runner\Release" # Adjusted path for standard Flutter windows build
# Sometimes it's build\windows\x64\runner\Release depending on version, checking standard first.
if (-not (Test-Path $buildOutput)) {
     $buildOutput = "$projectRoot\build\windows\x64\runner\Release"
}

$bundleDir = "$projectRoot\release_bundle"
$system32 = "C:\Windows\System32"

# 3. Create Bundle Directory
if (Test-Path $bundleDir) {
    Write-Host "Removing old bundle directory..."
    Remove-Item -Path $bundleDir -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $bundleDir | Out-Null

# 4. Copy Build Output
Write-Host "Copying application files..."
Copy-Item -Path "$buildOutput\*" -Destination $bundleDir -Recurse

# 5. Copy DLLs
Write-Host "Copying Visual C++ DLLs..."
$dlls = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")

foreach ($dll in $dlls) {
    $source = "$system32\$dll"
    if (Test-Path $source) {
        Copy-Item -Path $source -Destination $bundleDir
        Write-Host "  [+] Bundled $dll" -ForegroundColor Green
    } else {
        Write-Warning "  [-] Could not find $dll in System32. You may need to install VC++ Redistributable."
    }
}

Write-Host "`n--------------------------------------------------"
Write-Host "Bundle created successfully at:" -ForegroundColor Green
Write-Host "$bundleDir" -ForegroundColor White
Write-Host "You can now zip this folder and distribute it."
Write-Host "--------------------------------------------------"
