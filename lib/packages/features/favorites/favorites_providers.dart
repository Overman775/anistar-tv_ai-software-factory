import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'favorites_controller.dart';
import 'favorites_state.dart';

export 'favorites_repository_provider.dart';

final favoritesControllerProvider = NotifierProvider.autoDispose<FavoritesController, FavoritesState>(
  FavoritesController.new,
);
