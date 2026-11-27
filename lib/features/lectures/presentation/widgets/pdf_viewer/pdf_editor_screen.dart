import 'package:just_audio/just_audio.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../../../core/services/tts_cache_service.dart';
import '../../../../core/services/screen_protection_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../novels/presentation/widgets/novel_saved_words_screen.dart';
import '../../../../study/presentation/screens/study_ambience_mixer.dart';
import '../../screens/ai_pdf_study_screen.dart';
import 'pdf_annotation_dialogs.dart';
import 'pdf_annotation_layer.dart';
import 'pdf_annotation_models.dart';
import 'pdf_editor_controller.dart';
import 'pdf_editor_toolbar.dart';
import 'pdf_status_views.dart';
import 'pdf_word_translation_dialog.dart';

class PdfEditorScreen extends StatefulWidget {
  const PdfEditorScreen({
    super.key,
    required this.pdfUrl,
    required this.title,
    this.enableAmbientSounds = false,
    this.preventScreenshots = true,
  });

  final String pdfUrl;
  final String title;
  final bool enableAmbientSounds;
  final bool preventScreenshots;

  @override
  State<PdfEditorScreen> createState() => _PdfEditorScreenState();
}

class _PdfEditorScreenState extends State<PdfEditorScreen> {
  late final PdfEditorController editor;
  final PdfViewerController pdfController = PdfViewerController();
  AudioPlayer? _ttsPlayer;

  bool get _shouldProtectScreen {
    if (!widget.preventScreenshots) return false;
    final uri = Uri.tryParse(widget.pdfUrl);
    if (uri?.scheme == 'file') return false;
    return true;
  }

  @override
  void initState() {
    super.initState();
    if (_shouldProtectScreen) {
      ScreenProtectionService.acquire();
    }
    editor = PdfEditorController(url: widget.pdfUrl, title: widget.title);
    editor.addListener(_loadingListener);
    editor.load();
  }

  void _loadingListener() {
    if (mounted && (editor.loading || editor.localPath == null)) {
      setState(() {});
    }
    if (!editor.loading) {
      editor.removeListener(_loadingListener);
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    editor.removeListener(_loadingListener);
    editor.dispose();
    _ttsPlayer?.dispose();
    if (_shouldProtectScreen) {
      ScreenProtectionService.release();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, _) async {
      if (didPop) return;
      await editor.saveNow();
      if (context.mounted) Navigator.of(context).pop(true);
    },
    child: Scaffold(
      backgroundColor: AppColors.background,
      appBar: _appBar(),
      body: editor.loading
          ? PdfLoadingView(progress: editor.loadingProgress)
          : editor.localPath == null
          ? PdfErrorView(message: editor.error, onRetry: editor.load)
          : _workspace(),
    ),
  );

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: Colors.white,
    elevation: 0,
    leading: IconButton(
      tooltip: 'إغلاق',
      onPressed: _close,
      icon: const Icon(Icons.close_rounded),
    ),
    title: Text(
      widget.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w800),
    ),
    actions: [
      AnimatedBuilder(
        animation: editor,
        builder: (_, _) => IconButton(
          tooltip: 'محفوظ داخل التطبيق',
          onPressed: _showOfflineStatus,
          icon: Icon(
            editor.availableOffline
                ? Icons.download_done_rounded
                : Icons.download_for_offline_outlined,
            color: editor.availableOffline
                ? const Color(0xFF059669)
                : AppColors.primary,
          ),
        ),
      ),
      IconButton(
        tooltip: 'حفظ كل التعديلات',
        onPressed: _save,
        icon: const Icon(Icons.save_rounded, color: AppColors.primary),
      ),
      AnimatedBuilder(
        animation: editor,
        builder: (_, _) => Padding(
          padding: const EdgeInsetsDirectional.only(end: 10),
          child: Center(
            child: Text(
              editor.totalPages == 0
                  ? '—'
                  : '${editor.currentPage + 1}/${editor.totalPages}',
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _workspace() => Column(
    children: [
      AnimatedBuilder(
        animation: editor,
        builder: (_, _) => PdfEditorToolbar(
          tool: editor.tool,
          color: editor.color,
          canUndo: editor.canUndo,
          onToolChanged: _setTool,
          onColorChanged: editor.setColor,
          onUndo: editor.undo,
          onClear: _confirmClear,
          onAi: _openAi,
          onNotes: _openNotes,
          onSavedWords: () => NovelSavedWordsScreen.open(context),
        ),
      ),
      Expanded(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              PdfViewer.file(
                editor.localPath!,
                controller: pdfController,
                params: PdfViewerParams(
                  layoutStrategy: const SequentialPagesLayout(
                    margin: 8,
                    spacing: 8,
                  ),
                  backgroundColor: const Color(0xFFF1F3F8),
                  textSelectionParams: const PdfTextSelectionParams(
                    enabled: true,
                    enableSelectionHandles: true,
                    showContextMenuAutomatically: true,
                  ),
                  customizeContextMenuItems: (params, items) {
                    items.insert(
                      0,
                      ContextMenuButtonItem(
                        label: 'نطق الكلمة',
                        onPressed: () async {
                          final text = await params.textSelectionDelegate.getSelectedText();
                          params.dismissContextMenu();
                          if (text != null && text.trim().isNotEmpty) {
                            _pronounceSelectedWord(text.trim());
                          }
                        },
                      ),
                    );
                    items.insert(
                      1,
                      ContextMenuButtonItem(
                        label: 'ترجمة الكلمة',
                        onPressed: () async {
                          final text = await params.textSelectionDelegate.getSelectedText();
                          params.dismissContextMenu();
                          if (text != null && text.trim().isNotEmpty) {
                            _translateSelectedWord(text.trim());
                          }
                        },
                      ),
                    );
                  },
                  onViewerReady: (document, _) =>
                      editor.setTotalPages(document.pages.length),
                  onPageChanged: (page) => editor.setPage((page ?? 1) - 1),
                  pageOverlaysBuilder: (context, pageRect, page) => [
                    AnimatedBuilder(
                      animation: editor,
                      builder: (_, _) => PdfPageAnnotationLayer(
                        controller: editor,
                        pageIndex: page.pageNumber - 1,
                        onAddText: (page, position) =>
                            _editText(page: page, position: position),
                        onEditText: (text) => _editText(existing: text),
                        onAddNote: (page, position) =>
                            _editNote(page: page, position: position),
                        onEditNote: (note) => _editNote(existing: note),
                        onHighlightDeleted: _highlightDeleted,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.enableAmbientSounds) const StudyAmbienceMixer(),
              AnimatedBuilder(
                animation: editor,
                builder: (_, _) {
                  if (editor.tool != PdfToolMode.highlight &&
                      editor.tool != PdfToolMode.text &&
                      editor.tool != PdfToolMode.note) {
                    return const SizedBox.shrink();
                  }
                  return Positioned(
                    top: 14,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Material(
                        elevation: 4,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(30),
                        color: Colors.white.withValues(alpha: .96),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FilledButton.icon(
                                onPressed: () => _setTool(PdfToolMode.scroll),
                                icon: const Icon(
                                  Icons.pan_tool_outlined,
                                  size: 18,
                                  color: Colors.white,
                                ),
                                label: const Text(
                                  'تصفح',
                                  style: TextStyle(
                                    fontFamily: 'IBM',
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF6D28D9),
                                  foregroundColor: Colors.white,
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              FilledButton.icon(
                                onPressed: editor.tool == PdfToolMode.highlight
                                    ? editor.undoHighlight
                                    : editor.undo,
                                icon: const Icon(
                                  Icons.undo_rounded,
                                  size: 18,
                                  color: Color(0xFF6D28D9),
                                ),
                                label: const Text(
                                  'رجوع',
                                  style: TextStyle(
                                    fontFamily: 'IBM',
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF6D28D9),
                                  ),
                                ),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFFEDE9FE),
                                  foregroundColor: const Color(0xFF6D28D9),
                                  visualDensity: VisualDensity.compact,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ],
  );

  Future<void> _editText({
    int? page,
    Offset? position,
    PdfTextAnnotation? existing,
  }) async {
    final draft =
        existing?.copy() ??
        PdfTextAnnotation(
          id: 'text_${DateTime.now().microsecondsSinceEpoch}',
          pageIndex: page ?? editor.currentPage,
          position: position!,
          text: '',
          fontSize: editor.preferredFontSize,
        );
    final result = await showTextAnnotationEditor(
      context,
      draft,
      isNew: existing == null,
    );
    if (result == null) return;
    if (result.delete) {
      editor.deleteText(existing!);
    } else {
      editor.preferredFontSize = result.value!.fontSize;
      if (existing == null) {
        editor.addText(result.value!);
      } else {
        editor.updateText(existing, result.value!);
      }
    }
  }

  Future<void> _editNote({
    int? page,
    Offset? position,
    PdfNote? existing,
  }) async {
    final draft =
        existing?.copy() ??
        PdfNote(
          id: 'note_${DateTime.now().microsecondsSinceEpoch}',
          pageIndex: page ?? editor.currentPage,
          position: position!,
          text: '',
          color: Colors.white,
          createdAt: DateTime.now(),
          size: 140,
          isPinned: false,
        );
    final result = await showNoteEditor(
      context,
      draft,
      isNew: existing == null,
    );
    if (result == null) return;
    if (result.delete) {
      editor.deleteNote(existing!);
    } else if (existing == null) {
      editor.addNote(result.value!);
    } else {
      editor.updateNote(existing, result.value!);
    }
  }

  Future<void> _openNotes() async {
    final note = await showDocumentNotes(context, editor.document);
    if (note == null) return;
    await pdfController.goToPage(pageNumber: note.pageIndex + 1);
    editor.setPage(note.pageIndex);
  }

  void _openAi() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AiPdfStudyScreen(pdfPath: editor.localPath!, title: widget.title),
      ),
    );
  }

  Future<void> _save() async {
    await editor.saveNow();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ التعديلات مع المستند')),
    );
  }

  Future<void> _close() async {
    await editor.saveNow();
    if (mounted) Navigator.of(context).pop(true);
  }

  void _showOfflineStatus() => ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('الملف محفوظ بأمان ومتاح بدون إنترنت')),
  );

  void _highlightDeleted() => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: const Text('تم حذف التظليل'),
      action: SnackBarAction(label: 'تراجع', onPressed: editor.undo),
    ),
  );

  void _setTool(PdfToolMode tool) {
    editor.setTool(tool);
    if (tool != PdfToolMode.highlight) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'ارسم للتظليل، واضغط على أي تظليل موجود لمسحه. يمكنك التراجع من زر التراجع.',
          ),
          duration: Duration(seconds: 4),
        ),
      );
  }

  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح تعديلات الصفحة؟'),
        content: const Text('يمكنك التراجع بعد المسح من زر التراجع.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح'),
          ),
        ],
      ),
    );
    if (confirmed == true) editor.clearPage();
  }

  Future<void> _pronounceSelectedWord(String text) async {
    final clean = text.replaceAll(RegExp(r"^[^a-zA-Z0-9\u0600-\u06FF]+|[^a-zA-Z0-9\u0600-\u06FF]+$"), '').trim();
    if (clean.isEmpty) return;
    try {
      _ttsPlayer ??= AudioPlayer();
      await TtsCacheService.instance.pronounce(_ttsPlayer!, clean);
    } catch (_) {}
  }

  void _translateSelectedWord(String text) {
    PdfWordTranslationDialog.show(
      context,
      word: text,
      pdfTitle: widget.title,
    );
  }
}
