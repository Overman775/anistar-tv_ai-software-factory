import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Shows only the confirmed account name; no profile request is needed.
class AccountIdentity extends StatelessWidget {
  const AccountIdentity({required this.name, this.showName = true, super.key});

  final String name;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
    final initials = parts.map((part) => String.fromCharCode(part.runes.first)).join().toUpperCase();

    return Semantics(
      label: name,
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: AppSizes.touchControl,
              height: AppSizes.touchControl,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppPalette.menuControl, borderRadius: AppRadii.medium),
              child: Text(initials, style: textTheme.labelLarge),
            ),
            if (showName) ...[
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: textTheme.bodyMedium),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
