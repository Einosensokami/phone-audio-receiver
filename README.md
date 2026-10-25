# 手機音訊接收器（Wi-Fi / AirPlay）

## Wi-Fi 使用方式（預設）

現在雙擊 `Start-Receiver.vbs` 會啟動 ShairportQt AirPlay 接收器；原本的藍牙版本改由 `Start-BluetoothReceiver.vbs` 啟動。

1. 手機與電腦連到同一個家用區域網路；手機也可以連到同一台路由器下、能互通的 Wi-Fi。
2. 雙擊 `Start-Receiver.vbs`，保持 Shairport 視窗或系統匣程式開啟。
3. 如 Windows 顯示防火牆提示，允許 ShairportQt 在目前可信任的家用網路通訊。目前此 Wi-Fi 被 Windows 設為「公用」，只允許「私人」不會套用到目前連線。也可以在 Windows「設定 → 網路和網際網路 → Wi-Fi → 目前網路」中，確認是可信任的家用網路後自行設為「私人」。
4. 在 iPhone 播放音樂，打開「控制中心」，點音樂播放區的 AirPlay 圖示，選擇 `Phone Audio - 電腦名稱`。請使用音訊輸出選單。
5. 音量可由手機及 Windows 調整。停止接收時，在 Shairport 選單選擇 Quit；關閉視窗可能只會縮到系統匣。

第一次使用需連線 GitHub 下載約 65 MB 的官方發布包，啟動器會驗證固定版本 1.0.0.7 的 SHA-256，僅解出 Windows x64 執行檔到本資料夾的 `vendor`。後續可離線啟動。不修改藍牙配對、不設定開機自動啟動，也不自動修改防火牆或網路類型。

Shairport 的 `Change...` 可設定接收器名稱與 AirPlay 密碼；`Options` 可調整播放裝置。設定檔使用獨立的 `%USERPROFILE%\.ShairportQt_ConfigPhoneAudioReceiver.json`，首次建立時使用 Windows 預設音訊裝置。

### 手機找不到電腦

- 確認接收器仍在執行，且兩邊連到同一個可互通的區域網路。
- 檢查 Windows 防火牆是否允許 ShairportQt 在目前網路類型通訊。
- 避免訪客 Wi-Fi、AP 用戶端隔離，或會阻擋區域網路的 VPN；延伸器也必須允許裝置互通。
- 找得到但無聲時，確認手機已選擇正確的 AirPlay 輸出，以及 Windows 預設音訊裝置與音量。
- AirPlay 有緩衝延遲；受保護內容、通話或個別 App 是否輸出須以實際測試為準。

### 電腦端驗證

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Start-WifiReceiver.ps1 -SelfTest
```

會啟動接收器並檢查程式與 TCP 監聽，保留接收器供手機連線。此檢查不代表已完成手機探索、通過防火牆或驗證音訊播放。

來源：[ShairportQt 原始碼與 GPL-3.0 授權](https://github.com/Frank-Friemel/ShairportQt)、[1.0.0.7 官方發布包](https://github.com/Frank-Friemel/ShairportQt/releases/tag/1.0.0.7)、[Apple AirPlay 音訊操作](https://support.apple.com/en-ie/105068)。

## 原本的藍牙版本

讓 Windows 接收 iPhone 的藍牙音訊，從電腦的預設喇叭或耳機播放。手機仍是播放來源；不使用 Spotify API，也不需要 Spotify 帳號或開發者金鑰。

## 開始使用

1. 雙擊 `Start-BluetoothReceiver.vbs`。
2. 按「藍牙設定」，在 Windows 選擇新增藍牙裝置。同時在 iPhone 開啟「設定 → 藍牙」，完成配對並確認兩邊配對碼。
3. 回到接收器，按「重新掃描」，選擇 iPhone，再按「連接」。
4. 在 iPhone 播放音樂。如果沒有自動切換，在 iPhone 控制中心的音訊輸出選單選擇這台電腦。
5. 播放期間保持接收器開啟；按「中斷」或關閉視窗會釋放連線。

需要 Windows 10 版本 2004 以上或 Windows 11，以及支援的藍牙介面與驅動程式。使用系統內建 Windows PowerShell 5.1，不用安裝套件、不需管理員權限。啟動器的 ExecutionPolicy Bypass 僅套用於此次啟動，不變更系統設定。

接收的是手機實際輸出的聲音，包含通知與來源 App 原本播放的廣告；本程式不會移除或改變來源內容。藍牙會有延遲，不保證與手機喇叭同時出聲。

## 沒有聲音或找不到手機

- 確認兩邊藍牙已開啟並完成配對，之後重新掃描。
- 暫時中斷手機連接的其他藍牙耳機／喇叭。
- 確認 Windows 的預設音訊輸出正確，手機與電腦都沒有靜音。
- 若連線失敗，按「中斷」後重新連接；必要時移除配對再重新配對。
- 視窗未開啟時，在此資料夾執行下方命令，可看到錯誤訊息。

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Receiver.ps1
```

## 驗證

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\Receiver.ps1 -SelfTest
```

會開啟視窗、執行真實裝置掃描，四秒後關閉並回報結果。裝置數為零代表尚未發現可接收的手機，不代表音訊已驗證。實際播放需要 iPhone 配對及操作。

實作依據：[Microsoft AudioPlaybackConnection](https://learn.microsoft.com/en-us/uwp/api/windows.media.audio.audioplaybackconnection)。
