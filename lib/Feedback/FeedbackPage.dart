import 'package:leetcards/Common/Constants.dart';
import 'package:leetcards/Feedback/FeedbackService.dart';

import 'package:flutter/material.dart';

class FeedbackPage extends StatefulWidget
{
  // When both are set, feedback is submitted to the flashcard_feedback
  // collection scoped to that card. Otherwise it goes to the general feedback
  // collection.
  final String? cardId;
  final CardType? cardType;

  const FeedbackPage({super.key, this.cardId, this.cardType});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage>
{
  final TextEditingController _controller = TextEditingController();
  bool _isSubmitting = false;

  bool get _isCardScoped => widget.cardId != null && widget.cardType != null;

  @override
  void dispose()
  {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async
  {
    final text = _controller.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    try
    {
      if (_isCardScoped)
      {
        await FeedbackService.submitForCard(text, widget.cardId!, widget.cardType!);
      }
      else
      {
        await FeedbackService.submit(text);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thanks — feedback sent.')));
      Navigator.of(context).pop();
    }
    catch (e)
    {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not send feedback: $e')));
    }
  }

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
        toolbarHeight: 48,
        title: const Text('Send feedback', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _isCardScoped
                  ? 'Tell us what\'s wrong, confusing, or could be better about this card.'
                  : 'Bug reports, feature ideas, or anything else — we read every message.',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: _controller,
                  enabled: !_isSubmitting,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  maxLength: FeedbackService.m_MaxMessageLength,
                  decoration: InputDecoration(
                    hintText: 'What\'s on your mind?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    alignLabelWithHint: true))),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                child: _isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Send')),
            ],
          ),
        ),
      ),
    );
  }
}
