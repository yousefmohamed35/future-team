import 'dart:io';

import 'package:dio/dio.dart';
import 'package:future_app/core/network/api_constants.dart';
import 'package:future_app/core/network/api_error_handel.dart';
import 'package:future_app/core/network/api_error_model.dart';
import 'package:future_app/core/network/api_result.dart';
import 'package:future_app/features/auth/data/models/login_request_model.dart';
import 'package:future_app/features/auth/data/models/login_response_model.dart';
import 'package:future_app/features/auth/data/models/register_request_model.dart';
import 'package:future_app/features/auth/data/models/register_response_model.dart';
import 'package:future_app/features/auth/data/models/register_step2_request_model.dart';
import 'package:future_app/features/auth/data/models/register_step2_response_model.dart';
import 'package:path/path.dart' as p;

import '../../../../core/network/api_service.dart';
import 'dart:developer';

class AuthRepo {
  final ApiService _apiService;
  AuthRepo(this._apiService);

  // login
  Future<ApiResult<LoginResponseModel>> login(LoginRequestModel request) async {
    try {
      final response = await _apiService.login(
        request,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );

      // Check if login was unsuccessful
      if (!response.success) {
        // Create error model from the response with the Arabic message
        return ApiResult.failure(
          ApiErrorModel(
            success: response.success,
            message: response.message,
            errors: null,
          ),
        );
      }

      return ApiResult.success(response);
    } on DioException catch (e) {
      // Handle DioException - might be a parsing error or network error
      log(e.toString());

      // If it's a bad response, try to extract error message from response data
      if (e.type == DioExceptionType.badResponse && e.response?.data != null) {
        final responseData = e.response!.data;
        if (responseData is Map<String, dynamic>) {
          // Check if this is a success: false response
          if (responseData['success'] == false) {
            final message = responseData['message'] ?? 'حدث خطأ غير متوقع';
            return ApiResult.failure(
              ApiErrorModel(
                success: false,
                message: message.toString(),
                errors: null,
              ),
            );
          }
        }
      }

      return ApiResult.failure(ApiErrorHandler.handle(e));
    } catch (e) {
      // Handle other exceptions (like parsing errors)
      log(e.toString());

      // If it's a parsing error, the original response might be in the exception
      // Try to extract it if possible
      if (e is DioException && e.response?.data != null) {
        final responseData = e.response!.data;
        if (responseData is Map<String, dynamic> &&
            responseData['success'] == false) {
          final message = responseData['message'] ?? 'حدث خطأ غير متوقع';
          return ApiResult.failure(
            ApiErrorModel(
              success: false,
              message: message.toString(),
              errors: null,
            ),
          );
        }
      }

      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // logout
  Future<ApiResult<void>> logout() async {
    try {
      final response = await _apiService.logout(
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      return ApiResult.success(response);
    } catch (e) {
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // register step 1 – avatar is required (multipart, matches backend get_file_params()['avatar'])
  Future<ApiResult<RegisterResponseModel>> registerStep1(
    RegisterRequestModel request, {
    required File avatarFile,
  }) async {
    try {
      const maxSize = 158 * 1024 * 1024; // 158 MB
      final length = await avatarFile.length();
      if (length > maxSize) {
        return ApiResult.failure(ApiErrorModel(
          success: false,
          message: 'حجم صورة الملف الشخصي كبير جداً (الحد الأقصى 158 ميجا)',
          errors: null,
        ));
      }

      final fileName = p.basename(avatarFile.path);
      if (fileName.isEmpty) {
        return ApiResult.failure(ApiErrorModel(
          success: false,
          message: 'اسم ملف الصورة غير صحيح',
          errors: null,
        ));
      }

      final formData = FormData.fromMap({
        ...request.toJson(),
        'avatar': await MultipartFile.fromFile(
          avatarFile.path,
          filename: fileName,
        ),
      });

      final response = await _apiService.registerStep1WithImage(
        formData,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      return ApiResult.success(response);
    } on DioException catch (e) {
      log(e.toString());
      if (e.type == DioExceptionType.badResponse && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map<String, dynamic> && data['success'] == false) {
          final message = data['message']?.toString() ?? 'فشل التسجيل';
          return ApiResult.failure(ApiErrorModel(
            success: false,
            message: message,
            errors: null,
          ));
        }
      }
      return ApiResult.failure(ApiErrorHandler.handle(e));
    } catch (e) {
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }

  // register step 2
  Future<ApiResult<RegisterStep2ResponseModel>> registerStep2(
      RegisterStep2RequestModel request) async {
    try {
      final response = await _apiService.registerStep2(
        request,
        ApiConstants.apiKey,
        ApiConstants.appSource,
      );
      return ApiResult.success(response);
    } catch (e) {
      return ApiResult.failure(ApiErrorHandler.handle(e));
    }
  }
}
