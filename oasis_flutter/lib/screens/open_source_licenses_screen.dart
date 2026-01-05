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
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.code_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 24,
                ),
              ),
              title: Text(
                license.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                license.license,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
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
                    '本应用基于以上开源项目构建',
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

  const _License({
    required this.name,
    required this.license,
    required this.url,
  });
}
