param(
    [Parameter(Mandatory = $true, HelpMessage = "Path to a source PNG with transparent background (or solid white to be removed)")]
    [string]$Source,

    [switch]$RemoveWhiteBackground,

    [string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

Write-Host "Generating Windows icons from: $Source" -ForegroundColor Cyan

# Check ImageMagick availability
if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick 'magick' command not found. Install from https://imagemagick.org, then re-run."
    exit 1
}

if (-not (Test-Path $Source)) {
    Write-Error "Source file not found: $Source"
    exit 1
}

$resourcesDir = Join-Path $ProjectRoot 'windows/runner/resources'
$imagesDir    = Join-Path $ProjectRoot 'windows/runner/Images'

New-Item -ItemType Directory -Force -Path $resourcesDir | Out-Null
New-Item -ItemType Directory -Force -Path $imagesDir    | Out-Null

$icoPath   = Join-Path $resourcesDir 'app_icon.ico'
$png256    = Join-Path $resourcesDir 'app_icon_transparent.png'

# Helper to build magick command
$baseArgs = @($Source, '-background', 'none', '-alpha', 'on')
if ($RemoveWhiteBackground) {
    $baseArgs = @($Source, '-fuzz', '10%', '-transparent', 'white', '-background', 'none', '-alpha', 'on')
}

# 1) Generate a clean 256x256 PNG for reuse
& magick @baseArgs -resize 256x256 $png256
if ($LASTEXITCODE -ne 0) { Write-Error "Failed generating $png256"; exit 1 }

# 2) Generate multi-size ICO (16,32,48,64,128,256)
& magick @baseArgs -define icon:auto-resize="256,128,64,48,32,16" $icoPath
if ($LASTEXITCODE -ne 0) { Write-Error "Failed generating $icoPath"; exit 1 }

# 3) Generate MSIX tile images (all transparent)
$tiles = @(
    @{ Path = (Join-Path $imagesDir 'Square44x44Logo.png');    Size = '44x44'     },
    @{ Path = (Join-Path $imagesDir 'SmallTile.png');          Size = '71x71'     },
    @{ Path = (Join-Path $imagesDir 'Square150x150Logo.png');  Size = '150x150'   },
    @{ Path = (Join-Path $imagesDir 'LargeTile.png');          Size = '310x310'   },
    @{ Path = (Join-Path $imagesDir 'Wide310x150Logo.png');    Size = '310x150'   },
    @{ Path = (Join-Path $imagesDir 'SplashScreen.png');       Size = '620x300'   },
    @{ Path = (Join-Path $imagesDir 'BadgeLogo.png');          Size = '44x44'     }
)

foreach ($t in $tiles) {
    & magick @baseArgs -resize $t.Size $t.Path
    if ($LASTEXITCODE -ne 0) { Write-Error ("Failed generating {0}" -f $t.Path); exit 1 }
}

Write-Host "Done. ICO at: $icoPath" -ForegroundColor Green
Write-Host "256px PNG at: $png256" -ForegroundColor Green
Write-Host "MSIX images in: $imagesDir" -ForegroundColor Green

Write-Host "Next:" -ForegroundColor Yellow
Write-Host "- Rebuild EXE: flutter build windows" -ForegroundColor Yellow
Write-Host "- For MSIX, pass --logo-path $png256 (or point a custom manifest to windows/runner/Images)" -ForegroundColor Yellow
