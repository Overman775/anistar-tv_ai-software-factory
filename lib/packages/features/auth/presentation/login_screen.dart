import 'dart:async';

import 'package:core/data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

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

  Future<void> _submit() async {
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
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final error = auth.error;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: SizedBox(
              width: 440,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Вход в AniStar', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const ValueKey('login_username'),
                      controller: _username,
                      autofocus: true,
                      enabled: !auth.isLoading,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Логин'),
                      validator: (value) => value == null || value.trim().isEmpty ? 'Введите логин' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const ValueKey('login_password'),
                      controller: _password,
                      enabled: !auth.isLoading,
                      obscureText: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Пароль'),
                      validator: (value) => value == null || value.isEmpty ? 'Введите пароль' : null,
                      onFieldSubmitted: (_) => unawaited(_submit()),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error is Failure ? error.message : 'Не удалось проверить сессию. Повторите попытку.',
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      key: const ValueKey('login_submit'),
                      onPressed: auth.isLoading ? null : () => unawaited(_submit()),
                      child: Text(auth.isLoading ? 'Проверяем вход…' : 'Войти'),
                    ),
                    if (error != null)
                      TextButton(
                        onPressed: ref.read(authControllerProvider.notifier).retryRestore,
                        child: const Text('Повторить проверку сессии'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
