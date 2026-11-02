import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:oasis_flutter/services/blake3_keyed.dart';

/// keyed BLAKE3 与官方测试向量对照
///
/// 向量来源：上游同源客户端（SmartLife798）`CheckInTest.kt`，
/// 其中 keyed BLAKE3 向量由 BLAKE3 官方测试套件转写而来：
///   key   = "whats the Elvish word for friend"
///   input = ByteArray(n) { (it % 251).toByte() }
void main() {
  group('keyed BLAKE3', () {
    final List<int> key = utf8.encode('whats the Elvish word for friend');

    String hashOf(int n) {
      final Uint8List input = Uint8List(n);
      for (int i = 0; i < n; i++) {
        input[i] = i % 251;
      }
      return Blake3Keyed.keyedHashHex(key, input);
    }

    test('空输入（n=0）', () {
      expect(hashOf(0), '92b2b75604ed3c761f9d6f62392c8a9227ad0ea3f09573e783f1498a4ed60d26');
    });

    test('单块边界（n=1 / n=63 / n=64）', () {
      expect(hashOf(1), '6d7878dfff2f485635d39013278ae14f1454b8c0a3a2d34bc1ab38228a80c95b');
      expect(hashOf(63), 'bb1eb5d4afa793c1ebdd9fb08def6c36d10096986ae0cfe148cd101170ce37ae');
      expect(hashOf(64), 'ba8ced36f327700d213f120b1a207a3b8c04330528586f414d09f2f7d9ccb7e6');
    });

    test('多块与 chunk 树（n=1024 / n=4096）', () {
      expect(hashOf(1024), '75c46f6f3d9eb4f55ecaaee480db732e6c2105546f1e675003687c31719c7ba4');
      expect(hashOf(4096), 'befc660aea2f1718884cd8deb9902811d332f4fc4a38cf7c7300d597a081bfc0');
    });

    test('输出固定 32 字节 / 64 位 hex', () {
      final List<int> digest = Blake3Keyed.keyedHash(key, utf8.encode('abc'));
      expect(digest.length, 32);
      expect(Blake3Keyed.keyedHashHex(key, utf8.encode('abc')).length, 64);
    });

    test('key 长度必须为 32 字节', () {
      expect(() => Blake3Keyed.keyedHash(List<int>.filled(31, 0), utf8.encode('x')),
          throwsArgumentError);
      expect(() => Blake3Keyed.keyedHash(List<int>.filled(33, 0), utf8.encode('x')),
          throwsArgumentError);
    });

    test('key 或输入不同则结果不同', () {
      final List<int> otherKey = List<int>.of(key)..[0] ^= 0xff;
      expect(
        Blake3Keyed.keyedHashHex(key, utf8.encode('abc')),
        isNot(Blake3Keyed.keyedHashHex(otherKey, utf8.encode('abc'))),
      );
      expect(
        Blake3Keyed.keyedHashHex(key, utf8.encode('abc')),
        isNot(Blake3Keyed.keyedHashHex(key, utf8.encode('abd'))),
      );
    });
  });
}
