import 'package:leetcards/Common/Constants.dart';
import 'package:leetcards/Data/DatabaseService.dart';
import 'package:leetcards/Data/RemoteConfigService.dart';
import 'package:leetcards/Login/AuthService.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ProfilePage extends StatefulWidget
{
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
{
  UserTier m_CurrentTier = UserTier.Free;
  bool m_IsLoading = true;
  bool m_IsSaving = false;
  bool m_IsDeleting = false;
  bool _photoLoadFailed = false;

  @override
  void initState()
  {
    super.initState();
    _loadTier();
  }

  Future<void> _loadTier() async
  {
    final tier = await DatabaseService.getUserTier();
    setState(()
    {
      m_CurrentTier = tier;
      m_IsLoading = false;
    });
  }

  Future<void> _selectTier(UserTier tier) async
  {
    if (tier == m_CurrentTier || m_IsSaving) return;

    setState(()
    {
      m_CurrentTier = tier;
      m_IsSaving = true;
    });
    await DatabaseService.setUserTier(tier);
    if (mounted) setState(() => m_IsSaving = false);
  }

  @override
  Widget build(BuildContext context)
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Image.asset('assets/images/logo.png')),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            tooltip: 'Home'),
          const SizedBox(width: 16),
        ]),
      body: m_IsLoading
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildUserHeader(user, isDark),
                const SizedBox(height: 36),
                const Text('Subscription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  'Toggle freely — payment coming soon.',
                  style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[500] : Colors.grey[600])),
                const SizedBox(height: 16),
                _buildTierCard(
                  isDark: isDark,
                  tier: UserTier.Free,
                  icon: Icons.school_outlined,
                  features: const ['Fundamental flashcards', 'Progress tracking'],
                ),
                const SizedBox(height: 12),
                _buildTierCard(
                  isDark: isDark,
                  tier: UserTier.Plus,
                  icon: Icons.bolt_outlined,
                  features: const ['Everything in Free', 'Algorithm Easy questions'],
                ),
                const SizedBox(height: 12),
                _buildTierCard(
                  isDark: isDark,
                  tier: UserTier.Pro,
                  icon: Icons.workspace_premium_outlined,
                  features: const ['Everything in Plus', 'Algorithm Medium & Hard questions'],
                ),
                const SizedBox(height: 40),
                _buildDeleteAccount(isDark),
              ],
            ),
          ),
    );
  }

  Widget _buildDeleteAccount(bool isDark)
  {
    return Center(
      child: TextButton.icon(
        onPressed: m_IsDeleting ? null : _confirmDeleteAccount,
        icon: m_IsDeleting
          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
          : const Icon(Icons.delete_outline, size: 18, color: Colors.red),
        label: Text(
          m_IsDeleting ? 'Deleting…' : 'Delete account',
          style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500))));
  }

  Future<void> _confirmDeleteAccount() async
  {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete account?'),
        content: const Text(
          'This permanently deletes your account and all progress. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ]));

    if (confirmed != true || !mounted) return;

    setState(() => m_IsDeleting = true);
    try
    {
      await AuthService().deleteAccount();
      // Root StreamBuilder now shows LoginPage, but this route is still on
      // top of the navigator — pop everything pushed above the root so the
      // user actually sees the login screen.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    }
    catch (e)
    {
      if (mounted)
      {
        setState(() => m_IsDeleting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete account: $e')));
      }
    }
  }

  Widget _buildUserHeader(User? user, bool isDark)
  {
    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          backgroundImage: user?.photoURL != null && !_photoLoadFailed ? NetworkImage(user!.photoURL!) : null,
          onBackgroundImageError: user?.photoURL != null && !_photoLoadFailed
            ? (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _photoLoadFailed = true); })
            : null,
          child: user?.photoURL == null || _photoLoadFailed
            ? Text(
                (user?.displayName?.isNotEmpty == true ? user!.displayName![0] : '?').toUpperCase(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary))
            : null),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user?.displayName ?? 'User',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(
                user?.email ?? '',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  String _tierPrice(UserTier tier)
  {
    switch (tier)
    {
      case UserTier.Free:  return 'Free';
      case UserTier.Plus:  return '\$${RemoteConfigService.plusPricePerMonth} / month';
      case UserTier.Pro:   return '\$${RemoteConfigService.proPricePerMonth} / month';
    }
  }

  Widget _buildTierCard({
    required bool isDark,
    required UserTier tier,
    required IconData icon,
    required List<String> features,
  })
  {
    final bool isSelected = m_CurrentTier == tier;
    final Color accentColor = _tierColor(tier);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isSelected
          ? accentColor.withValues(alpha: isDark ? 0.15 : 0.08)
          : isDark ? AppColors.darkSurface : Colors.white,
        border: Border.all(
          color: isSelected ? accentColor : (isDark ? Colors.grey[700]! : Colors.grey.shade300),
          width: isSelected ? 2 : 1.5)),
      child: InkWell(
        onTap: m_IsSaving ? null : () => _selectTier(tier),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: accentColor)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          tier.Name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? accentColor : null)),
                        const Spacer(),
                        Text(
                          _tierPrice(tier),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.grey[400] : Colors.grey[600])),
                      ]),
                    const SizedBox(height: 6),
                    ...features.map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.check, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Expanded(child: Text(f, style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[300] : Colors.grey[700]))),
                        ],
                      ))),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (isSelected)
                Icon(Icons.check_circle_rounded, color: accentColor, size: 22)
              else
                Icon(Icons.circle_outlined, color: isDark ? Colors.grey[600] : Colors.grey[400], size: 22),
            ],
          ),
        ),
      ),
    );
  }

  Color _tierColor(UserTier tier)
  {
    switch (tier)
    {
      case UserTier.Free:  return AppColors.primary;
      case UserTier.Plus:  return AppColors.purple;
      case UserTier.Pro:   return const Color(0xFFD97706); // amber
    }
  }
}
