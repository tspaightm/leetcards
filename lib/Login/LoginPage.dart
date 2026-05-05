import "package:leetcards/Common/Constants.dart";
import "package:leetcards/Login/AuthService.dart";

import "dart:io" show Platform;

import "package:flutter/foundation.dart" show kIsWeb;
import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

class LoginPage extends StatelessWidget
{
  final VoidCallback? m_OnGuestContinue;

  const LoginPage({super.key, this.m_OnGuestContinue});

  static final AuthService _authService = AuthService();

  // Apple Sign-In on Android requires a separate web auth flow (Service ID +
  // redirect URI). Skipped for v1 — Android users can still use Google or GitHub.
  static final bool _showApple = kIsWeb || !Platform.isAndroid;

  @override
  Widget build(BuildContext context)
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  const Spacer(flex: 2),

                  // Logo / app identity
                  Image.asset(
                    isDark ? 'assets/images/full_dark_logo.png' : 'assets/images/full_light_logo.png',
                    width: 350),
                  const SizedBox(height: 8),
                  Text(
                    'Sharpen your skills. One card at a time.',
                    style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600])),

                  const Spacer(flex: 2),

                  // Feature highlights
                  _featureRow(Icons.quiz_outlined, 'Fundamentals', 'Core CS concepts as flashcards.', isDark),
                  const SizedBox(height: 14),
                  _featureRow(Icons.code, 'Algorithms', 'Coding prompts with guided questions.', isDark),
                  const SizedBox(height: 14),
                  _featureRow(Icons.bar_chart, 'Study anywhere', 'Quick sessions for bus rides, lunch breaks, and downtime.', isDark),

                  const Spacer(flex: 3),

                  _buildSignInButton(
                    context: context,
                    isDark: isDark,
                    onPressed: () => _signIn(context, _authService.signInWithGoogle),
                    icon: Image.asset('assets/images/google_g.png', width: 20, height: 20),
                    label: 'Continue with Google'),
                  if (_showApple) ...[
                    const SizedBox(height: 12),
                    _buildSignInButton(
                      context: context,
                      isDark: isDark,
                      onPressed: () => _signIn(context, _authService.signInWithApple),
                      icon: FaIcon(FontAwesomeIcons.apple, size: 22, color: isDark ? Colors.white : Colors.black),
                      label: 'Continue with Apple'),
                  ],
                  const SizedBox(height: 12),
                  _buildSignInButton(
                    context: context,
                    isDark: isDark,
                    onPressed: () => _signIn(context, _authService.signInWithGitHub),
                    icon: FaIcon(FontAwesomeIcons.github, size: 20, color: isDark ? Colors.white : Colors.black),
                    label: 'Continue with GitHub'),
                  const SizedBox(height: 12),
                  Text(
                    'Free to start. No credit card required.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[600] : Colors.grey[500])),
                  const SizedBox(height: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: m_OnGuestContinue ?? () => Navigator.of(context).pop(),
                      child: Text(
                        'Continue without signing in',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                          decoration: TextDecoration.underline,
                          decorationColor: isDark ? Colors.grey[500] : Colors.grey[400])))),

                  const Spacer(flex: 1),
                ],
              ),
            ),
          ),
      ))),
    );
  }

  Future<void> _signIn(BuildContext context, Future<SignInResult> Function() signInMethod) async
  {
    final messenger = ScaffoldMessenger.of(context);

    final result = await signInMethod();

    switch (result)
    {
      case SignInSuccess():
        // _buildHome swaps to HomeScreen when _currentUser updates.
        break;
      case SignInCancelled():
        break;
      case SignInConflict():
        messenger.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 6),
            content: Text(
              'An account with this email already exists. Please sign in with the method you used originally.')));
      case SignInError():
        messenger.showSnackBar(
          const SnackBar(content: Text("Error signing in. Please try again.")));
    }
  }

  Widget _buildSignInButton({
    required BuildContext context,
    required bool isDark,
    required VoidCallback onPressed,
    required Widget icon,
    required String label,
  })
  {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black87,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isDark ? Colors.grey[800]! : Colors.grey.shade300,
              width: 1))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 22, height: 22, child: Center(child: icon)),
            const SizedBox(width: 12),
            Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ])));
  }

  Widget _featureRow(IconData icon, String title, String description, bool isDark)
  {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: AppColors.primary)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Text(description, style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }
}
