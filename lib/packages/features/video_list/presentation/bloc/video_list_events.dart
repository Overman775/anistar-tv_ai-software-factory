part of 'video_list_bloc.dart';

/// Base class for VideoList events using Equatable for value comparison.
abstract class VideoListEvent extends Equatable {
  const VideoListEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered to start loading the initial list of videos.
class VideoListLoadStarted extends VideoListEvent {
  const VideoListLoadStarted();
}

/// Event triggered to request loading the next page of videos.
class VideoListLoadMoreRequested extends VideoListEvent {
  const VideoListLoadMoreRequested();
}
