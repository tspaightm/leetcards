import "package:leetcards/Common/Constants.dart";
import "package:leetcards/Flashcards/FlashcardGame.dart";
import "package:leetcards/Flashcards/FundamentalFlashcard.dart";
import "package:leetcards/Data/DatabaseService.dart";
import "package:leetcards/Utilities/MarkdownUtils.dart";

import "package:flutter/material.dart";
import "package:tuple/tuple.dart";

class FundamentalFlashcardGame extends FlashcardGame<FundamentalFlashcard>
{
  const FundamentalFlashcardGame
  ({
    super.key,
    required super.m_Difficulty,
    required super.m_Topic,
  });

  @override
  FlashcardGameState<FundamentalFlashcard, FundamentalFlashcardGame> createState() => FundamentalFlashcardGameState();
}

class FundamentalFlashcardGameState extends FlashcardGameState<FundamentalFlashcard, FundamentalFlashcardGame>
{
  int? m_SelectedOptionIndex;
  bool m_Submitted = false;
  bool m_ShowExplanation = false;

  bool m_IsLoadingFundamentals = true;
  String? m_FundamentalsError;

  @override
  void initState()
  {
    super.initState();
    loadAvailableCards();
  }

  @override
  CardType get cardType => CardType.fundamental;

  @override
  String get cardLogLabel => 'fundamental';

  @override
  Future<Map<String, dynamic>> fetchCardData(String id) =>
    DatabaseService.getFundamentalById(id);

  @override
  bool get isLoading => m_IsLoadingFundamentals;

  @override
  String? get errorMessage => m_FundamentalsError;

  @override
  bool get canGoBack => m_CachedFlashcard != null && m_CurrentIndex > 0;

  @override
  void onGoBack()
  {
    if (m_CurrentIndex > 0)
    {
      setState(()
      {
        m_SelectedOptionIndex = null;
        m_Submitted = false;
        m_ShowExplanation = false;
      });
      _loadCardAtIndex(m_CurrentIndex - 1);
    }
  }

  @override
  Future<void> loadAvailableCards() async
  {
    setState(()
    {
      m_IsLoadingFundamentals = true;
      m_FundamentalsError = null;
    });

    try
    {
      final stats = await DatabaseService.getEligibleFundamentals(
        difficulty: widget.m_Difficulty.index,
        topic: widget.m_Topic);
      final ids = stats.available..shuffle();

      if (!mounted) return;
      setState(()
      {
        m_EligibleIds = ids;
        m_CurrentIndex = 0;
        m_TotalCards = stats.total;
        m_CompletedCards = stats.completed;
        m_CompletionPercentage = stats.total > 0 ? (stats.completed / stats.total) * 100.0 : 0.0;
        // stay in loading state until card[0] body lands — the base class's
        // fallback in FlashcardGame.build would otherwise re-fire
        // loadAvailableCards while m_CachedFlashcard is still null.
        if (ids.isEmpty) m_IsLoadingFundamentals = false;
      });

      if (ids.isEmpty) return;
      await _loadCardAtIndex(0);
      if (!mounted) return;
      setState(() { m_IsLoadingFundamentals = false; });
    }
    catch (e)
    {
      if (!mounted) return;
      setState(()
      {
        m_FundamentalsError = 'Failed to load fundamentals. Please try again.';
        m_IsLoadingFundamentals = false;
      });
    }
  }

  Future<void> _loadCardAtIndex(int index) async
  {
    if (index < 0 || index >= m_EligibleIds.length) return;
    final id = m_EligibleIds[index];

    final cached = m_CardCache[id];
    if (cached != null)
    {
      setState(()
      {
        m_CurrentIndex = index;
        m_CachedFlashcard = cached;
      });
      evictStaleCacheEntries();
      prefetchNeighbors(index);
      return;
    }

    try
    {
      final data = await fetchCardData(id);
      if (!mounted) return;
      final flashcard = m_CardCache.putIfAbsent(id, () => parseFlashcard(data));
      setState(()
      {
        m_CurrentIndex = index;
        m_CachedFlashcard = flashcard;
      });
      evictStaleCacheEntries();
      prefetchNeighbors(index);
    }
    catch (e)
    {
      if (!mounted) return;
      setState(() { m_FundamentalsError = 'Failed to load card. Please try again.'; });
    }
  }

  @override
  FundamentalFlashcard parseFlashcard(Map<String, dynamic> data)
  {
    final String id = data["id"] as String;
    final options = (data["options"] as List<dynamic>)
      .map((opt) => Tuple2<String, bool>(
        opt["option"] as String,
        opt["correct"] as bool))
      .toList()
      ..shuffle();

    return FundamentalFlashcard(
      m_Id: id,
      m_Topics: List<String>.from(data['topics'] ?? []),
      m_Question: data["question"] as String,
      m_Options: options,
      m_Explanation: data["explanation"] as String? ?? '');
  }

  void submitAnswer()
  {
    setState(() { m_Submitted = true; });
  }

  void nextCard()
  {
    if (m_SelectedOptionIndex != null && m_CachedFlashcard != null)
    {
      final bool isCorrect = m_CachedFlashcard!.m_Options[m_SelectedOptionIndex!].item2;

      if (isCorrect)
      {
        m_CompletedCards++;
        updatePercentageLocally();
        saveProgress(m_CachedFlashcard!.m_Id);
      }

      moveToNext(removeCard: isCorrect);
    }
  }

  Future<void> saveProgress(String id) async
  {
    try
    {
      await DatabaseService.saveFundamentalCompletion(id);
    }
    catch (e)
    {
      // progress save failure is non-critical; silently ignore
    }
  }

  void moveToNext({bool removeCard = false})
  {
    m_SelectedOptionIndex = null;
    m_Submitted = false;
    m_ShowExplanation = false;

    if (removeCard && m_CurrentIndex < m_EligibleIds.length)
    {
      final removedId = m_EligibleIds.removeAt(m_CurrentIndex);
      m_CardCache.remove(removedId);

      if (m_CurrentIndex < m_EligibleIds.length)
        _loadCardAtIndex(m_CurrentIndex);
      else
        // List emptied by completion. Don't reload — the pending saveProgress
        // write hasn't flushed into the completed-IDs cache yet, so a reload
        // would resurrect the just-completed card. hasNoContent drives the
        // "all done" screen directly.
        setState(() { m_CachedFlashcard = null; });
    }
    else if (m_CurrentIndex < m_EligibleIds.length - 1)
    {
      _loadCardAtIndex(m_CurrentIndex + 1);
    }
    else
    {
      loadAvailableCards();
    }
  }

  @override
  Widget buildCard(FundamentalFlashcard flashcard)
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        markdownBody(context, flashcard.m_Question, 22),
        const SizedBox(height: 24),

        ...List.generate(flashcard.m_Options.length, (i)
        {
          final bool isSelected = m_SelectedOptionIndex == i;
          final bool isCorrect = flashcard.m_Options[i].item2;
          final bool isCorrectSelection = m_Submitted && isSelected && isCorrect;
          final bool isIncorrectSelection = m_Submitted && isSelected && !isCorrect;

          final Color borderColor;
          final Color bgColor;

          if (isCorrectSelection)
          {
            borderColor = Colors.green;
            bgColor = isDark ? Colors.green[900]!.withValues(alpha: 0.3) : Colors.green.shade50;
          }
          else if (isIncorrectSelection)
          {
            borderColor = Colors.red;
            bgColor = isDark ? Colors.red[900]!.withValues(alpha: 0.3) : Colors.red.shade50;
          }
          else if (isSelected)
          {
            borderColor = Theme.of(context).colorScheme.primary;
            bgColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
          }
          else
          {
            borderColor = isDark ? const Color(0x26FFFFFF) : Colors.grey.shade300;
            bgColor = isDark ? const Color(0x14FFFFFF) : Colors.white;
          }

          return Container(
            margin: const EdgeInsets.symmetric(vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor, width: 1.5),
              color: bgColor),
            child: RadioListTile<int>(
              value: i,
              groupValue: m_SelectedOptionIndex,
              title: markdownBody(context, flashcard.m_Options[i].item1, 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onChanged: (int? value)
              {
                setState(()
                {
                  m_SelectedOptionIndex = value;
                  m_Submitted = false;
                  m_ShowExplanation = false;
                });
              }));
        }),
        const SizedBox(height: 20),

        if (m_Submitted) ...[
          if (m_ShowExplanation)
            markdownBody(context, flashcard.m_Explanation, null)
          else
            Center(
              child: GestureDetector(
                onTap: () => setState(() => m_ShowExplanation = true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0x14FFFFFF) : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0x26FFFFFF) : Colors.grey.shade300)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.visibility, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 8),
                      Text("Show Explanation", style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.primary)),
                    ])))),
          const SizedBox(height: 20),
        ],

        Center(
          child: SizedBox(
            width: 120,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: m_Submitted ? nextCard : m_SelectedOptionIndex != null ? submitAnswer : null,
              child: Text(m_Submitted ? "Next" : "Submit")))),
      ]);
  }
}
