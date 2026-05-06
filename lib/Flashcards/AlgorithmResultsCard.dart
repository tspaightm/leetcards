import "package:leetcards/Common/Constants.dart";
import "package:leetcards/Feedback/FeedbackPage.dart";
import "package:leetcards/Flashcards/AlgorithmFlashcard.dart";
import "package:leetcards/Utilities/MarkdownUtils.dart";

import "package:flutter/material.dart";

class AlgorithmResultsCard extends StatefulWidget
{
  final List<bool> m_Correctness;
  final AlgorithmFlashcard m_Flashcard;
  final VoidCallback m_OnRetry;
  final VoidCallback m_OnNext;
  final void Function(int questionIndex) m_OnQuestionTap;
  final double? m_Progress;

  const AlgorithmResultsCard
  ({
    super.key,
    required this.m_Correctness,
    required this.m_Flashcard,
    required this.m_OnRetry,
    required this.m_OnNext,
    required this.m_OnQuestionTap,
    this.m_Progress,
  });

  @override
  State<AlgorithmResultsCard> createState() => AlgorithmResultsCardState();
}

class AlgorithmResultsCardState extends State<AlgorithmResultsCard>
{
  bool m_ShowExplanation = false;

  @override
  Widget build(BuildContext context)
  {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            tooltip: 'Home'),
          const SizedBox(width: 4),
        ],
        bottom: widget.m_Progress != null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(3),
              child: LinearProgressIndicator(
                value: widget.m_Progress,
                minHeight: 3,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary)))
          : null),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SafeArea(
          child: Card(
            color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            child: SingleChildScrollView(
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 24),
                      child: Text(widget.m_Flashcard.m_Title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 20),
                    Divider(height: 1, thickness: 1, color: isDark ? Colors.grey[600]! : Colors.grey.shade300),
                    const SizedBox(height: 20),

                    for (int i = 0; i < widget.m_Correctness.length; i++)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Material(
                          color: widget.m_Correctness[i]
                            ? isDark ? Colors.green[900]?.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.1)
                            : isDark ? Colors.red[900]?.withValues(alpha: 0.3) : Colors.red.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            onTap: () => widget.m_OnQuestionTap(i),
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                children: [
                                  Icon(
                                    widget.m_Correctness[i] ? Icons.check_circle : Icons.cancel,
                                    color: widget.m_Correctness[i] ? Colors.green : Colors.red),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "Q${i + 1}: ${widget.m_Correctness[i] ? "Correct" : "Incorrect"}",
                                      style: const TextStyle(fontWeight: FontWeight.w500))),
                                  Icon(Icons.arrow_forward_ios, size: 12,
                                    color: isDark ? Colors.grey[500] : Colors.grey[400]),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    Divider(height: 1, thickness: 1, color: isDark ? Colors.grey[600] : Colors.grey.shade300),
                    const SizedBox(height: 24),

                    if (m_ShowExplanation)
                      markdownBody(context, widget.m_Flashcard.m_Explanation, 16)
                    else
                      Center(
                        child: GestureDetector(
                          onTap: () => setState(() => m_ShowExplanation = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800]! : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: isDark ? Colors.grey[600]! : Colors.grey.shade300)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.visibility, color: Theme.of(context).colorScheme.primary),
                                const SizedBox(width: 8),
                                Text("Show Explanation", style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.primary)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 36),

                    LayoutBuilder(
                      builder: (context, constraints)
                      {
                        final bool horizontal = constraints.maxWidth >= 296;
                        final retryButton = SizedBox(
                          width: horizontal ? 140 : double.infinity,
                          child: OutlinedButton(
                            onPressed: widget.m_OnRetry,
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              side: BorderSide(color: isDark ? Colors.grey[500]! : Colors.grey.shade400)),
                            child: const Text("Retry")));
                        final nextButton = SizedBox(
                          width: horizontal ? 140 : double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              padding: const EdgeInsets.symmetric(vertical: 14)),
                            onPressed: widget.m_OnNext,
                            child: const Text("Next")));

                        if (horizontal)
                        {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [retryButton, const SizedBox(width: 16), nextButton]);
                        }
                        else
                        {
                          return Column(
                            children: [retryButton, const SizedBox(height: 16), nextButton]);
                        }
                      },
                    ),
                  ],
                )),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.chat_bubble_outline, size: 20),
                      tooltip: 'Send feedback on this card',
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FeedbackPage(
                            cardId: widget.m_Flashcard.m_Id,
                            cardType: CardType.algorithm))))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
