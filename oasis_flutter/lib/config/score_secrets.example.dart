/// 积分奖励签名盐值模板
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
