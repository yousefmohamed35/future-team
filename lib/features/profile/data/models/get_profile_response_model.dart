import 'package:json_annotation/json_annotation.dart';

part 'get_profile_response_model.g.dart';

@JsonSerializable()
class GetProfileResponseModel {
  @JsonKey(name: 'success')
  final bool success;

  @JsonKey(name: 'message')
  final String message;

  @JsonKey(name: 'data')
  final ProfileData data;

  GetProfileResponseModel({
    required this.success,
    required this.message,
    required this.data,
  });

  factory GetProfileResponseModel.fromJson(Map<String, dynamic> json) =>
      _$GetProfileResponseModelFromJson(json);

  Map<String, dynamic> toJson() => _$GetProfileResponseModelToJson(this);
}

@JsonSerializable()
class ProfileData {
  @JsonKey(name: 'id')
  final String id;

  @JsonKey(name: 'full_name')
  final String fullName;

  @JsonKey(name: 'email')
  final String email;

  @JsonKey(name: 'mobile')
  final String mobile;

  @JsonKey(name: 'bio')
  final String bio;

  @JsonKey(name: 'about')
  final String about;

  @JsonKey(name: 'avatar')
  final String avatar;

  @JsonKey(name: 'cover')
  final String cover;

  /// Student grade/level id (e.g. 44=الفرقة الأولى, 52=الثانية, 59=الثالثة, 65=الرابعة). Used for auto-filtering courses and college content.
  @JsonKey(name: 'grade')
  final int? grade;

  ProfileData({
    required this.id,
    required this.fullName,
    required this.email,
    required this.mobile,
    required this.bio,
    required this.about,
    required this.avatar,
    required this.cover,
    this.grade,
  });

  factory ProfileData.fromJson(Map<String, dynamic> json) =>
      _$ProfileDataFromJson(json);

  Map<String, dynamic> toJson() => _$ProfileDataToJson(this);
}
