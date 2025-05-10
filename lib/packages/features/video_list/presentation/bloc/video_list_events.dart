part of 'video_list_bloc.dart';

@freezed
class VideoListEvent with _$VideoListEvent {
  const factory VideoListEvent.loadStarted() = VideoListLoadStarted;
  const factory VideoListEvent.loadMoreRequested() = VideoListLoadMoreRequested;
}
