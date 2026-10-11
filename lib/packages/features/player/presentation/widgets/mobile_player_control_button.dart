import 'package:material_ui/material_ui.dart';

/// Shared touch target for the mobile playback overlay.
class MobilePlayerControlButton extends StatelessWidget {
  const MobilePlayerControlButton({
    required this.buttonKey,
    required this.label,
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final String buttonKey;
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    key: ValueKey(buttonKey),
    tooltip: label,
    onPressed: onPressed,
    style: IconButton.styleFrom(minimumSize: const Size(48, 48), foregroundColor: Colors.white),
    icon: Icon(icon, size: 26),
  );
}
