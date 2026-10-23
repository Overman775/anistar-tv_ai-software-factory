/// Destinations shared by both device profiles. Display order is independent of
/// the stable route enum values.
enum HomeDestination { home, favorites, genres, search }

List<HomeDestination> homeDestinations({required bool account}) => [
  HomeDestination.home,
  HomeDestination.search,
  if (account) HomeDestination.favorites,
  HomeDestination.genres,
];

String homeDestinationLabel(HomeDestination value) => switch (value) {
  HomeDestination.home => 'Главная',
  HomeDestination.search => 'Поиск',
  HomeDestination.favorites => 'Избранное',
  HomeDestination.genres => 'Жанры',
};
