import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:oasis_flutter/config/app_config.dart';
import 'package:oasis_flutter/services/client_version_service.dart';

/// 模拟小米应用商店详情页中包含版本号的那段 HTML
String fakeStoreHtml(String version) =>
    '''
      <div style="width:100%; display: inline-block">
          <div class="float-left">
              <div style="float: left">
                  版本号
              </div>
              <div style="float:right;">
                  $version
              </div>
          </div>
          <div class="float-right">
              <div style="float: left">
                  开发者
              </div>
              <div style="float:right;">
                  长沙云多啦信息技术有限公司
              </div>
          </div>
      </div>
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ClientVersionService.resetForTest();
  });

  group('页面解析', () {
    test('从商店详情页 HTML 中提取版本号', () {
      expect(
        ClientVersionService.parseVersionFromHtml(fakeStoreHtml('3.1.9')),
        '3.1.9',
      );
    });

    test('页面改版/无版本号时返回 null', () {
      expect(
        ClientVersionService.parseVersionFromHtml('<html>改版了</html>'),
        isNull,
      );
      expect(ClientVersionService.parseVersionFromHtml(''), isNull);
    });

    test('拒绝非法版本号', () {
      expect(ClientVersionService.isValidVersion('3'), isFalse);
      expect(ClientVersionService.isValidVersion('v3.1.9'), isFalse);
      expect(ClientVersionService.isValidVersion('3.1.9.4.2'), isFalse);
      expect(ClientVersionService.isValidVersion('3.1'), isTrue);
      expect(ClientVersionService.isValidVersion('3.1.9'), isTrue);
    });
  });

  group('取值优先级', () {
    test('用户自定义优先级最高，且完全不发起抓取', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.keyCustomClientVersion: '2.9.9',
        AppConfig.keyClientVersion: '3.1.0',
      });
      var fetchCount = 0;
      ClientVersionService.htmlFetcherForTest = () async {
        fetchCount++;
        return fakeStoreHtml('3.9.9');
      };

      expect(await ClientVersionService.resolve(), '2.9.9');
      expect(ClientVersionService.current, '2.9.9');
      expect(ClientVersionService.statusNotifier.value.source, 'custom');
      expect(fetchCount, 0);
    });

    test('无自定义时使用线上最新版，并写入缓存', () async {
      ClientVersionService.htmlFetcherForTest = () async =>
          fakeStoreHtml('3.2.0');

      expect(await ClientVersionService.resolve(), '3.2.0');
      expect(ClientVersionService.statusNotifier.value.source, 'remote');

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConfig.keyClientVersion), '3.2.0');
      expect(prefs.getInt(AppConfig.keyClientVersionAt), isNotNull);
    });

    test('抓取失败时回退到本地缓存', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.keyClientVersion: '3.1.0',
      });
      ClientVersionService.htmlFetcherForTest = () async => null;

      expect(await ClientVersionService.resolve(), '3.1.0');
      expect(ClientVersionService.statusNotifier.value.source, 'cache');
    });

    test('抓取失败且无缓存时回退到内置基线', () async {
      ClientVersionService.htmlFetcherForTest = () async => null;

      expect(
        await ClientVersionService.resolve(),
        AppConfig.baselineClientVersion,
      );
      expect(ClientVersionService.statusNotifier.value.source, 'baseline');
    });

    test('抓到的内容解析不出版本号时降级，不会写入脏值', () async {
      ClientVersionService.htmlFetcherForTest = () async =>
          '<html>页面改版了</html>';

      expect(
        await ClientVersionService.resolve(),
        AppConfig.baselineClientVersion,
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConfig.keyClientVersion), isNull);
    });

    test('缓存中的脏数据不会被采用', () async {
      SharedPreferences.setMockInitialValues({
        AppConfig.keyClientVersion: 'not-a-version',
      });
      ClientVersionService.htmlFetcherForTest = () async => null;

      expect(
        await ClientVersionService.resolve(),
        AppConfig.baselineClientVersion,
      );
      expect(ClientVersionService.statusNotifier.value.source, 'baseline');
    });

    test('设置自定义后立即生效，清除后恢复自动抓取', () async {
      ClientVersionService.htmlFetcherForTest = () async =>
          fakeStoreHtml('3.2.0');

      await ClientVersionService.setCustomVersion('1.2.3');
      expect(ClientVersionService.current, '1.2.3');
      expect(ClientVersionService.hasCustomVersion, isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(AppConfig.keyCustomClientVersion), '1.2.3');

      await ClientVersionService.clearCustomVersion();
      await ClientVersionService.resolve();

      expect(ClientVersionService.hasCustomVersion, isFalse);
      expect(ClientVersionService.current, '3.2.0');
      expect(
        (await SharedPreferences.getInstance()).getString(
          AppConfig.keyCustomClientVersion,
        ),
        isNull,
      );
    });

    test('非法自定义版本号会被拒绝', () async {
      await ClientVersionService.setCustomVersion('乱填的');
      expect(ClientVersionService.hasCustomVersion, isFalse);
      expect(ClientVersionService.current, AppConfig.baselineClientVersion);
    });
  });
}
