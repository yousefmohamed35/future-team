import 'dart:developer';

import 'package:future_app/core/database/app_cache_database.dart';
import 'package:future_app/core/models/banner_model.dart';
import 'package:future_app/core/network/api_constants.dart';
import 'package:future_app/core/network/api_error_handel.dart';
import 'package:future_app/core/network/api_result.dart';
import 'package:future_app/core/network/api_service.dart';

class HomeRepo {
  final ApiService _apiService;
  HomeRepo(this._apiService);

  // get banners
  Future<ApiResult<BannerResponseModel>> getBanners() async {
    try {
      final response = await _apiService.getBanners(
        ApiConstants.apiKey,
        ApiConstants.appSource,
        'home',
      );
      try {
        await AppCacheDatabase.instance
            .upsertBanners('home', response.data.banners);
      } catch (_) {}
      return ApiResult.success(response);
    } catch (e) {
      log(e.toString());
      try {
        final cached = await AppCacheDatabase.instance.getCachedBanners('home');
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
}
