import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:future_app/features/downloads/data/repository/download_repository.dart';
import 'package:future_app/features/downloads/data/service/download_service.dart';
import 'package:future_app/features/downloads/logic/cubit/download_state.dart';

class DownloadCubit extends Cubit<DownloadState> {
  final DownloadRepository _downloadRepository;
  final DownloadService _downloadService;
  Timer? _progressTimer;

  DownloadCubit(this._downloadRepository, this._downloadService)
      : super(DownloadInitial());

  /// Call from downloads page when visible – polls progress every second.
  void startProgressPolling() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      final current = state;
      if (current is! GetDownloadedVideosSuccess) return;
      final raw = await _downloadService.getActiveDownloadTasks();
      final active = raw
          .map((m) => ActiveDownloadInfo(
                taskId: m['taskId'] as String,
                progress: m['progress'] as int? ?? 0,
                title: m['title'] as String? ?? 'جاري التحميل',
              ))
          .toList();
      final hadActive = current.activeDownloads.isNotEmpty;
      final hasActive = active.isNotEmpty;
      if (hadActive && !hasActive) {
        // All downloads finished – refresh list
        stopProgressPolling();
        await getDownloadedVideosWithManager();
        return;
      }
      if (active.length != current.activeDownloads.length ||
          active.asMap().entries.any((e) =>
              current.activeDownloads.length <= e.key ||
              current.activeDownloads[e.key].progress != e.value.progress)) {
        emit(GetDownloadedVideosSuccess(current.videos,
            activeDownloads: active));
      }
    });
  }

  void stopProgressPolling() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }

  @override
  Future<void> close() {
    stopProgressPolling();
    return super.close();
  }

  Future<void> downloadLesson(String lessonId) async {
    emit(DownloadLoading());
    try {
      // Check storage permission - if denied, we still proceed (app directory needs no permission)
      final hasPermission = await _downloadService.hasStoragePermission();
      if (!hasPermission) {
        await _downloadService.requestPermission();
      }

      // Get download info from API
      final response = await _downloadRepository.downloadLesson(lessonId);

      print('Download response received: ${response.success}');
      print('Download data: ${response.data.toJson()}');

      if (!response.data.downloadable) {
        emit(DownloadError('هذا الفيديو غير متاح للتحميل'));
        return;
      }

      // Check if already downloaded
      final isDownloaded = await _downloadService.isVideoDownloaded(lessonId);
      if (isDownloaded) {
        emit(DownloadError('تم تحميل هذا الفيديو مسبقاً'));
        return;
      }

      // Start actual download using API response data
      final taskId =
          await _downloadService.downloadVideoFromApiResponse(response.data);

      if (taskId != null) {
        emit(DownloadSuccess(response));
      } else {
        emit(DownloadError('فشل في بدء التحميل'));
      }
    } catch (e) {
      print('Download error: $e');
      String errorMessage = 'حدث خطأ أثناء التحميل';

      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = 'حدث خطأ أثناء التحميل: ${e.toString()}';
      }

      emit(DownloadError(errorMessage));
    }
  }

  Future<void> getDownloadedVideos() async {
    emit(GetDownloadedVideosLoading());
    try {
      print('Getting downloaded videos...');

      // Clean up failed downloads first
      await _downloadService.cleanupFailedDownloads();

      // This works offline - no network calls needed
      final videos = await _downloadService.getDownloadedVideos();
      print('Found ${videos.length} downloaded videos');

      for (final video in videos) {
        print('Video: ${video.title} - ${video.localPath}');
      }

      emit(GetDownloadedVideosSuccess(videos));
    } catch (e) {
      print('Error getting downloaded videos: $e');
      emit(GetDownloadedVideosError(
          'خطأ في تحميل قائمة الفيديوهات المحملة: $e'));
    }
  }

  Future<void> deleteDownloadedVideo(String taskId) async {
    try {
      emit(GetDownloadedVideosLoading()); // 👈 مهم

      await _downloadService.deleteDownloadedVideo(taskId);

      final videos = await _downloadService.getDownloadedVideosWithManager();

      emit(GetDownloadedVideosSuccess(videos));
    } catch (e) {
      emit(GetDownloadedVideosError('فشل في حذف الفيديو: $e'));
    }
  }

  Future<void> initializeDownloadService() async {
    try {
      await _downloadService.initialize();
      print('Download service initialized successfully');

      // Remove any existing sample videos
      await _downloadService.removeSampleVideos();
      print('Sample videos removed successfully');
    } catch (e) {
      print('Error initializing download service: $e');
      // Continue anyway, the service might still work
    }
  }

  // Check and request storage permissions
  Future<bool> checkStoragePermissions() async {
    try {
      final hasPermission = await _downloadService.hasStoragePermission();
      if (!hasPermission) {
        final granted = await _downloadService.requestPermission();
        return granted;
      }
      return true;
    } catch (e) {
      print('Error checking permissions: $e');
      return false;
    }
  }

  /// تحميل درس باستخدام flutter_downloader مع حفظ عنوان الكورس في قاعدة البيانات
  /// [courseTitle] هو عنوان الكورس (مثلاً "القانون الدولي (3)") ليتم حفظه في التحميلات
  Future<void> downloadLessonWithManager(
    String lessonId,
    String courseTitle,
  ) async {
    emit(DownloadLoading());
    try {
      // التحقق من الصلاحيات - إذا لم تُمنح، نتابع باستخدام مجلد التطبيق (لا يحتاج صلاحيات)
      final hasPermission = await _downloadService.hasStoragePermission();
      if (!hasPermission) {
        await _downloadService.requestPermission();
        // لا نمنع التحميل - التطبيق يحفظ في مجلد خاص لا يحتاج صلاحيات
      }

      // الحصول على معلومات التحميل من API
      final response = await _downloadRepository.downloadLesson(lessonId);

      print('Download response received: ${response.success}');
      print('Download data: ${response.data.toJson()}');

      if (!response.data.downloadable) {
        emit(DownloadError('هذا الفيديو غير متاح للتحميل'));
        return;
      }

      // التحقق من أن الفيديو لم يتم تحميله مسبقاً
      final isDownloaded = await _downloadService.isVideoDownloaded(lessonId);
      if (isDownloaded) {
        emit(DownloadError('تم تحميل هذا الفيديو مسبقاً'));
        return;
      }

      // بدء التحميل باستخدام DownloadManager (يعرض التقدم في الواجهة ويحفظ داخل التطبيق)
      final taskId =
          await _downloadService.downloadVideoFromApiResponseWithManager(
        response.data,
        courseTitle: courseTitle,
        onProgress: (progress) =>
            emit(DownloadInProgress(progress, message: 'جاري التحميل...')),
      );

      if (taskId != null) {
        emit(DownloadSuccess(response));
        // تحديث قائمة التحميلات بعد بدء التحميل
        await getDownloadedVideosWithManager();
      } else {
        emit(DownloadError('فشل في تحميل الفيديو'));
      }
    } catch (e) {
      print('Download error: $e');
      String errorMessage = 'حدث خطأ أثناء التحميل';

      if (e is Exception) {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
      } else {
        errorMessage = 'حدث خطأ أثناء التحميل: ${e.toString()}';
      }

      emit(DownloadError(errorMessage));
    }
  }

  /// الحصول على الفيديوهات المحملة باستخدام DownloadManager
  Future<void> getDownloadedVideosWithManager() async {
    emit(GetDownloadedVideosLoading());
    try {
      print('Getting downloaded videos with DownloadManager...');

      // يعمل بدون اتصال بالإنترنت
      final videos = await _downloadService.getDownloadedVideosWithManager();
      print('Found ${videos.length} downloaded videos');

      for (final video in videos) {
        print('Video: ${video.title} - ${video.localPath}');
      }

      emit(GetDownloadedVideosSuccess(videos));
    } catch (e) {
      print('Error getting downloaded videos: $e');
      emit(GetDownloadedVideosError(
          'خطأ في تحميل قائمة الفيديوهات المحملة: $e'));
    }
  }
}
