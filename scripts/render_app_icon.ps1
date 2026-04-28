Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$iconDir = Join-Path $root "src-tauri\icons"
New-Item -ItemType Directory -Force $iconDir | Out-Null

function New-RoundedRectanglePath {
  param(
    [float]$X,
    [float]$Y,
    [float]$Width,
    [float]$Height,
    [float]$Radius
  )

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  $diameter = $Radius * 2
  $path.AddArc($X, $Y, $diameter, $diameter, 180, 90)
  $path.AddArc($X + $Width - $diameter, $Y, $diameter, $diameter, 270, 90)
  $path.AddArc($X + $Width - $diameter, $Y + $Height - $diameter, $diameter, $diameter, 0, 90)
  $path.AddArc($X, $Y + $Height - $diameter, $diameter, $diameter, 90, 90)
  $path.CloseFigure()
  return $path
}

function Fill-RoundedRect {
  param($Graphics, $Brush, [float]$X, [float]$Y, [float]$Width, [float]$Height, [float]$Radius)
  $path = New-RoundedRectanglePath $X $Y $Width $Height $Radius
  $Graphics.FillPath($Brush, $path)
  $path.Dispose()
}

function New-IconBitmap {
  param([int]$Size)

  $scale = $Size / 1024.0
  $bitmap = New-Object System.Drawing.Bitmap $Size, $Size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.Clear([System.Drawing.Color]::Transparent)
  $graphics.ScaleTransform($scale, $scale)

  $bgRect = [System.Drawing.RectangleF]::new(72, 72, 880, 880)
  $bgBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new(
    $bgRect,
    [System.Drawing.Color]::FromArgb(255, 23, 34, 58),
    [System.Drawing.Color]::FromArgb(255, 9, 17, 31),
    [System.Drawing.Drawing2D.LinearGradientMode]::ForwardDiagonal
  )
  Fill-RoundedRect $graphics $bgBrush 72 72 880 880 220

  $linePen = [System.Drawing.Pen]::new([System.Drawing.Color]::FromArgb(255, 232, 244, 255), 74)
  $linePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $linePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $graphics.DrawLine($linePen, 300, 724, 724, 300)

  $cyanBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 103, 232, 249))
  $whiteBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 248, 251, 255))
  $graphics.FillEllipse($cyanBrush, 302, 606, 116, 116)
  $graphics.FillEllipse($whiteBrush, 454, 454, 116, 116)
  $graphics.FillEllipse($cyanBrush, 610, 314, 116, 116)

  $arrowColor = [System.Drawing.Color]::FromArgb(255, 167, 139, 250)
  $arrowPen = [System.Drawing.Pen]::new($arrowColor, 58)
  $arrowPen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $arrowPen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $arcBounds = [System.Drawing.RectangleF]::new(666, 170, 184, 184)
  $graphics.DrawArc($arrowPen, $arcBounds, 212, 236)
  $arrowBrush = [System.Drawing.SolidBrush]::new($arrowColor)
  $arrowHead = New-Object System.Drawing.Drawing2D.GraphicsPath
  $arrowHead.AddPolygon([System.Drawing.PointF[]]@(
    [System.Drawing.PointF]::new(824, 376),
    [System.Drawing.PointF]::new(842, 256),
    [System.Drawing.PointF]::new(732, 302)
  ))
  $graphics.FillPath($arrowBrush, $arrowHead)

  $graphics.Dispose()
  $bgBrush.Dispose()
  $linePen.Dispose()
  $cyanBrush.Dispose()
  $whiteBrush.Dispose()
  $arrowPen.Dispose()
  $arrowBrush.Dispose()
  $arrowHead.Dispose()

  return $bitmap
}

function Save-Png {
  param([int]$Size, [string]$Path)
  $bitmap = New-IconBitmap $Size
  $bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
}

function ConvertTo-BigEndianBytes {
  param([UInt32]$Value)
  $bytes = [BitConverter]::GetBytes($Value)
  if ([BitConverter]::IsLittleEndian) {
    [Array]::Reverse($bytes)
  }
  return $bytes
}

function Write-Ico {
  param([string]$Path, [int[]]$Sizes)

  $images = @()
  foreach ($size in $Sizes) {
    $stream = New-Object System.IO.MemoryStream
    $bitmap = New-IconBitmap $size
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $images += [pscustomobject]@{ Size = $size; Bytes = $stream.ToArray() }
    $stream.Dispose()
    $bitmap.Dispose()
  }

  $output = New-Object System.IO.MemoryStream
  $writer = New-Object System.IO.BinaryWriter $output
  $writer.Write([UInt16]0)
  $writer.Write([UInt16]1)
  $writer.Write([UInt16]$images.Count)
  $offset = 6 + (16 * $images.Count)

  foreach ($image in $images) {
    $sizeByte = if ($image.Size -eq 256) { 0 } else { [byte]$image.Size }
    $writer.Write([byte]$sizeByte)
    $writer.Write([byte]$sizeByte)
    $writer.Write([byte]0)
    $writer.Write([byte]0)
    $writer.Write([UInt16]1)
    $writer.Write([UInt16]32)
    $writer.Write([UInt32]$image.Bytes.Length)
    $writer.Write([UInt32]$offset)
    $offset += $image.Bytes.Length
  }

  foreach ($image in $images) {
    $writer.Write($image.Bytes)
  }

  [System.IO.File]::WriteAllBytes($Path, $output.ToArray())
  $writer.Dispose()
  $output.Dispose()
}

function Write-Icns {
  param([string]$Path)

  $chunks = @(
    @{ Type = "icp4"; Size = 16 },
    @{ Type = "icp5"; Size = 32 },
    @{ Type = "icp6"; Size = 64 },
    @{ Type = "ic07"; Size = 128 },
    @{ Type = "ic08"; Size = 256 },
    @{ Type = "ic09"; Size = 512 },
    @{ Type = "ic10"; Size = 1024 }
  )

  $chunkData = @()
  $totalLength = 8
  foreach ($chunk in $chunks) {
    $stream = New-Object System.IO.MemoryStream
    $bitmap = New-IconBitmap $chunk.Size
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    $bytes = $stream.ToArray()
    $chunkData += [pscustomobject]@{ Type = $chunk.Type; Bytes = $bytes }
    $totalLength += 8 + $bytes.Length
    $stream.Dispose()
    $bitmap.Dispose()
  }

  $output = New-Object System.IO.MemoryStream
  $writer = New-Object System.IO.BinaryWriter $output
  $writer.Write([System.Text.Encoding]::ASCII.GetBytes("icns"))
  $writer.Write((ConvertTo-BigEndianBytes ([UInt32]$totalLength)))
  foreach ($chunk in $chunkData) {
    $writer.Write([System.Text.Encoding]::ASCII.GetBytes($chunk.Type))
    $writer.Write((ConvertTo-BigEndianBytes ([UInt32](8 + $chunk.Bytes.Length))))
    $writer.Write($chunk.Bytes)
  }

  [System.IO.File]::WriteAllBytes($Path, $output.ToArray())
  $writer.Dispose()
  $output.Dispose()
}

Save-Png 16 (Join-Path $iconDir "16x16.png")
Save-Png 32 (Join-Path $iconDir "32x32.png")
Save-Png 64 (Join-Path $iconDir "64x64.png")
Save-Png 128 (Join-Path $iconDir "128x128.png")
Save-Png 256 (Join-Path $iconDir "128x128@2x.png")
Save-Png 256 (Join-Path $iconDir "256x256.png")
Save-Png 512 (Join-Path $iconDir "512x512.png")
Save-Png 1024 (Join-Path $iconDir "icon.png")
Write-Ico (Join-Path $iconDir "icon.ico") @(16, 24, 32, 48, 64, 128, 256)
Write-Icns (Join-Path $iconDir "icon.icns")

Write-Output "Rendered Tauri app icons in $iconDir"
