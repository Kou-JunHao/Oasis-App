# 第三方开源库许可证

本项目使用了以下开源库，特此声明其许可证信息：

## Android 官方库

### AndroidX 核心库
- **androidx.core:core-ktx** (1.13.1) - Apache License 2.0
- **androidx.appcompat:appcompat** (1.7.1) - Apache License 2.0
- **androidx.activity:activity-ktx** (1.9.3) - Apache License 2.0
- **androidx.fragment:fragment-ktx** (1.8.5) - Apache License 2.0
- **androidx.constraintlayout:constraintlayout** (2.2.0) - Apache License 2.0
- **androidx.recyclerview:recyclerview** (1.3.2) - Apache License 2.0
- **androidx.viewpager2:viewpager2** (1.1.0) - Apache License 2.0
- **androidx.coordinatorlayout:coordinatorlayout** (1.2.0) - Apache License 2.0
- **androidx.swiperefreshlayout:swiperefreshlayout** (1.1.0) - Apache License 2.0

### Lifecycle 组件
- **androidx.lifecycle:lifecycle-viewmodel-ktx** (2.8.7) - Apache License 2.0
- **androidx.lifecycle:lifecycle-livedata-ktx** (2.8.7) - Apache License 2.0

### Navigation 组件
- **androidx.navigation:navigation-fragment-ktx** (2.8.4) - Apache License 2.0
- **androidx.navigation:navigation-ui-ktx** (2.8.4) - Apache License 2.0

### Camera 组件
- **androidx.camera:camera-core** (1.3.1) - Apache License 2.0
- **androidx.camera:camera-camera2** (1.3.1) - Apache License 2.0
- **androidx.camera:camera-lifecycle** (1.3.1) - Apache License 2.0
- **androidx.camera:camera-view** (1.3.1) - Apache License 2.0

### 测试库
- **androidx.test.ext:junit** (1.2.1) - Apache License 2.0
- **androidx.test.espresso:espresso-core** (3.6.1) - Apache License 2.0

## Google 官方库

### Material Design
- **com.google.android.material:material** (1.13.0) - Apache License 2.0

### ML Kit
- **com.google.mlkit:barcode-scanning** (17.2.0) - Apache License 2.0

### Dagger Hilt
- **com.google.dagger:hilt-android** (2.48) - Apache License 2.0
- **com.google.dagger:hilt-compiler** (2.48) - Apache License 2.0

### Gson
- **com.google.code.gson:gson** (2.11.0) - Apache License 2.0

## 第三方开源库

### 网络库
- **com.squareup.retrofit2:retrofit** (2.11.0) - Apache License 2.0
- **com.squareup.retrofit2:converter-gson** (2.11.0) - Apache License 2.0
- **com.squareup.okhttp3:okhttp** (4.12.0) - Apache License 2.0
- **com.squareup.okhttp3:logging-interceptor** (4.12.0) - Apache License 2.0

### 图片加载库
- **com.github.bumptech.glide:glide** (4.16.0) - BSD License, Apache License 2.0
- **com.github.bumptech.glide:okhttp3-integration** (4.16.0) - BSD License, Apache License 2.0
- **com.github.bumptech.glide:compiler** (4.16.0) - BSD License, Apache License 2.0

### 二维码库
- **com.google.zxing:core** (3.5.2) - Apache License 2.0

### 测试库
- **junit:junit** (4.13.2) - Eclipse Public License 1.0

## Flutter 依赖库（oasis_flutter）

| 库 | 许可证 | 用途 |
|---|---|---|
| Flutter / Dart | BSD 3-Clause | 应用框架与运行时 |
| provider | MIT | 状态管理 |
| go_router | BSD 3-Clause | 路由导航 |
| dio | MIT | HTTP 客户端 |
| http | BSD 3-Clause | 更新检查与镜像源请求 |
| crypto | BSD 3-Clause | 积分提交签名（MD5） |
| shared_preferences | BSD 3-Clause | 本地存储 |
| sqflite | BSD 2-Clause | 本地数据库 |
| path_provider | BSD 3-Clause | 路径获取 |
| dynamic_color | Apache License 2.0 | 莫奈取色 |
| google_fonts | Apache License 2.0 | 字体 |
| image_picker / camera | BSD 3-Clause | 图片选择与相机 |
| mobile_scanner | BSD 3-Clause | 二维码扫描 |
| permission_handler | MIT | 权限管理 |
| package_info_plus / device_info_plus | BSD 3-Clause | 包信息与设备信息 |
| url_launcher | BSD 3-Clause | 打开外部链接 |
| flutter_markdown | BSD 3-Clause | Markdown 渲染（更新说明） |
| animations | BSD 3-Clause | 过渡动画 |
| intl | BSD 3-Clause | 日期与本地化格式化 |
| cupertino_icons | MIT | 图标 |
| tobias | Apache License 2.0 | 支付宝支付 SDK 封装 |

> 完整清单与许可证链接可在应用内「设置 → 关于应用 → 开源许可」查看。

## 参考项目

以下项目采用 MIT 许可证，本项目的部分实现参考或移植自它们：

### life-798 (WaterWidget)
- 仓库：https://github.com/nocookies111/life-798
- 许可证：MIT License，Copyright (c) 2026 nocookies111
- 参考内容：积分任务、每日签到、积分提交签名算法与任务限速规则

### anti-ad-ilife-798
- 仓库：https://github.com/KynixInHK/anti-ad-ilife-798
- 许可证：MIT License
- 参考内容：项目最初的设计思路与接口实现

## 许可证详情

### Apache License 2.0
大部分库使用 Apache License 2.0，详细内容请参见：
https://www.apache.org/licenses/LICENSE-2.0

### BSD License
BSD 2-Clause：https://opensource.org/licenses/BSD-2-Clause
BSD 3-Clause：https://opensource.org/licenses/BSD-3-Clause

### MIT License
Flutter 侧的 provider、permission_handler、cupertino_icons 以及参考项目（life-798、anti-ad-ilife-798）使用 MIT License，详细内容请参见：
https://opensource.org/licenses/MIT

### Eclipse Public License 1.0
JUnit 使用 Eclipse Public License 1.0，详细内容请参见：
https://www.eclipse.org/legal/epl-v10.html

## 声明

本项目严格遵守所有第三方库的许可证要求。如有任何许可证相关问题，请联系项目维护者。

---

最后更新时间：2026年9月29日