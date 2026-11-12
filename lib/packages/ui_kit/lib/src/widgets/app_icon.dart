import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

/// Decorative by default; an informative standalone icon receives a label.
class AppIcon extends StatelessWidget {
  const AppIcon(AppIconType icon, {this.size, this.color, this.semanticLabel, super.key}) : _icon = icon;

  const AppIcon.fromMaterial(IconData icon, {this.size, this.color, this.semanticLabel, super.key}) : _icon = icon;

  final Object _icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final icon = switch (_icon) {
      final AppIconType symbol => symbol,
      final IconData material => AppIconType.fromMaterial(material),
      _ => throw StateError('Unsupported icon source.'),
    };
    final extent = size ?? theme.size ?? 28;
    return Icon(icon.glyph, size: extent, color: color, semanticLabel: semanticLabel);
  }
}

/// The Lucide font glyph used by every functional application icon.
enum AppIconType {
  arrowDown('arrow-down', LucideIcons.arrowDown),
  arrowLeft('arrow-left', LucideIcons.arrowLeft),
  arrowUp('arrow-up', LucideIcons.arrowUp),
  check('check', LucideIcons.check),
  chevronRight('chevron-right', LucideIcons.chevronRight),
  circleAlert('circle-alert', LucideIcons.circleExclamationPoint),
  eye('eye', LucideIcons.eye),
  eyeOff('eye-off', LucideIcons.eyeOff),
  fastForward('fast-forward', LucideIcons.fastForward),
  funnel('funnel', LucideIcons.funnel),
  heart('heart', LucideIcons.heart),
  heartMinus('heart-minus', LucideIcons.heartMinus),
  heartOff('heart-off', LucideIcons.heartOff),
  heartPlus('heart-plus', LucideIcons.heartPlus),
  home('house', LucideIcons.house),
  info('info', LucideIcons.info),
  layoutGrid('layout-grid', LucideIcons.layoutGrid),
  list('list', LucideIcons.list),
  listFilter('list-filter', LucideIcons.listFilter),
  listVideo('list-video', LucideIcons.listVideo),
  loaderCircle('loader-circle', LucideIcons.loaderCircle),
  logOut('log-out', LucideIcons.logOut),
  logIn('log-in', LucideIcons.logIn),
  pause('pause', LucideIcons.pause),
  play('play', LucideIcons.play),
  refresh('refresh-cw', LucideIcons.refreshCw),
  rewind('rewind', LucideIcons.rewind),
  rotateCcw('rotate-ccw', LucideIcons.rotateCcw),
  rotateCw('rotate-cw', LucideIcons.rotateCw),
  rotateSquare('rotate-cw-square', LucideIcons.rotateCwSquare),
  search('search', LucideIcons.search),
  share('share-2', LucideIcons.share2),
  skipBack('skip-back', LucideIcons.skipBack),
  skipForward('skip-forward', LucideIcons.skipForward),
  smartphone('smartphone', LucideIcons.smartphone),
  star('star', LucideIcons.star),
  user('user', LucideIcons.user),
  x('x', LucideIcons.x);

  const AppIconType(this.assetName, this.glyph);

  final String assetName;
  final IconData glyph;

  /// Preserves older public IconData inputs while their consumers migrate.
  static AppIconType fromMaterial(IconData icon) => switch (icon) {
    Icons.home || Icons.home_outlined || Icons.home_rounded => home,
    Icons.star_rounded || Icons.star_border_rounded || Icons.grade_rounded => star,
    Icons.category || Icons.category_outlined => layoutGrid,
    Icons.account_circle_outlined || Icons.person_outline_rounded => user,
    Icons.logout => logOut,
    Icons.login => logIn,
    Icons.search => search,
    Icons.arrow_back || Icons.arrow_back_rounded => arrowLeft,
    Icons.keyboard_arrow_up_rounded => arrowUp,
    Icons.keyboard_arrow_down_rounded => arrowDown,
    Icons.ios_share_rounded => share,
    Icons.favorite || Icons.favorite_border || Icons.favorite_rounded || Icons.favorite_border_rounded => heart,
    Icons.chevron_right || Icons.chevron_right_rounded => chevronRight,
    Icons.close_rounded => x,
    Icons.check || Icons.check_circle_rounded || Icons.check_circle_outline_rounded => check,
    Icons.visibility_outlined => eye,
    Icons.visibility_off_outlined => eyeOff,
    Icons.play_arrow_rounded || Icons.play_circle_outline_rounded => play,
    Icons.pause_rounded => pause,
    Icons.replay_10_rounded => rewind,
    Icons.forward_10_rounded => fastForward,
    Icons.skip_previous_rounded => skipBack,
    Icons.skip_next_rounded => skipForward,
    Icons.playlist_play_rounded || Icons.video_library_outlined || Icons.movie_outlined => listVideo,
    Icons.playlist_remove_rounded => heartOff,
    Icons.refresh_rounded => refresh,
    Icons.screen_rotation_rounded => rotateSquare,
    Icons.sort => listFilter,
    Icons.article_outlined || Icons.description_outlined => list,
    _ => circleAlert,
  };
}
