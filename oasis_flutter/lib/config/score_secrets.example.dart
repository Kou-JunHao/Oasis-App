/// 【已废弃 · 仅作历史记录】积分签名盐值模板（3.1.9 协议）
///
/// 原厂 3.1.10 起积分提交改用 **keyed BLAKE3** 签名（见
/// `lib/services/score_signer.dart`），不再需要任何硬编码盐值，
/// 因此本文件与 `score_secrets.dart` 已不再被任何代码引用。
///
/// 保留原因：说明 3.1.9 时代的协议形态，避免后来者误以为还需要补一个盐。
/// 如需彻底清理，可一并删除本文件、`lib/config/score_secrets.dart`
/// 以及 `.gitignore` 中的对应行。
///
/// —— 以下为原始说明（3.1.9 协议）——
///
/// 复制为 score_secrets.dart 并填入实际盐值：
///   cp lib/config/score_secrets.example.dart lib/config/score_secrets.dart
/// score_secrets.dart 已在 .gitignore 中排除，不会进入版本控制。
///
/// 盐值来源：原厂客户端（慧生活798）积分提交接口的签名参数，
/// 未配置时签到/任务提交会被服务端拒绝。
library;

/// App 端盐值（ApplicationType 1,1）
const String kScoreSaltApp = '';

/// 主平台盐值（ApplicationType 1,5）
const String kScoreSaltMain = '';
