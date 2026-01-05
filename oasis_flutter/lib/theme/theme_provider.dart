import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Material 3 主题提供者
/// 支持莫奈取色（动态颜色）、自定义主题颜色、深浅色模式切换
class ThemeProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;
  bool _useDynamicColor = true;
  Color? _seedColor;
  ColorScheme? _dynamicLightColorScheme;
  ColorScheme? _dynamicDarkColorScheme;

  ThemeProvider() {
    _initPreferences();
  }

  ThemeMode get themeMode => _themeMode;
  bool get useDynamicColor => _useDynamicColor;
  Color? get seedColor => _seedColor;
  ColorScheme? get dynamicLightColorScheme => _dynamicLightColorScheme;
  ColorScheme? get dynamicDarkColorScheme => _dynamicDarkColorScheme;

  Future<void> _initPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    _loadThemeMode();
    _loadDynamicColor();
    _loadSeedColor();
  }

  void _loadThemeMode() {
    final themeModeString = _prefs.getString('theme_mode') ?? 'system';
    _themeMode = _themeModeFromString(themeModeString);
    notifyListeners();
  }

  void _loadDynamicColor() {
    _useDynamicColor = _prefs.getBool('use_dynamic_color') ?? true;
    notifyListeners();
  }

  void _loadSeedColor() {
    final colorValue = _prefs.getInt('seed_color');
    if (colorValue != null) {
      _seedColor = Color(colorValue);
    }
    notifyListeners();
  }

  /// 设置主题模式
  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    await _prefs.setString('theme_mode', _themeModeToString(themeMode));
    notifyListeners();
  }

  /// 设置是否使用动态颜色（莫奈取色）
  Future<void> setDynamicColor(bool useDynamic) async {
    _useDynamicColor = useDynamic;
    await _prefs.setBool('use_dynamic_color', useDynamic);
    notifyListeners();
  }

  /// 设置种子颜色（用于生成颜色方案）
  Future<void> setSeedColor(Color? color) async {
    _seedColor = color;
    if (color != null) {
      // ignore: deprecated_member_use
      await _prefs.setInt('seed_color', color.value);
    } else {
      await _prefs.remove('seed_color');
    }
    notifyListeners();
  }

  /// 更新动态颜色方案（从系统获取）
  void updateDynamicColorScheme(ColorScheme? light, ColorScheme? dark) {
    _dynamicLightColorScheme = light;
    _dynamicDarkColorScheme = dark;
    notifyListeners();
  }

  /// 获取浅色主题
  ThemeData getLightTheme() {
    ColorScheme colorScheme;
    
    if (_useDynamicColor && _dynamicLightColorScheme != null) {
      // 使用系统动态颜色（莫奈取色）
      colorScheme = _dynamicLightColorScheme!;
    } else if (_seedColor != null) {
      // 使用自定义种子颜色生成
      colorScheme = ColorScheme.fromSeed(
        seedColor: _seedColor!,
        brightness: Brightness.light,
      );
    } else {
      // 使用默认蓝色主题
      colorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.light,
      );
    }

    return _buildTheme(colorScheme, Brightness.light);
  }

  /// 获取深色主题
  ThemeData getDarkTheme() {
    ColorScheme colorScheme;
    
    if (_useDynamicColor && _dynamicDarkColorScheme != null) {
      // 使用系统动态颜色（莫奈取色）
      colorScheme = _dynamicDarkColorScheme!;
    } else if (_seedColor != null) {
      // 使用自定义种子颜色生成
      colorScheme = ColorScheme.fromSeed(
        seedColor: _seedColor!,
        brightness: Brightness.dark,
      );
    } else {
      // 使用默认蓝色主题
      colorScheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF2196F3),
        brightness: Brightness.dark,
      );
    }

    return _buildTheme(colorScheme, Brightness.dark);
  }

  /// 构建Material 3主题
  ThemeData _buildTheme(ColorScheme colorScheme, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: brightness,
      
      // AppBar主题
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
      ),
      
      // Card主题
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: colorScheme.outlineVariant,
            width: 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      
      // FilledButton主题
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // OutlinedButton主题
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // TextButton主题
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(88, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      
      // FloatingActionButton主题
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      
      // NavigationBar主题
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: colorScheme.onSecondaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),
      
      // InputDecoration主题
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.primary,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: colorScheme.error,
            width: 1,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
      
      // Dialog主题
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      
      // BottomSheet主题
      bottomSheetTheme: BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      
      // Divider主题
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        space: 1,
        thickness: 1,
      ),
    );
  }

  String _themeModeToString(ThemeMode themeMode) {
    switch (themeMode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  ThemeMode _themeModeFromString(String themeModeString) {
    switch (themeModeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.system;
    }
  }
}
