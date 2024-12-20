# Set paths
$adbPath = "C:\Users\georg\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$flutterProjectPath = "E:\asu_last\MP_CSE431\hedieaty"
$screenRecordingPath = "$flutterProjectPath\screen_second.mp4"

# Specify the target device ID
$deviceId = "emulator-5554"

# Navigate to the Flutter project directory
Set-Location -Path $flutterProjectPath

# Kill any existing screenrecord process
& $adbPath -s $deviceId shell "killall -2 screenrecord" 2>$null

# Remove any existing recording file on device
& $adbPath -s $deviceId shell "rm /sdcard/screen_record.mp4" 2>$null

# Start screen recording
Write-Host "Starting screen recording..." -ForegroundColor Green
Start-Process -NoNewWindow -FilePath $adbPath -ArgumentList "-s", $deviceId, "shell", "screenrecord", "/sdcard/screen_record.mp4" -PassThru

# Small delay to ensure recording has started
Start-Sleep -Seconds 2

# Run the Flutter integration test
Write-Host "Running Flutter integration test..." -ForegroundColor Green
flutter drive --driver=test_driver/test_driver.dart --target=integration_test/e2e_test.dart

# Stop the recording by killing the screenrecord process
Write-Host "Stopping screen recording..." -ForegroundColor Green
& $adbPath -s $deviceId shell "killall -2 screenrecord"

# Wait a moment for the file to be properly saved
Start-Sleep -Seconds 3

# Check if the recording file exists on the device
$fileExists = & $adbPath -s $deviceId shell "ls /sdcard/screen_record.mp4 2>/dev/null"
if (-not $fileExists) {
    Write-Host "Error: Recording file not found on device" -ForegroundColor Red
    exit 1
}

# Pull the recording from the device
Write-Host "Pulling recording from device..." -ForegroundColor Green
& $adbPath -s $deviceId pull /sdcard/screen_record.mp4 $screenRecordingPath

if (Test-Path $screenRecordingPath) {
    Write-Host "Screen recording saved successfully to: $screenRecordingPath" -ForegroundColor Green
} else {
    Write-Host "Error: Failed to save recording locally" -ForegroundColor Red
}

# Clean up the file from the device
& $adbPath -s $deviceId shell "rm /sdcard/screen_record.mp4"
