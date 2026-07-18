import 'package:flutter/foundation.dart';

@immutable
sealed class CatalogEvent {
  const CatalogEvent();
}

@immutable
final class CatalogStarted extends CatalogEvent {
  const CatalogStarted();
}

@immutable
final class CatalogMoreRequested extends CatalogEvent {
  const CatalogMoreRequested();
}
