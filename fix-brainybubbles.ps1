param(
  [string]$PackageId = "com.yourstudio.brainybubbles",
  [string]$NdkVersion = "27.0.12077973"
)

$ErrorActionPreference = "Stop"

function Assert-ProjectRoot {
  if (-not (Test-Path ".\pubspec.yaml")) {
    throw "Run this from your Flutter project root (where pubspec.yaml lives). Current: $(Get-Location)"
  }
}

function Ensure-DevModeHint {
  Write-Host "If you see 'Building with plugins requires symlink support', enable Developer Mode (Windows Settings → For developers)." -ForegroundColor Yellow
  try { Start-Process "ms-settings:developers" -ErrorAction SilentlyContinue } catch {}
}

function Ensure-Assets {
  "assets\icons","assets\images","assets\audio" | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force $_ | Out-Null }
    $gitkeep = Join-Path $_ ".gitkeep"
    if (-not (Test-Path $gitkeep)) { New-Item -ItemType File -Force $gitkeep | Out-Null }
  }
  $pubspec = Get-Content ".\pubspec.yaml" -ErrorAction SilentlyContinue
  if ($pubspec) {
    $txt = $pubspec -join "`n"
    if ($txt -notmatch '(?ms)^\s*flutter:\s*(?:.*\n)*?\s*assets:\s*\n\s*-\s*assets/icons/\s*\n\s*-\s*assets/images/\s*\n\s*-\s*assets/audio/') {
      Write-Host "Reminder: add assets to pubspec.yaml under 'flutter:'" -ForegroundColor Yellow
      Write-Host @"
  uses-material-design: true
  assets:
    - assets/icons/
    - assets/images/
    - assets/audio/
"@
    }
  }
}

function Patch-GradleKts {
  $kts = ".\android\app\build.gradle.kts"
  if (-not (Test-Path $kts)) { throw "Missing $kts. Run 'flutter create .' then re-run this script." }
  $text = Get-Content $kts -Raw

  # namespace & appId
  if ($text -match '(?m)^\s*namespace\s*=') {
    $text = $text -replace '(?m)^\s*namespace\s*=\s*".*?"', "    namespace = `"$PackageId`""
  } else {
    # Insert namespace at top of android{ } if missing
    $text = $text -replace '(?ms)(android\s*\{)', "`$1`r`n    namespace = `"$PackageId`""
  }
  if ($text -match '(?ms)defaultConfig\s*\{[^}]*applicationId\s*=') {
    $text = $text -replace '(?ms)(defaultConfig\s*\{[^}]*applicationId\s*=\s*").*?(")', "`$1$PackageId`$2"
  } else {
    $text = $text -replace '(?ms)(defaultConfig\s*\{)', "`$1`r`n        applicationId = `"$PackageId`""
  }

  # compileSdk / targetSdk
  $text = $text -replace '(?m)^\s*compileSdk\s*=.*$', "    compileSdk = 35"
  $text = $text -replace '(?ms)(defaultConfig\s*\{[^}]*targetSdk\s*=\s*).*?(\r?\n)', "`$135`$2"

  # minSdk at least 21 using maxOf
  if ($text -notmatch 'minSdk\s*=\s*maxOf') {
    if ($text -match '(?ms)(defaultConfig\s*\{[^}]*minSdk\s*=\s*)(.*)') {
      $text = $text -replace '(?ms)(defaultConfig\s*\{[^}]*minSdk\s*=\s*).*?(\r?\n)', "`$1maxOf(21, flutter.minSdkVersion)`$2"
    } else {
      $text = $text -replace '(?ms)(defaultConfig\s*\{)', "`$1`r`n        minSdk = maxOf(21, flutter.minSdkVersion)"
    }
  }

  # ndkVersion pin
  if ($text -match '(?m)^\s*ndkVersion\s*=') {
    $text = $text -replace '(?m)^\s*ndkVersion\s*=\s*".*?"', "    ndkVersion = `"$NdkVersion`""
  } else {
    $text = $text -replace '(?m)^(    compileSdk\s*=\s*35\s*$)', "`$1`r`n    ndkVersion = `"$NdkVersion`""
  }

  Set-Content $kts $text -Encoding UTF8
  Write-Host "Patched build.gradle.kts → namespace/appId=$PackageId, compile/target=35, ndk=$NdkVersion" -ForegroundColor Green
}

function Fix-MainActivity {
  $srcRoot = ".\android\app\src\main\kotlin"
  if (-not (Test-Path $srcRoot)) { return }

  $pkgPath = ($PackageId -replace '\.', '\')
  $goodDir = Join-Path $srcRoot $pkgPath
  if (-not (Test-Path $goodDir)) { New-Item -ItemType Directory -Force $goodDir | Out-Null }

  $mains = Get-ChildItem $srcRoot -Recurse -Filter "MainActivity.kt" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName
  if (-not $mains) { return }

  $keep = $mains | Where-Object { $_ -like "*$pkgPath*MainActivity.kt" } | Select-Object -First 1
  if (-not $keep) { $keep = $mains | Select-Object -First 1 }

  $content = Get-Content $keep -Raw
  $content = $content -replace '(?m)^package\s+.*$', "package $PackageId"
  if ($content -notmatch 'FlutterActivity') {
    $content = "package $PackageId`r`n`r`nimport io.flutter.embedding.android.FlutterActivity`r`n`r`nclass MainActivity : FlutterActivity()" 
  }
  Set-Content $keep $content -Encoding UTF8

  $dest = Join-Path $goodDir "MainActivity.kt"
  if ($keep -ne $dest) { Copy-Item $keep $dest -Force }

  foreach ($m in $mains) { if ($m -ne $dest) { Remove-Item $m -Force } }

  Write-Host "MainActivity fixed at: $dest (package $PackageId)" -ForegroundColor Green
}

function Fix-ManifestActivityRef {
  $manifest = ".\android\app\src\main\AndroidManifest.xml"
  if (-not (Test-Path $manifest)) { return }
  $xml = Get-Content $manifest -Raw
  $xml = $xml -replace '(?m)(<activity[^>]*android:name=")[^"]+(")', '$1.MainActivity$2'
  Set-Content $manifest $xml -Encoding UTF8
}

# --- RUN ---
Assert-ProjectRoot
Ensure-DevModeHint
Ensure-Assets
Patch-GradleKts
Fix-MainActivity
Fix-ManifestActivityRef

try { & ".\android\gradlew" --stop } catch {}
flutter clean
flutter pub get

Write-Host "`nAll fixes applied. Try launching:" -ForegroundColor Cyan
Write-Host "  flutter run" -ForegroundColor Cyan