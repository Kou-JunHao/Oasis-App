@echo off
echo ====================================
echo Oasis Flutter 项目构建脚本
echo ====================================
echo.

echo [1/3] 清理构建缓存...
call flutter clean

echo.
echo [2/3] 获取依赖包...
call flutter pub get

echo.
echo [3/3] 构建完成!
echo.
echo 可用的命令:
echo   flutter run              - 运行应用 (调试模式)
echo   flutter run --release    - 运行应用 (发布模式)
echo   flutter build apk        - 构建 APK
echo   flutter build appbundle  - 构建 App Bundle
echo.
pause
