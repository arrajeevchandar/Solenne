import 'dart:async';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/errors/user_error_message.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/auth/legal_documents.dart';
import '../app_shell.dart';

enum _AuthMode { signUp, login }

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _skyController;
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _AuthMode _mode = _AuthMode.signUp;
  bool _loading = false;
  String? _error;
  bool _emailError = false;
  bool _passwordError = false;
  bool _usernameError = false;
  bool _confirmPasswordError = false;
  bool _acceptedTerms = false;
  bool _acceptedPrivacy = false;
  bool _acceptedAiConsent = false;
  Timer? _usernameDebounce;
  bool _checkingUsername = false;
  bool? _usernameAvailable;

  @override
  void initState() {
    super.initState();
    _skyController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 7200),
    )..repeat();
  }

  @override
  void dispose() {
    _skyController.dispose();
    _usernameController.dispose();
    _displayNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameDebounce?.cancel();
    super.dispose();
  }

  void _checkUsername(String value) {
    _usernameDebounce?.cancel();
    final normalized = AuthRepository.normalizeUsername(value);
    setState(() {
      _usernameAvailable = null;
      _checkingUsername = AuthRepository.isUsernameValid(normalized);
    });
    if (!_checkingUsername) return;
    _usernameDebounce = Timer(const Duration(milliseconds: 350), () async {
      bool available;
      try {
        available = await ref
            .read(authRepositoryProvider)
            .isUsernameAvailable(normalized);
      } catch (error) {
        if (mounted) {
          setState(() {
            _checkingUsername = false;
            _usernameAvailable = null;
            _error = userErrorMessage(
              error,
              fallback: 'Username availability could not be checked.',
            );
          });
        }
        return;
      }
      if (!mounted ||
          AuthRepository.normalizeUsername(_usernameController.text) !=
              normalized) {
        return;
      }
      setState(() {
        _checkingUsername = false;
        _usernameAvailable = available;
      });
    });
  }

  Future<void> _continue() async {
    if (_loading) return;
    final isSignUp = _mode == _AuthMode.signUp;
    final name = _displayNameController.text.trim();
    final username = AuthRepository.normalizeUsername(_usernameController.text);
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    setState(() {
      _emailError = false;
      _passwordError = false;
      _usernameError = false;
      _confirmPasswordError = false;
      _error = null;
    });

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _error = 'Enter a valid email address.';
        _emailError = true;
      });
      return;
    }
    if (password.length < 6) {
      setState(() {
        _error = 'Use at least 6 characters.';
        _passwordError = true;
      });
      return;
    }
    if (isSignUp && name.length < 2) {
      setState(() {
        _error = 'Enter your display name.';
        _usernameError = true;
      });
      return;
    }
    if (isSignUp && !AuthRepository.isUsernameValid(username)) {
      setState(() {
        _error = 'Use 3-20 lowercase letters, numbers, or underscores.';
        _usernameError = true;
      });
      return;
    }
    if (isSignUp && password != confirmPassword) {
      setState(() {
        _error = 'Passwords do not match.';
        _confirmPasswordError = true;
      });
      return;
    }
    if (isSignUp &&
        (!_acceptedTerms || !_acceptedPrivacy || !_acceptedAiConsent)) {
      setState(() {
        _error = 'Accept the Terms, Privacy Policy, and Data & AI Consent.';
      });
      return;
    }

    setState(() {
      _loading = true;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      if (isSignUp) {
        await repository.signUp(
          displayName: name,
          username: username,
          email: email,
          password: password,
          acceptedTerms: _acceptedTerms,
          acceptedPrivacy: _acceptedPrivacy,
          acceptedAiConsent: _acceptedAiConsent,
        );
      } else {
        await repository.signIn(email: email, password: password);
        await repository.ensureUserDocument();
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushAndRemoveUntil(fadeThroughRoute(const AppShell()), (_) => false);
    } on UsernameException catch (error) {
      setState(() {
        _error = error.message;
        _usernameError = true;
      });
    } on FirebaseAuthException catch (error) {
      setState(() {
        if (error.code == 'wrong-password') {
          _error = 'Incorrect email or password';
          _passwordError = true;
        } else if (error.code == 'user-not-found') {
          _error = 'Incorrect email or password';
          _emailError = true;
        } else if (error.code == 'invalid-credential') {
          _error = 'Incorrect email or password';
          _emailError = true;
          _passwordError = true;
        } else if (error.code == 'invalid-email') {
          _error = 'Enter a valid email address.';
          _emailError = true;
        } else if (error.code == 'weak-password') {
          _error = 'Password is too weak.';
          _passwordError = true;
        } else if (error.code == 'email-already-in-use') {
          _error = 'Email is already in use.';
          _emailError = true;
        } else {
          _error = userErrorMessage(error, fallback: 'Authentication failed.');
        }
      });
    } catch (error) {
      setState(
        () => _error = userErrorMessage(
          error,
          fallback: 'Authentication failed. Please try again.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    setState(() {
      _emailError = false;
      _passwordError = false;
      _usernameError = false;
      _confirmPasswordError = false;
      _error = null;
    });

    if (email.isEmpty || !email.contains('@')) {
      setState(() {
        _error = 'Enter your email first.';
        _emailError = true;
      });
      return;
    }
    setState(() {
      _loading = true;
    });
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(email);
      if (mounted) {
        setState(() => _error = 'Password reset email sent.');
      }
    } on FirebaseAuthException catch (error) {
      setState(() {
        if (error.code == 'user-not-found' || error.code == 'invalid-email') {
          _error = 'Incorrect email address.';
          _emailError = true;
        } else {
          _error = userErrorMessage(
            error,
            fallback: 'Failed to reset password.',
          );
        }
      });
    } catch (error) {
      setState(
        () => _error = userErrorMessage(
          error,
          fallback: 'Failed to reset password.',
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final cardWidth = math.min(screenSize.width - 30, 388.0);
    final compact = screenSize.height < 740;
    final isSignUp = _mode == _AuthMode.signUp;

    return Scaffold(
      body: SizedBox.expand(
        child: Stack(
          children: [
            const SolenneBackground(child: SizedBox.expand()),

            // Cosmic Background
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _skyController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _CosmicAuthPainter(progress: _skyController.value),
                  );
                },
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 14,
                  ),
                  child: SolenneGlass(
                    width: cardWidth,
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
                    borderRadius: 28,
                    blur: 30,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo
                        Center(
                          child: Image.asset(
                            'assets/images/solenne.png',
                            width: compact ? 84 : 100,
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 14),

                        Text(
                          isSignUp
                              ? 'Create your\nprivate space.'
                              : 'Welcome back\nto Solenne.',
                          style: AppTextStyles.display(
                            fontSize: compact ? 26 : 29,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          isSignUp
                              ? 'Your private space for entries and reflection.'
                              : 'Return to the room you have been building.',
                          style: AppTextStyles.body(
                            fontSize: 12.5,
                            color: AppColors.shellstone.withValues(alpha: 0.78),
                            fontStyle: FontStyle.italic,
                          ),
                        ),

                        const SizedBox(height: 16),

                        _AuthModeSwitch(
                          mode: _mode,
                          onChanged: (mode) => setState(() {
                            _mode = mode;
                            _error = null;
                            _emailError = false;
                            _passwordError = false;
                            _usernameError = false;
                            _confirmPasswordError = false;
                          }),
                        ),

                        const SizedBox(height: 16),

                        if (isSignUp) ...[
                          _LiquidTextField(
                            controller: _displayNameController,
                            label: 'display name',
                            textInputAction: TextInputAction.next,
                            hasError: _usernameError,
                          ),
                          const SizedBox(height: 10),
                          _LiquidTextField(
                            controller: _usernameController,
                            label: 'unique username',
                            textInputAction: TextInputAction.next,
                            hasError:
                                _usernameError || _usernameAvailable == false,
                            onChanged: _checkUsername,
                          ),
                          if (_checkingUsername || _usernameAvailable != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 5, left: 4),
                              child: Text(
                                _checkingUsername
                                    ? 'Checking availability...'
                                    : _usernameAvailable == true
                                    ? 'Username is available'
                                    : 'Username is already taken',
                                style: AppTextStyles.mono(
                                  fontSize: 8,
                                  color: _usernameAvailable == false
                                      ? AppColors.nudgeWarm
                                      : AppColors.quicksand.withValues(
                                          alpha: 0.72,
                                        ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                        ],

                        _LiquidTextField(
                          controller: _emailController,
                          label: 'email',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          hasError: _emailError,
                        ),

                        const SizedBox(height: 10),

                        _LiquidTextField(
                          controller: _passwordController,
                          label: 'password',
                          obscureText: true,
                          textInputAction: isSignUp
                              ? TextInputAction.next
                              : TextInputAction.done,
                          hasError: _passwordError,
                        ),

                        if (isSignUp) ...[
                          const SizedBox(height: 14),
                          _LiquidTextField(
                            controller: _confirmPasswordController,
                            label: 'confirm password',
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            hasError: _confirmPasswordError,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your username is searchable. Journals stay private until you share one.',
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: AppColors.shellstone.withValues(
                                alpha: 0.58,
                              ),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _LegalAcceptanceRow(
                            value: _acceptedTerms,
                            prefix: 'I am 18+ and accept the ',
                            link: 'Terms and Conditions',
                            onChanged: (value) =>
                                setState(() => _acceptedTerms = value),
                            onOpen: () => _showLegalDocument(
                              context,
                              LegalDocumentKind.terms,
                            ),
                          ),
                          _LegalAcceptanceRow(
                            value: _acceptedPrivacy,
                            prefix: 'I acknowledge the ',
                            link: 'Privacy Policy',
                            onChanged: (value) =>
                                setState(() => _acceptedPrivacy = value),
                            onOpen: () => _showLegalDocument(
                              context,
                              LegalDocumentKind.privacy,
                            ),
                          ),
                          _LegalAcceptanceRow(
                            value: _acceptedAiConsent,
                            prefix: 'I explicitly give ',
                            link: 'Data & AI Consent',
                            onChanged: (value) =>
                                setState(() => _acceptedAiConsent = value),
                            onOpen: () => _showLegalDocument(
                              context,
                              LegalDocumentKind.aiConsent,
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        _AuthButton(
                          label: _loading
                              ? 'Please wait'
                              : isSignUp
                              ? 'Sign up'
                              : 'Log in',
                          onTap: _continue,
                        ),

                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: AppColors.quicksand.withValues(
                                alpha: 0.92,
                              ),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],

                        if (!isSignUp) ...[
                          const SizedBox(height: 12),
                          Center(
                            child: GestureDetector(
                              onTap: _loading ? null : _resetPassword,
                              child: Text(
                                'forgot password',
                                style: AppTextStyles.mono(
                                  fontSize: 10,
                                  color: AppColors.shellstone.withValues(
                                    alpha: 0.62,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],

                        const SizedBox(height: 14),

                        Center(
                          child: _AuthFooterSwitch(
                            isSignUp: isSignUp,
                            onTap: () => setState(() {
                              _mode = isSignUp
                                  ? _AuthMode.login
                                  : _AuthMode.signUp;
                              _error = null;
                              _emailError = false;
                              _passwordError = false;
                              _usernameError = false;
                              _confirmPasswordError = false;
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== Supporting Widgets ==================

class _AuthModeSwitch extends StatelessWidget {
  final _AuthMode mode;
  final ValueChanged<_AuthMode> onChanged;

  const _AuthModeSwitch({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.royalBlue.withValues(alpha: 0.28),
        border: Border.all(color: AppColors.sapphire.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          _AuthModeOption(
            label: 'Sign up',
            selected: mode == _AuthMode.signUp,
            onTap: () => onChanged(_AuthMode.signUp),
          ),
          _AuthModeOption(
            label: 'Log in',
            selected: mode == _AuthMode.login,
            onTap: () => onChanged(_AuthMode.login),
          ),
        ],
      ),
    );
  }
}

class _AuthModeOption extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AuthModeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: selected
                ? AppColors.quicksand.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Text(
            label,
            style: AppTextStyles.mono(
              fontSize: 11,
              color: selected
                  ? AppColors.quicksand.withValues(alpha: 0.95)
                  : AppColors.shellstone.withValues(alpha: 0.65),
            ),
          ),
        ),
      ),
    );
  }
}

class _LiquidTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool hasError;
  final ValueChanged<String>? onChanged;

  const _LiquidTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.hasError = false,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      cursorColor: AppColors.quicksand,
      style: AppTextStyles.body(
        fontSize: 15,
        color: AppColors.swanWing.withValues(alpha: 0.94),
      ),
      decoration: InputDecoration(
        labelText: label.toUpperCase(),
        labelStyle: AppTextStyles.mono(
          fontSize: 10,
          color: hasError
              ? Colors.red.withValues(alpha: 0.8)
              : AppColors.quicksand.withValues(alpha: 0.6),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError
                ? Colors.red.withValues(alpha: 0.5)
                : AppColors.sapphire.withValues(alpha: 0.35),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: hasError
                ? Colors.red.withValues(alpha: 0.8)
                : AppColors.quicksand.withValues(alpha: 0.55),
            width: 1.4,
          ),
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _AuthButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.quicksand.withValues(alpha: 0.55),
            width: 1.3,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.quicksand.withValues(alpha: 0.38),
              AppColors.sapphire.withValues(alpha: 0.28),
              Colors.white.withValues(alpha: 0.08),
            ],
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.mono(
            fontSize: 13.5,
            color: Colors.white.withValues(alpha: 0.96),
          ),
        ),
      ),
    );
  }
}

class _AuthFooterSwitch extends StatelessWidget {
  final bool isSignUp;
  final VoidCallback onTap;

  const _AuthFooterSwitch({required this.isSignUp, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: RichText(
        textAlign: TextAlign.center,
        text: TextSpan(
          style: AppTextStyles.body(
            fontSize: 13,
            color: AppColors.swanWing.withValues(alpha: 0.7),
          ),
          children: [
            TextSpan(
              text: isSignUp
                  ? 'Already have an account? '
                  : 'Are you new here? ',
            ),
            TextSpan(
              text: isSignUp ? 'Log in' : 'Sign up',
              style: AppTextStyles.body(
                fontSize: 13,
                color: AppColors.quicksand.withValues(alpha: 0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalAcceptanceRow extends StatelessWidget {
  const _LegalAcceptanceRow({
    required this.value,
    required this.prefix,
    required this.link,
    required this.onChanged,
    required this.onOpen,
  });

  final bool value;
  final String prefix;
  final String link;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Checkbox(
        value: value,
        onChanged: (next) => onChanged(next ?? false),
        activeColor: AppColors.quicksand,
        checkColor: AppColors.royalBlue,
        side: BorderSide(color: AppColors.shellstone.withValues(alpha: 0.45)),
      ),
      Expanded(
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              prefix,
              style: AppTextStyles.body(
                fontSize: 11,
                color: AppColors.shellstone.withValues(alpha: 0.68),
              ),
            ),
            GestureDetector(
              onTap: onOpen,
              child: Text(
                link,
                style: AppTextStyles.body(
                  fontSize: 11,
                  color: AppColors.quicksand,
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

Future<void> _showLegalDocument(BuildContext context, LegalDocumentKind kind) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.75),
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SolenneGlass(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          borderRadius: 26,
          tint: AppColors.sapphire,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      kind.title,
                      style: AppTextStyles.display(fontSize: 27),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              Text(
                'VERSION ${kind.version}',
                style: AppTextStyles.mono(
                  fontSize: 8,
                  color: AppColors.quicksand.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    kind.body.trim(),
                    style: AppTextStyles.body(
                      fontSize: 13,
                      color: AppColors.shellstone.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _CosmicAuthPainter extends CustomPainter {
  final double progress;
  const _CosmicAuthPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final random = math.Random(31);

    final blueGlow = Paint()
      ..shader =
          RadialGradient(
            colors: [
              AppColors.sapphire.withValues(alpha: 0.12),
              AppColors.royalBlue.withValues(alpha: 0.08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.72, size.height * 0.58),
              radius: size.shortestSide * 0.85,
            ),
          );
    canvas.drawRect(Offset.zero & size, blueGlow);

    // Stars
    for (int i = 0; i < 160; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = 0.3 + random.nextDouble() * 0.9;
      final shimmer =
          0.5 +
          0.4 * math.sin(progress * math.pi * 2 + random.nextDouble() * 10);

      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()..color = Colors.white.withValues(alpha: 0.18 + shimmer * 0.25),
      );
    }
  }

  @override
  bool shouldRepaint(_CosmicAuthPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
