part of 'home_block.dart'; // Add part of directive

// Imports moved to home_block.dart

/// Base class for all events related to the Home screen.
@immutable
abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

/// Event triggered to load the initial list of videos.
class HomeLoadStarted extends HomeEvent {
  const HomeLoadStarted();
}

/// Event triggered to load the next page of videos (pagination).
class HomeLoadMoreRequested extends HomeEvent {
  const HomeLoadMoreRequested();
}

// TODO: Consider adding a refresh event if pull-to-refresh is needed.
// class HomeRefreshed extends HomeEvent {
//   const HomeRefreshed();
// }
