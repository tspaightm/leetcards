import "package:flutter/material.dart";

class AppColors
{
  // Primary
  static const Color primary    = Color.fromARGB(255, 76, 78, 237); // Indigo — buttons, icons
  static const Color purple     = Color(0xFF7C3AED); // Purple — logo identity
  static const Color indigo     = Color(0xFF6366F1); // Indigo — links, brand accent

  // Backgrounds
  static const Color darkBg      = Color(0xFF0B0F1A); // Main dark background
  static const Color darkSurface = Color(0xFF111827); // Dark cards / surfaces
  static const Color lightBg     = Color(0xFFF8FAFC); // Light background

  // Text
  static const Color textPrimary = Color(0xFFE5E7EB); // Primary text (dark mode)
}

class AppConstants
{
  static const String freePreviewCollectionId = 'Free Preview';
}

enum CardType { fundamental, algorithm }

enum UserTier { Free, Plus, Pro }
extension UserTierExtension on UserTier
{
  String get Name
  {
    switch (this)
    {
      case UserTier.Free: return "Free";
      case UserTier.Plus: return "Plus";
      case UserTier.Pro:  return "Pro";
    }
  }
}

enum BillingCycle { Monthly, Yearly }
extension BillingCycleExtension on BillingCycle
{
  String get Name
  {
    switch (this)
    {
      case BillingCycle.Monthly: return "Monthly";
      case BillingCycle.Yearly:  return "Yearly";
    }
  }
}

enum Difficulty { Easy, Medium, Hard }
extension DifficultyExtension on Difficulty
{
  String get Name
  {
    switch (this)
    {
      case Difficulty.Easy:   return "Easy";
      case Difficulty.Medium: return "Medium";
      case Difficulty.Hard:   return "Hard";
    }
  }
}