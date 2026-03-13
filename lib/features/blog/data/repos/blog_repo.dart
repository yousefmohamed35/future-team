import 'dart:developer';

import 'package:future_app/core/database/app_cache_database.dart';
import 'package:future_app/core/network/api_constants.dart';
import 'package:future_app/core/network/api_error_handel.dart';
import 'package:future_app/core/network/api_result.dart';
import 'package:future_app/core/network/api_service.dart';
import 'package:future_app/features/blog/data/models/blog_model.dart';

class BlogRepo {
  final ApiService _apiService;
  BlogRepo(this._apiService);

  // Get posts with pagination
  Future<ApiResult<GetPostsResponseModel>> getPosts({
    required int page,
    required int limit,
    String? categoryId,
  }) async {
    try {
      log('🌐 BlogRepo: Calling getPosts API - page: $page, limit: $limit');
      final response = await _apiService.getPosts(
        ApiConstants.apiKey,
        ApiConstants.appSource,
        page,
        limit,
        categoryId,
      );
      log('✅ BlogRepo: Get posts API success - ${response.data.length} posts');
      try {
        final key = 'posts_${page}_${limit}_${categoryId ?? "all"}';
        await AppCacheDatabase.instance.putEndpoint(key, response.toJson());
      } catch (_) {}
      return ApiResult.success(response);
    } catch (e) {
      log('❌ BlogRepo: Get posts API error: ${e.toString()}');
      try {
        final key = 'posts_${page}_${limit}_${categoryId ?? "all"}';
        final cached = await AppCacheDatabase.instance.getEndpoint(key);
        if (cached != null) {
          return ApiResult.success(GetPostsResponseModel.fromJson(cached));
        }
      } catch (_) {}
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // Get post categories
  Future<ApiResult<GetPostCategoriesResponseModel>> getPostCategories() async {
    try {
      log('🌐 BlogRepo: Calling getPostCategories API');
      final response = await _apiService.getPostCategories(
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      log('✅ BlogRepo: Get post categories API success - ${response.data.length} categories');
      try {
        await AppCacheDatabase.instance
            .putEndpoint('post_categories', response.toJson());
      } catch (_) {}
      return ApiResult.success(response);
    } catch (e) {
      log('❌ BlogRepo: Get post categories API error: ${e.toString()}');
      try {
        final cached =
            await AppCacheDatabase.instance.getEndpoint('post_categories');
        if (cached != null) {
          return ApiResult.success(
              GetPostCategoriesResponseModel.fromJson(cached));
        }
      } catch (_) {}
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // Get post details by ID
  Future<ApiResult<GetPostDetailsResponseModel>> getPostDetails(
      String postId) async {
    try {
      log('🌐 BlogRepo: Calling getPostDetails API for postId: $postId');
      final response = await _apiService.getPostDetails(
        postId,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      log('✅ BlogRepo: Get post details API success');
      try {
        await AppCacheDatabase.instance
            .putEndpoint('post_details_$postId', response.toJson());
      } catch (_) {}
      return ApiResult.success(response);
    } catch (e) {
      log('❌ BlogRepo: Get post details API error: ${e.toString()}');
      try {
        final cached =
            await AppCacheDatabase.instance.getEndpoint('post_details_$postId');
        if (cached != null) {
          return ApiResult.success(
              GetPostDetailsResponseModel.fromJson(cached));
        }
      } catch (_) {}
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }
}
