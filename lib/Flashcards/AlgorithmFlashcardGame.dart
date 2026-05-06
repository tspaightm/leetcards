import "package:leetcards/Common/Constants.dart";
import "package:leetcards/Flashcards/FlashcardGame.dart";
import "package:leetcards/Flashcards/AlgorithmFlashcard.dart";
import "package:leetcards/Flashcards/AlgorithmResultsCard.dart";
import "package:leetcards/Profile/ProfilePage.dart";
import "package:leetcards/Data/DatabaseService.dart";
import "package:leetcards/Utilities/MarkdownUtils.dart";

import "package:firebase_auth/firebase_auth.dart";
import "package:flutter/material.dart";

class AlgorithmFlashcardGame extends FlashcardGame<AlgorithmFlashcard>
{
  final String? m_CollectionId;
  final VoidCallback? m_OnReturnToLogin;

  const AlgorithmFlashcardGame
  ({
    super.key,
    required super.m_Difficulty,
    required super.m_Topic,
    this.m_CollectionId,
    this.m_OnReturnToLogin,
  });

  @override
  FlashcardGameState<AlgorithmFlashcard, AlgorithmFlashcardGame> createState() => AlgorithmFlashcardGameState();
}

class AlgorithmFlashcardGameState extends FlashcardGameState<AlgorithmFlashcard, AlgorithmFlashcardGame>
{
  int m_FlashcardQuestionNumber = 0;
  List<int> m_SelectedIndices = [];
  List<bool> m_IsCorrect = [];

  int m_SelectedOptionIndex = -1;
  bool m_ShowLongPrompt = true;
  bool m_IsDescriptionCollapsed = false;

  bool m_IsLoadingProblems = true;
  String? m_ProblemsError;

  @override
  void initState()
  {
    super.initState();
    loadAvailableCards();
  }

  @override
  CardType get cardType => CardType.algorithm;

  @override
  String get cardLogLabel => 'algorithm';

  @override
  Future<Map<String, dynamic>> fetchCardData(String id) =>
    DatabaseService.getAlgorithmById(id);

  @override
  Future<void> resetProgress() =>
    DatabaseService.resetProgress(
      type: cardType,
      difficulty: widget.m_Difficulty.index,
      topic: widget.m_Topic,
      collectionId: widget.m_CollectionId);

  @override
  Object get scrollKey => (m_CachedFlashcard?.m_Id ?? '', m_FlashcardQuestionNumber, m_ShowLongPrompt);

  @override
  bool get isLoading => m_IsLoadingProblems;

  @override
  String? get errorMessage => m_ProblemsError;

  @override
  bool get canGoBack
  {
    if (m_CachedFlashcard == null) return false;
    if (m_FlashcardQuestionNumber > 0 || !m_ShowLongPrompt) return true;
    return m_CurrentIndex > 0;
  }

  @override
  void onGoBack()
  {
    if (m_FlashcardQuestionNumber > 0 || !m_ShowLongPrompt)
      goBack();
    else if (m_CurrentIndex > 0)
      _loadCardAtIndex(m_CurrentIndex - 1);
  }

  @override
  Future<void> loadAvailableCards() async
  {
    setState(()
    {
      m_IsLoadingProblems = true;
      m_ProblemsError = null;
    });

    try
    {
      final stats = await DatabaseService.getEligibleAlgorithms(
        difficulty: widget.m_Difficulty.index,
        topic: widget.m_Topic,
        collectionId: widget.m_CollectionId);
      final ids = stats.available..shuffle();

      if (!mounted) return;
      setState(()
      {
        m_EligibleIds = ids;
        m_CurrentIndex = 0;
        m_TotalCards = stats.total;
        m_CompletedCards = stats.completed;
        m_CompletionPercentage = stats.total > 0 ? (stats.completed / stats.total) * 100.0 : 0.0;
        // stay in loading state until card[0] body lands — otherwise the
        // FlashcardGame.build fallback re-fires loadAvailableCards while
        // m_CachedFlashcard is still null.
        if (ids.isEmpty) m_IsLoadingProblems = false;
      });

      if (ids.isEmpty) return;
      await _loadCardAtIndex(0);
      if (!mounted) return;
      setState(() { m_IsLoadingProblems = false; });
    }
    catch (e)
    {
      if (!mounted) return;
      setState(()
      {
        m_ProblemsError = 'Failed to load problems. Please try again.';
        m_IsLoadingProblems = false;
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
        m_ShowLongPrompt = true;
        _resetQuizState();
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
        m_ShowLongPrompt = true;
        _resetQuizState();
      });
      evictStaleCacheEntries();
      prefetchNeighbors(index);
    }
    catch (e)
    {
      if (!mounted) return;
      setState(() { m_ProblemsError = 'Error loading problem. Please try again.'; });
    }
  }

  @override
  AlgorithmFlashcard parseFlashcard(Map<String, dynamic> data)
  {
    final String id = data["id"] as String;
    final questions = (data["questions"] as List<dynamic>)
      .map((q) => AlgorithmFlashcardQuestion.fromMap(q as Map<String, dynamic>))
      .toList();

    final examples = (data["examples"] as List<dynamic>? ?? [])
      .map((e) => AlgorithmFlashcardExample.fromMap(e as Map<String, dynamic>))
      .toList();

    return AlgorithmFlashcard(
      m_Id: id,
      m_Title: data["title"] as String,
      m_Description: data["description"] as String,
      m_Examples: examples,
      m_Constraints: List<String>.from(data['constraints'] ?? []),
      m_Topics: List<String>.from(data['topics'] ?? []),
      m_Questions: questions,
      m_Explanation: data["explanation"] as String);
  }

  void _resetQuizState()
  {
    final int questionCount = m_CachedFlashcard?.m_Questions.length ?? 0;
    m_FlashcardQuestionNumber = 0;
    m_SelectedIndices = List.filled(questionCount, -1);
    m_IsCorrect = List.filled(questionCount, false);
    m_SelectedOptionIndex = -1;
    m_IsDescriptionCollapsed = false;
  }

  void _proceedToQuestions()
  {
    setState(()
    {
      m_ShowLongPrompt = false;
    });
  }

  void _skipCard()
  {
    moveToNextProblem(removeCard: false);
  }

  void _markAsComplete()
  {
    saveProgress(m_CachedFlashcard!.m_Id);
    m_CompletedCards++;
    updatePercentageLocally();
    moveToNextProblem(removeCard: true);
  }

  @override
  Widget? buildNoContentExtra()
  {
    if (widget.m_CollectionId != AppConstants.freePreviewCollectionId) return null;

    final bool isSignedIn = FirebaseAuth.instance.currentUser != null;
    final linkStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.indigo,
      decoration: TextDecoration.underline,
      decorationColor: AppColors.indigo);
    final plainStyle = TextStyle(fontSize: 14, color: Colors.grey[600]);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          if (isSignedIn) {
            Navigator.push(context, MaterialPageRoute(
              builder: (_) => const ProfilePage()));
          } else {
            widget.m_OnReturnToLogin?.call();
          }
        },
        child: Text.rich(
          TextSpan(children: isSignedIn
            ? [
                TextSpan(text: 'Upgrade to Plus ', style: linkStyle),
                TextSpan(text: 'to unlock all Easy problems!', style: plainStyle),
              ]
            : [
                TextSpan(text: 'Sign in', style: linkStyle),
                TextSpan(text: ' and upgrade to Plus to unlock all Easy problems!', style: plainStyle),
              ]),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  List<Widget> buildExtraActions() => [
    PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert),
      tooltip: 'More options',
      onSelected: (value)
      {
        if (value == 'skip') { _skipCard(); }
        else if (value == 'complete') { _markAsComplete(); }
      },
      itemBuilder: (_) => const [
        PopupMenuItem(value: 'skip', child: Text('Skip for now')),
        PopupMenuItem(value: 'complete', child: Text('Mark as complete')),
      ]),
  ];

  void submitAnswer()
  {
    if (m_SelectedOptionIndex == -1) return;

    setState(()
    {
      final question = m_CachedFlashcard!.m_Questions[m_FlashcardQuestionNumber];

      m_SelectedIndices[m_FlashcardQuestionNumber] = m_SelectedOptionIndex;
      m_IsCorrect[m_FlashcardQuestionNumber] = question.m_Options[m_SelectedOptionIndex].item2;

      final int lastQuestion = m_CachedFlashcard!.m_Questions.length - 1;
      if (m_FlashcardQuestionNumber < lastQuestion)
      {
        m_FlashcardQuestionNumber++;
        m_SelectedOptionIndex = m_SelectedIndices[m_FlashcardQuestionNumber];
      }
      else
      {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AlgorithmResultsCard(
            m_Correctness: m_IsCorrect,
            m_Flashcard: m_CachedFlashcard!,
            m_Progress: cardProgress,
            m_OnRetry: ()
            {
              Navigator.pop(context);
              setState(() { _resetQuizState(); });
            },
            m_OnNext: ()
            {
              Navigator.pop(context);
              nextCard(true);
            },
            m_OnQuestionTap: (int questionIndex)
            {
              Navigator.pop(context);
              setState(()
              {
                m_ShowLongPrompt = false;
                m_FlashcardQuestionNumber = questionIndex;
                m_SelectedOptionIndex = m_SelectedIndices[questionIndex];
              });
            },
          ),
        ));
      }
    });
  }

  void nextCard(bool newCard)
  {
    setState(()
    {
      if (newCard)
      {
        final bool allCorrect = m_IsCorrect.every((isCorrect) => isCorrect);
        if (allCorrect)
        {
          m_CompletedCards++;
          updatePercentageLocally();
          saveProgress(m_CachedFlashcard!.m_Id);
        }

        moveToNextProblem(removeCard: allCorrect);
        m_ShowLongPrompt = true;
      }
      else
      {
        m_FlashcardQuestionNumber++;
      }

      m_SelectedOptionIndex = -1;
    });
  }

  Future<void> saveProgress(String id) async
  {
    try
    {
      await DatabaseService.saveAlgorithmCompletion(id);
    }
    catch (e)
    {
      // progress save failure is non-critical; silently ignore
    }
  }

  void moveToNextProblem({bool removeCard = false})
  {
    _resetQuizState();

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

  void goBack()
  {
    if (m_FlashcardQuestionNumber > 0)
    {
      setState(()
      {
        m_SelectedIndices[m_FlashcardQuestionNumber] = m_SelectedOptionIndex;
        m_FlashcardQuestionNumber--;
        m_SelectedOptionIndex = m_SelectedIndices[m_FlashcardQuestionNumber];
      });
    }
    else if (m_FlashcardQuestionNumber == 0 && !m_ShowLongPrompt)
    {
      setState(()
      {
        m_ShowLongPrompt = true;
        m_SelectedOptionIndex = -1;
      });
    }
  }

  @override
  Widget buildCard(AlgorithmFlashcard flashcard)
  {
    return m_ShowLongPrompt
      ? _buildLongPromptView(flashcard)
      : _buildQuestionsView(flashcard);
  }

  Widget _buildLongPromptView(AlgorithmFlashcard flashcard)
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dividerColor = isDark ? Colors.grey[600]! : Colors.grey.shade300;
    final Color codeBg = isDark ? Colors.grey[850]! : const Color(0xFFF3F4F6);
    final Color textColor = isDark ? Colors.white : Colors.black87;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(flashcard.m_Title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Divider(height: 1, thickness: 1, color: dividerColor),
        const SizedBox(height: 20),
        markdownBody(context, flashcard.m_Description, 15),
        if (flashcard.m_Examples.isNotEmpty) ...[
          const SizedBox(height: 24),
          for (int i = 0; i < flashcard.m_Examples.length; i++) ...[
            Text("Example ${i + 1}:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: codeBg,
                borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Input: ${flashcard.m_Examples[i].m_Input}",
                    style: TextStyle(fontFamily: "Inconsolata", fontSize: 14, color: textColor)),
                  const SizedBox(height: 4),
                  Text("Output: ${flashcard.m_Examples[i].m_Output}",
                    style: TextStyle(fontFamily: "Inconsolata", fontSize: 14, color: textColor)),
                  if (flashcard.m_Examples[i].m_Explanation.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    markdownBody(context, flashcard.m_Examples[i].m_Explanation, 13),
                  ],
                ],
              ),
            ),
            if (i < flashcard.m_Examples.length - 1) const SizedBox(height: 12),
          ],
        ],
        if (flashcard.m_Constraints.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text("Constraints:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
          const SizedBox(height: 8),
          markdownBody(context, flashcard.m_Constraints.map((c) => "- `$c`").join("\n"), 14),
        ],
        const SizedBox(height: 32),
        Center(
          child: SizedBox(
            width: 120,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: _proceedToQuestions,
              child: const Text("Next")))),
      ]
    );
  }

  Widget _buildQuestionsView(AlgorithmFlashcard flashcard)
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color dividerColor = isDark ? Colors.grey[600]! : Colors.grey.shade300;
    final Color primaryColor = Theme.of(context).colorScheme.primary;
    final AlgorithmFlashcardQuestion question = flashcard.m_Questions[m_FlashcardQuestionNumber];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(flashcard.m_Title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        Divider(height: 1, thickness: 1, color: dividerColor),
        if (m_IsDescriptionCollapsed)
          GestureDetector(
            onTap: () => setState(() => m_IsDescriptionCollapsed = false),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: double.infinity,
              child: Center(child: Icon(Icons.expand_more, size: 20, color: isDark ? Colors.grey[600] : Colors.grey[400]))),
          )
        else ...[
          const SizedBox(height: 20),
          markdownBody(context, flashcard.m_Description, 15),
          GestureDetector(
            onTap: () => setState(() => m_IsDescriptionCollapsed = true),
            behavior: HitTestBehavior.opaque,
            child: SizedBox(
              width: double.infinity,
              child: Center(child: Icon(Icons.expand_less, size: 20, color: isDark ? Colors.grey[600] : Colors.grey[400]))),
          ),
          Divider(height: 1, thickness: 1, color: dividerColor),
          const SizedBox(height: 20),
        ],
        Text("Question ${m_FlashcardQuestionNumber + 1} of ${flashcard.m_Questions.length}",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey[400]! : Colors.grey.shade700)),
        const SizedBox(height: 12),
        markdownBody(context, question.m_Question, 18),
        const SizedBox(height: 20),
        for (int i = 0; i < question.m_Options.length; i++)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: m_SelectedOptionIndex == i
                  ? primaryColor
                  : isDark ? const Color(0x26FFFFFF) : Colors.grey.shade300,
                width: 1.5),
              color: m_SelectedOptionIndex == i
                ? primaryColor.withValues(alpha: 0.1)
                : isDark ? const Color(0x14FFFFFF) : Colors.white),
            child: RadioListTile<int>(
              value: i,
              groupValue: m_SelectedOptionIndex,
              title: markdownBody(context, question.m_Options[i].item1, 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onChanged: (int? value)
              {
                setState(()
                {
                  m_SelectedOptionIndex = value ?? -1;
                });
              })),
        const SizedBox(height: 16),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints)
            {
              final bool horizontal = constraints.maxWidth >= 256;
              final backButton = SizedBox(
                width: 120,
                child: OutlinedButton(
                  onPressed: goBack,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: isDark ? Colors.grey[500]! : Colors.grey.shade400),
                    foregroundColor: isDark ? Colors.white : Colors.black87),
                  child: const Text("Back")));
              final nextButton = SizedBox(
                width: 120,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: m_SelectedOptionIndex != -1 ? AppColors.primary : const Color(0xFF374151),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: m_SelectedOptionIndex != -1 ? submitAnswer : null,
                  child: Text(m_FlashcardQuestionNumber < m_CachedFlashcard!.m_Questions.length - 1 ? "Next" : "Submit")));

              if (horizontal)
              {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [backButton, const SizedBox(width: 16), nextButton]);
              }
              else
              {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [backButton, const SizedBox(height: 16), nextButton]);
              }
            },
          ),
        ),
      ]
    );
  }
}
