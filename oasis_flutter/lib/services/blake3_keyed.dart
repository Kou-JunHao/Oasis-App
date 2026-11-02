// BLAKE3 keyed-hash（纯 Dart 实现）
//
// 用途：3.1.10 协议下 `/acc/score/score-send` 的 `sign` 参数由 keyed BLAKE3 生成，
// 原厂客户端调用的是 native 实现，且只取摘要的前 16 字节（32 字符 hex）。
//
// 本项目不为该用途引入第三方依赖：单次输入只有几十字节（远小于 1024 B 的一个 chunk），
// 但这里仍按 BLAKE3 规范实现了完整的 chunk 树，保证与官方输出逐字节一致
// （见 test/blake3_keyed_test.dart 中的官方向量）。
//
// 参考：BLAKE3 规范（IV、消息置换、CHUNK_START/CHUNK_END/PARENT/ROOT/KEYED_HASH 标志位）。
class Blake3Keyed {
  Blake3Keyed._();

  static const int _chunkStart = 1;
  static const int _chunkEnd = 2;
  static const int _parent = 4;
  static const int _root = 8;
  static const int _keyedHash = 16;

  static const List<int> _iv = <int>[
    0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
    0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
  ];

  static const List<int> _permutation = <int>[
    2, 6, 3, 10, 7, 0, 4, 13, 1, 11, 12, 5, 9, 14, 15, 8,
  ];

  /// 计算 keyed BLAKE3，返回 32 字节原始摘要。
  static List<int> keyedHash(List<int> key, List<int> input) {
    if (key.length != 32) {
      throw ArgumentError.value(
        key.length,
        'key',
        'BLAKE3 keyed 模式要求 32 字节 key',
      );
    }
    final List<int> keyWords = _words(key, 0, key.length).sublist(0, 8);
    final int chunks = input.isEmpty ? 1 : ((input.length + 1023) ~/ 1024);

    _Output subtree(int first, int count) {
      if (count == 1) {
        final int offset = first * 1024;
        final int remaining = input.length - offset;
        final int length = remaining < 1024 ? remaining : 1024;
        final int blocks = length <= 0 ? 1 : (length + 63) ~/ 64;
        List<int> cv = keyWords;
        for (int index = 0; index < blocks; index++) {
          final int left = length - index * 64;
          final int blockLength = left < 0 ? 0 : (left < 64 ? left : 64);
          final int flags = _keyedHash |
              (index == 0 ? _chunkStart : 0) |
              (index == blocks - 1 ? _chunkEnd : 0);
          final _Output output = _Output(
            cv,
            _words(input, offset + index * 64, blockLength),
            first,
            blockLength,
            flags,
          );
          if (index == blocks - 1) return output;
          cv = output.chaining();
        }
        throw StateError('BLAKE3 chunk 组装失败');
      }
      final int leftCount = _highestOneBit(count - 1);
      final List<int> leftCv = subtree(first, leftCount).chaining();
      final List<int> rightCv =
          subtree(first + leftCount, count - leftCount).chaining();
      return _Output(
        keyWords,
        <int>[...leftCv, ...rightCv],
        0,
        64,
        _keyedHash | _parent,
      );
    }

    return subtree(0, chunks).root();
  }

  /// 计算 keyed BLAKE3 并返回小写 hex（完整 32 字节 / 64 字符）。
  static String keyedHashHex(List<int> key, List<int> input) {
    final StringBuffer buffer = StringBuffer();
    for (final int byte in keyedHash(key, input)) {
      buffer.write(byte.toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }

  static int _highestOneBit(int value) {
    int result = 1;
    while (result << 1 <= value) {
      result <<= 1;
    }
    return result;
  }

  /// 把小端字节序列装成 16 个 32-bit word；不足 64 字节的尾部按 0 补齐。
  static List<int> _words(List<int> bytes, int offset, int length) {
    final List<int> result = List<int>.filled(16, 0);
    final int safeLength =
        length < 0 ? 0 : (length > 64 ? 64 : length);
    for (int index = 0; index < safeLength; index++) {
      final int position = offset + index;
      if (position >= bytes.length) break;
      result[index ~/ 4] |= (bytes[position] & 0xff) << (8 * (index % 4));
    }
    return result;
  }

  static List<int> _compress(
    List<int> cv,
    List<int> block,
    int counter,
    int length,
    int flags,
  ) {
    final List<int> state = <int>[
      cv[0], cv[1], cv[2], cv[3], cv[4], cv[5], cv[6], cv[7], //
      _iv[0], _iv[1], _iv[2], _iv[3], //
      counter & 0xffffffff, (counter >> 32) & 0xffffffff, //
      length, flags,
    ];
    List<int> message = block;

    int rotateRight(int value, int shift) {
      final int v = value & 0xffffffff;
      return ((v >> shift) | (v << (32 - shift))) & 0xffffffff;
    }

    void mix(int a, int b, int c, int d, int x, int y) {
      state[a] = (state[a] + state[b] + x) & 0xffffffff;
      state[d] = rotateRight(state[d] ^ state[a], 16);
      state[c] = (state[c] + state[d]) & 0xffffffff;
      state[b] = rotateRight(state[b] ^ state[c], 12);
      state[a] = (state[a] + state[b] + y) & 0xffffffff;
      state[d] = rotateRight(state[d] ^ state[a], 8);
      state[c] = (state[c] + state[d]) & 0xffffffff;
      state[b] = rotateRight(state[b] ^ state[c], 7);
    }

    for (int round = 0; round < 7; round++) {
      mix(0, 4, 8, 12, message[0], message[1]);
      mix(1, 5, 9, 13, message[2], message[3]);
      mix(2, 6, 10, 14, message[4], message[5]);
      mix(3, 7, 11, 15, message[6], message[7]);
      mix(0, 5, 10, 15, message[8], message[9]);
      mix(1, 6, 11, 12, message[10], message[11]);
      mix(2, 7, 8, 13, message[12], message[13]);
      mix(3, 4, 9, 14, message[14], message[15]);
      message = List<int>.generate(16, (int i) => message[_permutation[i]]);
    }

    return List<int>.generate(16, (int index) {
      if (index < 8) return state[index] ^ state[index + 8];
      return state[index] ^ cv[index - 8];
    });
  }
}

class _Output {
  const _Output(this.cv, this.block, this.counter, this.blockLength, this.flags);

  final List<int> cv;
  final List<int> block;
  final int counter;
  final int blockLength;
  final int flags;

  List<int> chaining() => Blake3Keyed._compress(
        cv,
        block,
        counter,
        blockLength,
        flags,
      ).sublist(0, 8);

  List<int> root() {
    final List<int> words = Blake3Keyed._compress(
      cv,
      block,
      0,
      blockLength,
      flags | Blake3Keyed._root,
    );
    return List<int>.generate(
      32,
      (int index) => (words[index ~/ 4] >> (8 * (index % 4))) & 0xff,
    );
  }
}
