/// 应用常量
class AppConstants {
  // 防止实例化
  AppConstants._();
  
  // 路由名称
  static const String routeHome = '/';
  static const String routeLogin = '/login';
  static const String routeRegister = '/register';
  static const String routeProfile = '/profile';
  static const String routeSettings = '/settings';
  static const String routeWaterUsage = '/water-usage';
  static const String routeDevices = '/devices';
  static const String routePayment = '/payment';
  
  // 动画时长
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration shortAnimationDuration = Duration(milliseconds: 150);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);
  
  // 间距
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingExtraLarge = 32.0;
  
  // 圆角
  static const double radiusSmall = 4.0;
  static const double radiusMedium = 8.0;
  static const double radiusLarge = 16.0;
  static const double radiusExtraLarge = 24.0;
  
  // 图标大小
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  static const double iconSizeExtraLarge = 48.0;
  
  // 字体大小
  static const double fontSizeSmall = 12.0;
  static const double fontSizeMedium = 14.0;
  static const double fontSizeLarge = 16.0;
  static const double fontSizeExtraLarge = 20.0;
  static const double fontSizeTitle = 24.0;
  
  // 错误消息
  static const String errorNetwork = '网络连接失败，请检查您的网络设置';
  static const String errorServer = '服务器错误，请稍后重试';
  static const String errorUnknown = '未知错误，请稍后重试';
  static const String errorTimeout = '请求超时，请稍后重试';
  static const String errorInvalidCredentials = '用户名或密码错误';
  
  // 成功消息
  static const String successLogin = '登录成功';
  static const String successLogout = '退出登录成功';
  static const String successRegister = '注册成功';
  static const String successUpdate = '更新成功';
  
  // 提示消息
  static const String hintUsername = '请输入用户名';
  static const String hintPassword = '请输入密码';
  static const String hintPhone = '请输入手机号';
  static const String hintVerificationCode = '请输入验证码';
}
