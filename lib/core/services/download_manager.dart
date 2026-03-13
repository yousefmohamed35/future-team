import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';

class DownloadManager {
  static List<FileSystemEntity> files = [];
  static final Dio _dio = Dio();

  /// تحميل فيديو أو ملف
  static Future<String?> download(
    String url, {
    required Function(int progress) onDownload,
    CancelToken? cancelToken,
    String? name,
    Function? onLoadAtLocal,
    bool isOpen = true,
    String? authToken,
  }) async {
    try {
      // التحقق من الصلاحيات أولاً (بدون طلب)
      bool hasPermission = false;

      if (Platform.isAndroid) {
        // مجلد التطبيق الخاص لا يحتاج صلاحيات على Android 13+
        // Android 12 وأقل: صلاحية التخزين التقليدية فقط (متوافق مع Google Play)
        final storageStatus = await Permission.storage.status;
        hasPermission = storageStatus.isGranted;

        if (!hasPermission) {
          debugPrint(
              '📱 Checking storage permission (Android 12 and below)...');
          final storageStatusAfter = await Permission.storage.request();
          hasPermission = storageStatusAfter.isGranted;
        }

        // نستخدم مجلد التطبيق الخاص دائماً - لا يحتاج صلاحيات على Android 13+
        if (!hasPermission) {
          debugPrint(
              '⚠️ No storage permission, using app directory (no permission needed on Android 13+)');
        } else {
          debugPrint('✅ Storage permission granted');
        }
      } else {
        // iOS لا يحتاج صلاحيات لمجلد التطبيق
        hasPermission = true;
      }

      // الحصول على مسار التخزين الداخلي للتطبيق (لا يحتاج صلاحيات)
      final supportDir = await getApplicationSupportDirectory();
      final downloadDir = Directory('${supportDir.path}/downloaded_videos');
      if (!await downloadDir.exists()) {
        await downloadDir.create(recursive: true);
      }
      String directory = downloadDir.path;
      String fileName = name ?? url.split('/').last;
      String fullPath = '$directory/$fileName';

      // التحقق من وجود الملف مسبقاً
      bool fileExists = await findFile(directory, fileName,
          onLoadAtLocal: onLoadAtLocal, isOpen: false);

      if (fileExists) {
        debugPrint('✅ File already exists: $fullPath');
        if (onLoadAtLocal != null) {
          onLoadAtLocal(fullPath);
        }
        return fullPath;
      }

      // تحميل الملف
      debugPrint('⬇️ Downloading file: $fileName...');

      Map<String, String> headers = {
        "Accept": "application/json",
      };

      if (authToken != null) {
        headers["Authorization"] = "Bearer $authToken";
      }

      try {
        Response response = await _dio.download(
          url,
          fullPath,
          onReceiveProgress: (count, total) {
            if (total != -1) {
              int progress = (count / total * 100).toInt();
              onDownload(progress);
              debugPrint('📥 Download progress: $progress%');
            }
          },
          cancelToken: cancelToken,
          options: Options(
            followRedirects: true,
            headers: headers,
            receiveTimeout: const Duration(minutes: 10),
            sendTimeout: const Duration(minutes: 10),
          ),
        );

        if (response.statusCode == 200) {
          debugPrint('✅ Download completed: $fullPath');
          return fullPath;
        } else {
          debugPrint('❌ Download failed with status: ${response.statusCode}');
          return null;
        }
      } on DioException catch (e) {
        debugPrint('❌ Download error: ${e.message}');
        // حذف الملف الجزئي في حالة الفشل
        File file = File(fullPath);
        if (await file.exists()) {
          await file.delete();
        }
        return null;
      }
    } catch (e) {
      debugPrint('❌ Unexpected error during download: $e');
      return null;
    }
  }

  /// البحث عن ملف في المجلد
  static Future<bool> findFile(
    String directory,
    String name, {
    Function? onLoadAtLocal,
    bool isOpen = true,
  }) async {
    try {
      files = Directory(directory).listSync().toList();

      for (var i = 0; i < files.length; i++) {
        if (files[i].path.contains(name)) {
          debugPrint('✅ File found: ${files[i].path}');

          if (onLoadAtLocal != null) {
            onLoadAtLocal(files[i].path);
          }

          return true;
        }
      }

      debugPrint('🚫 File not found: $name');
      return false;
    } catch (e) {
      debugPrint('❌ Error searching for file: $e');
      return false;
    }
  }

  /// الحصول على مسار ملف محمل
  static Future<String?> getLocalFilePath(String fileName) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final downloadDir = Directory('${supportDir.path}/downloaded_videos');
      if (!await downloadDir.exists()) return null;
      List<FileSystemEntity> files = downloadDir.listSync();

      for (var file in files) {
        if (file.path.contains(fileName)) {
          debugPrint('✅ Local file path: ${file.path}');
          return file.path;
        }
      }

      debugPrint('🚫 Local file not found: $fileName');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting local file path: $e');
      return null;
    }
  }

  /// حذف ملف محمل
  static Future<bool> deleteFile(String fileName) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      String fullPath = '${supportDir.path}/downloaded_videos/$fileName';

      File file = File(fullPath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ File deleted: $fullPath');
        return true;
      } else {
        debugPrint('🚫 File not found for deletion: $fullPath');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error deleting file: $e');
      return false;
    }
  }

  /// الحصول على حجم الملف بالـ MB
  static Future<double> getFileSize(String fileName) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      String fullPath = '${supportDir.path}/downloaded_videos/$fileName';

      File file = File(fullPath);
      if (await file.exists()) {
        int bytes = await file.length();
        double mb = bytes / (1024 * 1024);
        debugPrint('📊 File size: ${mb.toStringAsFixed(2)} MB');
        return mb;
      } else {
        return 0.0;
      }
    } catch (e) {
      debugPrint('❌ Error getting file size: $e');
      return 0.0;
    }
  }

  /// الحصول على قائمة بجميع الملفات المحملة
  static Future<List<FileSystemEntity>> getAllDownloadedFiles() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final downloadDir = Directory('${supportDir.path}/downloaded_videos');
      if (!await downloadDir.exists()) return [];
      List<FileSystemEntity> files = downloadDir.listSync();
      debugPrint('📁 Found ${files.length} downloaded files');
      return files;
    } catch (e) {
      debugPrint('❌ Error getting downloaded files: $e');
      return [];
    }
  }

  /// حذف جميع الملفات المحملة
  static Future<bool> deleteAllFiles() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final downloadDir = Directory('${supportDir.path}/downloaded_videos');
      if (!await downloadDir.exists()) return true;
      List<FileSystemEntity> files = downloadDir.listSync();

      for (var file in files) {
        if (file is File) {
          await file.delete();
        }
      }

      debugPrint('✅ All files deleted');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting all files: $e');
      return false;
    }
  }

  /// تحميل فيديو من رابط مباشر
  static Future<String?> downloadVideo(
    String url,
    String videoId,
    String videoTitle, {
    required Function(int progress) onProgress,
    String? authToken,
    CancelToken? cancelToken,
  }) async {
    // إنشاء اسم ملف فريد
    String fileName =
        'video_${videoId}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    return await download(
      url,
      name: fileName,
      onDownload: onProgress,
      authToken: authToken,
      cancelToken: cancelToken,
      isOpen: false,
    );
  }

  /// التحقق من توفر المساحة الكافية
  static Future<bool> hasEnoughSpace(int requiredBytes) async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // في الواقع يجب استخدام حزمة مثل disk_space للتحقق من المساحة المتاحة
        // هنا نفترض افتراضياً أن المساحة كافية
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('❌ Error checking space: $e');
      return true;
    }
  }
}
