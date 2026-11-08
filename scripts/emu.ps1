# Pleos Connect emulator from the terminal (Windows).
param(
    [Parameter(Position = 0)]
    [ValidateSet('start', 'wait', 'stop', 'status', 'console', 'launch', 'run', 'theme', 'anim', 'shot')]
    [string]$Command,
    [Parameter(Position = 1)]
    [string]$Value
)

Add-Type -AssemblyName System.Drawing

$Root = Split-Path -Parent $PSScriptRoot
$Sdk = if ($env:ANDROID_HOME) { $env:ANDROID_HOME }
       elseif ($env:ANDROID_SDK_ROOT) { $env:ANDROID_SDK_ROOT }
       else { Join-Path $env:LOCALAPPDATA 'Android\Sdk' }
$Emulator = Join-Path $Sdk 'emulator\emulator.exe'
$Adb = Join-Path $Sdk 'platform-tools\adb.exe'
$Log = Join-Path $env:TEMP 'pleos-emulator.log'
$Gpu = if ($env:PLEOS_GPU) { $env:PLEOS_GPU } else { 'host' }
$ConsolePort = if ($env:PLEOS_CONSOLE_PORT) { $env:PLEOS_CONSOLE_PORT } else { '8282' }
# Package to launch: PLEOS_APP, or the applicationId in app/build.gradle.kts.
$App = if ($env:PLEOS_APP) { $env:PLEOS_APP } else {
    $line = Select-String -Path (Join-Path $Root 'app\build.gradle.kts') -Pattern 'applicationId\s*=\s*"([^"]+)"' | Select-Object -First 1
    $line.Matches[0].Groups[1].Value
}
# Area the app gets on the 2560x1440 display (left, top, width, height), outside the system bars.
$Crop = [System.Drawing.Rectangle]::new(854, 93, 1678, 1206)

function Find-Avd {
    if ($env:PLEOS_AVD) { return $env:PLEOS_AVD }
    $found = & $Emulator -list-avds | Where-Object { $_ -match 'pleos' } | Select-Object -First 1
    if (-not $found) {
        Write-Host "No AVD with 'pleos' in its name. Set PLEOS_AVD."
        exit 1
    }
    return $found
}

switch ($Command) {
    'start' {
        if ((& $Adb devices) -match '^emulator-') { Write-Host 'Emulator already running.'; break }
        $avd = Find-Avd
        # -no-snapshot: always cold boot (required for VHAL) and never write a RAM snapshot to disk
        $proc = Start-Process -FilePath $Emulator -PassThru -NoNewWindow `
            -ArgumentList '-avd', $avd, '-no-snapshot', '-no-boot-anim', '-gpu', $Gpu `
            -RedirectStandardOutput $Log -RedirectStandardError "$Log.err"
        Write-Host "Started $avd (pid $($proc.Id)). Log: $Log"
    }
    'wait' {
        & $Adb wait-for-device
        while ((((& $Adb shell getprop sys.boot_completed) -join '').Trim()) -ne '1') { Start-Sleep -Seconds 2 }
        Write-Host 'Boot completed.'
    }
    'stop' {
        if ((& $Adb devices) -match '^emulator-') { & $Adb emu kill } else { Write-Host 'No emulator running.' }
    }
    'status' { & $Adb devices -l }
    'console' {
        # The Virtual Console listens on 8088 inside the guest; only the host side is configurable.
        & $Adb forward "tcp:$ConsolePort" tcp:8088 | Out-Null
        $url = "http://127.0.0.1:$ConsolePort"
        Write-Host "Virtual Console: $url"
        Start-Process $url
    }
    'launch' { & $Adb shell am start -n "$App/.MainActivity" }
    'run' {
        & (Join-Path $Root 'gradlew.bat') -q -p $Root installDebug
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & $Adb shell am force-stop $App
        # System apps may grab the screen after boot or a theme change; retry a few times.
        foreach ($try in 1..5) {
            & $Adb shell am start -n "$App/.MainActivity" 2>&1 | Out-Null
            Start-Sleep -Seconds 3
            if ((& $Adb shell dumpsys activity activities) -match "topResumedActivity.*$App/") {
                Write-Host "$App is in front."
                exit 0
            }
        }
        Write-Host "$App did not stay in front. Run 'launch' to retry."
        exit 1
    }
    'theme' {
        if ($Value -notin 'day', 'night', 'sensor') {
            Write-Host 'usage: scripts\emu.cmd theme {day|night|sensor}'
            exit 1
        }
        & $Adb shell cmd car_service day-night-mode $Value
    }
    'anim' {
        $factor = if ($Value) { $Value } else { '1' }
        foreach ($key in 'animator_duration_scale', 'transition_animation_scale', 'window_animation_scale') {
            & $Adb shell settings put global $key $factor
        }
        Write-Host "Animations x$factor (1 = normal)."
    }
    'shot' {
        $file = [System.IO.Path]::GetFullPath($(if ($Value) { $Value } else { 'shot.png' }))
        $whole = "$file.whole.png"
        & $Adb shell screencap -p /sdcard/emu-shot.png
        & $Adb pull /sdcard/emu-shot.png $whole | Out-Null
        & $Adb shell rm /sdcard/emu-shot.png
        $image = [System.Drawing.Bitmap]::FromFile($whole)
        $part = $image.Clone($Crop, $image.PixelFormat)
        $image.Dispose()
        $part.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
        $part.Dispose()
        Remove-Item $whole
        Write-Host "Saved $file"
    }
    default {
        Write-Host 'usage: scripts\emu.cmd {start|wait|stop|status|console|launch|run|theme|anim|shot}'
        exit 1
    }
}
