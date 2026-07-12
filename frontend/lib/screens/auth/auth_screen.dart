import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../routing/fade_through_route.dart';
import '../../theme/app_theme.dart';
import '../../features/auth/auth_providers.dart';
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
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    if (_loading) return;
    final isSignUp = _mode == _AuthMode.signUp;
    final name = _usernameController.text.trim();
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
        _error = 'Enter a username.';
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

    setState(() {
      _loading = true;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      if (isSignUp) {
        await repository.signUp(name: name, email: email, password: password);
      } else {
        await repository.signIn(email: email, password: password);
        await repository.ensureUserDocument();
      }
      if (!mounted) return;
      Navigator.of(
        context,
      ).pushAndRemoveUntil(fadeThroughRoute(const AppShell()), (_) => false);
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
          _error = error.message ?? 'Authentication failed.';
        }
      });
    } catch (error) {
      setState(() => _error = error.toString());
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
          _error = error.message ?? 'Failed to reset password.';
        }
      });
    } catch (error) {
      setState(() => _error = error.toString());
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
                            controller: _usernameController,
                            label: 'username',
                            textInputAction: TextInputAction.next,
                            hasError: _usernameError,
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
                            'No one else sees what you write or record here.',
                            style: AppTextStyles.body(
                              fontSize: 12,
                              color: AppColors.shellstone.withValues(
                                alpha: 0.58,
                              ),
                              fontStyle: FontStyle.italic,
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

  const _LiquidTextField({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
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
