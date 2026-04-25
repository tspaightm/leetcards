import "package:leetcards/Common/Constants.dart";
import "package:leetcards/Login/AuthService.dart";

import "package:flutter/material.dart";
import "package:font_awesome_flutter/font_awesome_flutter.dart";

class LoginPage extends StatelessWidget
{
  final VoidCallback? m_OnGuestContinue;

  const LoginPage({super.key, this.m_OnGuestContinue});

  static final AuthService _authService = AuthService();

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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _signIn(context, _authService.signInWithGoogle),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black87,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.grey.shade300))),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.g_mobiledata, size: 28, color: Colors.blue),
                          SizedBox(width: 10),
                          Text('Continue with Google', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ]))),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _signIn(context, _authService.signInWithGitHub),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF24292E),
                        foregroundColor: Colors.white,
                        elevation: 1,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          FaIcon(FontAwesomeIcons.github, size: 20),
                          SizedBox(width: 10),
                          Text('Continue with GitHub', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ]))),
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

  Future<void> _signIn(BuildContext context, Future<dynamic> Function() signInMethod) async
  {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try
    {
      final userCred = await signInMethod();
      if (userCred == null)
      {
        messenger.showSnackBar(
          const SnackBar(content: Text("Sign-in failed or cancelled.")));
      }
      else if (navigator.canPop())
      {
        // LoginPage was pushed on top of HomeScreen (e.g. from a locked card).
        // Pop back — the StreamBuilder handles navigation when it's the root route.
        navigator.pop();
      }
    }
    catch (e)
    {
      messenger.showSnackBar(
        const SnackBar(content: Text("Error signing in. Please try again.")));
    }
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
