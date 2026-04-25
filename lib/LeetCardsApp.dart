import "package:leetcards/Common/Constants.dart";
import "package:leetcards/HomeScreen.dart";
import "package:leetcards/Login/LoginPage.dart";

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
  late final Stream<User?> _authStream;
  late final ThemeData _lightTheme;
  late final ThemeData _darkTheme;

  @override
  void initState()
  {
    super.initState();
    _authStream = FirebaseAuth.instance.authStateChanges();
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

  void ToggleTheme()
  {
    setState(()
    {
      m_IsDarkMode = !m_IsDarkMode;
    });
  }

  void _enterGuestMode()
  {
    setState(()
    {
      m_GuestMode = true;
    });
  }

  void _exitGuestMode()
  {
    setState(()
    {
      m_GuestMode = false;
    });
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

  @override
  Widget build(BuildContext context)
  {
    final ThemeData activeTheme = m_IsDarkMode ? _darkTheme : _lightTheme;

    return MaterialApp(
      title: "LeetCards App",
      debugShowCheckedModeBanner: false,
      // Keep MaterialApp.theme static so AnimatedTheme never fires.
      // The active theme is injected synchronously via builder below.
      theme: _lightTheme,
      builder: (context, child) => Theme(data: activeTheme, child: child!),
      home: StreamBuilder<User?>(
        stream: _authStream,
        builder: (context, snapshot)
        {
          if (snapshot.connectionState == ConnectionState.waiting)
          {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
          }

          if (snapshot.hasData || m_GuestMode)
          {
            return HomeScreen(
              m_IsDarkMode: m_IsDarkMode,
              m_OnThemeToggle: ToggleTheme,
              m_OnSignOut: _exitGuestMode);
          }

          return LoginPage(m_OnGuestContinue: _enterGuestMode);
        }),
    );
  }
}
