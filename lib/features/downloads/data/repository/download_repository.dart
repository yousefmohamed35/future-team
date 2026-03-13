import 'package:dio/dio.dart';
import 'package:future_app/core/network/api_service.dart';
import 'package:future_app/core/network/api_constants.dart';
import 'package:future_app/core/models/download_model.dart';

abstract class DownloadRepository {
  Future<DownloadResponseModel> downloadLesson(String lessonId);
}

class DownloadRepositoryImpl implements DownloadRepository {
  final ApiService _apiService;

  DownloadRepositoryImpl(this._apiService);

  /// Set to true to bypass API and use mock data for download testing
  /// Note: YouTube links don't work for direct download (need .mp4 URL)
  static const bool _useTestData = false;

  @override
  Future<DownloadResponseModel> downloadLesson(String lessonId) async {
    // Bypass API for download testing
    if (_useTestData) {
      print(
          '⚠️ TEST MODE: Bypassing download API, using mock data for lesson: $lessonId');
      return DownloadResponseModel(
        success: true,
        message: 'Test mode - bypassing API',
        data: DownloadData(
          lessonId: lessonId,
          courseId: '38',
          title: 'محاضرة تجريبية',
          description: '<p>فيديو للاختبار</p>',
          videoUrl:
              'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          fileSize: 23684943,
          fileSizeMb: 22.59,
          fileType: 'video/mp4',
          duration: 126,
          durationText: '2 دقيقة',
          downloadable: true,
          videoSource: 'server',
          downloadNote: 'هذا الفيديو متاح للتحميل والمشاهدة أوفلاين.',
        ),
      );
    }

    try {
      print('Downloading lesson with ID: $lessonId');
      final response = await _apiService.downloadLesson(
        lessonId,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      print('Download API response received successfully');
      return response;
    } catch (e) {
      print('Download API error: $e');
      // Check if it's a DioException with specific error message
      if (e is DioException) {
        String errorMessage = 'حدث خطأ أثناء التحميل';

        if (e.response?.data != null) {
          final responseData = e.response!.data;
          if (responseData is Map<String, dynamic>) {
            final message = responseData['message'] ??
                responseData['error'] ??
                responseData['error_message'];
            if (message != null && message.toString().isNotEmpty) {
              errorMessage = message.toString();
            }
          }
        }

        throw Exception(errorMessage);
      }
      rethrow;
    }
  }
}
