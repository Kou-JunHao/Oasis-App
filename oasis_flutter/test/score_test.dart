import 'package:flutter_test/flutter_test.dart';

import 'package:oasis_flutter/models/score_models.dart';
import 'package:oasis_flutter/services/score_service.dart';

void main() {
  group('积分签名', () {
    test('时间戳为 30 秒粒度', () {
      expect(ScoreSigner.windowValue(1790400871389), 1790400870);
      // 同一 30 秒窗口内取值相同
      expect(ScoreSigner.windowValue(1790400899999), 1790400870);
      expect(ScoreSigner.windowValue(1790400900000), 1790400900);
    });

    test('token/uid 取末 8 位，不足 8 位时原样使用', () {
      expect(ScoreSigner.tail8('token1234567890abcdef'), '90abcdef');
      expect(ScoreSigner.tail8('12345678'), '12345678');
      expect(ScoreSigner.tail8('abc'), 'abc');
      expect(ScoreSigner.tail8(''), '');
    });

    test('App 端签名结果与实测算法一致', () {
      // md5("DAILY_CHECK_IN" + "1790400870" + "90abcdef" + "76543210" + 测试盐值)
      expect(
        ScoreSigner.sign(
          adId: 'DAILY_CHECK_IN',
          token: 'token1234567890abcdef',
          uid: 'uid_9876543210',
          salt: 'TEST_SALT_0123456789abcdefghijkl',
          nowMs: 1790400871389,
        ),
        'e44a576920192dbf84ae3b20d73d14bb',
      );
    });

    test('主平台签名使用不同盐值', () {
      expect(
        ScoreSigner.sign(
          adId: 'ad_reward_001',
          token: 'abcdefghijklmnop',
          uid: '12345678',
          salt: 'TEST_SALT_0123456789abcdefghijkl',
          nowMs: 1790400899999,
        ),
        'f153e8cd6576a627135c8af47a19083f',
      );
      // 盐值来自 gitignore 的 score_secrets.dart，仓库里只保留算法
      expect(ScoreSigner.saltOf(ScorePlatform.app), ScoreSigner.saltApp);
      expect(ScoreSigner.saltOf(ScorePlatform.main), ScoreSigner.saltMain);
    });
  });

  group('任务列表解析', () {
    test('解析任务、积分与签到信息', () {
      final overview = parseScoreOverview({
        'code': 0,
        'data': {
          'missions': [
            {'refId': 'ad_001', 'name': '看广告得积分', 'score': 10, 'limit': 3},
            {'refId': 'ad_002', 'title': '浏览任务', 'score': 5, 'limit': 1},
            {'refId': '', 'name': '无效任务', 'score': 5, 'limit': 1},
          ],
          'accScoreRsp': {
            'validScore': 1280,
            'totalScore': 3000,
            'daily': {'week': 0x0B}, // 周一、周二、周四已签
          },
          'dailyRSP': {
            'adId': 'DAILY_CHECK_IN',
            'score': 5,
            'config': [
              {'rule': 0x03, 'score': 10, 'msg': '连签2天'},
              {'rule': 0x7F, 'score': 100, 'msg': '连签7天'},
            ],
          },
        },
      }, ScorePlatform.app);

      expect(overview.validScore, 1280);
      expect(overview.totalScore, 3000);
      expect(overview.missions.length, 2);
      expect(overview.missions[0].name, '看广告得积分');
      expect(overview.missions[1].name, '浏览任务'); // 回退 title 字段

      final daily = overview.daily!;
      expect(daily.adId, 'DAILY_CHECK_IN');
      expect(daily.signedOn(1), isTrue);
      expect(daily.signedOn(2), isTrue);
      expect(daily.signedOn(3), isFalse);
      expect(daily.signedOn(4), isTrue);
    });

    test('签到奖励只包含本次签到新达成的档位', () {
      final daily = DailySignIn(
        adId: 'DAILY_CHECK_IN',
        baseScore: 5,
        weekMask: 0x03, // 周一、周二已签
        platform: ScorePlatform.app,
        rules: const [
          SignInRule(weekMask: 0x03, score: 10, message: '连签2天'),
          SignInRule(weekMask: 0x07, score: 20, message: '连签3天'),
          SignInRule(weekMask: 0x7F, score: 100, message: '连签7天'),
        ],
      );
      // 周三签到（weekDay=3）：已完成的 0x03 不重复发，0x07 新达成
      final rewards = daily.rewardsFor(3);
      expect(rewards.length, 1);
      expect(rewards.first.score, 20);
      // 已签到当天不再发奖励
      expect(daily.rewardsFor(1), isEmpty);
    });

    test('响应异常时返回空概览', () {
      expect(parseScoreOverview(null, ScorePlatform.app).missions, isEmpty);
      expect(parseScoreOverview({'code': -99}, ScorePlatform.app).validScore, 0);
    });
  });

  group('任务过滤', () {
    test('过滤理财类与无次数任务', () {
      ScoreMission m(String name, int score, int limit) => ScoreMission(
            refId: 'x',
            name: name,
            score: score,
            limit: limit,
            platform: ScorePlatform.app,
          );
      expect(m('看广告', 10, 1).executables, isTrue);
      expect(m('免费权益领取', 10, 1).executables, isFalse);
      expect(m('借贷任务', 10, 1).executables, isFalse);
      expect(m('零分任务', 0, 1).executables, isFalse);
      expect(m('无次数', 10, 0).executables, isFalse);
    });
  });

  group('积分明细解析', () {
    test('区分收入与支出并解析标题与 adId', () {
      final records = parseScoreRecords({
        'code': 0,
        'data': [
          {
            'ctime': 1790400871389,
            'type': 101,
            'data': {'adId': 'ad_001', 'adName': '广告任务'},
          },
          {
            'ctime': 1790400800000,
            'data': {'spend': 500, 'title': '兑换饮水'},
          },
        ],
      });

      expect(records.length, 2);
      expect(records[0].isIncome, isTrue);
      expect(records[0].adId, 'ad_001');
      expect(records[0].title, '广告任务');
      expect(records[1].isIncome, isFalse);
      expect(records[1].score, -500);
      expect(records[1].scoreText, '-500');
      expect(records[0].time, isNotNull);
    });

    test('明细非数组时返回空列表', () {
      expect(parseScoreRecords({'code': 0, 'data': {}}), isEmpty);
      expect(parseScoreRecords(null), isEmpty);
    });
  });
}
