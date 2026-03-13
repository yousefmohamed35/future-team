import 'dart:developer';

import 'package:future_app/core/database/app_cache_database.dart';
import 'package:future_app/core/helper/shared_pref_keys.dart';
import 'package:future_app/core/network/api_constants.dart';
import 'package:future_app/core/network/api_error_handel.dart';
import 'package:future_app/core/network/api_result.dart';
import 'package:future_app/core/network/api_service.dart';
import 'package:future_app/features/notifications/data/models/notifications_model.dart';

class NotificationsRepo {
  final ApiService _apiService;
  NotificationsRepo(this._apiService);

  // Get user notifications
  Future<ApiResult<GetNotificationsResponseModel>> getUserNotifications(
      String userId) async {
    try {
      log('🌐 NotificationsRepo: Calling getUserNotifications API for userId: $userId');
      final response = await _apiService.getUserNotifications(
        UserConstant.userId!,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      log('✅ NotificationsRepo: Get notifications API success - ${response.data.notifications.length} notifications');
      try {
        await AppCacheDatabase.instance
            .putEndpoint('notifications_$userId', response.toJson());
      } catch (_) {}
      return ApiResult.success(response);
    } catch (e) {
      log('❌ NotificationsRepo: Get notifications API error: ${e.toString()}');
      try {
        final cached = await AppCacheDatabase.instance
            .getEndpoint('notifications_$userId');
        if (cached != null) {
          return ApiResult.success(
              GetNotificationsResponseModel.fromJson(cached));
        }
      } catch (_) {}
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // Mark notification as read
  Future<ApiResult> markNotificationAsRead(String notificationId) async {
    try {
      log('🌐 NotificationsRepo: Calling markNotificationAsRead API for notificationId: $notificationId');
      await _apiService.markNotificationAsRead(
        notificationId,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      log('✅ NotificationsRepo: Mark notification as read API success');
      return const ApiResult.success(null);
    } catch (e) {
      log('❌ NotificationsRepo: Mark notification as read API error: ${e.toString()}');
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // Delete notification
  Future<ApiResult<DeleteNotificationResponseModel>> deleteNotification(
      String notificationId) async {
    try {
      log('🌐 NotificationsRepo: Calling deleteNotification API for notificationId: $notificationId');
      final response = await _apiService.deleteNotification(
        notificationId,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      log('✅ NotificationsRepo: Delete notification API success');
      return ApiResult.success(response);
    } catch (e) {
      log('❌ NotificationsRepo: Delete notification API error: ${e.toString()}');
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }
}
