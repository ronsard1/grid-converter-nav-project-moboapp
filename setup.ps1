# GridNav - one-command setup and APK build (Windows PowerShell)
# Run from this folder in the VS Code terminal:
#     powershell -ExecutionPolicy Bypass -File setup.ps1
# Everything is also written to setup-log.txt  -> send that file if something fails.

$log = Join-Path $PSScriptRoot 'setup-log.txt'
Set-Location $PSScriptRoot
"GridNav setup log - $(Get-Date)" | Out-File $log

function Run-Step($num, $title, [scriptblock]$cmd) {
    Write-Host ""
    Write-Host "[$num/7] $title" -ForegroundColor Cyan
    "`n===== [$num/7] $title =====" | Out-File $log -Append
    & $cmd 2>&1 | Tee-Object -FilePath $log -Append
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "STOPPED at step $num ($title)." -ForegroundColor Red
        Write-Host "Send the file setup-log.txt (in this folder) so the problem can be fixed." -ForegroundColor Yellow
        exit 1
    }
}

Run-Step 1 'Checking Flutter and Android tools' { flutter doctor -v }
Run-Step 2 'Creating the Android part'          { flutter create --platforms=android --org rw.gridnav --project-name gridnav . }
Run-Step 3 'Downloading packages'               { flutter pub get }
Run-Step 4 'Putting map library and fonts inside the app' { dart run tool/get_libs.dart }
Run-Step 5 'App name, GPS and internet permission'        { dart run tool/setup_android.dart }
Run-Step 6 'Removing old build files'  { flutter clean }
Run-Step 7 'Building the APK (takes a few minutes the first time)' { flutter build apk --release }

$apk = Join-Path $PSScriptRoot 'build\app\outputs\flutter-apk\app-release.apk'
Write-Host ""
Write-Host "DONE. Your APK is here:" -ForegroundColor Green
Write-Host "  $apk" -ForegroundColor Green
Write-Host "Send it to your phone (WhatsApp as Document, or USB) and install it."
Write-Host "To test on the emulator instead: start the emulator, then run  flutter run"
explorer.exe (Split-Path $apk)
