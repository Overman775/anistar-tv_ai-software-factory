import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../../auth/auth_providers.dart';
import '../favorites_providers.dart';

class FavoriteActionsSheet extends ConsumerStatefulWidget {
  const FavoriteActionsSheet({required this.animeId, required this.slug, required this.title, super.key});

  final int animeId;
  final String slug;
  final String title;

  @override
  ConsumerState<FavoriteActionsSheet> createState() => _FavoriteActionsSheetState();
}

class _FavoriteActionsSheetState extends ConsumerState<FavoriteActionsSheet> {
  Future<Result<bool, Failure>>? _future;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (ref.read(authAccessProvider).canUseAccount) {
      _load();
    }
  }

  void _load() {
    _error = null;
    _future = ref.read(favoritesControllerProvider.notifier).readStatus(animeId: widget.animeId, slug: widget.slug);
  }

  Future<void> _change(bool favorite) async {
    final account = ref.read(favoritesAccountProvider);
    if (_busy || account == null || ref.read(favoritesControllerProvider).updatingAnimeId != null) return;
    setState(() => _busy = true);
    final failure = await ref
        .read(favoritesControllerProvider.notifier)
        .setFavorite(animeId: widget.animeId, slug: widget.slug, favorite: favorite);
    if (!mounted || ref.read(favoritesAccountProvider) != account) return;
    if (failure == null) {
      if (ModalRoute.isCurrentOf(context) == true) {
        Navigator.of(context).pop(true);
      } else {
        setState(() => _busy = false);
      }
    } else {
      setState(() {
        _busy = false;
        _error = failure.message;
      });
    }
  }

  void _requestChange(bool? favorite) {
    if (favorite != null) {
      unawaited(_change(!favorite));
    }
  }

  Widget _content(AsyncSnapshot<Result<bool, Failure>> snapshot) {
    if (snapshot.connectionState != ConnectionState.done) {
      return const SizedBox(height: 64, child: Center(child: CircularProgressIndicator()));
    }
    final result = snapshot.data;
    final error = _error ?? result?.failureOrNull?.message;
    if (error != null || result == null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(error ?? 'Не удалось проверить избранное.'),
          TextButton(
            autofocus: true,
            onPressed: _busy ? null : () => setState(_load),
            child: const Text('Обновить статус'),
          ),
        ],
      );
    }
    final status = ref.read(favoritesControllerProvider);
    final favorite = status.confirmedStatus(widget.animeId, reported: result.successOrNull);
    final updating = status.updatingAnimeId;
    final busy = _busy || updating == widget.animeId;

    return AppButton(
      autofocus: true,
      busy: busy,
      enabled: favorite != null && (updating == null || updating == widget.animeId),
      onPressed: () => _requestChange(favorite),
      icon: AppIcon(favorite == true ? AppIconType.heartMinus : AppIconType.heartPlus),
      label: _label(favorite, busy),
    );
  }

  String _label(bool? favorite, bool busy) {
    if (busy) {
      return 'Обновляем избранное…';
    }

    return favorite == true ? 'Удалить из избранного' : 'Добавить в избранное';
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(favoritesAccountProvider, (previous, next) {
      if (previous == next) return;
      setState(() {
        _busy = false;
        _error = null;
        _future = null;
        if (next != null && ref.read(authAccessProvider).canUseAccount) _load();
      });
    });
    if (!ref.watch(authAccessProvider).canUseAccount) {
      return AppActionSheet(
        title: widget.title,
        child: AppButton(
          autofocus: true,
          label: 'Войти, чтобы добавить в избранное',
          icon: const AppIcon(AppIconType.logIn),
          onPressed: ref.read(authControllerProvider.notifier).requestSignIn,
        ),
      );
    }
    ref.watch(favoritesControllerProvider);

    return AppActionSheet(
      title: widget.title,
      mobileHeightFactor: MediaQuery.sizeOf(context).height < 500 ? 0.8 : 0.4,
      expandChild: true,
      child: ListView(
        children: [
          FutureBuilder<Result<bool, Failure>>(future: _future, builder: (_, snapshot) => _content(snapshot)),
          const SizedBox(height: AppSpacing.md),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(false),
            icon: const AppIcon.fromMaterial(Icons.close_rounded),
            label: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

Future<bool?> showFavoriteActions(
  BuildContext context, {
  required int animeId,
  required String slug,
  required String title,
}) => showAppActionSheet<bool>(
  context: context,
  builder: (_) => FavoriteActionsSheet(animeId: animeId, slug: slug, title: title),
);
