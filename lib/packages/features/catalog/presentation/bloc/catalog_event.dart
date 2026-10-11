import 'package:flutter/foundation.dart';

@immutable
sealed class CatalogEvent {
  const CatalogEvent();
}

@immutable
final class CatalogStarted extends CatalogEvent {
  final bool preserveContent;

  const CatalogStarted({this.preserveContent = false});
}

@immutable
final class CatalogMoreRequested extends CatalogEvent {
  final bool retry;

  const CatalogMoreRequested({this.retry = false});
}
