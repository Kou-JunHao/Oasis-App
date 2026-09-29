import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 开源许可证页面
class OpenSourceLicensesScreen extends StatelessWidget {
  const OpenSourceLicensesScreen({super.key});

  static final List<_License> _licenses = [
    _License(
      name: 'Flutter',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/flutter/flutter/blob/master/LICENSE',
    ),
    _License(
      name: 'Dart',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/dart-lang/sdk/blob/main/LICENSE',
    ),
    _License(
      name: 'Provider',
      license: 'MIT License',
      url: 'https://github.com/rrousselGit/provider/blob/master/LICENSE',
    ),
    _License(
      name: 'Dio',
      license: 'MIT License',
      url: 'https://github.com/cfug/dio/blob/main/LICENSE',
    ),
    _License(
      name: 'Dynamic Color',
      license: 'Apache License 2.0',
      url: 'https://github.com/material-foundation/flutter-packages/blob/main/packages/dynamic_color/LICENSE',
    ),
    _License(
      name: 'Google Fonts',
      license: 'Apache License 2.0',
      url: 'https://github.com/material-foundation/flutter-packages/blob/main/packages/google_fonts/LICENSE',
    ),
    _License(
      name: 'Shared Preferences',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/flutter/packages/blob/main/packages/shared_preferences/shared_preferences/LICENSE',
    ),
    _License(
      name: 'URL Launcher',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/flutter/packages/blob/main/packages/url_launcher/url_launcher/LICENSE',
    ),
    _License(
      name: 'Image Picker',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/flutter/packages/blob/main/packages/image_picker/image_picker/LICENSE',
    ),
    _License(
      name: 'Package Info Plus',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/fluttercommunity/plus_plugins/blob/main/packages/package_info_plus/package_info_plus/LICENSE',
    ),
    _License(
      name: 'Device Info Plus',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/fluttercommunity/plus_plugins/blob/main/packages/device_info_plus/device_info_plus/LICENSE',
    ),
    _License(
      name: 'Permission Handler',
      license: 'MIT License',
      url: 'https://github.com/Baseflow/flutter-permission-handler/blob/master/permission_handler/LICENSE',
    ),
    _License(
      name: 'SQLite (sqflite)',
      license: 'BSD 2-Clause License',
      url: 'https://github.com/tekartik/sqflite/blob/master/sqflite/LICENSE',
    ),
    _License(
      name: 'Camera',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/flutter/packages/blob/main/packages/camera/camera/LICENSE',
    ),
    _License(
      name: 'Crypto',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/dart-lang/crypto/blob/master/LICENSE',
    ),
    _License(
      name: 'HTTP',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/dart-lang/http/blob/master/LICENSE',
    ),
    _License(
      name: 'go_router',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/flutter/packages/blob/main/packages/go_router/LICENSE',
    ),
    _License(
      name: 'Mobile Scanner',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/juliansteenbakker/mobile_scanner/blob/master/LICENSE',
    ),
    _License(
      name: 'Animations',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/flutter/packages/blob/main/packages/animations/LICENSE',
    ),
    _License(
      name: 'Flutter Markdown',
      license: 'BSD 3-Clause License',
      url: 'https://pub.dev/packages/flutter_markdown/license',
    ),
    _License(
      name: 'intl',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/dart-lang/i18n/blob/main/pkgs/intl/LICENSE',
    ),
    _License(
      name: 'Path Provider',
      license: 'BSD 3-Clause License',
      url: 'https://github.com/flutter/packages/blob/main/packages/path_provider/path_provider/LICENSE',
    ),
    _License(
      name: 'Cupertino Icons',
      license: 'MIT License',
      url: 'https://pub.dev/packages/cupertino_icons/license',
    ),
    _License(
      name: 'Tobias（支付宝 SDK 封装）',
      license: 'Apache License 2.0',
      url: 'https://github.com/OpenFlutter/tobias/blob/master/LICENSE',
    ),
    // ===== 参考项目：部分功能的实现参考或移植自以下项目 =====
    _License(
      name: 'life-798 (WaterWidget)',
      license: 'MIT License',
      url: 'https://github.com/nocookies111/life-798',
      note: '积分任务、签到与积分提交签名算法参考自该项目',
      isReference: true,
    ),
    _License(
      name: 'anti-ad-ilife-798',
      license: 'MIT License',
      url: 'https://github.com/KynixInHK/anti-ad-ilife-798',
      note: '本项目最初的设计与接口实现参考自该项目',
      isReference: true,
    ),
  ];

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('开源许可'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _licenses.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final license = _licenses[index];
          return Card(
            child: ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: license.isReference
                      ? colorScheme.tertiaryContainer
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  license.isReference
                      ? Icons.volunteer_activism_rounded
                      : Icons.code_rounded,
                  color: license.isReference
                      ? colorScheme.onTertiaryContainer
                      : colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              title: Text(
                license.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    license.license,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (license.note != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        license.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
              trailing: IconButton(
                icon: const Icon(Icons.open_in_new_rounded),
                onPressed: () => _openUrl(license.url),
                tooltip: '查看许可证',
              ),
              onTap: () => _openUrl(license.url),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            color: colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.favorite_rounded,
                    color: colorScheme.onSecondaryContainer,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '感谢所有开源贡献者',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '本应用基于以上开源项目构建，并感谢参考项目的开源分享',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _License {
  final String name;
  final String license;
  final String url;

  /// 说明文字（参考项目用）
  final String? note;

  /// 是否为「参考项目」而非直接依赖
  final bool isReference;

  const _License({
    required this.name,
    required this.license,
    required this.url,
    this.note,
    this.isReference = false,
  });
}
