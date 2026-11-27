import 'package:material_ui/material_ui.dart';
import 'package:q360education/features/lectures/presentation/widgets/pdf_viewer/pdf_annotation_dialogs.dart';

import '../../../../core/theme/app_colors.dart';
import 'pdf_annotation_models.dart';

class TextAnnotationEditorSheet extends StatefulWidget {
  const TextAnnotationEditorSheet({
    super.key,
    required this.draft,
    required this.isNew,
  });

  final PdfTextAnnotation draft;
  final bool isNew;

  @override
  State<TextAnnotationEditorSheet> createState() =>
      _TextAnnotationEditorSheetState();
}

class _TextAnnotationEditorSheetState extends State<TextAnnotationEditorSheet> {
  late final TextEditingController textController;
  late Color selectedColor;
  late bool background;
  late double fontSize;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: widget.draft.text);
    selectedColor = widget.draft.color;
    background = widget.draft.hasBackground;
    fontSize = widget.draft.fontSize;
  }

  @override
  void dispose() {
    textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetPadding(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnnotationSheetHeader(
          title: widget.isNew ? 'إضافة نص' : 'تعديل النص',
          icon: Icons.text_fields_rounded,
          onDelete: widget.isNew
              ? null
              : () => Navigator.pop(
                  context,
                  const AnnotationEditResult<PdfTextAnnotation>.delete(),
                ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: textController,
          autofocus: true,
          maxLines: 3,
          decoration: annotationInputDecoration('اكتب النص هنا...'),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final item in const [
              Color(0xFF212121),
              Color(0xFF512DA8),
              Color(0xFFD32F2F),
              Color(0xFF2E7D32),
              Color(0xFFE65100),
            ])
              GestureDetector(
                onTap: () => setState(() => selectedColor = item),
                child: CircleAvatar(
                  radius: 13,
                  backgroundColor: selectedColor == item
                      ? AppColors.primary
                      : Colors.grey.shade200,
                  child: CircleAvatar(radius: 10, backgroundColor: item),
                ),
              ),
            FilterChip(
              checkmarkColor: background ? Colors.white : Colors.black,
              label: Text(
                background ? 'بخلفية' : 'بدون خلفية',
                style: TextStyle(
                  color: background ? Colors.white : Colors.black,
                ),
              ),
              selected: background,
              onSelected: (value) => setState(() => background = value),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            const Text(
              'حجم الخط:',
              style: TextStyle(
                fontFamily: 'IBM',
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${fontSize.round()} pt',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.remove_circle_outline_rounded),
              tooltip: 'تصغير لأقصى حد',
              onPressed: () =>
                  setState(() => fontSize = (fontSize - 1).clamp(2, 72)),
            ),
            Expanded(
              child: Slider(
                value: fontSize.clamp(2, 72),
                min: 2,
                max: 72,
                onChanged: (value) => setState(() => fontSize = value),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'تكبير الخط',
              onPressed: () =>
                  setState(() => fontSize = (fontSize + 1).clamp(2, 72)),
            ),
          ],
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final sizePreset in [2, 4, 8, 12, 16, 24])
              ActionChip(
                label: Text(
                  '$sizePreset pt',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: fontSize.round() == sizePreset
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: fontSize.round() == sizePreset
                        ? Colors.white
                        : const Color(0xFF6D28D9),
                  ),
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                backgroundColor: fontSize.round() == sizePreset
                    ? const Color(0xFF6D28D9)
                    : const Color(0xFFEDE9FE),
                side: BorderSide(
                  color: fontSize.round() == sizePreset
                      ? const Color(0xFF6D28D9)
                      : const Color(0xFFDDD6FE),
                ),
                onPressed: () =>
                    setState(() => fontSize = sizePreset.toDouble()),
              ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.check_rounded),
          label: Text(widget.isNew ? 'إضافة النص' : 'حفظ التعديل'),
        ),
      ],
    ),
  );

  void _save() {
    final text = textController.text.trim();
    if (text.isEmpty) return;
    final edited = widget.draft.copy()
      ..text = text
      ..color = selectedColor
      ..hasBackground = background
      ..fontSize = fontSize;
    Navigator.pop(
      context,
      AnnotationEditResult<PdfTextAnnotation>.save(edited),
    );
  }
}

class NoteEditorSheet extends StatefulWidget {
  const NoteEditorSheet({super.key, required this.draft, required this.isNew});

  final PdfNote draft;
  final bool isNew;

  @override
  State<NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends State<NoteEditorSheet> {
  late final TextEditingController controller;
  late double size;
  late bool isPinned;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.draft.text);
    size = widget.draft.size;
    isPinned = widget.draft.isPinned;
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _SheetPadding(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnnotationSheetHeader(
          title: widget.isNew ? 'إضافة ورقة ملاحظات 📝' : 'تعديل الملاحظة',
          icon: Icons.sticky_note_2_rounded,
          onDelete: widget.isNew
              ? null
              : () => Navigator.pop(
                  context,
                  const AnnotationEditResult<PdfNote>.delete(),
                ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          autofocus: true,
          maxLines: 5,
          style: const TextStyle(
            fontFamily: 'IBM',
            fontSize: 14,
            height: 1.45,
            color: Color(0xFF1E293B),
          ),
          decoration: annotationInputDecoration('اكتب ملاحظتك على الورقة...'),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: isPinned ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color:
                  isPinned ? const Color(0xFFFDA4AF) : const Color(0xFFE2E8F0),
            ),
          ),
          child: SwitchListTile(
            value: isPinned,
            activeColor: const Color(0xFFE11D48),
            onChanged: (value) => setState(() => isPinned = value),
            title: Row(
              children: [
                Icon(
                  isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: isPinned ? const Color(0xFFE11D48) : Colors.black54,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Text(
                  'تثبيت الورقة في مكانها 📌',
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            subtitle: const Text(
              'عند التثبيت لا تتحرك الورقة بالخطأ أثناء تقليب صفحات الـ PDF',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.photo_size_select_small_rounded, size: 20),
            const SizedBox(width: 6),
            const Text(
              'عرض الورقة:',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Expanded(
              child: Slider(
                value: size.clamp(80, 280),
                min: 80,
                max: 280,
                onChanged: (value) => setState(() => size = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF6D28D9),
            foregroundColor: Colors.white,
          ),
          icon: const Icon(Icons.check_rounded),
          label: Text(widget.isNew ? 'إضافة الورقة للمستند' : 'حفظ التعديل'),
        ),
      ],
    ),
  );

  void _save() {
    final text = controller.text.trim();
    if (text.isEmpty) return;
    Navigator.pop(
      context,
      AnnotationEditResult<PdfNote>.save(
        widget.draft.copy()
          ..text = text
          ..size = size
          ..isPinned = isPinned,
      ),
    );
  }
}

class _SheetPadding extends StatelessWidget {
  const _SheetPadding({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      18,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 18,
    ),
    child: child,
  );
}

class AnnotationSheetHeader extends StatelessWidget {
  const AnnotationSheetHeader({
    super.key,
    required this.title,
    required this.icon,
    required this.onDelete,
  });

  final String title;
  final IconData icon;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: AppColors.primary),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'IBM',
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      if (onDelete != null)
        IconButton(
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline_rounded),
          color: AppColors.error,
        ),
    ],
  );
}

InputDecoration annotationInputDecoration(String hint) => InputDecoration(
  hintText: hint,
  filled: true,
  fillColor: const Color(0xFFF8F7FC),
  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
);
