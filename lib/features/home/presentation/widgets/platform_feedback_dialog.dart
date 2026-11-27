import 'package:material_ui/material_ui.dart';

import '../../data/services/platform_feedback_service.dart';

Future<PlatformFeedbackDraft?> showPlatformFeedbackDialog(
  BuildContext context, {
  required bool isRequired,
}) => showDialog<PlatformFeedbackDraft>(
  context: context,
  barrierDismissible: !isRequired,
  builder: (_) => _PlatformFeedbackDialog(isRequired: isRequired),
);

class _PlatformFeedbackDialog extends StatefulWidget {
  final bool isRequired;

  const _PlatformFeedbackDialog({required this.isRequired});

  @override
  State<_PlatformFeedbackDialog> createState() =>
      _PlatformFeedbackDialogState();
}

class _PlatformFeedbackDialogState extends State<_PlatformFeedbackDialog> {
  final _formKey = GlobalKey<FormState>();
  final _platformController = TextEditingController();
  final _lecturerController = TextEditingController();
  final _suggestionController = TextEditingController();
  int _platformRating = 0;
  int _lecturerRating = 0;
  bool _showRatingErrors = false;

  @override
  void dispose() {
    _platformController.dispose();
    _lecturerController.dispose();
    _suggestionController.dispose();
    super.dispose();
  }

  String? _validateText(String? value) =>
      (value?.trim().length ?? 0) < 3 ? 'اكتب 3 أحرف على الأقل' : null;

  void _submit() {
    final validText = _formKey.currentState?.validate() ?? false;
    final validRatings = _platformRating > 0 && _lecturerRating > 0;
    setState(() => _showRatingErrors = !validRatings);
    if (!validText || !validRatings) return;

    Navigator.of(context).pop(
      PlatformFeedbackDraft(
        platformRating: _platformRating,
        platformFeedback: _platformController.text,
        lecturerRating: _lecturerRating,
        lecturerFeedback: _lecturerController.text,
        learningSuggestion: _suggestionController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !widget.isRequired,
    child: AlertDialog(
      title: const Text('رأيك يطوّر تجربتك'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('إيه رأيك في المنصة؟'),
                _StarRating(
                  value: _platformRating,
                  onChanged: (value) => setState(() {
                    _platformRating = value;
                    _showRatingErrors = false;
                  }),
                ),
                if (_showRatingErrors && _platformRating == 0)
                  const _RatingError(),
                TextFormField(
                  controller: _platformController,
                  validator: _validateText,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'اكتب رأيك في تجربة استخدام المنصة',
                  ),
                ),
                const SizedBox(height: 18),
                const Text('إيه رأيك في المحاضر؟'),
                _StarRating(
                  value: _lecturerRating,
                  onChanged: (value) => setState(() {
                    _lecturerRating = value;
                    _showRatingErrors = false;
                  }),
                ),
                if (_showRatingErrors && _lecturerRating == 0)
                  const _RatingError(),
                TextFormField(
                  controller: _lecturerController,
                  validator: _validateText,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'اكتب رأيك في الشرح والمحاضر',
                  ),
                ),
                const SizedBox(height: 18),
                const Text('هل لديك شكوى أو إضافة تحسّن تجربة التعلم؟'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _suggestionController,
                  validator: _validateText,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    hintText: 'اكتب اقتراحك أو اكتب: لا يوجد',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (!widget.isRequired)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('تخطي هذه المرة'),
          ),
        FilledButton(onPressed: _submit, child: const Text('إرسال التقييم')),
      ],
    ),
  );
}

class _StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarRating({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    textDirection: TextDirection.ltr,
    children: List.generate(5, (index) {
      final rating = index + 1;
      return IconButton(
        onPressed: () => onChanged(rating),
        tooltip: '$rating من 5',
        icon: Icon(
          rating <= value ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFF59E0B),
          size: 34,
        ),
      );
    }),
  );
}

class _RatingError extends StatelessWidget {
  const _RatingError();

  @override
  Widget build(BuildContext context) => Text(
    'اختر تقييمًا بالنجوم',
    style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12),
    textAlign: TextAlign.center,
  );
}
