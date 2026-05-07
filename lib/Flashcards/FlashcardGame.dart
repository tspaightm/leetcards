import "package:leetcards/Common/Constants.dart";
import "package:leetcards/Data/DatabaseService.dart";
import "package:leetcards/Feedback/FeedbackPage.dart";

import "package:flutter/material.dart";

abstract class FlashcardGame<T> extends StatefulWidget
{
  final Difficulty m_Difficulty;
  final String? m_Topic;

  const FlashcardGame
  ({
    super.key,
    required this.m_Difficulty,
    required this.m_Topic,
  });

  @override
  State<FlashcardGame<T>> createState();
}

abstract class FlashcardGameState<T, W extends FlashcardGame<T>> extends State<W>
{
  T? m_CachedFlashcard;

  // Shared list-of-cards state. Each subclass populates m_EligibleIds in its
  // own loadAvailableCards() flow; the base class drives prefetch + caching.
  List<String> m_EligibleIds = [];
  int m_CurrentIndex = 0;
  final Map<String, T> m_CardCache = {};

  // Progress numerators kept on the state so the progress bar updates locally
  // without round-tripping through the database after each completion.
  double? m_CompletionPercentage;
  int m_TotalCards = 0;
  int m_CompletedCards = 0;

  bool get isLoading => false;
  String? get errorMessage => null;
  bool get hasNoContent => m_EligibleIds.isEmpty;
  String get loadingMessage => "Loading...";
  String get noContentMessage => "You've completed all the cards!";
  String get errorTitle => "Error Loading Content";

  Widget buildCard(T flashcard);
  Future<void> loadAvailableCards();
  CardType get cardType;

  // Subclasses provide the type-specific Firestore call and parser, plus a
  // short label used in cache debug logs.
  Future<Map<String, dynamic>> fetchCardData(String id);
  T parseFlashcard(Map<String, dynamic> data);
  String get cardLogLabel;

  // ID of the currently displayed card, used for card-scoped feedback. Null
  // when no card is loaded.
  String? get currentCardId;

  // Override to return a value that changes whenever the scroll position
  // should reset to the top (new card, new question, view mode change, etc.).
  Object get scrollKey => m_CachedFlashcard.hashCode;

  void onReturnToHome()
  {
    Navigator.of(context).pop();
  }

  bool get canGoBack => false;
  void onGoBack() {}

  // Progress 0.0–1.0 through the available card list. null = no bar shown.
  double? get cardProgress => m_CompletionPercentage != null
    ? m_CompletionPercentage! / 100.0
    : null;

  void updatePercentageLocally()
  {
    if (m_TotalCards == 0) return;
    setState(() { m_CompletionPercentage = (m_CompletedCards / m_TotalCards) * 100.0; });
  }

  // Keep only the current card ± 1 in the parsed-card cache. Long skip-heavy
  // sessions would otherwise retain every visited card's body indefinitely.
  void evictStaleCacheEntries()
  {
    if (m_EligibleIds.isEmpty) { m_CardCache.clear(); return; }
    final keep = <String>{};
    for (final offset in const [-1, 0, 1])
    {
      final idx = m_CurrentIndex + offset;
      if (idx >= 0 && idx < m_EligibleIds.length) keep.add(m_EligibleIds[idx]);
    }
    m_CardCache.removeWhere((id, _) => !keep.contains(id));
  }

  void _logCache()
  {
    debugPrint('[cache] $cardLogLabel idx=$m_CurrentIndex/${m_EligibleIds.length - 1} entries=${m_CardCache.keys.toList()}');
  }

  void prefetchNeighbors(int index)
  {
    bool kicked = false;
    for (final offset in const [-1, 1])
    {
      final idx = index + offset;
      if (idx < 0 || idx >= m_EligibleIds.length) continue;
      final id = m_EligibleIds[idx];
      if (m_CardCache.containsKey(id)) continue;
      kicked = true;
      fetchCardData(id).then((data)
      {
        if (!mounted) return;
        m_CardCache.putIfAbsent(id, () => parseFlashcard(data));
        _logCache();
      }).catchError((_) { /* retry on user advance */ });
    }
    if (!kicked) _logCache();
  }

  // Extra actions inserted before the home button in the main content AppBar.
  List<Widget> buildExtraActions() => const [];

  // Optional widget shown below the completion message in the no-content state.
  Widget? buildNoContentExtra() => null;

  Future<void> resetProgress() =>
    DatabaseService.resetProgress(
      type: cardType,
      difficulty: widget.m_Difficulty.index,
      topic: widget.m_Topic);

  Future<void> _confirmAndReset() async
  {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text('Reset progress for this section? You\'ll start from scratch.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Reset', style: TextStyle(color: Colors.red[400]))),
        ],
      ),
    );

    if (confirmed == true && mounted)
    {
      await resetProgress();
      if (mounted) loadAvailableCards();
    }
  }

  Widget buildLoadingState()
  {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        elevation: 0),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(loadingMessage)
          ],
        ),
      ),
    );
  }

  Widget buildErrorState()
  {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        elevation: 0),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                errorTitle,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                errorMessage ?? 'An unknown error occurred.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600])),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: loadAvailableCards,
                child: const Text('Try Again')),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildNoContentState()
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: onReturnToHome,
            tooltip: 'Home'),
          const SizedBox(width: 16),
        ]),
      body: SafeArea(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Card(
            color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_rounded, size: 72, color: Colors.green[400]),
                  const SizedBox(height: 20),
                  const Text(
                    'All done!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    noContentMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: isDark ? Colors.grey[400] : Colors.grey[600])),
                  if (buildNoContentExtra() case final Widget extra) ...[
                    const SizedBox(height: 24),
                    extra,
                  ],
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: onReturnToHome,
                      child: const Text('Return to Home'))),
                  const SizedBox(height: 16),
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _confirmAndReset,
                      child: Text(
                        'Reset Progress',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[500],
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.grey[500])))),
                ],
              ),
            ),
          ),
        ),
      )),
    );
  }

  Widget buildMainContent()
  {
    if (m_CachedFlashcard == null)
    {
      return buildLoadingState();
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: canGoBack
          ? IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: onGoBack,
              tooltip: 'Back')
          : null,
        actions: [
          ...buildExtraActions(),
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: onReturnToHome,
            tooltip: 'Home'),
          const SizedBox(width: 16)],
        bottom: cardProgress != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                value: cardProgress,
                minHeight: 3,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)))
          : null),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: SafeArea(
          child: Card(
            color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.darkSurface
              : const Color(0xFFF9FAFB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            child: SingleChildScrollView(
              key: ValueKey(scrollKey),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: buildCard(m_CachedFlashcard as T)),
                  if (currentCardId case final String id)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, size: 20),
                        tooltip: 'Send feedback on this card',
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FeedbackPage(cardId: id, cardType: cardType))))),
                ]))))));
  }

  @override
  Widget build(BuildContext context)
  {
    if (isLoading) return buildLoadingState();
    if (errorMessage != null) return buildErrorState();
    if (hasNoContent) return buildNoContentState();

    if (m_CachedFlashcard == null)
    {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) loadAvailableCards();
      });
      return buildLoadingState();
    }

    return buildMainContent();
  }
}
