import 'dart:developer';

import 'package:future_app/core/database/app_cache_database.dart';
import 'package:future_app/core/models/banner_model.dart';
import 'package:future_app/core/network/api_constants.dart';
import 'package:future_app/core/network/api_error_handel.dart';
import 'package:future_app/core/network/api_result.dart';
import 'package:future_app/core/network/api_service.dart';
import 'package:future_app/features/courses/data/models/courses_model.dart';

class CoursesRepo {
  final ApiService _apiService;
  CoursesRepo(this._apiService);

  // get courses with pagination
  /// [filtersLevels] optional - filter by grade (e.g. 44=الفرقة الأولى, 52=الثانية, 59=الثالثة, 65=الرابعة)
  Future<ApiResult<GetCoursesResponseModel>> getCourses({
    required int page,
    required int limit,
    int? categoryId,
    int? filtersLevels,
  }) async {
    try {
      final response = await _apiService.getCourses(
        ApiConstants.apiKey,
        ApiConstants.appSource,
        page,
        limit,
        categoryId,
        filtersLevels,
      );

      log('✅ Courses API success: message=${response.message}, coursesCount=${response.data.length}, totalItems=${response.pagination.totalItems}');

      // Cache latest courses for offline mode
      try {
        await AppCacheDatabase.instance.upsertCourses(response.data);
      } catch (cacheError) {
        log('⚠️ Failed to cache courses: $cacheError');
      }

      return ApiResult.success(response);
    } catch (e) {
      log('❌ CoursesRepo.getCourses error: $e');

      // Try to serve cached data when API fails (offline mode)
      try {
        final cachedCourses = await AppCacheDatabase.instance
            .getCachedCourses(filtersLevels: filtersLevels);

        if (cachedCourses.isNotEmpty) {
          log('📦 Returning ${cachedCourses.length} cached courses due to API error.');

          final pagination = PaginationData(
            currentPage: 1,
            perPage: cachedCourses.length,
            totalItems: cachedCourses.length,
            totalPages: 1,
          );

          final cachedResponse = GetCoursesResponseModel(
            success: true,
            message: 'Loaded from offline cache',
            data: cachedCourses,
            pagination: pagination,
          );

          return ApiResult.success(cachedResponse);
        }
      } catch (cacheError) {
        log('⚠️ Failed to load cached courses: $cacheError');
      }

      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // get banners
  Future<ApiResult<BannerResponseModel>> getBanners() async {
    try {
      log('🌐 CoursesRepo: Calling getBanners API...');
      final response = await _apiService.getBanners(
        ApiConstants.apiKey,
        ApiConstants.appSource,
        'courses',
      );
      log('✅ CoursesRepo: Banner API success - ${response.data.banners.length} banners');
      log('Banner URLs: ${response.data.banners}');

      // Cache banners for offline mode
      try {
        await AppCacheDatabase.instance
            .upsertBanners('courses', response.data.banners);
      } catch (cacheError) {
        log('⚠️ Failed to cache banners: $cacheError');
      }

      return ApiResult.success(response);
    } catch (e) {
      log('❌ CoursesRepo: Banner API error: ${e.toString()}');

      // Try to serve cached banners when API fails (offline mode)
      try {
        final cachedBanners =
            await AppCacheDatabase.instance.getCachedBanners('courses');
        if (cachedBanners.isNotEmpty) {
          log('📦 Returning ${cachedBanners.length} cached banners due to API error.');

          final cachedResponse = BannerResponseModel(
            success: true,
            message: 'Loaded banners from offline cache',
            data: BannerResponseData(banners: cachedBanners),
          );

          return ApiResult.success(cachedResponse);
        }
      } catch (cacheError) {
        log('⚠️ Failed to load cached banners: $cacheError');
      }

      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // get single course by ID (cached for offline)
  Future<ApiResult<GetSingleCourseResponseModel>> getSingleCourse(
      String courseId) async {
    try {
      log('🌐 CoursesRepo: Calling getSingleCourse API for ID: $courseId');
      final response = await _apiService.getSingleCourse(
        courseId,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      log('✅ CoursesRepo: Single course API success - ${response.data.title}');

      // Cache for offline mode
      try {
        await AppCacheDatabase.instance.putEndpoint(
          'course_detail_$courseId',
          response.toJson(),
        );
      } catch (cacheError) {
        log('⚠️ Failed to cache single course: $cacheError');
      }

      return ApiResult.success(response);
    } catch (e) {
      log('❌ CoursesRepo: Single course API error: ${e.toString()}');

      // Try offline cache
      try {
        final cached = await AppCacheDatabase.instance
            .getEndpoint('course_detail_$courseId');
        if (cached != null && cached.isNotEmpty) {
          log('📦 Returning cached single course for ID: $courseId');
          final model = GetSingleCourseResponseModel.fromJson(cached);
          return ApiResult.success(GetSingleCourseResponseModel(
            success: true,
            message: 'Loaded from offline cache',
            data: model.data,
          ));
        }
      } catch (cacheError) {
        log('⚠️ Failed to load cached single course: $cacheError');
      }

      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // get course content (lectures) – cached for offline
  Future<ApiResult<GetCourseContentResponseModel>> getCourseContent(
      String courseId) async {
    try {
      log('🌐 CoursesRepo: Calling getCourseContent API for ID: $courseId');
      final response = await _apiService.getCourseContent(
        courseId,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      log('✅ CoursesRepo: Course content API success - ${response.data.lectures.length} lectures');

      // Cache for offline mode
      try {
        await AppCacheDatabase.instance.putEndpoint(
          'course_content_$courseId',
          response.toJson(),
        );
      } catch (cacheError) {
        log('⚠️ Failed to cache course content: $cacheError');
      }

      return ApiResult.success(response);
    } catch (e) {
      log('❌ CoursesRepo: Course content API error: ${e.toString()}');

      // Try offline cache
      try {
        final cached = await AppCacheDatabase.instance
            .getEndpoint('course_content_$courseId');
        if (cached != null && cached.isNotEmpty) {
          log('📦 Returning cached course content for ID: $courseId');
          final model = GetCourseContentResponseModel.fromJson(cached);
          return ApiResult.success(GetCourseContentResponseModel(
            success: true,
            message: 'Loaded from offline cache',
            data: model.data,
          ));
        }
      } catch (cacheError) {
        log('⚠️ Failed to load cached course content: $cacheError');
      }

      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }
}
