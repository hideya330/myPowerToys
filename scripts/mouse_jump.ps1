Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# --- 設定：プレビューウィンドウのサイズ ---
$previewWidth = 600  # 横幅（お好みで調整）

# 1. 全モニターの範囲（仮想スクリーン）を取得
# 1. 全モニターを結合した仮想スクリーンの領域を取得
$vScreen = [System.Windows.Forms.SystemInformation]::VirtualScreen

# 2. プレビューの高さ計算（アスペクト比維持）
$scale = $previewWidth / $vScreen.Width
$previewHeight = [int]($vScreen.Height * $scale)

# 3. フォーム（ウィンドウ）の作成
$form = New-Object Windows.Forms.Form
$form.Text = "Mouse Jump (PS版)"
$form.Size = New-Object Drawing.Size($previewWidth, $previewHeight)
$form.FormBorderStyle = "FixedToolWindow"
$form.StartPosition = "CenterScreen"
$form.TopMost = $true

# 4. スクリーンショットの取得
$bmp = New-Object Drawing.Bitmap($vScreen.Width, $vScreen.Height)
$graphics = [Drawing.Graphics]::FromImage($bmp)
$graphics.CopyFromScreen($vScreen.Left, $vScreen.Top, 0, 0, $bmp.Size)

# 5. 画像を表示するボックス
$pictureBox = New-Object Windows.Forms.PictureBox
$pictureBox.Dock = "Fill"
$pictureBox.Image = $bmp
$pictureBox.SizeMode = "StretchImage"
$form.Controls.Add($pictureBox)

# 6. クリック時の挙動（ワープ処理）
$pictureBox.Add_Click({
    param($sender, $e)
    # クリックされた位置を取得
    $localPoint = $form.PointToClient([Windows.Forms.Cursor]::Position)
    
    # 実際の座標に変換
    $realX = [int]($localPoint.X / $scale) + $vScreen.Left
    $realY = [int]($localPoint.Y / $scale) + $vScreen.Top
    
    # マウス移動
    [Windows.Forms.Cursor]::Position = New-Object Drawing.Point($realX, $realY)
    $form.Close()
})

# キー入力で閉じる設定（Escキーなど）
$form.KeyPreview = $true
$form.Add_KeyDown({
    if ($_.KeyCode -eq "Escape") { $form.Close() }
})

# 実行
[Windows.Forms.Application]::Run($form)
$graphics.Dispose()
$bmp.Dispose()