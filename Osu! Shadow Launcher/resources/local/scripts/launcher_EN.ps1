$WindowSize = New-Object System.Management.Automation.Host.Size(58, 22)
$Host.UI.RawUI.WindowSize = $WindowSize
$Host.UI.RawUI.BufferSize = $WindowSize
$Host.UI.RawUI.WindowTitle = "Osu! Shadow Launcher"

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("user32.dll")]
    [return: MarshalAs(UnmanagedType.Bool)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
}
"@

$ScriptDir = Split-Path (Split-Path $PSScriptRoot)
if ([string]::IsNullOrEmpty($ScriptDir)) { $ScriptDir = $PWD.Path }

Function Get-FilePathGfx($Title) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Title = $Title
    $dialog.Filter = "Executable (*.exe)|*.exe"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $dialog.FileName
    }
    return $null
}

$configFile = "$ScriptDir\config.json"
$osuPath = "$env:LOCALAPPDATA\osu!\osu!.exe"

if (-not (Test-Path $osuPath)) {
    Write-Host "`n [?] NOTICE" -ForegroundColor Yellow
    Write-Host " [?] osu!.exe was not found at default path: $osuPath" -ForegroundColor DarkGray
    Write-Host " [~] Please select the location of osu!.exe manually..." -ForegroundColor White
    
    $osuPath = Get-FilePathGfx "Select location of osu!.exe..."
	
    if ([string]::IsNullOrEmpty($osuPath) -or -not (Test-Path $osuPath) -or (Split-Path $osuPath -Leaf).ToLower() -ne "osu!.exe") {
        Write-Host "`n [!] CRITICAL ERROR: Invalid file or selection cancelled." -ForegroundColor Red
        Write-Host " [!] Press Enter to exit..." -NoNewline -ForegroundColor White
        Read-Host
        exit
    }
}

Function Focus-Osu($proc) {
    $timeout = 15
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeout) {
        $proc.Refresh()
        if ($proc.MainWindowHandle -ne [IntPtr]::Zero) {
            Start-Sleep -Seconds 1.5
            [Win32]::ShowWindow($proc.MainWindowHandle, 9) | Out-Null
            [Win32]::SetForegroundWindow($proc.MainWindowHandle) | Out-Null
            break
        }
        Start-Sleep -Milliseconds 250
    }
    $sw.Stop()
}

Function Update-TosuEnv($TosuDir) {
    $envPath = Join-Path $TosuDir "tosu.env"
    
    $settings = @{
        "OPEN_DASHBOARD_ON_STARTUP" = "false"
        "ENABLE_KEY_OVERLAY"        = "true"
        "ENABLE_INGAME_OVERLAY"     = "true"
        "SERVER_IP"                 = "127.0.0.1"
        "SERVER_PORT"               = "24050"
        "ALLOWED_IPS"               = "127.0.0.1,localhost,absolute"
    }
    $preserveKeys = @("SERVER_IP", "SERVER_PORT", "ALLOWED_IPS")

    $existingContent = if (Test-Path $envPath) { Get-Content $envPath } else { @() }
    $newContent = @()
    $foundKeys = @()

    foreach ($line in $existingContent) {
        $updated = $false
        foreach ($key in $settings.Keys) {
            if ($line -match "^$key=") {
                if ($key -in $preserveKeys) {
                    $newContent += $line
                } else {
                    $newContent += "$key=$($settings[$key])"
                }
                $foundKeys += $key
                $updated = $true
                break
            }
        }
        if (-not $updated) {
            $newContent += $line
        }
    }

    foreach ($key in $settings.Keys) {
        if ($key -notin $foundKeys) {
            $newContent += "$key=$($settings[$key])"
        }
    }

    $newContent | Set-Content $envPath -Force
    Write-Host "    │ [*] tosu.env has been successfully configured!" -ForegroundColor DarkGray
}

while ($true) {
    Clear-Host

    if (-not (Test-Path $configFile)) {
        Write-Host "`n    ┌─[ INITIALIZING SETUP ]───────────────────" -ForegroundColor DarkGray
        Write-Host "    │ Searching for modules..." -ForegroundColor Cyan
        
        $tosuAuto = Get-ChildItem -Path $ScriptDir -Filter "tosu.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($tosuAuto) {
            $tosuPath = $tosuAuto.FullName
            Write-Host "    │ [+] Found: tosu.exe" -ForegroundColor Green
            Update-TosuEnv (Split-Path $tosuPath)
        } else {
            Write-Host "    │ [?] Tosu was not found." -ForegroundColor Yellow
			Write-Host "    │" -ForegroundColor Yellow
            Write-Host "    │ [1] Browse local files (.exe)" -ForegroundColor Cyan
            Write-Host "    │ [2] Download latest version (GitHub)" -ForegroundColor Cyan
            Write-Host "    │ [Enter to skip] > " -NoNewline -ForegroundColor White
            $tKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
            
            if ($tKey.Character -eq '1') {
                Write-Host "1" -ForegroundColor Cyan
                $pickedTosu = Get-FilePathGfx "Select location of tosu.exe..."
                if ($pickedTosu) {
                    if ((Split-Path $pickedTosu -Leaf).ToLower() -eq "tosu.exe") {
                        $sourceDir = Split-Path $pickedTosu
                        $targetDir = Join-Path $ScriptDir "tosu"
                        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }
                        Write-Host "    │ [*] Importing Tosu..." -ForegroundColor Yellow
                        Copy-Item -Path "$sourceDir\*" -Destination $targetDir -Recurse -Force
                        $tosuPath = Join-Path $targetDir "tosu.exe"
                        Write-Host "    │ [+] Tosu imported successfully!" -ForegroundColor Green
                        Update-TosuEnv $targetDir
                    } else {
                        Write-Host "    │ [!] Error: File not containing tosu.exe!" -ForegroundColor Red
                        $tosuPath = $null
                    }
                } else { $tosuPath = $null }
            } elseif ($tKey.Character -eq '2') {
                Write-Host "2" -ForegroundColor Cyan
                try {
                    $progAct = "Tosu Installation Process"
                    Write-Progress -Activity $progAct -Status "Fetching repository data..." -PercentComplete 10
                    $apiUrl = "https://api.github.com/repos/tosuapp/tosu/releases/latest"
                    $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
                    $asset = $release.assets | Where-Object { $_.name -match "windows" -and $_.name -like "*.zip" } | Select-Object -First 1

                    if ($asset) {
                        $zipPath = Join-Path $ScriptDir $asset.name
                        $targetDir = Join-Path $ScriptDir "tosu"

                        Write-Progress -Activity $progAct -Status "Downloading $($asset.name)..." -PercentComplete 30
                        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing

                        Write-Progress -Activity $progAct -Status "Extracting $($asset.name)..." -PercentComplete 60
                        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }
                        Expand-Archive -Path $zipPath -DestinationPath $targetDir -Force

                        Write-Progress -Activity $progAct -Status "Importing default settings..." -PercentComplete 80
                        
                        $localEnv = Join-Path $ScriptDir "local\default_settings.env"
                        if (Test-Path $localEnv) { Copy-Item -Path $localEnv -Destination "$targetDir\tosu.env" -Force }

                        $localIngame = Join-Path $ScriptDir "local\default_ingame_settings.json"
                        $settingsDir = Join-Path $targetDir "settings"
                        if (-not (Test-Path $settingsDir)) { New-Item -ItemType Directory -Path $settingsDir | Out-Null }
                        if (Test-Path $localIngame) { Copy-Item -Path $localIngame -Destination "$settingsDir\__ingame__.values.json" -Force }

                        $localStatic = Join-Path $ScriptDir "local\static"
                        $staticDir = Join-Path $targetDir "static"
                        if (Test-Path $localStatic) {
                            if (-not (Test-Path $staticDir)) { New-Item -ItemType Directory -Path $staticDir | Out-Null }
                            Copy-Item -Path "$localStatic\*" -Destination $staticDir -Recurse -Force
                        }

                        Write-Progress -Activity $progAct -Status "Cleaning up..." -PercentComplete 95
                        Remove-Item -Path $zipPath -Force

                        $tosuPath = Join-Path $targetDir "tosu.exe"
                        Write-Progress -Activity $progAct -Status "Finished!" -PercentComplete 100
                        Start-Sleep -Milliseconds 500
                        Write-Progress -Activity $progAct -Completed

                        Write-Host "    │ [+] Tosu was successfully downloaded and installed!" -ForegroundColor Green
                        Update-TosuEnv $targetDir
                    } else {
                        Write-Host "    │ [!] Unable to find a compatible Windows release." -ForegroundColor Red
                        $tosuPath = $null
                    }
                } catch {
                    Write-Host "    │ [!] Download error: $($_.Exception.Message)" -ForegroundColor Red
                    $tosuPath = $null
                }
            } else {
                Write-Host "Skipped" -ForegroundColor DarkGray
                $tosuPath = $null
            }
        }
        
        Write-Host "    │" -ForegroundColor DarkGray
        Write-Host "    │ [?] Do you want to import GosuMemory? [deprecated] (Y/N) > " -NoNewline -ForegroundColor Yellow
        $gKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($gKey.VirtualKeyCode -eq 13) {
            $gResponse = "n"
            Write-Host "N (Skipped)" -ForegroundColor DarkGray
        } else {
            $gResponse = $gKey.Character.ToString()
            Write-Host $gResponse -ForegroundColor Cyan
        }
        
        $gosuPath = $null
        if ($gResponse.Trim().ToLower() -in @('y', 'yes')) {
            $gosuAuto = Get-ChildItem -Path $ScriptDir -Filter "gosumemory.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($gosuAuto) {
                $gosuPath = $gosuAuto.FullName
                Write-Host "    │ [+] Found: gosumemory.exe" -ForegroundColor Green
            } else {
                $pickedGosu = Get-FilePathGfx "Select location of gosumemory.exe..."
                if ($pickedGosu) {
                    if ((Split-Path $pickedGosu -Leaf).ToLower() -eq "gosumemory.exe") {
                        $targetDir = Join-Path $ScriptDir "gosumemory"
                        if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }
                        Write-Host "    │ [*] Importing GosuMemory..." -ForegroundColor Yellow
                        Copy-Item -Path $pickedGosu -Destination $targetDir -Force
                        $gosuPath = Join-Path $targetDir "gosumemory.exe"
                        Write-Host "    │ [+] GosuMemory imported successfully!" -ForegroundColor Green
                    } else {
                        Write-Host "    │ [!] Error: File not containing gosumemory.exe!" -ForegroundColor Red
                        $gosuPath = $null
                    }
                }
            }
        }

        $wOsu = ""
        $wReturn = ""
        $wPath = $null

        Write-Host "    │" -ForegroundColor DarkGray
        Write-Host "    │ [?] Do you want to set up Wooting Profile Switcher? (Y/N) > " -NoNewline -ForegroundColor Yellow
        $wKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        if ($wKey.VirtualKeyCode -eq 13) {
            $wResponse = "n"
            Write-Host "N (Skipped)" -ForegroundColor DarkGray
        } else {
            $wResponse = $wKey.Character.ToString()
            Write-Host $wResponse -ForegroundColor Cyan
        }

        if ($wResponse.Trim().ToLower() -in @('y', 'yes')) {
            $wootingAuto = Get-ChildItem -Path $ScriptDir -Filter "wooting-profile-switcher.exe" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($wootingAuto) {
                $wPath = $wootingAuto.FullName
                Write-Host "    │ [+] Found: wooting-profile-switcher.exe" -ForegroundColor Green
            } else {
                Write-Host "    │ [?] Wooting Switcher not found. What do you want to do?" -ForegroundColor Yellow
				Write-Host "    │" -ForegroundColor Yellow
                Write-Host "    │ [1] Browse local files (.exe)" -ForegroundColor Cyan
                Write-Host "    │ [2] Download latest version (GitHub)" -ForegroundColor Cyan
                Write-Host "    │ [Enter to skip] > " -NoNewline -ForegroundColor White
                $wMenuKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                
                if ($wMenuKey.Character -eq '1') {
                    Write-Host "1" -ForegroundColor Cyan
                    $pickedWooting = Get-FilePathGfx "Select location of wooting-profile-switcher.exe..."
                    if ($pickedWooting) {
                        if ((Split-Path $pickedWooting -Leaf).ToLower() -like "*wooting-profile-switcher*.exe") {
                            $sourceDir = Split-Path $pickedWooting
                            $targetDir = Join-Path $ScriptDir "wooting-profile-switcher"
                            if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }
                            
                            Write-Host "    │ [*] Importing Wooting Profile Switcher..." -ForegroundColor Yellow
                            Copy-Item -Path $pickedWooting -Destination $targetDir -Force
                            
                            $configJson = Join-Path $sourceDir "wooting-profile-switcher.json"
                            if (Test-Path $configJson) {
                                Copy-Item -Path $configJson -Destination $targetDir -Force
                                Write-Host "    │ [+] Wooting-profile-switcher.json imported successfully!" -ForegroundColor Green
                            }
                            
                            $wPath = Join-Path $targetDir (Split-Path $pickedWooting -Leaf)
                            Write-Host "    │ [+] Wooting Profile Switcher imported successfully!" -ForegroundColor Green
                        } else {
                            Write-Host "    │ [!] Error: File not containing 'wooting-profile-switcher'!" -ForegroundColor Red
                        }
                    } else {
                        Write-Host "    │ [!] Wooting Profile Switcher not found..." -ForegroundColor Red
                    }
                } elseif ($wMenuKey.Character -eq '2') {
                    Write-Host "2" -ForegroundColor Cyan
                    try {
                        $progActW = "Wooting Installation Process"
                        Write-Progress -Activity $progActW -Status "Fetching repository data..." -PercentComplete 20
                        $apiUrl = "https://api.github.com/repos/ShayBox/Wooting-Profile-Switcher/releases/latest"
                        $release = Invoke-RestMethod -Uri $apiUrl -UseBasicParsing
                        $asset = $release.assets | Where-Object { $_.name -match "x64-portable\.exe$" } | Select-Object -First 1

                        if ($asset) {
                            $targetDir = Join-Path $ScriptDir "wooting-profile-switcher"
                            if (-not (Test-Path $targetDir)) { New-Item -ItemType Directory -Path $targetDir | Out-Null }
                            $wPath = Join-Path $targetDir "wooting-profile-switcher.exe"

                            Write-Progress -Activity $progActW -Status "Downloading $($asset.name)..." -PercentComplete 50
                            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $wPath -UseBasicParsing

                            Write-Progress -Activity $progActW -Status "Finished!" -PercentComplete 100
                            Start-Sleep -Milliseconds 500
                            Write-Progress -Activity $progActW -Completed

                            Write-Host "    │ [+] Wooting Profile Switcher downloaded and ready!" -ForegroundColor Green
                        } else {
                            Write-Host "    │ [!] Unable to find a compatible release." -ForegroundColor Red
                            $wPath = $null
                        }
                    } catch {
                        Write-Host "    │ [!] Download error: $($_.Exception.Message)" -ForegroundColor Red
                        $wPath = $null
                    }
                } else {
                    Write-Host "Skipped" -ForegroundColor DarkGray
                    $wPath = $null
                }
            }

            if ($wPath) {
                Write-Host "    │" -ForegroundColor Magenta
                Write-Host "    │ Enter profile number for osu!" -ForegroundColor Yellow
                Write-Host "    │ [Enter to DISABLE switching] > " -NoNewline -ForegroundColor White
                $wOsuKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                if ($wOsuKey.VirtualKeyCode -eq 13) {
                    $wOsu = ""
                    Write-Host "Disabled" -ForegroundColor DarkGray
                } else {
                    $wOsu = $wOsuKey.Character.ToString()
                    Write-Host $wOsu -ForegroundColor Cyan
                }
                
                if (-not [string]::IsNullOrWhiteSpace($wOsu)) {
                    Write-Host "    │" -ForegroundColor Magenta
                    Write-Host "    │ Enter profile number after exiting the game (return)" -ForegroundColor Yellow
                    Write-Host "    │ [Enter to SKIP return] > " -NoNewline -ForegroundColor White
                    $wRetKey = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    if ($wRetKey.VirtualKeyCode -eq 13) {
                        $wReturn = ""
                        Write-Host "Skipped" -ForegroundColor DarkGray
                    } else {
                        $wReturn = $wRetKey.Character.ToString()
                        Write-Host $wReturn -ForegroundColor Cyan
                    }
                }
            }
        }
        Write-Host "    └──────────────────────────────────────────" -ForegroundColor DarkGray
        
        $configData = @{ 
            TosuPath = $tosuPath; 
            GosuPath = $gosuPath; 
            WootingPath = $wPath;
            WootingOsu = $wOsu; 
            WootingReturn = $wReturn 
        }
        $configData | ConvertTo-Json | Set-Content $configFile
        continue
    }

    $config = Get-Content $configFile | ConvertFrom-Json
    
    $options = @()
    $options += [PSCustomObject]@{ Label = "Launch Osu!"; Action = "OSU" }
    
    if ($config.TosuPath) { $options += [PSCustomObject]@{ Label = "Launch Osu! + Tosu"; Action = "TOSU" } }
    if ($config.GosuPath) { $options += [PSCustomObject]@{ Label = "Launch Osu! + GosuMemory"; Action = "GOSU" } }
    
    $options += [PSCustomObject]@{ Label = "Exit"; Action = "EXIT" }

    Write-Host ""
    Write-Host "    ██████╗ ███████╗██╗   ██╗██╗" -ForegroundColor DarkGray
    Write-Host "   ██╔═══██╗██╔════╝██║   ██║██║" -ForegroundColor DarkGray
    Write-Host "   ██║   ██║███████╗██║   ██║██║" -ForegroundColor Gray
    Write-Host "   ██║   ██║╚════██║██║   ██║╚═╝" -ForegroundColor Gray
    Write-Host "   ╚██████╔╝███████║╚██████╔╝██╗" -ForegroundColor White
    Write-Host "    ╚═════╝ ╚══════╝ ╚═════╝ ╚═╝" -ForegroundColor White
    Write-Host " ───────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    
    for ($i = 0; $i -lt $options.Count; $i++) {
        Write-Host "   [$($i + 1)] $($options[$i].Label)" -ForegroundColor Cyan
    }
    
    Write-Host ""
    Write-Host "   [C] Edit Configuration" -ForegroundColor DarkGray
    if ($config.TosuPath) {
        Write-Host "   [T] Tosu Configuration" -ForegroundColor DarkGray
    }
    Write-Host " ───────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host " > " -NoNewline -ForegroundColor White
    
    $keyInfo = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    $keyStr = $keyInfo.Character.ToString()
    Write-Host $keyStr -ForegroundColor White
    
    if ($keyStr.ToLower() -eq 'c') {
        Remove-Item -Path $configFile -Force -ErrorAction SilentlyContinue
        Write-Host "`n   [*] Reconfiguring..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500
        continue
    }

    if ($keyStr.ToLower() -eq 't' -and $config.TosuPath) {
        Write-Host "`n   [*] Configuring Tosu..." -ForegroundColor Yellow
        $tosuProcess = Start-Process $config.TosuPath -WorkingDirectory (Split-Path $config.TosuPath) -PassThru -WindowStyle Hidden
        
        $tosuIp = "127.0.0.1"
        $tosuPort = "24050"
        $envPath = Join-Path (Split-Path $config.TosuPath) "tosu.env"
        if (Test-Path $envPath) {
            Get-Content $envPath | ForEach-Object {
                if ($_ -match "^SERVER_IP=(.*)") { $tosuIp = $matches[1].Trim() }
                if ($_ -match "^SERVER_PORT=(.*)") { $tosuPort = $matches[1].Trim() }
            }
        }
        $dashboardUrl = "http://${tosuIp}:${tosuPort}"

        Write-Host "   [*] Waiting for the dashboard to start ($dashboardUrl)..." -ForegroundColor DarkGray
        $timeout = 10 
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $isReady = $false
        
        while ($sw.Elapsed.TotalSeconds -lt $timeout) {
            try {
                $null = Invoke-WebRequest -Uri $dashboardUrl -UseBasicParsing -TimeoutSec 1 -ErrorAction Stop
                $isReady = $true
                break
            } catch {
                Start-Sleep -Milliseconds 500
            }
        }
        $sw.Stop()

        if ($isReady) {
            Start-Process $dashboardUrl
            Write-Host "   [*] Press Enter to finish configuration..." -ForegroundColor Cyan
            Read-Host
        } else {
            Write-Host "   [!] Tosu dashboard failed to start or is not responding." -ForegroundColor Red
            Start-Sleep -Seconds 2
        }
        
        $tosuProcess | Stop-Process -Force -ErrorAction SilentlyContinue
        continue
    }
    
    $parsedInt = 0
    $isNumber = [int]::TryParse($keyStr, [ref]$parsedInt)
    
    if ($isNumber -and $parsedInt -gt 0 -and $parsedInt -le $options.Count) {
        $selectedIndex = $parsedInt - 1
        $action = $options[$selectedIndex].Action
        
        if ($action -eq "EXIT") {
            Write-Host "`n   [*] Exiting..." -NoNewline -ForegroundColor DarkGray
            for ($dot = 0; $dot -lt 3; $dot++) {
                Start-Sleep -Milliseconds 300
                Write-Host "." -NoNewline -ForegroundColor DarkGray
            }
            Write-Host ""
            exit
        }

        Write-Host "`n   [*] $($options[$selectedIndex].Label)" -NoNewline -ForegroundColor Green
        for ($dot = 0; $dot -lt 3; $dot++) {
            Start-Sleep -Milliseconds 300
            Write-Host "." -NoNewline -ForegroundColor Green
        }
        Write-Host ""
        
        if ($config.WootingPath -and (Test-Path $config.WootingPath) -and -not [string]::IsNullOrWhiteSpace($config.WootingOsu)) {
            try {
                [int]$rawIdx = [int]::Parse($config.WootingOsu.ToString().Trim())
                [int]$idx = $rawIdx - 1
                Write-Host "   [*] Switching Wooting to osu! profile ($rawIdx)..." -ForegroundColor Magenta
                Start-Process $config.WootingPath -ArgumentList "-p $idx" -WindowStyle Hidden -Wait
            } catch {
                Write-Host "   [!] Wooting profile switch error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }

        if ($action -eq "OSU") {
            $osuProc = Start-Process $osuPath -WorkingDirectory (Split-Path $osuPath) -PassThru
            Focus-Osu $osuProc
            $osuProc | Wait-Process
        } elseif ($action -eq "TOSU") {
            $tosuProcess = Start-Process $config.TosuPath -WorkingDirectory (Split-Path $config.TosuPath) -PassThru
            Start-Sleep -Milliseconds 2500
            $osuProc = Start-Process $osuPath -WorkingDirectory (Split-Path $osuPath) -PassThru
            Focus-Osu $osuProc
            $osuProc | Wait-Process
            $tosuProcess | Stop-Process -Force -ErrorAction SilentlyContinue
        } elseif ($action -eq "GOSU") {
            $gosuProcess = Start-Process $config.GosuPath -WorkingDirectory (Split-Path $config.GosuPath) -PassThru
            Start-Sleep -Milliseconds 2500
            $osuProc = Start-Process $osuPath -WorkingDirectory (Split-Path $osuPath) -PassThru
            Focus-Osu $osuProc
            $osuProc | Wait-Process
            $gosuProcess | Stop-Process -Force -ErrorAction SilentlyContinue
        }
        
        if ($config.WootingPath -and (Test-Path $config.WootingPath) -and -not [string]::IsNullOrWhiteSpace($config.WootingReturn)) {
            try {
                [int]$rawIdxRet = [int]::Parse($config.WootingReturn.ToString().Trim())
                [int]$idxRet = $rawIdxRet - 1
                Write-Host "`n   [*] Restoring Wooting to profile $($rawIdxRet)..." -ForegroundColor Magenta
                Start-Process $config.WootingPath -ArgumentList "-p $idxRet" -WindowStyle Hidden -Wait
            } catch {
                Write-Host "   [!] Wooting profile restore error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host "`n   [*] See you next time" -NoNewline -ForegroundColor Cyan
        for ($dot = 0; $dot -lt 3; $dot++) {
            Start-Sleep -Milliseconds 300
            Write-Host "." -NoNewline -ForegroundColor Cyan
        }
        Write-Host ""
        Start-Sleep -Milliseconds 500
        
        exit
    } else {
        Write-Host "`n   [!] Invalid Option." -ForegroundColor Red
        Write-Host "   [!] Press Enter to continue..." -NoNewline -ForegroundColor DarkGray
        Read-Host
    }
}