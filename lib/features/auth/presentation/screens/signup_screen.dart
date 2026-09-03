import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/responsive/responsive.dart';
import '../../../profile/application/profile_providers.dart';
import '../../application/auth_providers.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/date_of_birth_field.dart';

final _usernameFormat = RegExp(r'^[a-z0-9_]{3,20}$');

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  DateTime? _dateOfBirth;
  String? _dobError;
  String? _usernameError;
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final formValid = _formKey.currentState?.validate() ?? false;

    setState(() {
      _dobError = _dateOfBirth == null
          ? 'Date of birth is required'
          : (DateOfBirthField.isEligible(_dateOfBirth!)
                ? null
                : 'You must be ${DateOfBirthField.minimumAge}+ to use Forgo');
    });

    if (!formValid || _dobError != null) return;

    setState(() {
      _submitting = true;
      _errorMessage = null;
      _usernameError = null;
    });

    final username = _usernameController.text.trim().toLowerCase();
    try {
      final available = await ref
          .read(profileRepositoryProvider)
          .isUsernameAvailable(username);
      if (!available) {
        setState(() {
          _usernameError = 'That username is taken';
          _submitting = false;
        });
        return;
      }

      await ref.read(authRepositoryProvider).signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        fullName: _nameController.text.trim(),
        username: username,
        dateOfBirth: _dateOfBirth!,
      );
      if (mounted) context.go('/home');
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } catch (_) {
      setState(
        () => _errorMessage = 'Something went wrong. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () => context.go('/login')),
      ),
      body: ResponsivePage(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Create your account', style: textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Forgo is 18+ only — we handle real money stakes.',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) AuthErrorBanner(message: _errorMessage!),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: (value) {
                  if ((value ?? '').trim().isEmpty) return 'Enter your name';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Username',
                  prefixText: '@',
                  helperText: 'Lowercase letters, numbers, underscores — 3-20 characters',
                  errorText: _usernameError,
                ),
                onChanged: (_) {
                  if (_usernameError != null) {
                    setState(() => _usernameError = null);
                  }
                },
                validator: (value) {
                  final username = (value ?? '').trim().toLowerCase();
                  if (username.isEmpty) return 'Choose a username';
                  if (!_usernameFormat.hasMatch(username)) {
                    return 'Lowercase letters, numbers, underscores only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (value) {
                  final email = value?.trim() ?? '';
                  if (email.isEmpty) return 'Enter your email';
                  if (!email.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 8 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (value) {
                  if ((value ?? '').length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DateOfBirthField(
                value: _dateOfBirth,
                errorText: _dobError,
                onChanged: (date) {
                  setState(() {
                    _dateOfBirth = date;
                    _dobError = null;
                  });
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Create account'),
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text('Already have an account?', style: textTheme.bodyMedium),
                  TextButton(
                    onPressed: () => context.go('/login'),
                    child: const Text('Log in'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
