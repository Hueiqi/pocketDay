$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path $PSScriptRoot -Parent
function Write-PocketIcon([string]$relativePath, [int]$size) {
    $bitmap = New-Object System.Drawing.Bitmap($size, $size)
    $canvas = [System.Drawing.Graphics]::FromImage($bitmap)
    $canvas.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $canvas.Clear([System.Drawing.ColorTranslator]::FromHtml('#F34843'))
    $canvas.ScaleTransform(($size / 108.0), ($size / 108.0))
    $coin = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#FFD36B'))
    $inner = New-Object System.Drawing.SolidBrush([System.Drawing.ColorTranslator]::FromHtml('#FFE4E2'))
    $red = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#F34843'), 5)
    $brown = New-Object System.Drawing.Pen([System.Drawing.ColorTranslator]::FromHtml('#B85D29'), 2.5)
    $red.StartCap = $red.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $red.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $canvas.FillEllipse($coin, 49, 22, 28, 28)
    $canvas.DrawLine($brown, 63, 28, 63, 44)
    $canvas.DrawLine($brown, 58, 32, 65, 32)
    $canvas.DrawArc($brown, 61, 32, 8, 8, -90, 180)
    $canvas.DrawLine($brown, 65, 40, 58, 40)
    $pocket = New-Object System.Drawing.Drawing2D.GraphicsPath
    $pocket.AddLine(28, 43, 80, 43)
    $pocket.AddLine(80, 43, 80, 62)
    $pocket.AddBezier(80, 62, 80, 77, 65, 85, 54, 88)
    $pocket.AddBezier(54, 88, 43, 85, 28, 77, 28, 62)
    $pocket.CloseFigure()
    $canvas.FillPath([System.Drawing.Brushes]::White, $pocket)
    $lining = New-Object System.Drawing.Drawing2D.GraphicsPath
    $lining.AddLine(36, 52, 72, 52)
    $lining.AddLine(72, 52, 72, 61)
    $lining.AddBezier(72, 61, 72, 70, 62, 77, 54, 80)
    $lining.AddBezier(54, 80, 46, 77, 36, 70, 36, 61)
    $lining.CloseFigure()
    $canvas.FillPath($inner, $lining)
    $canvas.DrawLines($red, [System.Drawing.PointF[]]@(
        [System.Drawing.PointF]::new(44, 62),
        [System.Drawing.PointF]::new(51, 69),
        [System.Drawing.PointF]::new(65, 54)
    ))
    $destination = Join-Path $projectRoot $relativePath
    [IO.Directory]::CreateDirectory((Split-Path $destination -Parent)) | Out-Null
    $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    $canvas.Dispose(); $bitmap.Dispose(); $coin.Dispose(); $inner.Dispose()
    $red.Dispose(); $brown.Dispose(); $pocket.Dispose(); $lining.Dispose()
}
Write-PocketIcon 'assets/branding/pocketday.png' 1024
@{mdpi=48; hdpi=72; xhdpi=96; xxhdpi=144; xxxhdpi=192}.GetEnumerator() | ForEach-Object {
    Write-PocketIcon "android/app/src/main/res/mipmap-$($_.Key)/ic_launcher.png" $_.Value
}
$catalog = Get-Content (Join-Path $projectRoot 'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json') -Raw | ConvertFrom-Json
foreach ($asset in $catalog.images) {
    $size = [double]($asset.size.Split('x')[0]) * [double]($asset.scale.TrimEnd('x'))
    Write-PocketIcon "ios/Runner/Assets.xcassets/AppIcon.appiconset/$($asset.filename)" ([int]$size)
}
Write-PocketIcon 'web/favicon.png' 32
foreach ($size in @(192, 512)) {
    Write-PocketIcon "web/icons/Icon-$size.png" $size
    Write-PocketIcon "web/icons/Icon-maskable-$size.png" $size
}
Write-Output 'Generated PocketDay launcher icons for Android, iOS, and web.'
