<# :
@echo off
:: ==============================================================
:: VRoid Reference Overlay (v3.9 - Anti-Mojibake Edition)
:: ==============================================================
echo Starting VRoid Reference Overlay v3.9...
echo.

:: Copy self to temp .ps1 file
set "vroid_script=%TEMP%\vroid_overlay_%RANDOM%.ps1"
copy /y "%~f0" "%vroid_script%" >nul

:: Run PowerShell with Bypass policy
powershell -NoProfile -ExecutionPolicy Bypass -File "%vroid_script%"

:: Pause if error occurs
if %errorlevel% neq 0 (
    echo.
    echo [ERROR] Program crashed.
    pause
)

:: Cleanup
if exist "%vroid_script%" del "%vroid_script%"
exit /b
#>

# ==============================================================
# PowerShell Code
# ==============================================================
try {
    # --- AUTHOR CONFIGURATION (Unicode Safe Mode) ---
    # "Surcen" + "苏" (0x82CF) + "森" (0x68EE)
    $authorName = "Surcen" + [char]0x82CF + [char]0x68EE
    $appVersion = "v3.9"
    $appTitle   = "VRoid Reference Overlay"
    
    # "免费工具，禁止贩卖" (Free Tool, Not for Resale)
    # Constructed using Unicode chars to prevent garbled text (Mojibake)
    $msgLine1 = [char]0x514D + [char]0x8D39 + [char]0x5DE5 + [char]0x5177 + [char]0xFF0C + [char]0x7981 + [char]0x6B62 + [char]0x8D29 + [char]0x5356
    $msgFull  = "$appTitle $appVersion`nAuthor: $authorName`n`n$msgLine1`n(Free Tool - Not for Resale)"
    # ----------------------------

    # 1. Define Win32 API
    $code = @"
    using System;
    using System.Runtime.InteropServices;

    public class Win32 {
        [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
        [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
        [DllImport("user32.dll")] public static extern int SendMessage(IntPtr hWnd, int Msg, int wParam, int lParam);
        [DllImport("user32.dll")] public static extern bool ReleaseCapture();
        
        public const int WM_NCLBUTTONDOWN = 0xA1;
        public const int HT_CAPTION = 0x2;
    }
"@
    Add-Type -TypeDefinition $code -Language CSharp

    # 2. Load Assemblies
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Enable High DPI
    try {
        if ([System.Windows.Forms.Application].GetMember("SetHighDpiMode").Count -gt 0) {
            [System.Windows.Forms.Application]::SetHighDpiMode("SystemAware")
        }
        [System.Windows.Forms.Application]::EnableVisualStyles()
    } catch {}

    # --- Global Variables ---
    $script:rawImage = $null
    $script:exitApp = $false
    # Dark Grey for transparency later
    $bgColor = [System.Drawing.Color]::FromArgb(16, 16, 16) 
    # Visible Grey for startup
    $startColor = [System.Drawing.Color]::FromArgb(40, 40, 40)

    # ==============================================================
    # 1. THE IMAGE OVERLAY FORM
    # ==============================================================
    $imgForm = New-Object System.Windows.Forms.Form
    $imgForm.Text = "$appTitle"
    $imgForm.FormBorderStyle = "None"
    $imgForm.TopMost = $true
    $imgForm.ShowInTaskbar = $false
    $imgForm.StartPosition = "Manual"
    $imgForm.Location = New-Object System.Drawing.Point(200, 200)
    $imgForm.Size = New-Object System.Drawing.Size(350, 350)
    $imgForm.BackColor = $startColor

    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Dock = "Fill"
    $pictureBox.SizeMode = "Zoom"
    $pictureBox.BackColor = [System.Drawing.Color]::Transparent
    $imgForm.Controls.Add($pictureBox)

    # --- Feature: Mouse Wheel Zoom ---
    $pictureBox.Add_MouseEnter({ $pictureBox.Focus() })
    
    $pictureBox.Add_MouseWheel({
        param($sender, $e)
        $zoomFactor = 1.1
        if ($e.Delta -lt 0) { $zoomFactor = 0.9 }
        $newW = [int]($imgForm.Width * $zoomFactor)
        $newH = [int]($imgForm.Height * $zoomFactor)
        $newW = [Math]::Max(50, [Math]::Min($newW, 2000))
        $newH = [Math]::Max(50, [Math]::Min($newH, 2000))
        $imgForm.Size = New-Object System.Drawing.Size($newW, $newH)
    })

    # --- Mouse Logic: Drag to Move & Resize ---
    $script:isResizing = $false
    $script:dragStart = $null
    $script:startSize = $null

    $pictureBox.Add_MouseMove({
        param($sender, $e)
        $resizeZone = 30
        $inResizeZone = ($e.X -ge ($pictureBox.Width - $resizeZone) -and $e.Y -ge ($pictureBox.Height - $resizeZone))

        if ($script:isResizing) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
            $currentPos = [System.Windows.Forms.Cursor]::Position
            $dx = $currentPos.X - $script:dragStart.X
            $dy = $currentPos.Y - $script:dragStart.Y
            $newW = [Math]::Max(100, $script:startSize.Width + $dx)
            $newH = [Math]::Max(100, $script:startSize.Height + $dy)
            $imgForm.Size = New-Object System.Drawing.Size($newW, $newH)
        }
        elseif ($inResizeZone) {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::SizeNWSE
        } else {
            $pictureBox.Cursor = [System.Windows.Forms.Cursors]::Default
        }
    })

    $pictureBox.Add_MouseDown({
        param($sender, $e)
        if ($e.Button -eq 'Left') {
            $resizeZone = 30
            $inResizeZone = ($e.X -ge ($pictureBox.Width - $resizeZone) -and $e.Y -ge ($pictureBox.Height - $resizeZone))

            if ($inResizeZone) {
                $script:isResizing = $true
                $script:dragStart = [System.Windows.Forms.Cursor]::Position
                $script:startSize = $imgForm.Size
                $pictureBox.Capture = $true 
            } else {
                [Win32]::ReleaseCapture()
                [Win32]::SendMessage($imgForm.Handle, 0xA1, 2, 0)
            }
        }
    })

    $pictureBox.Add_MouseUp({ 
        $script:isResizing = $false
        $pictureBox.Capture = $false
    })

    # Placeholder Text (Big and Clear)
    $lblPlace = New-Object System.Windows.Forms.Label
    $lblPlace.Text = "[ RIGHT-CLICK HERE ]`n`nTo Load Image"
    $lblPlace.ForeColor = [System.Drawing.Color]::White
    $lblPlace.AutoSize = $false
    $lblPlace.TextAlign = "MiddleCenter"
    $lblPlace.Dock = "Fill"
    $lblPlace.Font = New-Object System.Drawing.Font("Arial", 16, [System.Drawing.FontStyle]::Bold)
    $pictureBox.Controls.Add($lblPlace)

    # ==============================================================
    # 2. CONTEXT MENU (PURE ASCII)
    # ==============================================================
    $ctxMenu = New-Object System.Windows.Forms.ContextMenuStrip

    function Add-Menu($text, $action) {
        $item = $ctxMenu.Items.Add($text)
        if ($action) { $item.Add_Click($action) }
        return $item
    }

    Add-Menu "[ Load Image ]" { 
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Filter = "Images|*.png;*.jpg;*.bmp"
        if ($dlg.ShowDialog() -eq "OK") {
            try {
                $img = [System.Drawing.Image]::FromFile($dlg.FileName)
                if ($script:rawImage) { $script:rawImage.Dispose() }
                $script:rawImage = $img
                $pictureBox.Image = $script:rawImage
                $lblPlace.Visible = $false
                $imgForm.BackColor = $bgColor
                $imgForm.TransparencyKey = $bgColor
                $ratio = $img.Width / $img.Height
                $baseW = [Math]::Min($img.Width, 500)
                $imgForm.Size = New-Object System.Drawing.Size($baseW, [int]($baseW / $ratio))
            } catch { [System.Windows.Forms.MessageBox]::Show("Error loading image") }
        }
    } | Out-Null
    
    $ctxMenu.Items.Add("-") | Out-Null
    Add-Menu "[ Lock Image ] (Click-Through)" { Lock-Window } | Out-Null

    $itemTrans = $ctxMenu.Items.Add("Transform")
    $subTrans = $itemTrans.DropDown
    $subTrans.Items.Add("Rotate Left").Add_Click({ if ($script:rawImage) { $script:rawImage.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone); $pictureBox.Refresh() } })
    $subTrans.Items.Add("Rotate Right").Add_Click({ if ($script:rawImage) { $script:rawImage.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone); $pictureBox.Refresh() } })
    $subTrans.Items.Add("Flip Horizontal").Add_Click({ if ($script:rawImage) { $script:rawImage.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipX); $pictureBox.Refresh() } })
    $subTrans.Items.Add("Flip Vertical").Add_Click({ if ($script:rawImage) { $script:rawImage.RotateFlip([System.Drawing.RotateFlipType]::RotateNoneFlipY); $pictureBox.Refresh() } })

    $itemOp = $ctxMenu.Items.Add("Opacity")
    $subOp = $itemOp.DropDown
    $subOp.Items.Add("Custom Slider...").Add_Click({
        $sliderForm = New-Object System.Windows.Forms.Form
        $sliderForm.Size = New-Object System.Drawing.Size(250, 80)
        $sliderForm.Text = "Opacity"
        $sliderForm.FormBorderStyle = "FixedToolWindow"
        $sliderForm.StartPosition = "Manual"
        $sliderForm.Location = [System.Windows.Forms.Cursor]::Position
        $tb = New-Object System.Windows.Forms.TrackBar; $tb.Dock = "Top"; $tb.Minimum = 10; $tb.Maximum = 100; $tb.Value = [int]($imgForm.Opacity * 100)
        $tb.Add_Scroll({ $imgForm.Opacity = $tb.Value / 100.0 })
        $sliderForm.Controls.Add($tb)
        $sliderForm.ShowDialog()
    })
    $subOp.Items.Add("-") | Out-Null
    $ops = @(100, 80, 60, 40, 20)
    foreach ($val in $ops) { $subOp.Items.Add("$val%").Add_Click({ $imgForm.Opacity = $val / 100.0 }.GetNewClosure()) }

    $ctxMenu.Items.Add("-") | Out-Null
    
    # --- ABOUT / CREDIT MENU ---
    # Using the decoded variable for perfect display
    Add-Menu "About / Credits" {
        [System.Windows.Forms.MessageBox]::Show($msgFull, "About")
    } | Out-Null

    Add-Menu "Exit" { 
        $script:exitApp = $true
        $imgForm.Close()
        $notifyIcon.Visible = $false
        [System.Windows.Forms.Application]::Exit()
    } | Out-Null
    
    $pictureBox.ContextMenuStrip = $ctxMenu

    # ==============================================================
    # 3. TRAY ICON
    # ==============================================================
    $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
    $notifyIcon.Icon = [System.Drawing.SystemIcons]::Application
    $notifyIcon.Text = "Right-Click to Unlock"
    $notifyIcon.Visible = $true

    $trayMenu = New-Object System.Windows.Forms.ContextMenu
    $trayUnlock = $trayMenu.MenuItems.Add("Unlock Image")
    $trayExit = $trayMenu.MenuItems.Add("Exit")
    $notifyIcon.ContextMenu = $trayMenu

    function Lock-Window {
        $GWL_EXSTYLE = -20
        $WS_EX_TRANSPARENT = 0x20
        $hwnd = $imgForm.Handle
        $style = [Win32]::GetWindowLong($hwnd, $GWL_EXSTYLE)
        [Win32]::SetWindowLong($hwnd, $GWL_EXSTYLE, $style -bor $WS_EX_TRANSPARENT)
        $imgForm.Text = "LOCKED"
        $notifyIcon.ShowBalloonTip(2000, "Image Locked", "Right-click Tray Icon to Unlock.", [System.Windows.Forms.ToolTipIcon]::Info)
    }

    $UnlockAction = {
        $GWL_EXSTYLE = -20
        $WS_EX_TRANSPARENT = 0x20
        $hwnd = $imgForm.Handle
        $style = [Win32]::GetWindowLong($hwnd, $GWL_EXSTYLE)
        [Win32]::SetWindowLong($hwnd, $GWL_EXSTYLE, $style -bxor $WS_EX_TRANSPARENT)
        $imgForm.Activate()
    }
    
    $trayUnlock.Add_Click($UnlockAction)
    $notifyIcon.Add_DoubleClick($UnlockAction)
    $trayExit.Add_Click({ $script:exitApp = $true; $imgForm.Close(); $notifyIcon.Visible = $false })

    # ==============================================================
    # 4. RUN
    # ==============================================================
    $imgForm.Show()
    [System.Windows.Forms.Application]::Run($imgForm)

} catch {
    Write-Host "Error: $_" -ForegroundColor Red
    pause
}