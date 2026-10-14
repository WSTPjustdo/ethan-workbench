param([switch]$Verify)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()
$workspace = Split-Path $PSScriptRoot -Parent
$loginFile = Join-Path $workspace '.local-runtime\config\login.json'
if (-not (Test-Path -LiteralPath $loginFile)) {
    [System.Windows.Forms.MessageBox]::Show('找不到本机账号配置，请确认此文件仍位于工作台目录。', '本地账号') | Out-Null
    exit 1
}
$credentials = Get-Content -LiteralPath $loginFile -Raw -Encoding UTF8 | ConvertFrom-Json
$form = New-Object System.Windows.Forms.Form
$form.Text = 'Ethan工作台 - 登录账号'
$form.ClientSize = New-Object System.Drawing.Size(490, 265)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)

function Add-Label($Text, $X, $Y, $Width) {
    $label = New-Object System.Windows.Forms.Label
    $label.Text = $Text
    $label.Location = New-Object System.Drawing.Point($X, $Y)
    $label.Size = New-Object System.Drawing.Size($Width, 25)
    $form.Controls.Add($label)
}
Add-Label '将密码复制到登录页，即可进入Ethan工作台。' 24 20 450
Add-Label '账号' 24 65 60
Add-Label '密码' 24 108 60
$account = New-Object System.Windows.Forms.TextBox
$account.Location = New-Object System.Drawing.Point(86, 61)
$account.Size = New-Object System.Drawing.Size(245, 28)
$account.ReadOnly = $true
$account.Text = $credentials.username
$account.AccessibleName = '登录账号'
$form.Controls.Add($account)
$password = New-Object System.Windows.Forms.TextBox
$password.Location = New-Object System.Drawing.Point(86, 104)
$password.Size = New-Object System.Drawing.Size(245, 28)
$password.ReadOnly = $true
$password.UseSystemPasswordChar = $true
$password.Text = $credentials.password
$password.AccessibleName = '本机密码'
$form.Controls.Add($password)
$copyAccount = New-Object System.Windows.Forms.Button
$copyAccount.Text = '复制账号'
$copyAccount.Location = New-Object System.Drawing.Point(345, 59)
$copyAccount.Size = New-Object System.Drawing.Size(110, 32)
$form.Controls.Add($copyAccount)
$copyPassword = New-Object System.Windows.Forms.Button
$copyPassword.Text = '复制密码'
$copyPassword.Location = New-Object System.Drawing.Point(345, 102)
$copyPassword.Size = New-Object System.Drawing.Size(110, 32)
$form.Controls.Add($copyPassword)
$showPassword = New-Object System.Windows.Forms.CheckBox
$showPassword.Text = '显示密码'
$showPassword.Location = New-Object System.Drawing.Point(86, 148)
$showPassword.Size = New-Object System.Drawing.Size(120, 28)
$showPassword.Add_CheckedChanged({ $password.UseSystemPasswordChar = -not $showPassword.Checked })
$form.Controls.Add($showPassword)
$status = New-Object System.Windows.Forms.Label
$status.Location = New-Object System.Drawing.Point(24, 213)
$status.Size = New-Object System.Drawing.Size(445, 38)
$status.Text = '账号仅保存在本机；请勿把密码发给他人。'
$form.Controls.Add($status)
$copyAccount.Add_Click({
    try { [System.Windows.Forms.Clipboard]::SetText($account.Text); $status.Text = '账号已复制。' }
    catch { $status.Text = '复制失败，请选中账号后按 Ctrl+C。' }
})
$copyPassword.Add_Click({
    try { [System.Windows.Forms.Clipboard]::SetText($password.Text); $status.Text = '密码已复制，请在登录页粘贴。' }
    catch { $status.Text = '复制失败，请显示密码后选中并按 Ctrl+C。' }
})
$open = New-Object System.Windows.Forms.Button
$open.Text = '打开登录页'
$open.Location = New-Object System.Drawing.Point(325, 153)
$open.Size = New-Object System.Drawing.Size(130, 34)
$open.Add_Click({ Start-Process 'http://127.0.0.1:5188/login' })
$form.Controls.Add($open)
if ($Verify) {
    if (-not $password.UseSystemPasswordChar -or -not $password.Text -or -not $account.Text) { throw 'Account window validation failed.' }
    Write-Output 'Account window controls verified; password masked; no clipboard change.'
} else { $form.ShowDialog() | Out-Null }
$form.Dispose()
