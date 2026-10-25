param([switch]$SelfTest)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, System.Runtime.WindowsRuntime
$null = [Windows.Media.Audio.AudioPlaybackConnection,Windows.Media.Audio,ContentType=WindowsRuntime]
$null = [Windows.Devices.Enumeration.DeviceInformation,Windows.Devices.Enumeration,ContentType=WindowsRuntime]
$devicesType = [Windows.Devices.Enumeration.DeviceInformationCollection,Windows.Devices.Enumeration,ContentType=WindowsRuntime]
$openResultType = [Windows.Media.Audio.AudioPlaybackConnectionOpenResult,Windows.Media.Audio,ContentType=WindowsRuntime]
$asTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and $_.IsGenericMethod -and
    $_.GetGenericArguments().Count -eq 1 -and $_.GetParameters().Count -eq 1 -and
    $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'
} | Select-Object -First 1
$asActionTask = [System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {
    $_.Name -eq 'AsTask' -and !$_.IsGenericMethod -and
    $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction'
} | Select-Object -First 1

[xml]$markup = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="手機音訊接收器" Width="560" Height="590" MinWidth="490" MinHeight="550"
        WindowStartupLocation="CenterScreen" Background="#101916" Foreground="#F2F7F4"
        FontFamily="Microsoft JhengHei" FontSize="15">
  <Window.Resources>
    <Style TargetType="Button">
      <Setter Property="Padding" Value="16,10"/>
      <Setter Property="Margin" Value="0,0,10,0"/>
      <Setter Property="Background" Value="#DCE8E0"/>
      <Setter Property="Foreground" Value="#102119"/>
      <Setter Property="BorderThickness" Value="0"/>
    </Style>
  </Window.Resources>
  <Grid Margin="28">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
      <RowDefinition Height="Auto"/><RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>
    <StackPanel>
      <TextBlock Text="把電腦變成手機的喇叭" FontSize="25" FontWeight="Bold"/>
      <TextBlock Text="透過藍牙接收 iPhone 聲音，不需要登入音樂帳號。"
                 Foreground="#ADC3B7" TextWrapping="Wrap" Margin="0,10,0,20"/>
    </StackPanel>
    <Border Grid.Row="1" Background="#1B2D24" Padding="16" CornerRadius="8" Margin="0,0,0,20">
      <TextBlock TextWrapping="Wrap" LineHeight="25"
        Text="1. 在 Windows 藍牙設定中新增並配對 iPhone。&#10;2. 按「重新掃描」，選擇手機，再按「連接」。&#10;3. 手機開始播放；必要時在音訊輸出選擇這台電腦。"/>
    </Border>
    <TextBlock Grid.Row="2" Text="可接收音訊的手機" FontWeight="Bold" Margin="0,0,0,10"/>
    <ListBox Grid.Row="3" Name="Devices" DisplayMemberPath="Name" Background="#1B2D24"
             Foreground="#F2F7F4" BorderThickness="0" Padding="8" MinHeight="70"/>
    <StackPanel Grid.Row="4" Orientation="Horizontal" Margin="0,18,0,14">
      <Button Name="Connect" Content="連接" Background="#5FE199" IsEnabled="False"/>
      <Button Name="Disconnect" Content="中斷" IsEnabled="False"/>
      <Button Name="Scan" Content="重新掃描"/>
      <Button Name="Settings" Content="藍牙設定" Margin="0"/>
    </StackPanel>
    <StackPanel Grid.Row="5">
      <TextBlock Name="Status" Text="準備掃描…" TextWrapping="Wrap" Foreground="#82E5AB"/>
      <TextBlock Text="播放期間請保持本視窗開啟。音量由手機與 Windows 調整。"
                 Foreground="#ADC3B7" FontSize="12" TextWrapping="Wrap" Margin="0,12,0,0"/>
    </StackPanel>
  </Grid>
</Window>
'@
$reader = New-Object System.Xml.XmlNodeReader $markup
$window = [Windows.Markup.XamlReader]::Load($reader)
$reader.Close()
$list = $window.FindName('Devices')
$connect = $window.FindName('Connect')
$disconnect = $window.FindName('Disconnect')
$scan = $window.FindName('Scan')
$settings = $window.FindName('Settings')
$status = $window.FindName('Status')
$script:connection = $null
$script:pending = $null
$script:phase = ''
$script:scanPassed = $false
$script:failure = $null
$script:connectedName = ''
$script:lastState = ''

function Update-Buttons {
    $busy = $null -ne $script:pending
    $scan.IsEnabled = !$busy -and $null -eq $script:connection
    $list.IsEnabled = !$busy -and $null -eq $script:connection
    $connect.IsEnabled = !$busy -and $null -eq $script:connection -and $null -ne $list.SelectedItem
    $disconnect.IsEnabled = !$busy -and $null -ne $script:connection
}

function Close-Connection {
    if ($null -ne $script:connection) {
        $script:connection.Dispose()
        $script:connection = $null
    }
    $script:lastState = ''
}

function Show-Failure($errorRecord) {
    $script:failure = $errorRecord.Exception.GetBaseException().Message
    $script:pending = $null
    Close-Connection
    $status.Text = "連線未完成：$($script:failure) 請確認藍牙已開啟、手機已配對，再重試。"
    Update-Buttons
}

function Start-Scan {
    try {
        $status.Text = '正在尋找已配對、支援音訊傳送的裝置…'
        $selector = [Windows.Media.Audio.AudioPlaybackConnection]::GetDeviceSelector()
        $operation = [Windows.Devices.Enumeration.DeviceInformation]::FindAllAsync($selector)
        $script:pending = $asTask.MakeGenericMethod($devicesType).Invoke($null, @($operation))
        $script:phase = 'scan'
        Update-Buttons
    } catch { Show-Failure $_ }
}

$scan.Add_Click({ Start-Scan })
$list.Add_SelectionChanged({ Update-Buttons })
$settings.Add_Click({
    try { Start-Process 'ms-settings:bluetooth' } catch { Show-Failure $_ }
})
$connect.Add_Click({
    try {
        $script:connectedName = $list.SelectedItem.Name
        $script:connection = [Windows.Media.Audio.AudioPlaybackConnection]::TryCreateFromId($list.SelectedItem.Id)
        if ($null -eq $script:connection) { throw '這個裝置目前不支援音訊接收，請重新配對。' }
        $operation = $script:connection.StartAsync()
        $script:pending = $asActionTask.Invoke($null, @($operation))
        $script:phase = 'start'
        $status.Text = "正在啟用 $($script:connectedName) 的音訊連線…"
        Update-Buttons
    } catch { Show-Failure $_ }
})
$disconnect.Add_Click({
    try {
        Close-Connection
        $status.Text = '已中斷音訊連線。'
        Update-Buttons
    } catch { Show-Failure $_ }
})

# Poll tasks on the UI thread so scanning and connecting do not freeze the window.
$timer = New-Object Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(250)
$timer.Add_Tick({
    try {
        if ($null -ne $script:pending -and $script:pending.IsCompleted) {
            $task = $script:pending
            $script:pending = $null
            if ($task.IsFaulted) { throw $task.Exception.GetBaseException() }
            if ($task.IsCanceled) { throw '操作已取消。' }
            switch ($script:phase) {
                'scan' {
                    $list.Items.Clear()
                    foreach ($device in $task.Result) { $null = $list.Items.Add($device) }
                    $script:scanPassed = $true
                    if ($list.Items.Count -gt 0) {
                        $list.SelectedIndex = 0
                        $status.Text = '選擇你的 iPhone，按「連接」。'
                    } else {
                        $status.Text = '尚未找到手機。請開啟藍牙設定，配對 iPhone 後重新掃描。'
                    }
                }
                'start' {
                    $operation = $script:connection.OpenAsync()
                    $script:pending = $asTask.MakeGenericMethod($openResultType).Invoke($null, @($operation))
                    $script:phase = 'open'
                    $status.Text = '正在開啟音訊，請保持 iPhone 藍牙開啟…'
                }
                'open' {
                    $result = $task.Result
                    if ($result.Status.ToString() -ne 'Success') {
                        throw "裝置回報 $($result.Status)。請確認手機在附近且未連接其他喇叭。"
                    }
                    $script:lastState = ''
                }
            }
            Update-Buttons
        }
        if ($null -ne $script:connection -and $null -eq $script:pending) {
            $state = $script:connection.State.ToString()
            if ($state -ne $script:lastState) {
                $script:lastState = $state
                if ($state -eq 'Opened') {
                    $status.Text = "已連接 $($script:connectedName)。請在手機播放，聲音會由電腦輸出。"
                } else {
                    $status.Text = '音訊連線尚未開啟或已中斷，請按「中斷」後重新連接。'
                }
            }
        }
    } catch { Show-Failure $_ }
})
$window.Add_Loaded({ $timer.Start(); Start-Scan })
$window.Add_Closed({
    $timer.Stop()
    Close-Connection
})

if ($SelfTest) {
    $testTimer = New-Object Windows.Threading.DispatcherTimer
    $testTimer.Interval = [TimeSpan]::FromSeconds(4)
    $testTimer.Add_Tick({ $testTimer.Stop(); $window.Close() })
    $testTimer.Start()
}
$null = $window.ShowDialog()
if ($SelfTest) {
    [pscustomobject]@{
        WindowLoaded = $window.IsLoaded
        ScanCompleted = $script:scanPassed
        DeviceCount = $list.Items.Count
        Error = $script:failure
    } | ConvertTo-Json
    if (!$script:scanPassed -or $null -ne $script:failure) { exit 1 }
}
