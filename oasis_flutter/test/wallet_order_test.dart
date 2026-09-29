import 'package:flutter_test/flutter_test.dart';

import 'package:oasis_flutter/models/api_models.dart';
import 'package:oasis_flutter/providers/wallet_provider.dart';

WalletData wallet(String id, double balance) => WalletData(
      id: id,
      total: balance,
      olCash: balance,
    );

List<String> idsOf(List<WalletData> wallets) =>
    wallets.map((w) => w.id ?? '').toList();

void main() {
  group('钱包自定义排序', () {
    final wallets = [
      wallet('a', 10),
      wallet('b', 5),
      wallet('c', 1),
    ];

    test('未设置顺序时保持传入顺序', () {
      expect(idsOf(WalletProvider.applyWalletOrder(wallets, [])), ['a', 'b', 'c']);
    });

    test('按自定义顺序重排', () {
      expect(
        idsOf(WalletProvider.applyWalletOrder(wallets, ['c', 'a', 'b'])),
        ['c', 'a', 'b'],
      );
    });

    test('未列入顺序的钱包排到末尾并保持相对顺序', () {
      expect(
        idsOf(WalletProvider.applyWalletOrder(wallets, ['c'])),
        ['c', 'a', 'b'],
      );
    });

    test('顺序表里不存在的 id 被忽略，不影响结果', () {
      expect(
        idsOf(WalletProvider.applyWalletOrder(wallets, ['zzz', 'b', 'a'])),
        ['b', 'a', 'c'],
      );
    });

    test('id 为空的钱包不会被误排', () {
      final list = [wallet('', 3), wallet('a', 1)];
      expect(idsOf(WalletProvider.applyWalletOrder(list, ['a'])), ['a', '']);
    });

    test('空列表安全返回', () {
      expect(WalletProvider.applyWalletOrder([], ['a']), isEmpty);
    });
  });
}
