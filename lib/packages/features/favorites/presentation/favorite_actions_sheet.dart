import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

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
  late Future<Result<bool, Failure>> _future;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _error = null;
    _future = ref.read(favoritesRepositoryProvider).getStatus(animeId: widget.animeId, slug: widget.slug);
  }

  Future<void> _change(bool favorite) async {
    setState(() => _busy = true);
    final failure = await ref
        .read(favoritesControllerProvider.notifier)
        .setFavorite(animeId: widget.animeId, slug: widget.slug, favorite: favorite);
    if (!mounted) {
      return;
    }
    if (failure == null) {
      Navigator.of(context).pop(true);
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

  Widget _content(BuildContext context, AsyncSnapshot<Result<bool, Failure>> snapshot) {
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
    final favorite = result.successOrNull;

    return AppButton(
      autofocus: true,
      busy: _busy,
      enabled: favorite != null,
      onPressed: () => _requestChange(favorite),
      icon: AppIcon(favorite == true ? AppIconType.heartMinus : AppIconType.heartPlus),
      label: _label(favorite),
    );
  }

  String _label(bool? favorite) {
    if (_busy) {
      return 'Обновляем избранное…';
    }

    return favorite == true ? 'Удалить из избранного' : 'Добавить в избранное';
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(favoritesControllerProvider);

    return AppActionSheet(
      title: widget.title,
      mobileHeightFactor: MediaQuery.sizeOf(context).height < 500 ? 0.8 : 0.4,
      child: ListView(
        children: [
          FutureBuilder<Result<bool, Failure>>(future: _future, builder: _content),
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
