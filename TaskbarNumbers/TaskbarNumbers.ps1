# アセンブリのロード
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

# Win32 API の定義 (クリック貫通を実現するため)
$signature = @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    public const int GWL_EXSTYLE = -20;
    public const int WS_EX_LAYERED = 0x80000;
    public const int WS_EX_TRANSPARENT = 0x20;

    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hwnd, int index);

    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hwnd, int index, int newStyle);
}
"@
Add-Type -TypeDefinition $signature

# フォーム（透過ウィンドウ）の作成
$form = New-Object System.Windows.Forms.Form
$form.Text = "TaskbarNumbersOverlay"
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.TopMost = $true
$form.ShowInTaskbar = $false
$form.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$form.Bounds = [System.Windows.Forms.SystemInformation]::VirtualScreen
$form.BackColor = [System.Drawing.Color]::Magenta
$form.TransparencyKey = [System.Drawing.Color]::Magenta

$form.add_Load({
    $hwnd = $form.Handle
    $exStyle = [Win32]::GetWindowLong($hwnd, [Win32]::GWL_EXSTYLE)
    [Win32]::SetWindowLong($hwnd, [Win32]::GWL_EXSTYLE, $exStyle -bor [Win32]::WS_EX_LAYERED -bor [Win32]::WS_EX_TRANSPARENT) | Out-Null
})

# --- UI Automation 用の固定変数 ---
$rootElement = [System.Windows.Automation.AutomationElement]::RootElement
$trayCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ClassNameProperty, "Shell_TrayWnd")
$btnCondition = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$excludeIds = @("StartButton", "SearchButton", "TaskViewButton", "WidgetsButton", "ChatButton", "CopilotButton")

# --- 数字ラベルをあらかじめ10個作成しておく ---
$labels = @()
$font = New-Object System.Drawing.Font("Arial", 11, [System.Drawing.FontStyle]::Bold)

for ($i = 0; $i -lt 10; $i++) {
    $displayNum = $i + 1
    $numText = if ($displayNum -eq 10) { "0" } else { $displayNum.ToString() }
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $numText
    $lbl.Font = $font
    $lbl.ForeColor = [System.Drawing.Color]::White
    $lbl.BackColor = [System.Drawing.Color]::Transparent
    $lbl.AutoSize = $false
    $lbl.Height = 20
    $lbl.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $lbl.Visible = $false # 初期状態は非表示
    
    $form.Controls.Add($lbl)
    $labels += $lbl
}

# --- タイマーの設定（1秒ごとにアイコン位置を追従） ---
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1000 # 1000ミリ秒 = 1秒

$timer.add_Tick({
    try {
        $taskbar = $rootElement.FindFirst([System.Windows.Automation.TreeScope]::Children, $trayCondition)
        if ($null -eq $taskbar) { return }

        $buttons = $taskbar.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCondition)
        $iconRects = @()

        foreach ($btn in $buttons) {
            $rect = $btn.Current.BoundingRectangle
            $name = $btn.Current.Name
            $autoId = $btn.Current.AutomationId

            if ($rect.Width -le 0 -or $rect.Height -le 0) { continue }
            if ($excludeIds -contains $autoId) { continue }
            if ($rect.Width -gt ($rect.Height * 1.5)) { continue }
            if ($name -match "^(スタート|Start|検索|Search|タスク\s*ビュー|Task\s*View|ウィジェット|Widgets|チャット|Chat|Copilot.*)$") { continue }

            $iconRects += $rect
        }

        # X座標の順番（左から右）に並び替え
        $iconRects = $iconRects | Sort-Object X
        $count = [Math]::Min(10, $iconRects.Count)

        # ラベルの位置を更新
        for ($i = 0; $i -lt 10; $i++) {
            if ($i -lt $count) {
                $rect = $iconRects[$i]
                $lbl = $labels[$i]
                
                $lbl.Width = $rect.Width
                $yPos = $rect.Top - 8
                $lbl.Location = New-Object System.Drawing.Point([int]$rect.Left, [int]$yPos)
                
                if (-not $lbl.Visible) { $lbl.Visible = $true }
            } else {
                # アイコンが減った場合は余分な数字を隠す
                if ($labels[$i].Visible) { $labels[$i].Visible = $false }
            }
        }
    } catch {
        # アプリの起動/終了直後など、要素の取得中にエラーが起きた場合はスキップ
    }
})

$timer.Start()
# --------------------------------------------------

# --- タスクトレイアイコンの設定 ---
$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
$notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
$notifyIcon.Text = "TaskbarNumbers (右クリックで終了)"
$notifyIcon.Visible = $true

$contextMenu = New-Object System.Windows.Forms.ContextMenu
$exitMenuItem = New-Object System.Windows.Forms.MenuItem
$exitMenuItem.Text = "終了"
$exitMenuItem.add_Click({
    $timer.Stop()
    $notifyIcon.Visible = $false
    $form.Close()
})
$contextMenu.MenuItems.Add($exitMenuItem)
$notifyIcon.ContextMenu = $contextMenu

# 実行
[System.Windows.Forms.Application]::Run($form)