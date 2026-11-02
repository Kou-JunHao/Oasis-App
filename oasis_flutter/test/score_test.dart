import 'package:flutter_test/flutter_test.dart';

import 'package:oasis_flutter/models/score_models.dart';
import 'package:oasis_flutter/services/score_signer.dart';

void main() {
  group('积分签名（3.1.10 协议）', () {
    test('时间戳为 30 秒粒度且单位是秒', () {
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

    test('路径 token 为去符号后的末 8 位', () {
      expect(ScoreSigner.pathToken(), 'coresend');
      expect(
        ScoreSigner.pathToken('/api/v1/acc/score/score-send'),
        'coresend',
      );
      // 短路径左侧补 0 后取末 8 位
      expect(ScoreSigner.pathToken('/ab'), '000000ab');
    });

    test('adId 规范化：按 key 稳定排序', () {
      expect(ScoreSigner.normalizeAdId('b=2&a=1'), 'a=1&b=2');
      expect(ScoreSigner.normalizeAdId('a=1&b=2'), 'a=1&b=2');
      expect(ScoreSigner.normalizeAdId('DAILY_CHECK_IN'), 'DAILY_CHECK_IN');
      // 同 key 保留原顺序
      expect(ScoreSigner.normalizeAdId('a=2&a=1'), 'a=2&a=1');
      expect(ScoreSigner.normalizeAdId('a=1&a=2'), 'a=1&a=2');
    });

    test('签名结果与官方 3.1.10 验证向量一致', () {
      // 向量来源：上游同源客户端测试用例
      //   CheckIn.sign("daily-fixture", "prefix-12345678", "prefix-abcdefgh",
      //                1_792_944_000_000L, protocolVersion = "3.1.10")
      const int mondayMidnightChina = 1792944000000; // 2026-10-26 00:00 +08
      expect(
        ScoreSigner.sign(
          adId: 'daily-fixture',
          token: 'prefix-12345678',
          uid: 'prefix-abcdefgh',
          nowMs: mondayMidnightChina,
        ),
        '36ce4348b84310502e39e08598667b4a',
      );
      // 同一时间窗内 +29999ms 结果不变
      expect(
        ScoreSigner.sign(
          adId: 'daily-fixture',
          token: 'prefix-12345678',
          uid: 'prefix-abcdefgh',
          nowMs: mondayMidnightChina + 29999,
        ),
        '36ce4348b84310502e39e08598667b4a',
      );
      // 跨到下一个时间窗则变化
      expect(
        ScoreSigner.sign(
          adId: 'daily-fixture',
          token: 'prefix-12345678',
          uid: 'prefix-abcdefgh',
          nowMs: mondayMidnightChina + 30000,
        ),
        '5f3896b39f4c621e6893663d54bc2dc0',
      );
    });

    test('签名对参数顺序不敏感但对重复 key 顺序敏感', () {
      String signOf(String adId) => ScoreSigner.sign(
            adId: adId,
            token: 'prefix-12345678',
            uid: 'prefix-abcdefgh',
            nowMs: 1792944000000,
          );
      expect(signOf('a=1&b=2'), signOf('b=2&a=1'));
      expect(signOf('a=2&a=1'), isNot(signOf('a=1&a=2')));
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
      });

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
      expect(parseScoreOverview(null).missions, isEmpty);
      expect(parseScoreOverview({'code': -99}).validScore, 0);
    });
  });

  group('任务过滤', () {
    test('过滤理财类与无次数任务', () {
      ScoreMission m(String name, int score, int limit) => ScoreMission(
            refId: 'x',
            name: name,
            score: score,
            limit: limit,
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
