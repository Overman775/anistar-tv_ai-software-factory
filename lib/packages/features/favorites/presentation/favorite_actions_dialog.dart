import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../favorites_providers.dart';

class FavoriteActionsDialog extends ConsumerStatefulWidget {
  const FavoriteActionsDialog({required this.animeId, required this.slug, required this.title, super.key});

  final int animeId;
  final String slug;
  final String title;

  @override
  ConsumerState<FavoriteActionsDialog> createState() => _FavoriteActionsDialogState();
}

class _FavoriteActionsDialogState extends ConsumerState<FavoriteActionsDialog> {
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

    return FilledButton.icon(
      autofocus: true,
      onPressed: _busy || favorite == null ? null : () => unawaited(_change(!favorite)),
      icon: Icon(favorite == true ? Icons.star_border_rounded : Icons.star_rounded),
      label: Text(_label(favorite)),
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

    return AlertDialog(
      title: Text(widget.title),
      content: FutureBuilder<Result<bool, Failure>>(future: _future, builder: _content),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: const Text('Отмена')),
      ],
    );
  }
}

Future<bool?> showFavoriteActions(
  BuildContext context, {
  required int animeId,
  required String slug,
  required String title,
}) => showDialog<bool>(
  context: context,
  builder: (_) => FavoriteActionsDialog(animeId: animeId, slug: slug, title: title),
);
