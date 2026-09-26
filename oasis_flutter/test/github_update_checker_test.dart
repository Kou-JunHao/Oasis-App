import 'package:flutter_test/flutter_test.dart';

import 'package:oasis_flutter/utils/github_update_checker.dart';

/// 构造 GitHub release asset 结构
List<dynamic> assetsOf(List<String> names) => [
      for (final name in names)
        {
          'name': name,
          'browser_download_url': 'https://example.com/download/$name',
        },
    ];

/// v2.0.3 / v2.0.4 实际发布的资产命名
const _releasedAssets = [
  'app-arm64-v8a-release.apk',
  'app-armeabi-v7a-release.apk',
  'app-x86_64-release.apk',
];

void main() {
  group('pickApkUrlForAbi', () {
    test('arm64 真机选中 arm64 包', () {
      expect(
        GitHubUpdateChecker.pickApkUrlForAbi(
          assetsOf(_releasedAssets),
          'arm64-v8a',
        ),
        endsWith('app-arm64-v8a-release.apk'),
      );
    });

    test('armeabi-v7a 设备选中 32 位 ARM 包', () {
      expect(
        GitHubUpdateChecker.pickApkUrlForAbi(
          assetsOf(_releasedAssets),
          'armeabi-v7a',
        ),
        endsWith('app-armeabi-v7a-release.apk'),
      );
    });

    test('x86_64 设备选中 x86_64 包（旧逻辑会误判成 arm64）', () {
      final url = GitHubUpdateChecker.pickApkUrlForAbi(
        assetsOf(_releasedAssets),
        'x86_64',
      );
      expect(url, endsWith('app-x86_64-release.apk'));
      expect(url, isNot(contains('arm64')));
    });

    test('32 位 x86 设备不会被 x86_64 包冒领', () {
      // 同时提供 x86 与 x86_64 时，应精确命中 x86
      expect(
        GitHubUpdateChecker.pickApkUrlForAbi(
          assetsOf([..._releasedAssets, 'app-x86-release.apk']),
          'x86',
        ),
        endsWith('app-x86-release.apk'),
      );
    });

    test('顺序打乱也能选对', () {
      expect(
        GitHubUpdateChecker.pickApkUrlForAbi(
          assetsOf([
            'app-x86_64-release.apk',
            'app-arm64-v8a-release.apk',
            'app-armeabi-v7a-release.apk',
          ]),
          'arm64-v8a',
        ),
        endsWith('app-arm64-v8a-release.apk'),
      );
    });

    test('命名不规范时退回子串匹配', () {
      expect(
        GitHubUpdateChecker.pickApkUrlForAbi(
          assetsOf(['oasis-v2.0.5-arm64-v8a.apk']),
          'arm64-v8a',
        ),
        endsWith('oasis-v2.0.5-arm64-v8a.apk'),
      );
    });

    test('只有 universal 包时使用通用包', () {
      expect(
        GitHubUpdateChecker.pickApkUrlForAbi(
          assetsOf(['app-universal-release.apk']),
          'arm64-v8a',
        ),
        endsWith('app-universal-release.apk'),
      );
    });

    test('没有任何 APK 时返回空串（调用方回退到 release 页面）', () {
      expect(
        GitHubUpdateChecker.pickApkUrlForAbi(
          assetsOf(['source-code.zip', 'mapping.txt']),
          'arm64-v8a',
        ),
        isEmpty,
      );
    });
  });

  group('版本号比较', () {
    test('2.0.5 比 2.0.4 新', () {
      expect(GitHubUpdateChecker.isNewerVersion('2.0.4', '2.0.5'), isTrue);
    });

    test('同版本不提示更新', () {
      expect(GitHubUpdateChecker.isNewerVersion('2.0.5', '2.0.5'), isFalse);
    });

    test('四段版本号的第四段会被忽略（所以不能用 2.0.4.1 发版）', () {
      expect(GitHubUpdateChecker.isNewerVersion('2.0.4', '2.0.4.1'), isFalse);
      expect(GitHubUpdateChecker.isNewerVersion('2.0.4', '2.0.5'), isTrue);
    });
  });
}
