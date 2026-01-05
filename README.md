# Oasis App - Anti-Ad <details><summary>~~i████798~~</summary>iLife798</details> 项目

这是一个针对<details><summary>~~i████798~~</summary>iLife798</details>用户的去广告解决方案项目

## 项目结构

### 📱 oasis_flutter (主要开发版本)
位于 `oasis_flutter/` 文件夹下，这是 **OasisAPP** 的 Flutter 跨平台实现。

- **应用包名**: `uno.skkk.oasis`
- **最低支持版本**: Android 7.0 (API 24)
- **目标版本**: Android 16 (API 36)
- **开发框架**: Flutter 3.27+
- **架构**: Provider 状态管理 + Material Design 3

#### 主要特性
- 跨平台支持（Android为主）
- 现代化的 Material Design 3 界面
- 流畅的用户体验
- 应用内更新功能
- 完整的设备管理和控制
- 钱包充值与订单管理

### 🚧 Oasis-Android (已暂停维护)
位于 `Oasis-Android/` 文件夹下，这是 **OasisAPP** 的 Android 原生实现。

- **状态**: ⚠️ **暂停维护，建议使用 Flutter 版本**
- **应用包名**: `uno.skkk.oasis`
- **开发语言**: Kotlin
- **架构**: 使用 Hilt 依赖注入，ViewBinding

> **注意**: Kotlin 版本已暂停维护，所有新功能和更新将在 Flutter 版本中进行。推荐使用 `oasis_flutter` 获取最新功能和更好的体验。


## 项目目标

本项目旨在为<details><summary>~~i████798~~</summary>iLife798</details>用户提供一个无广告的控制界面，解决原厂应用广告过多的问题。

### 主要功能
- 设备控制和管理
- 去除原厂应用中的广告内容
- 提供清洁、简洁的用户界面

## 快速开始

### Flutter 应用 (oasis_flutter) - 推荐
```bash
cd oasis_flutter
flutter pub get
flutter run
```

#### 构建发布版本
```bash
# 构建所有架构的APK（推荐）
flutter build apk --release --split-per-abi

# 构建特定架构
flutter build apk --release --target-platform android-arm64
```

### Android 应用 (Oasis-Android) - 已暂停维护
```bash
cd Oasis-Android
./gradlew build
```


## 技术栈

### Flutter 应用 (主要开发版本)
- **框架**: Flutter 3.27+
- **语言**: Dart
- **最低 SDK**: Android 24 (Android 7.0)
- **目标 SDK**: Android 34 (Android 15)
- **状态管理**: Provider
- **UI**: Material Design 3
- **主要依赖**:
  - go_router (路由导航)
  - http (网络请求)
  - shared_preferences (本地存储)
  - mobile_scanner (二维码扫描)
  - camera (相机功能)
  - flutter_markdown (Markdown渲染)
  - permission_handler (权限管理)

### Android 应用 (已暂停维护)
- **语言**: Kotlin
- **最低 SDK**: 24 (Android 7.0)
- **目标 SDK**: 36 (Android 16)
- **依赖注入**: Hilt
- **UI**: ViewBinding + Material Design



## 贡献指南

欢迎提交 Issue 和 Pull Request 来改进项目。

### 开发环境要求
- **Flutter**: Flutter SDK 3.27 或更高版本
- **Android Studio**: Arctic Fox 或更高版本（推荐安装 Flutter 和 Dart 插件）
- **VS Code**: 可选，需安装 Flutter 和 Dart 扩展

## 免责声明

本项目仅供学习和研究使用，不用于商业目的。所有后果由使用者承担，与项目作者无关。

## 第三方许可证

本项目使用了多个开源库，详细的第三方许可证信息请参见：
- [第三方许可证列表](THIRD_PARTY_LICENSES.md)
- [许可证文件目录](LICENSES/)

主要使用的开源库包括：

### Flutter 版本
- **Flutter SDK** - BSD License
- **Material Design Components** - Apache License 2.0
- **go_router** - BSD License
- **provider** - MIT License
- **http** - BSD License
- **其他库** - 详见 pubspec.yaml

### Android (Kotlin) 版本
- **AndroidX 系列库** - Apache License 2.0
- **Material Design Components** - Apache License 2.0
- **Retrofit & OkHttp** - Apache License 2.0
- **Glide** - BSD License
- **Dagger Hilt** - Apache License 2.0
- **其他库** - 详见第三方许可证文件

## 联系方式

如有问题或建议，请通过 GitHub Issues 联系我们。

---

感谢原项目 [anti-ad-ilife-798](https://github.com/KynixInHK/anti-ad-ilife-798) 提供的灵感和技术支持。

**注意**: 请确保在使用本项目前了解相关法律法规，并承担相应责任。本应用承诺不会远程传输您的个人数据，也不会将用户数据分享给任何第三方。均使用原应用的API。
