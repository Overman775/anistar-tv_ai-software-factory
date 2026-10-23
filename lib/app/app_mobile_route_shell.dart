part of 'app_routes.dart';

class _AppMobileRouteShell extends ConsumerWidget {
  const _AppMobileRouteShell({required this.destination, required this.title, required this.content});

  final HomeDestination destination;
  final String title;
  final Widget content;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MobileHomeShell(
    destination: destination,
    onDestinationSelected: (value) => HomeRoute(destination: value).go(context),
    accountName: ref.watch(authAccessProvider).account,
    onSignOut: ref.watch(authAccessProvider).canUseAccount ? () => unawaited(_signOut(context, ref)) : null,
    onSignIn: ref.watch(authAccessProvider).canUseAccount
        ? null
        : ref.read(authControllerProvider.notifier).requestSignIn,
    onOpenLogs: _logsAction(context),
    onAnimeTap: (anime) => _openAnime(context, anime, destination),
    contextTitle: title,
    onBack: () => context.pop(),
    content: content,
  );
}
