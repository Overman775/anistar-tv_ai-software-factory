import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../favorites_providers.dart';
import 'favorite_actions_dialog.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({
    required this.animeId,
    required this.slug,
    required this.title,
    this.initialFavorite,
    super.key,
  });

  final int animeId;
  final bool? initialFavorite;
  final String slug;
  final String title;

  Future<void> _change(BuildContext context, WidgetRef ref, bool? favorite) async {
    if (favorite == null) {
      await showFavoriteActions(context, animeId: animeId, slug: slug, title: title);

      return;
    }
    final failure = await ref
        .read(favoritesControllerProvider.notifier)
        .setFavorite(animeId: animeId, slug: slug, favorite: !favorite);
    if (failure != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  String _label(bool? favorite, bool updating) {
    if (updating) {
      return 'Обновляем избранное…';
    }

    return switch (favorite) {
      true => 'Удалить из избранного',
      false => 'Добавить в избранное',
      null => 'Избранное',
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(favoritesControllerProvider);
    final favorite = state.known[animeId] ?? initialFavorite;

    return FilledButton.tonalIcon(
      key: ValueKey('favorite-button-$animeId'),
      onPressed: state.updatingAnimeId != null ? null : () => unawaited(_change(context, ref, favorite)),
      icon: Icon(favorite == true ? Icons.star_rounded : Icons.star_border_rounded),
      label: Text(_label(favorite, state.updatingAnimeId == animeId)),
    );
  }
}
