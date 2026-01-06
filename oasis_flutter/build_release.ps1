# Oasis Flutter 发布构建脚本
# 构建号（versionCode）为固定值 2001
# 构建时间戳在编译时自动生成（YYYYMMDDHHMMSS格式）

Write-Host "=== Oasis Flutter 发布构建 ===" -ForegroundColor Cyan

# 读取当前版本信息
$pubspecContent = Get-Content "pubspec.yaml" -Raw
if ($pubspecContent -match 'version:\s+([0-9.]+)\+([0-9]+)') {
    $versionName = $matches[1]
    $versionCode = $matches[2]
    Write-Host "版本名称: $versionName" -ForegroundColor Green
    Write-Host "版本代码: $versionCode" -ForegroundColor Green
} else {
    Write-Host "无法解析版本号！" -ForegroundColor Red
    exit 1
}

Write-Host "`n开始构建 APK..." -ForegroundColor Cyan
Write-Host "注意：构建时间戳将在编译时自动生成" -ForegroundColor Yellow

# 执行构建
flutter build apk --release --split-per-abi

if ($LASTEXITCODE -eq 0) {
    Write-Host "`n=== 构建成功 ===" -ForegroundColor Green
    Write-Host "版本名称: $versionName" -ForegroundColor Yellow
    Write-Host "版本代码: $versionCode" -ForegroundColor Yellow
    Write-Host "构建时间: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor Yellow
    
    # 显示生成的文件
    Write-Host "`n生成的 APK 文件:" -ForegroundColor Cyan
    Get-ChildItem "build\app\outputs\flutter-apk\*.apk" | ForEach-Object {
        $sizeMB = [math]::Round($_.Length / 1MB, 2)
        Write-Host "  $($_.Name) - ${sizeMB}MB" -ForegroundColor White
    }
} else {
    Write-Host "`n=== 构建失败 ===" -ForegroundColor Red
    exit 1
}
