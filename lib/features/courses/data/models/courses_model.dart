import 'package:json_annotation/json_annotation.dart';
import 'package:future_app/core/models/lecture_model.dart';
import 'dart:developer' as dev;

part 'courses_model.g.dart';

// Main Response Model – supports both formats: (data + pagination) OR (courses + total_courses)
@JsonSerializable()
class GetCoursesResponseModel {
  @JsonKey(name: 'success')
  final bool success;

  @JsonKey(name: 'message')
  final String message;

  @JsonKey(name: 'data')
  final List<CourseModel> data;

  @JsonKey(name: 'pagination')
  final PaginationData pagination;

  GetCoursesResponseModel({
    required this.success,
    required this.message,
    required this.data,
    required this.pagination,
  });

  /// Supports both API formats: [data] + [pagination] OR [courses] + [total_courses].
  factory GetCoursesResponseModel.fromJson(Map<String, dynamic> json) {
    dev.log('Courses API raw response: $json');
    final listRaw = json['courses'] ?? json['data'];
    final List<CourseModel> data = listRaw == null
        ? []
        : (listRaw as List<dynamic>)
            .map((e) => CourseModel.fromJson(e as Map<String, dynamic>))
            .toList();
    final PaginationData pagination;
    if (json['pagination'] != null) {
      pagination =
          PaginationData.fromJson(json['pagination'] as Map<String, dynamic>);
    } else {
      final totalItems =
          (json['total_courses'] as num?)?.toInt() ?? data.length;
      pagination = PaginationData(
        currentPage: 1,
        perPage: data.isEmpty ? 10 : data.length,
        totalItems: totalItems,
        totalPages: totalItems > 0 ? 1 : 1,
      );
    }
    return GetCoursesResponseModel(
      success: json['success'] as bool? ?? true,
      message: json['message'] as String? ?? '',
      data: data,
      pagination: pagination,
    );
  }

  Map<String, dynamic> toJson() => _$GetCoursesResponseModelToJson(this);
}

// Course Model
@JsonSerializable()
class CourseModel {
  @JsonKey(name: 'id')
  final String id;

  @JsonKey(name: 'title')
  final String title;

  @JsonKey(name: 'description')
  final String description;

  @JsonKey(name: 'excerpt')
  final String excerpt;

  @JsonKey(name: 'teacherName')
  final String teacherName;

  @JsonKey(name: 'teacherId')
  final String teacherId;

  @JsonKey(name: 'imageUrl')
  final String imageUrl;

  @JsonKey(name: 'level')
  final String level;

  @JsonKey(name: 'language')
  final String language;

  @JsonKey(name: 'totalHours')
  final int totalHours;

  @JsonKey(name: 'totalDuration')
  final int totalDuration;

  @JsonKey(name: 'rating')
  final double rating;

  @JsonKey(name: 'studentsCount')
  final int studentsCount;

  @JsonKey(name: 'isFree')
  final bool isFree;

  @JsonKey(name: 'price')
  final double price;

  @JsonKey(name: 'categories')
  final List<String> categories;

  @JsonKey(name: 'tags')
  final List<String> tags;

  @JsonKey(name: 'status')
  final String status;

  @JsonKey(name: 'createdAt')
  final String createdAt;

  @JsonKey(name: 'updatedAt')
  final String updatedAt;

  /// IDs of students manually assigned to this course from dashboard. Paid courses only show if student.id is in this list.
  @JsonKey(name: 'assigned_student_ids', fromJson: _assignedStudentIdsFromJson)
  final List<String> assignedStudentIds;

  /// Grade/level id (e.g. 44=أولى, 52=ثانية, 59=ثالثة, 65=رابعة) for filtering. Must match API filters_levels.
  @JsonKey(name: 'grade')
  final int? grade;

  /// Parse assigned_student_ids from API (accepts both string and int IDs).
  static List<String> _assignedStudentIdsFromJson(dynamic value) {
    if (value == null) return const [];
    if (value is! List) return const [];
    return value
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  CourseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.excerpt,
    required this.teacherName,
    required this.teacherId,
    required this.imageUrl,
    required this.level,
    required this.language,
    required this.totalHours,
    required this.totalDuration,
    this.rating = 0.0,
    this.studentsCount = 0,
    this.isFree = false,
    this.price = 0.0,
    this.categories = const [],
    this.tags = const [],
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.assignedStudentIds = const [],
    this.grade,
  });

  factory CourseModel.fromJson(Map<String, dynamic> json) =>
      _$CourseModelFromJson(json);

  Map<String, dynamic> toJson() => _$CourseModelToJson(this);

  // Helper getters
  String get priceText => isFree ? 'مجانًا' : '${price.toInt()} ج.م';

  String get durationText => totalHours > 0 ? '$totalHours ساعة' : '';

  String get ratingText => rating > 0 ? rating.toStringAsFixed(1) : '';
}

// Single Course Response Model
@JsonSerializable()
class GetSingleCourseResponseModel {
  @JsonKey(name: 'success')
  final bool success;

  @JsonKey(name: 'message')
  final String message;

  @JsonKey(name: 'data')
  final CourseModel data;

  GetSingleCourseResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  factory GetSingleCourseResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GetSingleCourseResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$GetSingleCourseResponseModelToJson(this);
}

// Pagination Model
@JsonSerializable()
class PaginationData {
  @JsonKey(name: 'current_page')
  final int currentPage;

  @JsonKey(name: 'per_page')
  final int perPage;

  @JsonKey(name: 'total_items')
  final int totalItems;

  @JsonKey(name: 'total_pages')
  final int totalPages;

  PaginationData({
    required this.currentPage,
    required this.perPage,
    required this.totalItems,
    required this.totalPages,
  });

  factory PaginationData.fromJson(Map<String, dynamic> json) =>
      _$PaginationDataFromJson(json);

  Map<String, dynamic> toJson() => _$PaginationDataToJson(this);

  // Helper getters
  bool get hasNextPage => currentPage < totalPages;
  bool get hasPreviousPage => currentPage > 1;
}

// Course Content Response Model
@JsonSerializable()
class GetCourseContentResponseModel {
  @JsonKey(name: 'success')
  final bool success;

  @JsonKey(name: 'message')
  final String message;

  @JsonKey(name: 'data')
  final CourseContentData data;

  GetCourseContentResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  factory GetCourseContentResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GetCourseContentResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$GetCourseContentResponseModelToJson(this);
}

// Course Content Data Model
@JsonSerializable()
class CourseContentData {
  @JsonKey(name: 'lectures')
  final List<LectureModel> lectures;

  CourseContentData({
    required this.lectures,
  });

  factory CourseContentData.fromJson(Map<String, dynamic> json) =>
      _$CourseContentDataFromJson(json);

  Map<String, dynamic> toJson() => _$CourseContentDataToJson(this);
}
