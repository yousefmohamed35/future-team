import 'package:future_app/core/models/download_model.dart';

abstract class DownloadState {}

class DownloadInitial extends DownloadState {}

class DownloadLoading extends DownloadState {}

class DownloadInProgress extends DownloadState {
  final int progress; // 0-100
  final String? message;

  DownloadInProgress(this.progress, {this.message});
}

class DownloadSuccess extends DownloadState {
  final DownloadResponseModel response;

  DownloadSuccess(this.response);
}

class DownloadError extends DownloadState {
  final String message;

  DownloadError(this.message);
}

class GetDownloadedVideosLoading extends DownloadState {}

class GetDownloadedVideosSuccess extends DownloadState {
  final List<DownloadedVideoModel> videos;

  /// Active (running) downloads with progress 0-100. Shown at top of list.
  final List<ActiveDownloadInfo> activeDownloads;

  GetDownloadedVideosSuccess(this.videos,
      {List<ActiveDownloadInfo>? activeDownloads})
      : activeDownloads = activeDownloads ?? const [];
}

/// One active download task (running) with progress.
class ActiveDownloadInfo {
  final String taskId;
  final int progress; // 0-100
  final String title;

  const ActiveDownloadInfo({
    required this.taskId,
    required this.progress,
    required this.title,
  });
}

class GetDownloadedVideosError extends DownloadState {
  final String message;

  GetDownloadedVideosError(this.message);
}
