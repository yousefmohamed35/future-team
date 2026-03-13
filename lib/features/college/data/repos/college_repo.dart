import 'dart:developer';

import 'package:future_app/core/database/app_cache_database.dart';
import 'package:future_app/core/models/banner_model.dart';
import 'package:future_app/core/network/api_constants.dart';
import 'package:future_app/core/network/api_error_handel.dart';
import 'package:future_app/core/network/api_result.dart';
import 'package:future_app/core/network/api_service.dart';
import 'package:future_app/features/courses/data/models/courses_model.dart';

class CollegeRepo {
  final ApiService _apiService;
  CollegeRepo(this._apiService);

  // Get college banners
  Future<ApiResult<BannerResponseModel>> getBanners() async {
    try {
      log('🌐 CollegeRepo: Calling getBanners API');
      final response = await _apiService.getBanners(
        ApiConstants.apiKey,
        ApiConstants.appSource,
        'college',
      );
      try {
        await AppCacheDatabase.instance
            .upsertBanners('college', response.data.banners);
      } catch (_) {}
      return ApiResult.success(response);
    } catch (e) {
      log('❌ CollegeRepo: Get banners API error: ${e.toString()}');
      try {
        final cached =
            await AppCacheDatabase.instance.getCachedBanners('college');
        if (cached.isNotEmpty) {
          return ApiResult.success(BannerResponseModel(
            success: true,
            message: 'Loaded from offline cache',
            data: BannerResponseData(banners: cached),
          ));
        }
      } catch (_) {}
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // Get college courses by category (1=future, 2=books, 3=tables)
  Future<ApiResult<GetCoursesResponseModel>> getCourses({
    int? categoryId,
    int? filtersLevels,
    int page = 1,
    int limit = 100,
  }) async {
    try {
      log('🌐 CollegeRepo: Calling getCourses API - category: $categoryId');
      final response = await _apiService.getCourses(
        ApiConstants.apiKey,
        ApiConstants.appSource,
        page,
        limit,
        categoryId,
        filtersLevels,
      );
      log('✅ CollegeRepo: Get courses API success - ${response.data.length} courses');
      try {
        await AppCacheDatabase.instance.upsertCourses(response.data);
      } catch (_) {}
      return ApiResult.success(response);
    } catch (e) {
      log('❌ CollegeRepo: Get courses API error: ${e.toString()}');
      try {
        final cached = await AppCacheDatabase.instance
            .getCachedCourses(filtersLevels: filtersLevels);
        if (cached.isNotEmpty) {
          final pagination = PaginationData(
            currentPage: 1,
            perPage: cached.length,
            totalItems: cached.length,
            totalPages: 1,
          );
          return ApiResult.success(GetCoursesResponseModel(
            success: true,
            message: 'Loaded from offline cache',
            data: cached,
            pagination: pagination,
          ));
        }
      } catch (_) {}
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }
}
