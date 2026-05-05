import "package:leetcards/Common/Constants.dart";
import "package:leetcards/Data/DatabaseService.dart";
import "package:leetcards/HomeScreen.dart";
import "package:leetcards/Login/LoginPage.dart";

import "dart:async";

import "package:firebase_analytics/firebase_analytics.dart";
import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

class LeetCardsApp extends StatefulWidget
{
  const LeetCardsApp({super.key});

  @override
  State<LeetCardsApp> createState() => LeetCardsAppState();
}

class LeetCardsAppState extends State<LeetCardsApp>
{
  bool m_IsDarkMode = true;
  bool m_GuestMode = false;
  User? _currentUser;
  bool _authInitialized = false;
  late final StreamSubscription<User?> _authSub;
  late final ThemeData _lightTheme;
  late final ThemeData _darkTheme;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  void initState()
  {
    super.initState();
    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (!mounted) return;

      if (user == null)
      {
        setState(()
        {
          _currentUser = user;
          _authInitialized = true;
          m_IsDarkMode = true;
        });
        return;
      }

      // Await the saved theme before flipping _currentUser so HomeScreen's
      // first frame renders with the correct theme.
      final saved = await DatabaseService.getDarkModePreference(user.uid);
      if (!mounted) return;

      // Discard if the user signed out during the await — applying would
      // resurrect the old auth state.
      if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;

      setState(()
      {
        _currentUser = user;
        _authInitialized = true;
        if (saved != null) m_IsDarkMode = saved;
      });
    });
    _lightTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.primary,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      textTheme: _buildTextTheme(Brightness.light),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(animationDuration: Duration.zero)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(animationDuration: Duration.zero)),
      textButtonTheme: TextButtonThemeData(style: ButtonStyle(animationDuration: Duration.zero)));
    _darkTheme = ThemeData(
      useMaterial3: true,
      colorSchemeSeed: AppColors.primary,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      textTheme: _buildTextTheme(Brightness.dark),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkBg,
        foregroundColor: AppColors.textPrimary,
        elevation: 2),
      elevatedButtonTheme: ElevatedButtonThemeData(style: ButtonStyle(animationDuration: Duration.zero)),
      outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(animationDuration: Duration.zero)),
      textButtonTheme: TextButtonThemeData(style: ButtonStyle(animationDuration: Duration.zero)));
  }

  @override
  void dispose()
  {
    _authSub.cancel();
    super.dispose();
  }

  void ToggleTheme()
  {
    final newValue = !m_IsDarkMode;
    setState(() => m_IsDarkMode = newValue);

    // Fire-and-forget — UI shouldn't wait on the Firestore round-trip.
    if (FirebaseAuth.instance.currentUser != null)
    {
      DatabaseService.setDarkModePreference(newValue);
    }
  }

  void _enterGuestMode()
  {
    FirebaseAnalytics.instance.logEvent(name: 'guest_continue');
    setState(()
    {
      m_GuestMode = true;
    });
  }

  void _returnToLogin()
  {
    setState(() => m_GuestMode = false);
    // popUntil clears any pushed routes (e.g. FlashcardGame from a locked-card
    // tap) so we land on LoginPage rather than leaving it underneath.
    _navKey.currentState?.popUntil((route) => route.isFirst);
  }

  TextTheme _buildTextTheme(Brightness brightness)
  {
    final base = GoogleFonts.plusJakartaSansTextTheme(
      ThemeData(brightness: brightness).textTheme);

    return base.copyWith(
      // Display — 700, tightest tracking
      displayLarge:  base.displayLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.57),
      displayMedium: base.displayMedium?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.45),
      displaySmall:  base.displaySmall?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.36),
      // Headline — 700 / 600
      headlineLarge:  base.headlineLarge?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.32),
      headlineMedium: base.headlineMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.28),
      headlineSmall:  base.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.24),
      // Title — 600
      titleLarge:  base.titleLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.22),
      titleMedium: base.titleMedium?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.16),
      titleSmall:  base.titleSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.14),
      // Body — 400
      bodyLarge:  base.bodyLarge?.copyWith(fontWeight: FontWeight.w400, letterSpacing: -0.16),
      bodyMedium: base.bodyMedium?.copyWith(fontWeight: FontWeight.w400, letterSpacing: -0.14),
      bodySmall:  base.bodySmall?.copyWith(fontWeight: FontWeight.w400, letterSpacing: -0.12),
      // Label / buttons — 600
      labelLarge:  base.labelLarge?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.14),
      labelMedium: base.labelMedium?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.12),
      labelSmall:  base.labelSmall?.copyWith(fontWeight: FontWeight.w500, letterSpacing: -0.11),
    );
  }

  Widget _buildHome()
  {
    if (!_authInitialized)
    {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_currentUser != null || m_GuestMode)
    {
      return HomeScreen(
        m_IsDarkMode: m_IsDarkMode,
        m_OnThemeToggle: ToggleTheme,
        m_OnReturnToLogin: _returnToLogin);
    }
    return LoginPage(m_OnGuestContinue: _enterGuestMode);
  }

  @override
  Widget build(BuildContext context)
  {
    final ThemeData activeTheme = m_IsDarkMode ? _darkTheme : _lightTheme;

    return MaterialApp(
      title: "LeetCards",
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      // Keep MaterialApp.theme static so AnimatedTheme never fires.
      // The active theme is injected synchronously via builder below.
      theme: _lightTheme,
      builder: (context, child) => Theme(data: activeTheme, child: child!),
      navigatorObservers: [
        FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
      ],
      home: _buildHome(),
    );
  }
}
