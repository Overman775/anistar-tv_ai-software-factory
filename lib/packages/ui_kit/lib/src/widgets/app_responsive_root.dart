import 'package:material_ui/material_ui.dart';
import 'package:sizer/sizer.dart';

import 'app_device_profile.dart';
import 'app_layout_scope.dart';

export 'app_device_profile.dart';
export 'app_layout_scope.dart';

/// One Sizer instance covers authentication, routes and modal surfaces.
class AppResponsiveRoot extends StatelessWidget {
  const AppResponsiveRoot({required this.profile, required this.child, super.key});

  final AppDeviceProfile profile;
  final Widget child;

  @override
  Widget build(BuildContext context) => Sizer(
    maxTabletWidth: 1024,
    builder: (context, orientation, screenType) => AppLayoutScope(
      profile: profile,
      viewportSize: Size(Device.width, Device.height),
      horizontalPadding: profile == AppDeviceProfile.tv ? 48 : 4.w.clamp(16.0, 24.0),
      child: child,
    ),
  );
}
