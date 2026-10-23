import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

/// Shows a confirmed account name with an optional profile image fallback.
class AccountIdentity extends StatelessWidget {
  const AccountIdentity({required this.name, this.imageUrl, this.showName = true, super.key});

  final String name;
  final String? imageUrl;
  final bool showName;

  @override
  Widget build(BuildContext context) => Semantics(
    label: name,
    child: ExcludeSemantics(
      child: Row(
        children: [
          AppAvatar(name: name, imageUrl: imageUrl),
          if (showName) ...[
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
