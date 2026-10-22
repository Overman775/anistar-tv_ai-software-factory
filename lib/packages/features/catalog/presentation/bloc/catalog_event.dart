import 'package:flutter/foundation.dart';

import '../../domain/repositories/catalog_repository.dart';

@immutable
sealed class CatalogEvent {
  const CatalogEvent();
}

@immutable
final class CatalogStarted extends CatalogEvent {
  final bool preserveContent;
  final bool preservePages;
  final CatalogRepository? repository;

  const CatalogStarted({this.preserveContent = false, this.preservePages = false, this.repository});
}

@immutable
final class CatalogMoreRequested extends CatalogEvent {
  final bool retry;

  const CatalogMoreRequested({this.retry = false});
}
