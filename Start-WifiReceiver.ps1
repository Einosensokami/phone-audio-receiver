param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
$version = '1.0.0.7'
$archiveHash = '94021e2737d26939d05153cad22651677911bf290820abaab441bb1bc40980d5'
$vendor = Join-Path $PSScriptRoot 'vendor'
$archive = Join-Path $vendor "ShairportQt_$version.zip"
$appFolder = Join-Path $vendor "ShairportQt-$version"
$exe = Join-Path $appFolder 'ShairportQt.exe'
$configName = 'PhoneAudioReceiver'
$configPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) ".ShairportQt_Config$configName.json"

try {
    if ($env:PROCESSOR_ARCHITECTURE -ne 'AMD64') {
        throw '此啟動器需要 x64 Windows，其他架構請由 ShairportQt 官方下載適用版本。'
    }
    if (!(Test-Path -LiteralPath $exe)) {
        New-Item -ItemType Directory -Path $vendor -Force | Out-Null
        if (!(Test-Path -LiteralPath $archive)) {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -UseBasicParsing -Uri "https://github.com/Frank-Friemel/ShairportQt/releases/download/$version/ShairportQt_$version.zip" -OutFile $archive
        }
        if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ne $archiveHash) {
            throw "下載檔案校驗失敗，請刪除 $archive 後重試。"
        }
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        $zip = [IO.Compression.ZipFile]::OpenRead($archive)
        try {
            $entry = @($zip.Entries | Where-Object { $_.FullName -eq 'ShairportQt/Windows_x64/ShairportQt.exe' })
            if ($entry.Count -ne 1) { throw '下載包內找不到唯一的 Windows x64 接收器。' }
            New-Item -ItemType Directory -Path $appFolder -Force | Out-Null
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry[0], $exe, $true)
        } finally { $zip.Dispose() }
    }

    # A separate profile preserves any existing ShairportQt settings.
    if (!(Test-Path -LiteralPath $configPath)) {
        $initialConfig = @{
            APname = "Phone Audio - $env:COMPUTERNAME"
            Language = 'en-EN'
            TrayIcon = $true
            StartMinimized = $false
            UseWinToast = $false
            AudioDevice = 'default'
        } | ConvertTo-Json
        [IO.File]::WriteAllText($configPath, $initialConfig, (New-Object Text.UTF8Encoding $false))
    }
    $process = Start-Process -FilePath $exe -ArgumentList "-config=$configName" -WorkingDirectory $appFolder -PassThru
    if ($SelfTest) {
        Start-Sleep -Seconds 5
        $running = @(Get-Process -Name ShairportQt -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $exe })
        if ($running.Count -eq 0) { throw 'AirPlay 接收器啟動後已離開，請手動啟動檢查訊息。' }
        $listeners = @(Get-NetTCPConnection -State Listen -ErrorAction Stop | Where-Object { $_.OwningProcess -in $running.Id })
        [pscustomobject]@{
            ReceiverRunning = $true
            ListeningPorts = @($listeners.LocalPort)
            Profile = $configPath
            PhonePlaybackVerified = $false
        } | ConvertTo-Json
        if ($listeners.Count -eq 0) { throw '接收器尚未開始監聽 TCP 連線。' }
    }
} catch {
    if ($SelfTest) { throw }
    Add-Type -AssemblyName PresentationFramework
    [Windows.MessageBox]::Show($_.Exception.Message, 'Wi-Fi 音訊接收器') | Out-Null
    exit 1
}
