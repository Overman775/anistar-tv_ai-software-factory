import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _usernameFocus = FocusNode(debugLabel: 'Логин');
  final _passwordFocus = FocusNode(debugLabel: 'Пароль');
  final _submitFocus = FocusNode(debugLabel: 'Войти');
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    for (final node in [_usernameFocus, _passwordFocus, _submitFocus]) {
      node.addListener(_revealFocus);
    }
  }

  void _revealFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final target = [_usernameFocus, _passwordFocus, _submitFocus].where((node) => node.hasFocus).firstOrNull;
      final targetContext = target?.context;
      if (targetContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            targetContext,
            alignment: 0.5,
            duration: AppMotion.durationOf(context, AppMotion.fast),
          ),
        );
      }
    });
  }

  KeyEventResult _moveFieldFocus(KeyEvent event, FocusNode down, FocusNode up) {
    final target = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => down,
      LogicalKeyboardKey.arrowUp => up,
      _ => null,
    };
    if (target == null) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      target.requestFocus();
    }

    return KeyEventResult.handled;
  }

  void _focusAfterLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || ref.read(authControllerProvider).isLoading) {
        return;
      }
      (_username.text.isEmpty ? _usernameFocus : _passwordFocus).requestFocus();
    });
  }

  Future<void> _submit() async {
    if (ref.read(authControllerProvider).isLoading) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await ref.read(authControllerProvider.notifier).signIn(_username.text, _password.text);
    if (mounted) {
      _password.clear();
    }
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _submitFocus.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      if (previous?.isLoading == true && !next.isLoading) {
        _focusAfterLoading();
      }
    });
    final auth = ref.watch(authControllerProvider);
    final error = auth.error;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: TvBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: SizedBox(
                width: 520,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: AppPalette.surface,
                    borderRadius: AppRadii.large,
                    border: Border.fromBorderSide(BorderSide(color: AppPalette.outline)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const AnistarLogo(size: 32),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                child: Text(
                                  'AniStar TV',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.headlineMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'Войдите в аккаунт AniStar',
                            style: textTheme.bodyLarge?.copyWith(color: AppPalette.textSecondary),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          Focus(
                            canRequestFocus: false,
                            onKeyEvent: (_, event) => _moveFieldFocus(event, _passwordFocus, _usernameFocus),
                            child: TextFormField(
                              key: const ValueKey('login_username'),
                              controller: _username,
                              focusNode: _usernameFocus,
                              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                              autofocus: true,
                              enabled: !auth.isLoading,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Логин',
                                prefixIcon: Icon(Icons.person_outline_rounded),
                              ),
                              validator: (value) => value == null || value.trim().isEmpty ? 'Введите логин' : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Focus(
                            canRequestFocus: false,
                            onKeyEvent: (_, event) => _moveFieldFocus(event, _submitFocus, _usernameFocus),
                            child: TextFormField(
                              key: const ValueKey('login_password'),
                              controller: _password,
                              focusNode: _passwordFocus,
                              enabled: !auth.isLoading,
                              obscureText: _obscurePassword,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                labelText: 'Пароль',
                                prefixIcon: const Icon(Icons.lock_outline_rounded),
                                suffixIcon: IconButton(
                                  tooltip: _obscurePassword ? 'Показать пароль' : 'Скрыть пароль',
                                  onPressed: auth.isLoading
                                      ? null
                                      : () => setState(() => _obscurePassword = !_obscurePassword),
                                  icon: Icon(
                                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                  ),
                                ),
                              ),
                              validator: (value) => value == null || value.isEmpty ? 'Введите пароль' : null,
                              onFieldSubmitted: (_) => unawaited(_submit()),
                            ),
                          ),
                          if (error != null) ...[
                            const SizedBox(height: 16),
                            Semantics(
                              key: const ValueKey('login_error'),
                              liveRegion: true,
                              child: Text(
                                error is Failure ? error.message : 'Не удалось выполнить вход. Повторите попытку.',
                                style: TextStyle(color: Theme.of(context).colorScheme.error),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          Focus(
                            canRequestFocus: false,
                            onKeyEvent: (_, event) => _moveFieldFocus(event, _submitFocus, _passwordFocus),
                            child: FilledButton(
                              key: const ValueKey('login_submit'),
                              focusNode: _submitFocus,
                              onPressed: auth.isLoading ? null : () => unawaited(_submit()),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (auth.isLoading) ...[
                                    const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                  ],
                                  Flexible(
                                    child: Text(
                                      auth.isLoading ? 'Проверяем вход…' : 'Войти',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
