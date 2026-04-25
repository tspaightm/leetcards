import 'package:leetcards/Common/Constants.dart';
import 'package:flutter/material.dart';

class DifficultyPercentageCard extends StatelessWidget
{
  final Difficulty m_Difficulty;
  final double? m_Percentage;
  final VoidCallback? m_OnTap;
  final bool m_ShowProgress;
  final bool m_IsLocked;

  const DifficultyPercentageCard
  ({
    super.key,
    required this.m_Difficulty,
    required this.m_Percentage,
    this.m_OnTap,
    this.m_ShowProgress = true,
    this.m_IsLocked = false,
  });

  @override
  Widget build(BuildContext context)
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEmpty = m_Percentage == null;
    final Color ringColor = isEmpty
      ? (isDark ? Colors.grey[600]! : Colors.grey[400]!)
      : (isDark ? const Color(0xFFA5B4FC) : AppColors.primary);
    final Color cardColor = isDark ? const Color(0xFF1A1F35) : Colors.white;

    // Tier-locked cards (algorithm cards for non-subscribers)
    if (m_IsLocked)
    {
      final Color mutedColor = isDark ? Colors.grey[600]! : Colors.grey[400]!;
      final String tierLabel = m_Difficulty == Difficulty.Easy ? 'Plus' : 'Pro';

      return Material(
        animationDuration: Duration.zero,
        elevation: 0,
        color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
            width: 1.5)),
        child: InkWell(
          onTap: m_OnTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  m_Difficulty.Name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: mutedColor)),
                const SizedBox(height: 4),
                Icon(Icons.lock_outline, size: 18, color: mutedColor),
                const SizedBox(height: 4),
                Text(
                  'Unlock with $tierLabel',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.indigo,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.indigo)),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      animationDuration: Duration.zero,
      elevation: isEmpty ? 0 : 2,
      color: isEmpty ? (isDark ? AppColors.darkSurface : Colors.grey.shade100) : cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? Colors.grey[700]! : Colors.grey.shade300,
          width: isEmpty ? 1.5 : 2)),
      child: InkWell(
        onTap: m_OnTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                m_Difficulty.Name,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isEmpty
                    ? (isDark ? Colors.grey[600]! : Colors.grey[400]!)
                    : (isDark ? Colors.grey[300]! : Colors.grey[800]!))),
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      value: (m_Percentage ?? 0) / 100,
                      strokeWidth: 5,
                      backgroundColor: isDark ? Colors.grey[700] : Colors.grey.shade200,
                      valueColor: AlwaysStoppedAnimation<Color>(ringColor))),
                  Text(
                    isEmpty ? '0%' : '${m_Percentage!.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: ringColor)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
