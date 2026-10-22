import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';

import '../../assets.dart';

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
    final tint = color ?? theme.color ?? Theme.of(context).colorScheme.onSurface;

    return SvgPicture.asset(
      'assets/icons/${icon.assetName}.svg',
      package: Assets.package,
      width: extent,
      height: extent,
      colorFilter: ColorFilter.mode(tint.withValues(alpha: tint.a * (theme.opacity ?? 1)), BlendMode.srcIn),
      semanticsLabel: semanticLabel,
      excludeFromSemantics: semanticLabel == null,
    );
  }
}

/// The local Lucide source used by every functional application icon.
enum AppIconType {
  arrowDown('arrow-down'),
  arrowLeft('arrow-left'),
  arrowUp('arrow-up'),
  check('check'),
  chevronRight('chevron-right'),
  circleAlert('circle-alert'),
  eye('eye'),
  eyeOff('eye-off'),
  fastForward('fast-forward'),
  funnel('funnel'),
  heart('heart'),
  heartMinus('heart-minus'),
  heartOff('heart-off'),
  heartPlus('heart-plus'),
  home('house'),
  info('info'),
  layoutGrid('layout-grid'),
  list('list'),
  listFilter('list-filter'),
  listVideo('list-video'),
  loaderCircle('loader-circle'),
  logOut('log-out'),
  logIn('log-in'),
  pause('pause'),
  play('play'),
  refresh('refresh-cw'),
  rewind('rewind'),
  rotateCcw('rotate-ccw'),
  rotateCw('rotate-cw'),
  rotateSquare('rotate-cw-square'),
  search('search'),
  share('share-2'),
  skipBack('skip-back'),
  skipForward('skip-forward'),
  smartphone('smartphone'),
  star('star'),
  user('user'),
  x('x');

  const AppIconType(this.assetName);

  final String assetName;

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
