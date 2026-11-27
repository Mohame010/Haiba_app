part of '../novel_reader_state.dart';

extension _ReaderAnnotations on NovelReaderState {
  Future<void> _pickBackground() async {
    try {
      final picked = await FilePicker.platform.pickFiles(type: FileType.image);
      final source = picked?.files.single.path;
      if (source == null) return;
      final directory = await getApplicationSupportDirectory();
      final extension = source.contains('.')
          ? source.substring(source.lastIndexOf('.'))
          : '.image';
      final target = File(
        '${directory.path}${Platform.pathSeparator}'
        'novel_background_${widget.novelId}$extension',
      );
      await File(source).copy(target.path);
      if (mounted) {
        _updateState(() => _backgroundPath = target.path);
        _schedulePreferencesSave();
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تعيين صورة الخلفية: $error')),
        );
      }
    }
  }

  Future<void> _saveHighlight(NovelWord word) async {
    final chapter = _chapter;
    final novel = _novel;
    if (chapter == null || novel == null) return;
    try {
      await _repository.saveAnnotation(
        novelId: novel.id,
        chapterId: chapter.id,
        selectedText: word.word,
        type: 'highlight',
      );
      if (!mounted) return;
      _updateState(() => _highlightedWords.add(_normalizeWord(word.word)));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ تمييز الكلمة')));
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حفظ التمييز: $error')));
      }
    }
  }

  Future<void> _editWordNote(NovelWord word) async {
    final normalizedWord = _normalizeWord(word.word);
    var editedNote = _chapterNotes[normalizedWord] ?? '';
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ملاحظة على ${word.word}'),
        content: TextFormField(
          initialValue: editedNote,
          autofocus: true,
          maxLines: 4,
          onChanged: (value) => editedNote = value,
          decoration: const InputDecoration(labelText: 'اكتب ملاحظتك'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, editedNote.trim()),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (note == null || note.isEmpty || !mounted) return;
    try {
      await _repository.saveAnnotation(
        novelId: _novel!.id,
        chapterId: _chapter!.id,
        selectedText: word.word,
        type: 'note',
        note: note,
      );
      if (mounted) {
        _updateState(() => _chapterNotes[normalizedWord] = note);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ الملاحظة')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر حفظ الملاحظة: $error')));
      }
    }
  }

  Future<void> _showWordNote(
    String word,
    GlobalKey anchorKey,
    String note,
  ) async {
    final renderObject = anchorKey.currentContext?.findRenderObject();
    final box = renderObject is RenderBox ? renderObject : null;
    final origin = box?.localToGlobal(Offset.zero) ?? const Offset(24, 140);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        final screen = MediaQuery.sizeOf(dialogContext);
        final width = math.min(290.0, screen.width - 32);
        final left = origin.dx
            .clamp(16.0, screen.width - width - 16)
            .toDouble();
        final top = (origin.dy - 135)
            .clamp(70.0, screen.height - 210)
            .toDouble();
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => Navigator.pop(dialogContext),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xfffff4b8),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 12),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          word,
                          textDirection: TextDirection.ltr,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        Text(note, textDirection: TextDirection.rtl),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openWord(
    String raw, {
    GlobalKey? anchorKey,
    int? sourceStart,
    int? sourceEnd,
  }) async {
    final clean = raw
        .replaceAll('\u2019', "'")
        .replaceAll(RegExp(r"[^A-Za-z\-']"), '');
    final novel = _novel;
    if (clean.isEmpty || novel == null) return;
    final wordFuture = _loadWord(novel.id, clean);
    await showDialog<void>(
      context: context,
      barrierColor: Colors.transparent,
      builder: (dialogContext) {
        final renderObject = anchorKey?.currentContext?.findRenderObject();
        final box = renderObject is RenderBox ? renderObject : null;
        final origin = box?.localToGlobal(Offset.zero) ?? const Offset(24, 120);
        final size = MediaQuery.sizeOf(dialogContext);
        final width = math.min(330.0, size.width - 32);
        final left = origin.dx.clamp(16.0, size.width - width - 16).toDouble();
        final top = (origin.dy - 190).clamp(72.0, size.height - 260).toDouble();
        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              child: Material(
                color: Colors.transparent,
                child: Card(
                  color: Colors.white.withValues(alpha: .94),
                  elevation: 10,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: FutureBuilder<NovelWord>(
                      future: wordFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState != ConnectionState.done) {
                          return _buildWordLoadingCard(clean);
                        }
                        if (snapshot.hasError || snapshot.data == null) {
                          return _buildWordErrorCard(
                            clean,
                            snapshot.error,
                            onRetry: () {
                              Navigator.pop(dialogContext);
                              unawaited(
                                _openWord(
                                  raw,
                                  anchorKey: anchorKey,
                                  sourceStart: sourceStart,
                                  sourceEnd: sourceEnd,
                                ),
                              );
                            },
                          );
                        }
                        return _buildWordCard(
                          snapshot.data!,
                          novel,
                          dialogContext,
                          sourceStart: sourceStart,
                          sourceEnd: sourceEnd,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<NovelWord> _loadWord(String novelId, String clean) async =>
      await _repository.findWord(novelId, clean) ??
      NovelWord(
        word: clean,
        arabicMeaning: 'لا يوجد معنى مسجل لهذه الكلمة',
        contextMeaning: 'لم يتم العثور على ترجمة.',
        transcription: 'غير متاح',
      );
}
