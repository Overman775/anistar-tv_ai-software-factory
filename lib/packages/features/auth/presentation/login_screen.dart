import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ui_kit/ui_kit.dart';

import '../auth_providers.dart';
import '../domain/auth_invalid_credentials_failure.dart';
import 'login_brand.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({this.canCancel = false, super.key});

  final bool canCancel;

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
  final _visibilityFocus = FocusNode(debugLabel: 'Видимость пароля');
  final _guestFocus = FocusNode(debugLabel: 'Продолжить без входа');
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    for (final node in [_usernameFocus, _passwordFocus, _visibilityFocus, _submitFocus, _guestFocus]) {
      node.addListener(_revealFocus);
    }
  }

  void _revealFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final target = [
        _usernameFocus,
        _passwordFocus,
        _visibilityFocus,
        _submitFocus,
        _guestFocus,
      ].where((node) => node.hasFocus).firstOrNull;
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

  KeyEventResult _passwordNavigation(KeyEvent event) {
    final fromPasswordEnd =
        _passwordFocus.hasFocus &&
        _password.selection.isCollapsed &&
        _password.selection.extentOffset == _password.text.length &&
        event.logicalKey == LogicalKeyboardKey.arrowRight;
    final toPassword = _visibilityFocus.hasFocus && event.logicalKey == LogicalKeyboardKey.arrowLeft;
    if (!fromPasswordEnd && !toPassword) {
      return KeyEventResult.ignored;
    }
    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      (toPassword ? _passwordFocus : _visibilityFocus).requestFocus();
    }

    return KeyEventResult.handled;
  }

  void _focusAfterLoading() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final auth = ref.read(authControllerProvider);
      if (auth.isLoading || auth.value?.isSigningIn == true || auth.value?.requiresCancellation == true) {
        return;
      }
      (_username.text.isEmpty ? _usernameFocus : _passwordFocus).requestFocus();
    });
  }

  Future<void> _submit() async {
    final auth = ref.read(authControllerProvider);
    if (auth.isLoading ||
        auth.value?.isSigningIn == true ||
        auth.value?.requiresCancellation == true ||
        !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    _submitFocus.requestFocus();
    await ref.read(authControllerProvider.notifier).signIn(_username.text, _password.text);
  }

  void _continueAnonymous() {
    final controller = ref.read(authControllerProvider.notifier);
    if (widget.canCancel) {
      unawaited(controller.cancelSignIn());
    } else {
      controller.enterAnonymous();
    }
  }

  void _onPop(bool didPop, Object? result) {
    if (!didPop && widget.canCancel) {
      unawaited(ref.read(authControllerProvider.notifier).cancelSignIn());
    }
  }

  @override
  void dispose() {
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _submitFocus.dispose();
    _visibilityFocus.dispose();
    _guestFocus.dispose();
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (previous, next) {
      final restored = previous?.isLoading == true && !next.isLoading && AppLayoutScope.isTvOf(context);
      final signInFinished = previous?.value?.isSigningIn == true && next.value?.isSigningIn != true;
      if (next.value?.operation == AuthOperation.cancellationFailed) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _guestFocus.requestFocus();
          }
        });
      }
      if (restored || signInFinished) {
        if (next.value?.signInFailure is AuthInvalidCredentialsFailure) {
          _password.clear();
        }
        _focusAfterLoading();
      }
    });
    final auth = ref.watch(authControllerProvider);
    final snapshot = auth.value;
    final busy = auth.isLoading || snapshot?.isSigningIn == true;
    final cancellationRequired = snapshot?.requiresCancellation == true;
    final blocked = busy || cancellationRequired;
    final error = snapshot?.cancellationFailure ?? snapshot?.signInFailure ?? auth.error;
    final textTheme = Theme.of(context).textTheme;
    final fieldLabelStyle = textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600);
    final isTv = AppLayoutScope.isTvOf(context);
    final fieldHeight = (MediaQuery.textScalerOf(context).scale(textTheme.bodyLarge?.fontSize ?? 18) * 1.45 + 32).clamp(
      isTv ? AppSizes.tvControl : AppSizes.touchControl,
      double.infinity,
    );

    final form = Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Вход в аккаунт', style: textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          ExcludeSemantics(child: Text('Логин', style: fieldLabelStyle)),
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: 'Логин',
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) => _moveFieldFocus(event, _passwordFocus, _usernameFocus),
              child: AppFocusBorder(
                focusNode: _usernameFocus,
                restingColor: AppPalette.outline,
                child: TextFormField(
                  key: const ValueKey('login_username'),
                  controller: _username,
                  focusNode: _usernameFocus,
                  onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                  autofocus: isTv,
                  enabled: !blocked,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    fillColor: AppPalette.surface,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    focusedErrorBorder: InputBorder.none,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty ? 'Введите логин' : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ExcludeSemantics(child: Text('Пароль', style: fieldLabelStyle)),
          const SizedBox(height: AppSpacing.sm),
          Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) => _moveFieldFocus(event, _submitFocus, _usernameFocus),
            child: Focus(
              canRequestFocus: false,
              onKeyEvent: (_, event) => _passwordNavigation(event),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Пароль',
                      child: AppFocusBorder(
                        focusNode: _passwordFocus,
                        restingColor: AppPalette.outline,
                        child: TextFormField(
                          key: const ValueKey('login_password'),
                          controller: _password,
                          focusNode: _passwordFocus,
                          enabled: !blocked,
                          obscureText: _obscurePassword,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.done,
                          decoration: const InputDecoration(
                            fillColor: AppPalette.surface,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            focusedErrorBorder: InputBorder.none,
                          ),
                          validator: (value) => value == null || value.isEmpty ? 'Введите пароль' : null,
                          onFieldSubmitted: (_) => unawaited(_submit()),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  SizedBox.square(
                    dimension: fieldHeight,
                    child: IconButton(
                      focusNode: _visibilityFocus,
                      tooltip: _obscurePassword ? 'Показать пароль' : 'Скрыть пароль',
                      onPressed: blocked ? null : () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: AppIcon(_obscurePassword ? AppIconType.eye : AppIconType.eyeOff),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (error != null) ...[
            const SizedBox(height: AppSpacing.md),
            Semantics(
              key: const ValueKey('login_error'),
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  border: Border.fromBorderSide(BorderSide(color: AppPalette.danger)),
                  borderRadius: AppRadii.medium,
                ),
                child: Text(
                  error is Failure ? error.message : 'Не удалось выполнить вход. Повторите попытку.',
                  style: textTheme.bodyMedium?.copyWith(color: AppPalette.danger),
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) => _moveFieldFocus(event, _guestFocus, _passwordFocus),
            child: AppButton(
              key: const ValueKey('login_submit'),
              focusNode: _submitFocus,
              busy: busy,
              enabled: !cancellationRequired,
              label: busy ? 'Проверяем вход…' : 'Войти',
              onPressed: () => unawaited(_submit()),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Focus(
            canRequestFocus: false,
            onKeyEvent: (_, event) => _moveFieldFocus(event, _guestFocus, _submitFocus),
            child: AppButton(
              key: const ValueKey('login_guest'),
              focusNode: _guestFocus,
              variant: AppButtonVariant.neutral,
              enabled: widget.canCancel || !busy,
              busy: snapshot?.isCancellingSignIn == true,
              label: switch (snapshot?.operation) {
                AuthOperation.cancellingSignIn => 'Отменяем вход…',
                AuthOperation.cancellationFailed => 'Повторить отмену',
                _ => 'Продолжить без входа',
              },
              onPressed: _continueAnonymous,
            ),
          ),
        ],
      ),
    );

    return PopScope(
      canPop: !widget.canCancel,
      onPopInvokedWithResult: _onPop,
      child: Scaffold(
        backgroundColor: AppPalette.background,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final padding = isTv ? (constraints.maxWidth * 0.05).clamp(24.0, 96.0) : AppSpacing.lg;
              final horizontal = isTv && constraints.maxWidth >= 760;
              final brand = LoginBrand(vertical: horizontal);

              return SingleChildScrollView(
                padding: EdgeInsets.all(padding),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - padding * 2).clamp(0.0, double.infinity),
                  ),
                  child: Center(
                    child: horizontal
                        ? Row(
                            children: [
                              Expanded(child: brand),
                              const SizedBox(width: AppSpacing.xxxl),
                              Expanded(
                                child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: form),
                              ),
                            ],
                          )
                        : ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                brand,
                                const SizedBox(height: AppSpacing.xl),
                                form,
                              ],
                            ),
                          ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
