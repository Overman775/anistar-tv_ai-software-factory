import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../auth/auth_providers.dart';
import '../favorites_providers.dart';

class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({
    required this.animeId,
    required this.slug,
    required this.title,
    this.initialFavorite,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  final int animeId;
  final FocusNode? focusNode;
  final bool autofocus;
  final bool? initialFavorite;
  final String slug;
  final String title;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool _reading = false;
  int _readGeneration = 0;

  Future<void> _change(bool? favorite) async {
    if (_reading || ref.read(favoritesControllerProvider).updatingAnimeId != null) {
      return;
    }
    final id = widget.animeId;
    final controller = ref.read(favoritesControllerProvider.notifier);
    if (favorite == null) {
      final generation = ++_readGeneration;
      setState(() => _reading = true);
      final result = await ref.read(favoritesRepositoryProvider).getStatus(animeId: id, slug: widget.slug);
      if (!mounted || widget.animeId != id || generation != _readGeneration) {
        return;
      }
      setState(() => _reading = false);
      result.when(
        success: (confirmed) => controller.observe(id, confirmed),
        failure: (failure) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message))),
      );

      return;
    }
    final failure = await controller.setFavorite(animeId: id, slug: widget.slug, favorite: !favorite);
    if (failure != null && mounted && widget.animeId == id) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }

  @override
  void didUpdateWidget(covariant FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animeId != widget.animeId || oldWidget.slug != widget.slug) {
      ++_readGeneration;
      _reading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final access = ref.watch(authAccessProvider);
    if (!access.canUseAccount) {
      return AppButton(
        key: ValueKey('favorite-login-${widget.animeId}'),
        focusNode: widget.focusNode,
        autofocus: widget.autofocus,
        variant: AppButtonVariant.neutral,
        label: 'Войти, чтобы добавить в избранное',
        icon: const AppIcon(AppIconType.logIn),
        onPressed: ref.read(authControllerProvider.notifier).requestSignIn,
      );
    }
    final state = ref.watch(favoritesControllerProvider);
    final favorite = state.known[widget.animeId] ?? widget.initialFavorite;
    final busy = _reading || state.updatingAnimeId == widget.animeId;

    return AppButton(
      key: ValueKey('favorite-button-${widget.animeId}'),
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      busy: busy,
      enabled: state.updatingAnimeId == null || state.updatingAnimeId == widget.animeId,
      onPressed: () => unawaited(_change(favorite)),
      icon: AppIcon(favorite == true ? AppIconType.heartMinus : AppIconType.heartPlus),
      label: busy
          ? 'Сохраняем…'
          : switch (favorite) {
              true => 'В избранном',
              false => 'В избранное',
              null => 'Проверить избранное',
            },
      variant: AppButtonVariant.neutral,
    );
  }
}
