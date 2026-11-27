import 'package:material_ui/material_ui.dart';

import 'pdf_annotation_edit_sheets.dart';
import 'pdf_annotation_models.dart';

Future<AnnotationEditResult<PdfTextAnnotation>?> showTextAnnotationEditor(
  BuildContext context,
  PdfTextAnnotation draft, {
  required bool isNew,
}) => showModalBottomSheet<AnnotationEditResult<PdfTextAnnotation>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => TextAnnotationEditorSheet(draft: draft, isNew: isNew),
);

Future<AnnotationEditResult<PdfNote>?> showNoteEditor(
  BuildContext context,
  PdfNote draft, {
  required bool isNew,
}) => showModalBottomSheet<AnnotationEditResult<PdfNote>>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
  ),
  builder: (_) => NoteEditorSheet(draft: draft, isNew: isNew),
);

Future<PdfNote?> showDocumentNotes(
  BuildContext context,
  PdfAnnotationDocument document,
) {
  final notes = document.notes.values.expand((items) => items).toList()
    ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
  return showModalBottomSheet<PdfNote>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          const ListTile(
            leading: Icon(Icons.format_list_bulleted_rounded),
            title: Text(
              'ملاحظات المستند',
              style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: notes.isEmpty
                ? const Center(child: Text('لا توجد ملاحظات حتى الآن'))
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => ListTile(
                      onTap: () => Navigator.pop(context, notes[index]),
                      leading: CircleAvatar(
                        backgroundColor: notes[index].isPinned
                            ? const Color(0xFFFFF1F2)
                            : const Color(0xFFEDE9FE),
                        child: Icon(
                          notes[index].isPinned
                              ? Icons.push_pin_rounded
                              : Icons.edit_note_rounded,
                          color: notes[index].isPinned
                              ? const Color(0xFFE11D48)
                              : const Color(0xFF6D28D9),
                          size: 18,
                        ),
                      ),
                      title: Text(
                        notes[index].text.isEmpty
                            ? 'ورقة ملاحظات فارغة'
                            : notes[index].text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        'صفحة ${notes[index].pageIndex + 1} ${notes[index].isPinned ? '• مثبتة 📌' : ''}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    ),
  );
}
