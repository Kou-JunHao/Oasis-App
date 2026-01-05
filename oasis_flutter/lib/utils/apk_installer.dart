import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// APK下载和安装管理器
class ApkInstaller {
  static const MethodChannel _channel = MethodChannel('uno.skkk.oasis/apk_installer');
  /// 下载APK文件
  /// [url] 下载链接
  /// [onProgress] 进度回调 (已下载字节, 总字节)
  /// [onComplete] 完成回调 (文件路径)
  /// [onError] 错误回调
  static Future<String?> downloadApk(
    String url, {
    Function(int received, int total)? onProgress,
    Function(String filePath)? onComplete,
    Function(String error)? onError,
  }) async {
    try {
      if (kDebugMode) {
        print('开始下载APK: $url');
      }

      // 检查存储权限
      final hasPermission = await _requestStoragePermission();
      if (!hasPermission) {
        final error = '需要存储权限才能下载更新';
        onError?.call(error);
        return null;
      }

      // 获取公共下载目录 /storage/emulated/0/Download/Oasis
      final downloadDir = await _getPublicDownloadDirectory();
      if (downloadDir == null) {
        final error = '无法访问Download目录';
        onError?.call(error);
        return null;
      }

      // 文件名
      final fileName = 'oasis_update_${DateTime.now().millisecondsSinceEpoch}.apk';
      final filePath = '${downloadDir.path}/$fileName';

      if (kDebugMode) {
        print('下载路径: $filePath');
      }

      // 开始下载
      final request = http.Request('GET', Uri.parse(url));
      final response = await request.send();

      if (response.statusCode != 200) {
        final error = '下载失败: HTTP ${response.statusCode}';
        onError?.call(error);
        return null;
      }

      final totalBytes = response.contentLength ?? 0;
      var receivedBytes = 0;

      final file = File(filePath);
      final sink = file.openWrite();

      await for (final chunk in response.stream) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        
        if (totalBytes > 0) {
          onProgress?.call(receivedBytes, totalBytes);
        }

        if (kDebugMode && receivedBytes % (1024 * 1024) == 0) {
          print('已下载: ${(receivedBytes / (1024 * 1024)).toStringAsFixed(1)} MB');
        }
      }

      await sink.close();

      if (kDebugMode) {
        print('下载完成: $filePath');
      }

      onComplete?.call(filePath);
      return filePath;
    } catch (e) {
      if (kDebugMode) {
        print('下载APK时发生错误: $e');
      }
      onError?.call(e.toString());
      return null;
    }
  }

  /// 安装APK文件
  /// [filePath] APK文件路径
  static Future<bool> installApk(String filePath) async {
    try {
      if (kDebugMode) {
        print('开始安装APK: $filePath');
      }

      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        if (kDebugMode) {
          print('APK文件不存在: $filePath');
        }
        return false;
      }

      // 检查安装权限
      if (Platform.isAndroid) {
        final hasPermission = await _requestInstallPermission();
        if (!hasPermission) {
          if (kDebugMode) {
            print('缺少安装权限');
          }
          return false;
        }
      }

      // 使用平台通道安装APK
      try {
        final result = await _channel.invokeMethod('installApk', {'filePath': filePath});
        if (kDebugMode) {
          print('安装结果: $result');
        }
        return result == true;
      } catch (e) {
        if (kDebugMode) {
          print('调用平台方法失败: $e');
        }
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        print('安装APK时发生错误: $e');
      }
      return false;
    }
  }

  /// 获取Android版本号
  static Future<int> _getAndroidVersion() async {
    try {
      if (Platform.isAndroid) {
        // 默认返回较新版本，确保请求必要权限
        return 13;
      }
      return 0;
    } catch (e) {
      return 13;
    }
  }

  /// 获取公共Download目录下的Oasis文件夹
  /// 返回 /storage/emulated/0/Download/Oasis
  static Future<Directory?> _getPublicDownloadDirectory() async {
    try {
      if (Platform.isAndroid) {
        // Android 10+ 使用分区存储，优先使用公共Download目录
        // 路径：/storage/emulated/0/Download/Oasis
        final publicDownload = Directory('/storage/emulated/0/Download/Oasis');
        
        if (kDebugMode) {
          print('尝试创建目录: ${publicDownload.path}');
        }
        
        // 创建Oasis文件夹（如果不存在）
        if (!await publicDownload.exists()) {
          await publicDownload.create(recursive: true);
          if (kDebugMode) {
            print('已创建Oasis文件夹: ${publicDownload.path}');
          }
        }
        
        return publicDownload;
      }
      
      // 非Android平台fallback
      final directory = await getExternalStorageDirectory();
      if (directory != null) {
        final downloadDir = Directory('${directory.path}/Download/Oasis');
        if (!await downloadDir.exists()) {
          await downloadDir.create(recursive: true);
        }
        return downloadDir;
      }
      
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('获取公共Download目录失败: $e');
      }
      
      // Fallback: 使用应用私有目录
      try {
        final directory = await getExternalStorageDirectory();
        if (directory != null) {
          final downloadDir = Directory('${directory.path}/Download/Oasis');
          if (!await downloadDir.exists()) {
            await downloadDir.create(recursive: true);
          }
          return downloadDir;
        }
      } catch (fallbackError) {
        if (kDebugMode) {
          print('Fallback也失败: $fallbackError');
        }
      }
      
      return null;
    }
  }

  /// 请求存储权限
  static Future<bool> _requestStoragePermission() async {
    try {
      if (Platform.isAndroid) {
        // Android 13+ 不再需要存储权限来访问应用特定目录
        final androidVersion = await _getAndroidVersion();
        if (androidVersion >= 13) {
          return true;
        }

        // Android 10-12
        if (androidVersion >= 10) {
          // 使用应用特定目录，不需要权限
          return true;
        }

        // Android 9及以下需要存储权限
        final status = await Permission.storage.request();
        return status.isGranted;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('请求存储权限失败: $e');
      }
      return false;
    }
  }

  /// 请求安装权限
  static Future<bool> _requestInstallPermission() async {
    try {
      if (Platform.isAndroid) {
        final androidVersion = await _getAndroidVersion();
        
        // Android 8.0+ 需要REQUEST_INSTALL_PACKAGES权限
        if (androidVersion >= 8) {
          final status = await Permission.requestInstallPackages.request();
          
          if (!status.isGranted) {
            if (kDebugMode) {
              print('用户拒绝了安装权限');
            }
            // 打开设置页面让用户手动授权
            await openAppSettings();
            return false;
          }
          
          return status.isGranted;
        }
        
        // Android 7.0及以下直接返回true
        return true;
      }
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('请求安装权限失败: $e');
      }
      return false;
    }
  }

  /// 取消下载（可选实现）
  static void cancelDownload() {
    // TODO: 实现取消下载逻辑
    if (kDebugMode) {
      print('取消下载');
    }
  }
}
