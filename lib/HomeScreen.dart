import "package:leetcards/Common/Constants.dart";
import "package:leetcards/Flashcards/AlgorithmFlashcardGame.dart";
import "package:leetcards/Flashcards/FundamentalFlashcardGame.dart";
import "package:leetcards/Feedback/FeedbackPage.dart";
import "package:leetcards/Login/AuthService.dart";
import "package:leetcards/Data/DatabaseService.dart";
import "package:leetcards/Progress/ProgressWidgets.dart";
import "package:leetcards/Profile/ProfilePage.dart";

import "dart:async";

import "package:flutter/material.dart";
import "package:firebase_auth/firebase_auth.dart";

class _ProfileMenuContent extends PopupMenuEntry<String>
{
  final User user;
  final VoidCallback onDarkModeToggle;
  final Future<void> Function() onSignOut;

  const _ProfileMenuContent({required this.user, required this.onDarkModeToggle, required this.onSignOut});

  @override
  double get height => 0; // sized by content

  @override
  bool represents(String? value) => false;

  @override
  State<_ProfileMenuContent> createState() => _ProfileMenuContentState();
}

class _ProfileMenuContentState extends State<_ProfileMenuContent>
{
  Widget _menuRow({required Widget icon, required String label, Color? color}) =>
    Row(children: [
      icon,
      const SizedBox(width: 12),
      Text(label, style: TextStyle(color: color)),
    ]);

  @override
  Widget build(BuildContext context)
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color iconColor = Theme.of(context).colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.user.displayName ?? 'User',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(widget.user.email ?? '',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ))),
        Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey.shade300),
        InkWell(
          onTap: () => Navigator.pop(context, 'account'),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: kMinInteractiveDimension,
              child: _menuRow(
                icon: Icon(Icons.workspace_premium_outlined, size: 20, color: iconColor),
                label: 'Account')))),
        InkWell(
          onTap: widget.onDarkModeToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: kMinInteractiveDimension,
              child: Row(children: [
                Icon(isDark ? Icons.dark_mode : Icons.light_mode, size: 20, color: iconColor),
                const SizedBox(width: 12),
                Text('Dark Mode', style: TextStyle(color: iconColor)),
                const Spacer(),
                IgnorePointer(
                  child: Switch(
                    value: isDark,
                    onChanged: (_) {},
                    activeColor: Colors.orange,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey[400],
                    thumbIcon: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                        ? null
                        : const Icon(Icons.circle, color: Colors.transparent)),
                    trackOutlineColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                        ? Colors.transparent
                        : Colors.grey[400]))),
              ])))),
        Divider(height: 1, color: isDark ? Colors.grey[700] : Colors.grey.shade300),
        InkWell(
          onTap: () async {
            // Remove the popup route instantly (no animation) so the widget
            // tree is clean before the auth state change triggers a rebuild.
            final route = ModalRoute.of(context);
            if (route != null) Navigator.of(context).removeRoute(route);
            await widget.onSignOut();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: kMinInteractiveDimension,
              child: _menuRow(
                icon: const Icon(Icons.logout, size: 20, color: Colors.red),
                label: 'Sign Out',
                color: Colors.red)))),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget
{
  final bool m_IsDarkMode;
  final VoidCallback m_OnThemeToggle;
  final VoidCallback? m_OnReturnToLogin;

  const HomeScreen
  ({
    super.key,
    required this.m_IsDarkMode,
    required this.m_OnThemeToggle,
    this.m_OnReturnToLogin,
  });

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen>
{
  bool get _isSignedIn => FirebaseAuth.instance.currentUser != null;

  List<String> m_AvailableTopics = [];
  String? m_SelectedTopic;

  List<Map<String, dynamic>> m_AvailableCollections = [];
  String? m_SelectedCollectionId;

  Map<Difficulty, double?> m_FundamentalDifficultyPercentages = {};
  Map<Difficulty, double?> m_AlgorithmDifficultyPercentages = {};

  UserTier m_UserTier = UserTier.Free;
  bool m_IsLoadingProgress = true;
  String? m_ProgressError;
  late final StreamSubscription<User?> _authSub;
  late final StreamSubscription<UserTier> _tierSub;

  @override
  void initState()
  {
    super.initState();
    // skip(1): authStateChanges emits the current user on subscribe — we already
    // handle the mount case with the direct loadProgress() below. Listener only
    // fires on actual changes (e.g. account linking promotes guest → signed-in).
    _authSub = FirebaseAuth.instance.authStateChanges().skip(1).listen((_)
    {
      loadProgress();
    });
    // Webhook-driven tier updates (e.g. payment lands mid-session) → silently
    // refresh progress so the free-preview gate adjusts without a spinner flash.
    _tierSub = DatabaseService.tierChanges.listen((_) => loadProgress(silent: true));
    loadTopics();
    loadCollections();
    loadProgress();
  }

  @override
  void dispose()
  {
    _authSub.cancel();
    _tierSub.cancel();
    super.dispose();
  }

  Future<void> loadTopics() async
  {
    final topics = await DatabaseService.getAvailableTopics();
    if (mounted) setState(() { m_AvailableTopics = topics; });
  }

  Future<void> loadCollections() async
  {
    final collections = await DatabaseService.getAvailableCollections();
    if (mounted) setState(() { m_AvailableCollections = collections; });
  }

  Future<void> loadProgress({bool silent = false}) async
  {
    if (!mounted) return;
    if (!silent)
    {
      setState(()
      {
        m_IsLoadingProgress = true;
        m_ProgressError = null;
      });
    }

    final swTotal = Stopwatch()..start();
    try
    {
      final swTier = Stopwatch()..start();
      final tier = await DatabaseService.getUserTier();
      debugPrint('[perf] getUserTier: ${swTier.elapsedMilliseconds}ms');

      final String? algorithmCollectionId = (!_isSignedIn || tier == UserTier.Free)
        ? AppConstants.freePreviewCollectionId
        : m_SelectedCollectionId;

      Future<T> timed<T>(String label, Future<T> Function() action) async
      {
        final sw = Stopwatch()..start();
        final result = await action();
        debugPrint('[perf] $label: ${sw.elapsedMilliseconds}ms');
        return result;
      }

      final results = await (
        timed('algo-pct', () => DatabaseService.getAlgorithmCompletionPercentagesByDifficulty(
          topic: m_SelectedTopic,
          collectionId: algorithmCollectionId)),
        timed('fund-pct', () => DatabaseService.getFundamentalCompletionPercentagesByDifficulty(
          topic: m_SelectedTopic)),
      ).wait;

      if (!mounted) return;
      setState(()
      {
        m_UserTier = tier;
        m_AlgorithmDifficultyPercentages = results.$1;
        m_FundamentalDifficultyPercentages = results.$2;
        m_IsLoadingProgress = false;
        m_ProgressError = null;
      });
      debugPrint('[perf] loadProgress total: ${swTotal.elapsedMilliseconds}ms');
    }
    catch (e)
    {
      if (!mounted) return;
      setState(()
      {
        m_IsLoadingProgress = false;
        m_ProgressError = 'Failed to load progress. Please try again.';
      });
    }
  }

  void _showHelpSheet()
  {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Help',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 250),
      transitionBuilder: (ctx, animation, _, child)
      {
        final topOffset = MediaQuery.of(ctx).padding.top + 48;
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return Stack(
          children: [
            Positioned(
              top: topOffset, left: 0, right: 0, bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(ctx).pop(),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0, end: 0.45).animate(curved),
                  child: const ColoredBox(color: Colors.black))),
            ),
            Positioned(
              top: topOffset, left: 0, right: 0, bottom: 0,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.topCenter,
                  heightFactor: curved.value,
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
      pageBuilder: (context, anim, __) => GestureDetector(
        onVerticalDragEnd: (details)
        {
          if ((details.primaryVelocity ?? 0) < -300) Navigator.of(context).pop();
        },
        child: Align(
          alignment: Alignment.topCenter,
          child: Material(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
          elevation: 4,
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('How to use LeetCards',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _helpRow(Icons.filter_list, 'Pick a topic', 'Filter by Arrays, Strings, DP, and more.'),
                const SizedBox(height: 12),
                _helpRow(Icons.quiz_outlined, 'Fundamentals', 'Flashcards covering core computer science concepts.'),
                const SizedBox(height: 12),
                _helpRow(Icons.code, 'Algorithms', 'Coding prompts to sharpen your problem-solving.'),
                const SizedBox(height: 12),
                _helpRow(Icons.bar_chart, 'Track progress', 'See how much you\'ve completed across difficulties.'),
                const SizedBox(height: 20),
                Divider(height: 1, color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey.shade300),
                const SizedBox(height: 12),
                InkWell(
                  onTap: ()
                  {
                    Navigator.of(context).pop();
                    Navigator.of(this.context).push(
                      MaterialPageRoute(builder: (_) => const FeedbackPage()));
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 20, color: AppColors.primary),
                        const SizedBox(width: 12),
                        const Text('Send feedback', style: TextStyle(fontWeight: FontWeight.w600)),
                      ]))),
              ],
            ),
          ),
        ),
      ),
    ),
    );
  }

  Widget _helpRow(IconData icon, String title, String description)
  {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(description, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProfileMenu()
  {
    final user = FirebaseAuth.instance.currentUser;

    return PopupMenuButton<String>(
      icon: const Icon(Icons.person_outline),
      tooltip: 'Profile',
      onSelected: (value) async
      {
        switch (value)
        {
          case 'account':
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
            if (mounted) loadProgress();
        }
      },
      itemBuilder: (context) => [
        _ProfileMenuContent(
          user: user!,
          onDarkModeToggle: widget.m_OnThemeToggle,
          onSignOut: () async {
            await AuthService().signOut();
            if (mounted) widget.m_OnReturnToLogin?.call();
          }),
      ]);
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 48,
        leading: Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Image.asset('assets/images/logo.png')),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpSheet,
            tooltip: 'Help'),
          if (_isSignedIn)
            _buildProfileMenu(),
          const SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
        onRefresh: loadProgress,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              buildWelcomeSection(),
              const SizedBox(height: 36),
              buildTopicChips(),
              const SizedBox(height: 36),
              if (m_IsLoadingProgress)
                buildProgressLoading()
              else if (m_ProgressError != null)
                buildProgressError()
              else
                buildProgressOverview(),
            ],
          ),
        ),
      )),
    );
  }

  Widget buildWelcomeSection()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _isSignedIn ? 'Welcome back!' : 'Welcome!',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(
          _isSignedIn ? 'Pick up where you left off.' : 'Get started studying below.',
          style: TextStyle(
            fontSize: 15,
            color: Theme.of(context).brightness == Brightness.dark
              ? Colors.grey[400]
              : Colors.grey[600])),
      ],
    );
  }

  Widget buildTopicChips()
  {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip("All", m_SelectedTopic == null, () { setState(() => m_SelectedTopic = null); loadProgress(); }),
          const SizedBox(width: 8),
          ...m_AvailableTopics.map((topic) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _buildChip(topic, m_SelectedTopic == topic, () { setState(() => m_SelectedTopic = topic); loadProgress(); }))),
        ],
      ));
  }

  Widget _buildChip(String label, bool selected, VoidCallback onTap,
    {double hPad = 16, double vPad = 8, double fontSize = 13})
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
        decoration: BoxDecoration(
          color: selected
            ? AppColors.primary
            : isDark ? Colors.grey[800] : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
              ? AppColors.primary
              : isDark ? Colors.grey[600]! : Colors.grey.shade400,
            width: 1.5)),
        child: Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w500,
            color: selected
              ? Colors.white
              : isDark ? Colors.grey[300] : Colors.grey[800])))));
  }

  Widget buildProgressOverview()
  {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Your Progress', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.refresh, size: 18),
              onPressed: loadProgress,
              tooltip: 'Refresh',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints()),
          ],
        ),
        const SizedBox(height: 12),

        if (!m_IsLoadingProgress && !_isSignedIn) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 36),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Flexible(
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => widget.m_OnReturnToLogin?.call(),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(
                          text: 'Sign in',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.indigo,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.indigo)),
                        TextSpan(
                          text: ' to track your progress.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.grey[400] : Colors.grey[600])),
                      ]))))),
              ],
            ),
          ),
        ],

        buildSectionHeader(Icons.quiz_outlined, "Fundamentals"),
        const SizedBox(height: 12),
        buildDifficultyGrid(m_FundamentalDifficultyPercentages, (difficulty) =>
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => FundamentalFlashcardGame(
              m_Difficulty: difficulty,
              m_Topic: m_SelectedTopic)))
          .then((_) => loadProgress())),
        const SizedBox(height: 36),

        _buildAlgorithmsSectionHeader(),
        const SizedBox(height: 12),
        buildDifficultyGrid(
          m_AlgorithmDifficultyPercentages,
          (difficulty) => Navigator.push(context, MaterialPageRoute(
            builder: (context) => AlgorithmFlashcardGame(
              m_Difficulty: difficulty,
              m_Topic: m_SelectedTopic,
              m_CollectionId: _effectiveCollectionId(_isSignedIn, difficulty),
              m_OnReturnToLogin: widget.m_OnReturnToLogin)))
          .then((_) => loadProgress()),
          isLockedFor: _algorithmLockPredicate(_isSignedIn),
          onLockedTap: _isSignedIn
            ? () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()))
                .then((_) => loadProgress())
            : () => widget.m_OnReturnToLogin?.call()),
      ],
    );
  }

  Widget buildSectionHeader(IconData icon, String title)
  {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildAlgorithmsSectionHeader()
  {
    return Row(
      children: [
        Icon(Icons.code, size: 20, color: AppColors.primary),
        const SizedBox(width: 8),
        const Text('Algorithms', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        if (_isSignedIn && m_UserTier != UserTier.Free && m_AvailableCollections.isNotEmpty) ...[
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildChip('All', m_SelectedCollectionId == null, ()
                  {
                    setState(() => m_SelectedCollectionId = null);
                    loadProgress();
                  }, hPad: 10, vPad: 5, fontSize: 11),
                  ...m_AvailableCollections.map((c)
                  {
                    final id = c['id'] as String;
                    final name = c['name'] as String? ?? id;
                    return Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: _buildChip(name, m_SelectedCollectionId == id, ()
                      {
                        setState(() => m_SelectedCollectionId = id);
                        loadProgress();
                      }, hPad: 10, vPad: 5, fontSize: 11));
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  bool Function(Difficulty)? _algorithmLockPredicate(bool isSignedIn)
  {
    if (isSignedIn && m_UserTier == UserTier.Pro) return null;
    return (d) => d != Difficulty.Easy;
  }

  String? _effectiveCollectionId(bool isSignedIn, Difficulty difficulty)
  {
    if (difficulty == Difficulty.Easy && (!isSignedIn || m_UserTier == UserTier.Free))
    {
      return AppConstants.freePreviewCollectionId;
    }
    return m_SelectedCollectionId;
  }

  Widget buildDifficultyGrid(
    Map<Difficulty, double?> percentages,
    void Function(Difficulty) onTap,
    {bool Function(Difficulty)? isLockedFor, VoidCallback? onLockedTap})
  {
    final bool allLocked = isLockedFor != null && Difficulty.values.every((d) => isLockedFor(d));
    final double minHeight = allLocked ? 110.0 : 120.0;
    const double aspectRatio = 1.2;

    return LayoutBuilder(
      builder: (context, constraints)
      {
        final double cardWidth = (constraints.maxWidth - 24) / 3;
        final double cardHeight = (cardWidth / aspectRatio).clamp(minHeight, double.infinity);

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: cardHeight),
          itemCount: 3,
          itemBuilder: (context, index)
          {
            final Difficulty difficulty = Difficulty.values[index];
            final bool isLocked = isLockedFor?.call(difficulty) ?? false;

            final double? pct = percentages[difficulty];
            return DifficultyPercentageCard(
              m_Difficulty: difficulty,
              m_Percentage: pct,
              m_ShowProgress: true,
              m_IsLocked: isLocked,
              m_OnTap: (isLocked ? onLockedTap : pct != null ? () => onTap(difficulty) : null));
          },
        );
      },
    );
  }

  Widget buildProgressLoading()
  {
    return const Center(
      heightFactor: 4,
      child: CircularProgressIndicator());
  }

  Widget buildProgressError()
  {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(m_ProgressError!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: loadProgress,
            child: const Text("Retry")),
        ],
      ),
    );
  }
}
