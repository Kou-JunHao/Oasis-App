import 'package:flutter/material.dart';

/// 全局 SnackBar 载体：会话失效等全局提示用
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// 全局导航器：用于弹出会话失效时的二级页面、以及全局更新面板
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
