import 'package:material_ui/material_ui.dart';

import '../../../../core/theme/app_colors.dart';
import 'pdf_annotation_models.dart';

class PdfEditorToolbar extends StatelessWidget {
  const PdfEditorToolbar({
    super.key,
    required this.tool,
    required this.color,
    required this.canUndo,
    required this.onToolChanged,
    required this.onColorChanged,
    required this.onUndo,
    required this.onClear,
    required this.onAi,
    required this.onNotes,
    this.onSavedWords,
  });

  final PdfToolMode tool;
  final Color color;
  final bool canUndo;
  final ValueChanged<PdfToolMode> onToolChanged;
  final ValueChanged<Color> onColorChanged;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onAi;
  final VoidCallback onNotes;
  final VoidCallback? onSavedWords;

  static const colors = [
    Color(0xFFFFEB3B),
    Color(0xFF69F0AE),
    Color(0xFF40C4FF),
    Color(0xFFFFAB40),
    Color(0xFFFF80AB),
  ];

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    elevation: 2,
    shadowColor: Colors.black12,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 64,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
            children: [
              _ToolButton(
                icon: Icons.pan_tool_outlined,
                label: 'تصفح',
                selected: tool == PdfToolMode.scroll,
                onTap: () => onToolChanged(PdfToolMode.scroll),
              ),
              _ToolButton(
                icon: Icons.border_color_rounded,
                label: 'تظليل',
                selected: tool == PdfToolMode.highlight,
                onTap: () => onToolChanged(PdfToolMode.highlight),
              ),
              _ToolButton(
                icon: Icons.text_fields_rounded,
                label: 'نص',
                selected: tool == PdfToolMode.text,
                onTap: () => onToolChanged(PdfToolMode.text),
              ),
              _ToolButton(
                icon: Icons.sticky_note_2_outlined,
                label: 'ملاحظة',
                selected: tool == PdfToolMode.note,
                onTap: () => onToolChanged(PdfToolMode.note),
              ),
              _IconButton(
                icon: Icons.undo_rounded,
                label: 'تراجع',
                enabled: canUndo,
                onTap: onUndo,
              ),
              // _IconButton(
              //   icon: Icons.auto_awesome_rounded,
              //   label: 'مساعد',
              //   onTap: onAi,
              // ),
              _IconButton(
                icon: Icons.format_list_bulleted_rounded,
                label: 'الملاحظات',
                onTap: onNotes,
              ),
              if (onSavedWords != null)
                _IconButton(
                  icon: Icons.collections_bookmark_rounded,
                  label: 'الكلمات',
                  onTap: onSavedWords!,
                ),
            ],
          ),
        ),
        SizedBox(
          height: 46,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 46),
            padding: const EdgeInsetsDirectional.fromSTEB(12, 6, 8, 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF8F7FC),
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text(
                    tool == PdfToolMode.scroll
                        ? 'حرّك الصفحة أو كبّرها، وسيظل التظليل ثابتًا'
                        : tool == PdfToolMode.highlight
                        ? 'ارسم، أو اضغط على تظليل لحذفه'
                        : tool == PdfToolMode.text
                        ? 'اضغط على الصفحة لإضافة نص'
                        : 'اضغط على الصفحة لإضافة ملاحظة',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontFamily: 'IBM',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (tool == PdfToolMode.highlight ||
                      tool == PdfToolMode.note) ...[
                    const SizedBox(width: 12),
                    for (final item in colors)
                      GestureDetector(
                        onTap: () => onColorChanged(item),
                        child: Container(
                          width: 26,
                          height: 26,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: item,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == item
                                  ? AppColors.primary
                                  : Colors.white,
                              width: color == item ? 3 : 1,
                            ),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 3),
                            ],
                          ),
                        ),
                      ),
                  ],
                  // if (tool == PdfToolMode.highlight ||
                  //     tool == PdfToolMode.text ||
                  //     tool == PdfToolMode.note) ...[
                  //   const SizedBox(width: 8),
                  //   FilledButton.icon(
                  //     onPressed: () => onToolChanged(PdfToolMode.scroll),
                  //     icon: const Icon(
                  //       Icons.pan_tool_outlined,
                  //       size: 16,
                  //       color: Colors.white,
                  //     ),
                  //     label: const Text(
                  //       'تصفح',
                  //       style: TextStyle(
                  //         color: Colors.white,
                  //         fontWeight: FontWeight.w700,
                  //       ),
                  //     ),
                  //     style: FilledButton.styleFrom(
                  //       backgroundColor: const Color(0xFF6D28D9),
                  //       foregroundColor: Colors.white,
                  //       visualDensity: VisualDensity.compact,
                  //       padding: const EdgeInsets.symmetric(horizontal: 12),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10),
                  //       ),
                  //     ),
                  //   ),
                  //   const SizedBox(width: 6),
                  //   FilledButton.icon(
                  //     onPressed: canUndo ? onUndo : null,
                  //     icon: Icon(
                  //       Icons.undo_rounded,
                  //       size: 16,
                  //       color: canUndo
                  //           ? const Color(0xFF6D28D9)
                  //           : Colors.grey.shade400,
                  //     ),
                  //     label: Text(
                  //       'رجوع',
                  //       style: TextStyle(
                  //         color: canUndo
                  //             ? const Color(0xFF6D28D9)
                  //             : Colors.grey.shade400,
                  //         fontWeight: FontWeight.w700,
                  //       ),
                  //     ),
                  //     style: FilledButton.styleFrom(
                  //       backgroundColor: const Color(0xFFEDE9FE),
                  //       foregroundColor: const Color(0xFF6D28D9),
                  //       disabledBackgroundColor: Colors.grey.shade200,
                  //       disabledForegroundColor: Colors.grey.shade400,
                  //       visualDensity: VisualDensity.compact,
                  //       padding: const EdgeInsets.symmetric(horizontal: 12),
                  //       shape: RoundedRectangleBorder(
                  //         borderRadius: BorderRadius.circular(10),
                  //       ),
                  //     ),
                  //   ),
                  // ],
                  if (tool == PdfToolMode.scroll) ...[
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => onToolChanged(PdfToolMode.highlight),
                      icon: const Icon(
                        Icons.border_color_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'العودة للتظليل',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF6D28D9),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  if (tool != PdfToolMode.scroll)
                    TextButton.icon(
                      onPressed: onClear,
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: const Text('مسح الصفحة'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.error,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: 6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF0E9FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'IBM',
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Padding(
      padding: const EdgeInsetsDirectional.only(end: 4),
      child: IconButton.filledTonal(
        onPressed: enabled ? onTap : null,
        icon: Icon(icon, size: 20),
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xFFF4EEFF),
          foregroundColor: AppColors.primary,
        ),
      ),
    ),
  );
}
