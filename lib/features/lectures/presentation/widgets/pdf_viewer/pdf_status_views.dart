import 'package:material_ui/material_ui.dart';

class PdfLoadingView extends StatelessWidget {
  const PdfLoadingView({super.key, required this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircularProgressIndicator(value: progress),
        const SizedBox(height: 12),
        Text(
          progress == null
              ? 'جارٍ تجهيز الملف...'
              : 'جارٍ التنزيل ${(progress! * 100).round()}%',
        ),
      ],
    ),
  );
}

class PdfErrorView extends StatelessWidget {
  const PdfErrorView({super.key, required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.picture_as_pdf_outlined, size: 52),
          const SizedBox(height: 12),
          Text(message ?? 'تعذر فتح الملف', textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );
}
