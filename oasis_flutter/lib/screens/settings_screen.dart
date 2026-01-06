import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../providers/auth_provider.dart';
import '../theme/theme_provider.dart';
import '../utils/github_update_checker.dart';
import '../utils/github_mirror_config.dart';
import '../utils/apk_installer.dart';
import '../widgets/color_picker_dialog.dart';
import '../widgets/payment_sheet.dart';
import '../widgets/bottom_sheet_helper.dart';
import 'login_screen.dart';
import 'open_source_licenses_screen.dart';

/// 设置页面 - Material 3风格，完整功能实现
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with AutomaticKeepAliveClientMixin {
  String _appVersion = '1.0.0';
  String _buildDate = 'Unknown';
  String _buildNumber = '';
  bool _isCheckingUpdate = false;
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _downloadedApkPath;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  /// 加载应用版本信息
  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      
      // 从原生代码获取构建时间戳
      String buildTimestamp = '';
      try {
        const platform = MethodChannel('uno.skkk.oasis/build_info');
        buildTimestamp = await platform.invokeMethod('getBuildTimestamp');
        debugPrint('✓ 成功获取构建时间戳: $buildTimestamp');
      } catch (e) {
        debugPrint('✗ 获取构建时间戳失败: $e');
        debugPrint('使用fallback: packageInfo.buildNumber = ${packageInfo.buildNumber}');
      }
      
      if (mounted) {
        setState(() {
          _appVersion = packageInfo.version;
          // 优先使用构建时间戳，如果为空则使用占位符
          _buildNumber = buildTimestamp.isNotEmpty ? buildTimestamp : 'Unknown';
          
          // 从构建时间戳解析完整构建时间（格式：YYYYMMDDHHMMSS）
          if (_buildNumber != 'Unknown' && _buildNumber.length >= 14) {
            try {
              final year = _buildNumber.substring(0, 4);
              final month = _buildNumber.substring(4, 6);
              final day = _buildNumber.substring(6, 8);
              final hour = _buildNumber.substring(8, 10);
              final minute = _buildNumber.substring(10, 12);
              final second = _buildNumber.substring(12, 14);
              _buildDate = '$year-$month-$day $hour:$minute:$second';
            } catch (e) {
              _buildDate = 'Unknown';
            }
          } else {
            _buildDate = 'Unknown';
          }
        });
      }
    } catch (e) {
      debugPrint('获取版本信息失败: $e');
    }
  }

  /// 检查更新
  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final updateInfo = await GitHubUpdateChecker.checkForUpdates();

      if (!mounted) return;

      if (updateInfo != null) {
        _showUpdateDialog(updateInfo);
      } else {
        _showNoUpdateDialog();
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar('检查更新失败: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  /// 显示更新对话框
  void _showUpdateDialog(UpdateInfo updateInfo) async {
    final colorScheme = Theme.of(context).colorScheme;
    
    // 对话框内部的状态
    bool isDownloading = false;
    double downloadProgress = 0.0;
    
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).padding.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 拖动条
                    Center(
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // 图标和标题
                    Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.system_update_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '发现新版本 ${updateInfo.tagName}',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // 内容区域
                    SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  color: colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.onPrimaryContainer, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '发布时间: ${_formatDateTime(updateInfo.publishedAt)}',
                            style: TextStyle(
                              fontSize: 13,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '更新内容',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: MarkdownBody(
                      data: updateInfo.body.isEmpty ? '暂无更新说明' : updateInfo.body,
                      styleSheet: MarkdownStyleSheet(
                        p: Theme.of(context).textTheme.bodyMedium,
                        h1: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        h2: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        h3: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        listBullet: Theme.of(context).textTheme.bodyMedium,
                        code: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          backgroundColor: colorScheme.surfaceContainerHighest,
                        ),
                        a: TextStyle(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                      onTapLink: (text, href, title) async {
                        if (href != null) {
                          final uri = Uri.parse(href);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
                    const SizedBox(height: 24),
                    // 按钮
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: isDownloading ? null : () => Navigator.pop(context, false),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text('稍后'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isDownloading 
                                ? null 
                                : () async {
                                    // 立即更新UI状态
                                    setDialogState(() {
                                      isDownloading = true;
                                      downloadProgress = 0.0;
                                    });

                                    try {
                                      // 开始下载APK
                                      await ApkInstaller.downloadApk(
                                        updateInfo.downloadUrl,
                                        onProgress: (received, total) {
                                          if (total > 0) {
                                            setDialogState(() {
                                              downloadProgress = received / total;
                                            });
                                          }
                                        },
                                        onComplete: (path) async {
                                          setState(() {
                                            _downloadedApkPath = path;
                                          });
                                          
                                          if (!context.mounted) return;
                                          
                                          // 下载完成，关闭对话框
                                          Navigator.pop(context);
                                          
                                          // 显示安装对话框
                                          _showInstallDialog(context, path);
                                        },
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('下载失败: $e')),
                                        );
                                      }
                                    } finally {
                                      setDialogState(() {
                                        isDownloading = false;
                                        downloadProgress = 0.0;
                                      });
                                    }
                                  },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: isDownloading 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.download_rounded),
                            label: Text(isDownloading 
                                ? '下载中 ${(downloadProgress * 100).toStringAsFixed(0)}%' 
                                : '立即更新'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 下载并安装更新
  Future<void> _downloadAndInstallUpdate(BuildContext context, UpdateInfo updateInfo) async {
    setState(() {
      _isDownloading = true;
      _downloadProgress = 0.0;
    });

    try {
      // 开始下载APK
      final filePath = await ApkInstaller.downloadApk(
        updateInfo.downloadUrl,
        onProgress: (received, total) {
          if (total > 0) {
            setState(() {
              _downloadProgress = received / total;
            });
          }
        },
        onComplete: (path) async {
          setState(() {
            _downloadedApkPath = path;
          });
          
          if (!mounted) return;
          
          // 下载完成，关闭对话框
          Navigator.pop(context);
          
          // 显示安装提示
          await _showInstallDialog(context, path);
        },
        onError: (error) {
          if (!mounted) return;
          
          setState(() {
            _isDownloading = false;
            _downloadProgress = 0.0;
          });
          
          _showErrorSnackBar('下载失败: $error');
        },
      );
      
      if (filePath == null && mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _downloadProgress = 0.0;
        });
        _showErrorSnackBar('下载失败: $e');
      }
    }
  }

  /// 显示安装确认对话框
  Future<void> _showInstallDialog(BuildContext context, String apkPath) async {
    final colorScheme = Theme.of(context).colorScheme;
    
    final result = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: true,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: colorScheme.primary,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  '下载完成',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '更新包已下载完成，点击"立即安装"开始安装',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('稍后安装'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.install_mobile_rounded),
                        label: const Text('立即安装'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == true && mounted) {
      // 开始安装
      final success = await ApkInstaller.installApk(apkPath);
      
      if (!success && mounted) {
        _showErrorSnackBar('无法拉起安装程序，请手动安装');
      }
    }
    
    // 无论是否安装，都重置下载状态
    if (mounted) {
      setState(() {
        _isDownloading = false;
        _downloadProgress = 0.0;
      });
    }
  }

  /// 显示无更新对话框
  void _showNoUpdateDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: true,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动条
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 图标
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 32,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 16),
                // 标题
                Text(
                  '当前已是最新版本',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                // 版本信息
                Text(
                  '当前版本: $_appVersion',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                // 按钮
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('确定'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 显示应用信息对话框
  void _showAppInfoDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          bottom: true,
          child: Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: 24 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 拖动条
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // 应用图标和标题
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.water_drop_rounded,
                    color: colorScheme.onPrimaryContainer,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Oasis App',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '生活用水管理应用',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                // 信息列表
                Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _InfoRow(icon: Icons.info_outline_rounded, label: '版本号', value: _appVersion),
                      const Divider(height: 16),
                      _InfoRow(icon: Icons.tag_rounded, label: '构建号', value: _buildNumber.isNotEmpty ? _buildNumber : 'Unknown'),
                      const Divider(height: 16),
                      _InfoRow(icon: Icons.calendar_today_rounded, label: '构建时间', value: _buildDate),
                      const Divider(height: 16),
                      _InfoRow(icon: Icons.code_rounded, label: '框架', value: 'Flutter'),
                      const Divider(height: 16),
                      _InfoRow(icon: Icons.person_outline_rounded, label: '作者', value: 'Kou-JunHao'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // 按钮
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () {
                          Navigator.pop(context);
                          _openGitHub();
                        },
                        icon: const Icon(Icons.code_rounded, size: 20),
                        label: const Text('GitHub'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.check_rounded, size: 20),
                        label: const Text('确定'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 打开GitHub页面
  Future<void> _openGitHub() async {
    final uri = Uri.parse('https://github.com/Kou-JunHao/Oasis-App');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        _showErrorSnackBar('无法打开浏览器，请手动访问项目地址');
      }
    }
  }

  /// 显示镜像源选择对话框
  Future<void> _showMirrorSelectionDialog() async {
    final colorScheme = Theme.of(context).colorScheme;
    final mirrors = await GitHubMirrorConfig.getAllMirrors();
    final currentMirror = await GitHubMirrorConfig.getSelectedMirror();
    int selectedIndex = mirrors.indexWhere((m) => m.name == currentMirror.name);
    if (selectedIndex == -1) selectedIndex = 0;

    // 用于存储连通性测试结果
    final Map<int, bool?> connectivityStatus = {};

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            bottom: true,
            child: Padding(
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 24,
                bottom: 24 + MediaQuery.of(context).padding.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 拖动条
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colorScheme.onSurfaceVariant.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // 标题
                  Row(
                    children: [
                      Icon(Icons.cloud_sync_rounded, size: 28, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'GitHub镜像源',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      // 刷新连通性按钮
                      IconButton(
                        icon: const Icon(Icons.refresh_rounded),
                        tooltip: '测试连通性',
                        onPressed: () async {
                          setState(() {
                            connectivityStatus.clear();
                          });
                          for (int i = 0; i < mirrors.length; i++) {
                            final isConnected = await GitHubMirrorConfig.testMirrorConnectivity(
                              mirrors[i].apiUrl,
                            );
                            setState(() {
                              connectivityStatus[i] = isConnected;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '选择检查更新时使用的镜像源，国内建议使用加速镜像',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 镜像源列表
                  ...List.generate(mirrors.length, (index) {
                    final mirror = mirrors[index];
                    final bool? isConnected = connectivityStatus[index];
                    final bool isCustom = index >= 3; // 前3个是预设镜像
                    
                    return RadioListTile<int>(
                      value: index,
                      groupValue: selectedIndex,
                      onChanged: (value) async {
                        setState(() {
                          selectedIndex = value!;
                        });
                        await GitHubMirrorConfig.setSelectedMirror(value!);
                      },
                      title: Row(
                        children: [
                          Expanded(child: Text(mirror.name)),
                          // 连通性指示器
                          if (isConnected != null) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: isConnected ? Colors.green : Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                          ],
                          // 删除按钮（仅自定义镜像）
                          if (isCustom)
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded, size: 20),
                              color: Colors.red,
                              tooltip: '删除',
                              onPressed: () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('确认删除'),
                                    content: Text('确定要删除镜像源 "${mirror.name}" 吗？'),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('取消'),
                                      ),
                                      FilledButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        style: FilledButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        child: const Text('删除'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirmed == true) {
                                  await GitHubMirrorConfig.removeCustomMirror(index - 3);
                                  // 如果删除的是当前选中的镜像，重置为第一个
                                  if (selectedIndex == index) {
                                    await GitHubMirrorConfig.setSelectedMirror(0);
                                    selectedIndex = 0;
                                  } else if (selectedIndex > index) {
                                    selectedIndex--;
                                  }
                                  // 重新获取镜像列表
                                  final newMirrors = await GitHubMirrorConfig.getAllMirrors();
                                  setState(() {
                                    mirrors.clear();
                                    mirrors.addAll(newMirrors);
                                    connectivityStatus.clear();
                                  });
                                }
                              },
                            ),
                        ],
                      ),
                      subtitle: Text(
                        mirror.description,
                        style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      ),
                      contentPadding: EdgeInsets.zero,
                    );
                  }),
                  const SizedBox(height: 16),
                  // 添加自定义镜像按钮
                  OutlinedButton.icon(
                    onPressed: () => _showAddCustomMirrorDialog(context, setState, mirrors),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('添加自定义镜像'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 48),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 关闭按钮
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('完成'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // 刷新状态以显示新选择的镜像源
    if (mounted) {
      setState(() {});
    }
  }

  /// 显示添加自定义镜像对话框
  Future<void> _showAddCustomMirrorDialog(
    BuildContext parentContext,
    StateSetter parentSetState,
    List<GitHubMirror> mirrors,
  ) async {
    final result = await showInputBottomSheet(
      context: parentContext,
      title: '添加自定义镜像',
      icon: Icons.add_circle_outline_rounded,
      fields: [
        InputField(
          key: 'name',
          label: '镜像名称',
          hint: '例如：我的镜像',
          icon: Icons.label_outline_rounded,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入镜像名称';
            }
            return null;
          },
        ),
        InputField(
          key: 'apiUrl',
          label: 'API地址',
          hint: '例如：https://mirror.example.com/https://api.github.com',
          icon: Icons.api_rounded,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入API地址';
            }
            if (!value.startsWith('http://') && !value.startsWith('https://')) {
              return 'API地址必须以http://或https://开头';
            }
            return null;
          },
        ),
        InputField(
          key: 'rawUrl',
          label: '原始地址',
          hint: '例如：https://mirror.example.com/https://github.com',
          icon: Icons.link_rounded,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '请输入原始地址';
            }
            if (!value.startsWith('http://') && !value.startsWith('https://')) {
              return '原始地址必须以http://或https://开头';
            }
            return null;
          },
        ),
        InputField(
          key: 'description',
          label: '描述（可选）',
          hint: '简要描述此镜像源',
          icon: Icons.description_outlined,
          maxLines: 2,
        ),
      ],
      confirmText: '添加',
    );

    if (result != null) {
      final mirror = GitHubMirror(
        name: result['name']!.trim(),
        apiUrl: result['apiUrl']!.trim(),
        rawUrl: result['rawUrl']!.trim(),
        description: result['description']?.trim() ?? '自定义镜像源',
      );

      await GitHubMirrorConfig.addCustomMirror(mirror);

      // 重新获取镜像列表
      final newMirrors = await GitHubMirrorConfig.getAllMirrors();
      parentSetState(() {
        mirrors.clear();
        mirrors.addAll(newMirrors);
      });

      if (parentContext.mounted) {
        ScaffoldMessenger.of(parentContext).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('自定义镜像添加成功'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  /// 打开Buy Me a Coffee
  Future<void> _openBuyMeACoffee() async {
    final uri = Uri.parse('https://buymeacoffee.com/skkk');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        _showErrorSnackBar('无法打开浏览器');
      }
    }
  }

  /// 显示错误提示
  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: '确定',
          onPressed: () {},
        ),
      ),
    );
  }

  /// 格式化日期时间
  String _formatDateTime(String dateTimeStr) {
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return '${dateTime.year}年${dateTime.month.toString().padLeft(2, '0')}月${dateTime.day.toString().padLeft(2, '0')}日';
    } catch (e) {
      return dateTimeStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // App Bar
          SliverAppBar.medium(
            title: const Text('设置'),
            floating: false,
            pinned: true,
          ),
          
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 用户信息卡片
                _UserInfoCard(
                  user: authProvider.user,
                  onTap: () {
                    // TODO: 跳转到个人信息页面
                  },
                ),
                const SizedBox(height: 24),

                // 外观设置
                _SectionHeader(title: '外观设置'),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: Icon(Icons.palette_rounded, color: colorScheme.primary),
                        title: const Text('莫奈取色'),
                        subtitle: const Text('使用系统壁纸颜色作为主题色'),
                        value: themeProvider.useDynamicColor,
                        onChanged: (value) {
                          themeProvider.setDynamicColor(value);
                        },
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: Icon(Icons.brush_rounded, color: colorScheme.primary),
                        title: const Text('自定义主题颜色'),
                        subtitle: const Text('选择您喜欢的主题颜色'),
                        trailing: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: themeProvider.seedColor ?? const Color(0xFF2196F3),
                            shape: BoxShape.circle,
                            border: Border.all(color: colorScheme.outline, width: 2),
                          ),
                        ),
                        onTap: () async {
                          final color = await showColorPickerDialog(
                            context,
                            initialColor: themeProvider.seedColor,
                          );
                          if (color != null) {
                            themeProvider.setSeedColor(color);
                          }
                        },
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: Icon(Icons.color_lens_rounded, color: colorScheme.primary),
                        title: const Text('主题模式'),
                        subtitle: const Text('选择浅色、深色或跟随系统'),
                        trailing: SegmentedButton<ThemeMode>(
                          showSelectedIcon: false,
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_rounded, size: 18),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_rounded, size: 18),
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_rounded, size: 18),
                            ),
                          ],
                          selected: {themeProvider.themeMode},
                          onSelectionChanged: (Set<ThemeMode> newSelection) {
                            themeProvider.setThemeMode(newSelection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 关于应用
                _SectionHeader(title: '关于应用'),
                const SizedBox(height: 12),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.info_rounded, color: colorScheme.primary),
                        title: const Text('应用信息'),
                        subtitle: Text('版本 $_appVersion • 构建于 $_buildDate'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _showAppInfoDialog,
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: Icon(Icons.cloud_sync_rounded, color: colorScheme.primary),
                        title: const Text('GitHub镜像源'),
                        subtitle: const Text('选择更新检查使用的镜像'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _showMirrorSelectionDialog,
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: Icon(Icons.system_update_rounded, color: colorScheme.primary),
                        title: const Text('检查更新'),
                        subtitle: const Text('查找新版本'),
                        trailing: _isCheckingUpdate
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.chevron_right_rounded),
                        onTap: _isCheckingUpdate ? null : _checkForUpdates,
                      ),
                      const Divider(height: 1, indent: 72),
                      ListTile(
                        leading: Icon(Icons.gavel_rounded, color: colorScheme.primary),
                        title: const Text('开源许可'),
                        subtitle: const Text('查看第三方开源许可证'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const OpenSourceLicensesScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // 支持作者
                _SectionHeader(title: '支持作者'),
                const SizedBox(height: 12),
                Card(
                  color: colorScheme.secondaryContainer,
                  child: InkWell(
                    onTap: () => _showPaymentSheet(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.favorite_rounded,
                              color: colorScheme.onPrimaryContainer,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '请我喝杯咖啡 ☕',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '如果您觉得这个应用对您有帮助',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.arrow_forward_rounded,
                            color: colorScheme.onSecondaryContainer,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // 退出登录按钮
                FilledButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('退出登录'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                ),
                const SizedBox(height: 16),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _logout(BuildContext context) async {
    final confirmed = await showConfirmBottomSheet(
      context: context,
      title: '确认退出',
      message: '确定要退出登录吗？',
      icon: Icons.logout_rounded,
      isDangerous: true,
      confirmText: '退出',
      cancelText: '取消',
    );

    if (confirmed == true && context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      await authProvider.logout();
      
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  void _showPaymentSheet(BuildContext context) {
    showPaymentSheetLegacy(context);
  }
}

/// 区段标题
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 20),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// 用户信息卡片
class _UserInfoCard extends StatelessWidget {
  final dynamic user;
  final VoidCallback? onTap;

  const _UserInfoCard({this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Hero(
                tag: 'user_avatar',
                child: CircleAvatar(
                  radius: 36,
                  backgroundColor: colorScheme.primaryContainer,
                  backgroundImage: user?.avatar != null && user!.avatar!.isNotEmpty
                      ? NetworkImage(user!.avatar!)
                      : null,
                  child: user?.avatar == null || user!.avatar!.isEmpty
                      ? Icon(
                          Icons.person_rounded,
                          size: 40,
                          color: colorScheme.onPrimaryContainer,
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.username ?? '未登录',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.phone_android_rounded,
                          size: 16,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          user?.phone ?? '',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 信息行
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
