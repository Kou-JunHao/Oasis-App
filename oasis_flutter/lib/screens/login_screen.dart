import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';
import '../utils/github_update_checker.dart';
import '../utils/apk_installer.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _captchaController = TextEditingController();
  
  bool _agreedToTerms = false;
  int _countdown = 0;
  Uint8List? _captchaImage;
  bool _loadingCaptcha = false;
  int _captchaS = 500; // 保存验证码会话参数,与Kotlin版本保持一致

  @override
  void initState() {
    super.initState();
    _loadCaptcha();
    _checkForUpdates();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _captchaController.dispose();
    super.dispose();
  }

  /// 检查应用更新
  Future<void> _checkForUpdates() async {
    try {
      final updateInfo = await GitHubUpdateChecker.checkForUpdates();
      if (updateInfo != null && mounted) {
        _showUpdateBottomSheet(updateInfo);
      }
    } catch (e) {
      debugPrint('检查更新失败: $e');
    }
  }

  /// 显示更新底部弹窗
  void _showUpdateBottomSheet(UpdateInfo updateInfo) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _UpdateBottomSheet(updateInfo: updateInfo),
    );
  }

  Future<void> _loadCaptcha() async {
    setState(() {
      _loadingCaptcha = true;
    });

    try {
      // 验证码不需要token，可以创建临时ApiService
      _captchaS = 500;
      final r = DateTime.now().millisecondsSinceEpoch;
      
      final tempApiService = ApiService();
      final response = await tempApiService.getCaptcha(_captchaS, r);
      
      if (response.statusCode == 200 && response.data != null) {
        setState(() {
          _captchaImage = Uint8List.fromList(response.data as List<int>);
          _loadingCaptcha = false;
        });
      } else {
        setState(() {
          _loadingCaptcha = false;
        });
        if (mounted) {
          _showMessage('加载验证码失败');
        }
      }
    } catch (e) {
      setState(() {
        _loadingCaptcha = false;
      });
      if (mounted) {
        _showMessage('加载验证码失败: $e');
      }
    }
  }

  void _startCountdown() {
    if (!mounted) return;
    
    setState(() {
      _countdown = 60;
    });
    
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false; // 检查是否已销毁
      
      if (_countdown > 0) {
        setState(() {
          _countdown--;
        });
        return true;
      }
      return false;
    });
  }

  Future<void> _getSmsCode() async {
    if (_phoneController.text.isEmpty) {
      _showMessage('请输入手机号');
      return;
    }

    if (_captchaController.text.isEmpty) {
      _showMessage('请输入图形验证码');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.getSmsCode(
      _phoneController.text,
      _captchaController.text,
      _captchaS, // 传递获取图形验证码时使用的s参数
    );

    if (success) {
      _startCountdown();
      _showMessage('验证码已发送');
    } else {
      _showMessage(authProvider.errorMessage ?? '获取验证码失败');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_agreedToTerms) {
      _showMessage('请先同意服务条款和隐私政策');
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final success = await authProvider.login(
      _phoneController.text,
      _codeController.text,
      _captchaController.text,
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else if (mounted) {
      _showMessage(authProvider.errorMessage ?? '登录失败');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      body: SafeArea(
        child: Consumer<AuthProvider>(
          builder: (context, authProvider, _) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 40),
                        
                        // Logo和标题
                        Icon(
                          Icons.water_drop_rounded,
                          size: 72,
                          color: colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Oasis',
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.primary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '生活用水管理',
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 48),
                        
                        // 手机号输入
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: '手机号',
                            hintText: '请输入手机号码',
                            prefixIcon: const Icon(Icons.phone_android_rounded),
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
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: colorScheme.error,
                                width: 2,
                              ),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return '请输入手机号';
                            }
                            if (!RegExp(r'^1[3-9]\d{9}$').hasMatch(value)) {
                              return '请输入有效的手机号';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        
                        // 图形验证码输入
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _captchaController,
                                decoration: InputDecoration(
                                  labelText: '图形验证码',
                                  hintText: '请输入验证码',
                                  prefixIcon: const Icon(Icons.verified_user_rounded),
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
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: colorScheme.error,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return '请输入图形验证码';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            // 图形验证码图片
                            Container(
                              width: 120,
                              height: 56,
                              clipBehavior: Clip.antiAlias,
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: colorScheme.outline.withOpacity(0.2),
                                ),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _loadCaptcha,
                                  borderRadius: BorderRadius.circular(12),
                                  child: _loadingCaptcha
                                      ? Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: colorScheme.primary,
                                            ),
                                          ),
                                        )
                                      : _captchaImage != null
                                          ? Image.memory(
                                              _captchaImage!,
                                              fit: BoxFit.contain,
                                              width: 120,
                                              height: 56,
                                            )
                                          : Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.refresh_rounded,
                                                  size: 24,
                                                  color: colorScheme.primary,
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '点击刷新',
                                                  style: textTheme.labelSmall?.copyWith(
                                                    color: colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        
                        // 短信验证码输入
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: _codeController,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: '短信验证码',
                                  hintText: '请输入短信验证码',
                                  prefixIcon: const Icon(Icons.sms_rounded),
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
                                  focusedErrorBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: colorScheme.error,
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return AppConstants.hintVerificationCode;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            SizedBox(
                              width: 120,
                              height: 56,
                              child: FilledButton(
                                onPressed: _countdown > 0 ? null : _getSmsCode,
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                ),
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _countdown > 0 ? '$_countdown秒' : '获取验证码',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        // 同意条款复选框
                        Row(
                          children: [
                            Checkbox(
                              value: _agreedToTerms,
                              onChanged: (value) {
                                setState(() {
                                  _agreedToTerms = value ?? false;
                                });
                              },
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            Expanded(
                              child: Text.rich(
                                TextSpan(
                                  text: '我已阅读并同意',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  children: [
                                    TextSpan(
                                      text: '《服务条款》',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const TextSpan(text: '和'),
                                    TextSpan(
                                      text: '《隐私政策》',
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        // 登录按钮
                        FilledButton(
                          onPressed: authProvider.isLoading ? null : _login,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 2,
                            textStyle: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: authProvider.isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      colorScheme.onPrimary,
                                    ),
                                  ),
                                )
                              : const Text('登录'),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 更新提示底部弹窗
class _UpdateBottomSheet extends StatefulWidget {
  final UpdateInfo updateInfo;

  const _UpdateBottomSheet({required this.updateInfo});

  @override
  State<_UpdateBottomSheet> createState() => _UpdateBottomSheetState();
}

class _UpdateBottomSheetState extends State<_UpdateBottomSheet> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          Row(
            children: [
              Icon(Icons.system_update_rounded, color: colorScheme.primary, size: 28),
              const SizedBox(width: 12),
              Text(
                '发现新版本',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 版本信息
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '版本 ${widget.updateInfo.tagName}',
                      style: textTheme.titleMedium?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '最新',
                        style: textTheme.labelSmall?.copyWith(color: colorScheme.onPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // 下载进度
          if (_isDownloading) ...[
            LinearProgressIndicator(
              value: _downloadProgress,
              backgroundColor: colorScheme.surfaceContainerHighest,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 8),
            Text(
              '下载中... ${(_downloadProgress * 100).toInt()}%',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.primary),
            ),
            const SizedBox(height: 16),
          ],
          
          // 按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isDownloading ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('稍后'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: _isDownloading ? null : _downloadAndInstall,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _isDownloading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(_isDownloading ? '下载中...' : '立即更新'),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Future<void> _downloadAndInstall() async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      final apkPath = await ApkInstaller.downloadApk(
        widget.updateInfo.downloadUrl,
        onProgress: (received, total) {
          if (mounted) {
            setState(() {
              _downloadProgress = total > 0 ? received / total : 0.0;
            });
          }
        },
      );

      if (!mounted) return;

      if (apkPath != null) {
        final installed = await ApkInstaller.installApk(apkPath);
        if (!mounted) return;

        if (!installed) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('安装失败，请手动安装')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载失败，请检查网络连接')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDownloading = false;
        });
      }
    }
  }
}
