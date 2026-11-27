part of '../novel_reader_state.dart';

extension _ReaderSettings on NovelReaderState {
  Future<void> _showSavedWords() async {
    final novel = _novel;
    if (novel == null) return;
    var shouldOpenAsPage = false;
    var searchQuery = '';
    Future<List<NovelWord>> loadPage({
      required int offset,
      required int limit,
      String? queryText,
    }) => _repository.loadSavedWords(
      offset: offset,
      limit: limit,
      queryText: queryText,
    );
    Future<void> pronounceWord(
      String word, {
      VoidCallback? onPlaybackStarted,
    }) => _speakWord(word, onPlaybackStarted: onPlaybackStarted);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (sheetContext) =>
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              if (!shouldOpenAsPage &&
                  notification.extent >= notification.maxExtent) {
                shouldOpenAsPage = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                });
              }
              return false;
            },
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: .72,
              minChildSize: .48,
              maxChildSize: 1,
              snap: true,
              snapSizes: const [.72, 1],
              builder: (context, scrollController) => Directionality(
                textDirection: TextDirection.rtl,
                child: NovelSavedWordsCollection(
                  loadPage: loadPage,
                  pronounceWord: pronounceWord,
                  scrollController: scrollController,
                  onQueryChanged: (value) => searchQuery = value,
                ),
              ),
            ),
          ),
    );
    if (!mounted || !shouldOpenAsPage) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NovelSavedWordsScreen(
          loadPage: loadPage,
          pronounceWord: pronounceWord,
          initialQuery: searchQuery,
        ),
      ),
    );
  }

  Widget _colorChoiceButton(
    String label,
    Color color,
    ValueChanged<Color> onChanged, {
    Color? contrastAgainst,
    String contrastLabel = 'لون الصفحة',
    double minContrastRatio = 3.2,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(
      label,
      style: const TextStyle(
        fontFamily: 'IBM',
        fontWeight: FontWeight.w600,
        fontSize: 13.5,
      ),
    ),
    leading: Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black26),
      ),
    ),
    trailing: const Icon(Icons.colorize_rounded, size: 20),
    onTap: () async {
      final picked = await showDialog<Color>(
        context: context,
        builder: (_) => ReaderColorDialog(
          initial: color,
          contrastAgainst: contrastAgainst,
          contrastLabel: contrastLabel,
          minContrastRatio: minContrastRatio,
        ),
      );
      if (picked != null) onChanged(picked);
    },
  );

  Widget _presetThemeCard({
    required String name,
    required Color page,
    required Color text,
    required Color highlight,
    required StateSetter setSheetState,
  }) {
    final isSelected =
        _pageColor.toARGB32() == page.toARGB32() &&
        _textColor.toARGB32() == text.toARGB32();
    return GestureDetector(
      onTap: () {
        _updateState(() {
          _pageColor = page;
          _textColor = text;
          _highlightColor = highlight;
        });
        setSheetState(() {});
        _schedulePreferencesSave();
      },
      child: Container(
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: page,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.black12,
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            else
              const BoxShadow(
                color: Colors.black12,
                blurRadius: 3,
                offset: Offset(0, 1),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Aa',
              style: TextStyle(
                color: text,
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              name,
              style: TextStyle(
                color: text.withValues(alpha: 0.88),
                fontFamily: 'IBM',
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showReadingSettings() => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => Theme(
      data: Theme.of(sheetContext).copyWith(
        canvasColor: Colors.white,
        scaffoldBackgroundColor: Colors.white,
        colorScheme: Theme.of(sheetContext).colorScheme.copyWith(
          surface: Colors.white,
          onSurface: const Color(0xff17202A),
        ),
      ),
      child: StatefulBuilder(
        builder: (context, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'إعدادات القراءة',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, fontFamily: 'IBM'),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('حجم النص الإنجليزي', style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w600)),
                  Text(
                    '${_englishFontSize.round()} pt',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.text_decrease),
                  Expanded(
                    child: Slider(
                      value: _englishFontSize.clamp(8, 36),
                      min: 8,
                      max: 36,
                      onChanged: (value) {
                        _updateState(() => _englishFontSize = value);
                        setSheetState(() {});
                        _schedulePreferencesSave();
                      },
                    ),
                  ),
                  const Icon(Icons.text_increase),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('حجم النص العربي', style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w600)),
                  Text(
                    '${_arabicFontSize.round()} pt',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.text_decrease),
                  Expanded(
                    child: Slider(
                      value: _arabicFontSize.clamp(8, 36),
                      min: 8,
                      max: 36,
                      onChanged: (value) {
                        _updateState(() => _arabicFontSize = value);
                        setSheetState(() {});
                        _schedulePreferencesSave();
                      },
                    ),
                  ),
                  const Icon(Icons.text_increase),
                ],
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'عرض فيديو الخلفية التزامني',
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                subtitle: const Text(
                  'تشغيل مقاطع الفيديو المصاحبة للمشاهد في الخلفية',
                  style: TextStyle(fontFamily: 'IBM', fontSize: 12),
                ),
                value: _showVideo,
                activeColor: const Color(0xFF6D28D9),
                onChanged: (val) {
                  _updateState(() => _showVideo = val);
                  setSheetState(() {});
                  _schedulePreferencesSave();
                },
              ),
              const Divider(height: 18),
              const Text(
                'أنماط القراءة المعتمدة (موصى بها)',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 68,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _presetThemeCard(
                      name: 'كلاسيكي',
                      page: const Color(0xFFF8FAFC),
                      text: const Color(0xFF1E1B4B),
                      highlight: const Color(0xFFFFE28A),
                      setSheetState: setSheetState,
                    ),
                    const SizedBox(width: 8),
                    _presetThemeCard(
                      name: 'سيبيا ورقي',
                      page: const Color(0xFFF4ECD8),
                      text: const Color(0xFF2E241A),
                      highlight: const Color(0xFFFCD34D),
                      setSheetState: setSheetState,
                    ),
                    const SizedBox(width: 8),
                    _presetThemeCard(
                      name: 'ليلي فاخر',
                      page: const Color(0xFF0F172A),
                      text: const Color(0xFFE2E8F0),
                      highlight: const Color(0xFF4338CA),
                      setSheetState: setSheetState,
                    ),
                    const SizedBox(width: 8),
                    _presetThemeCard(
                      name: 'نعناعي مريح',
                      page: const Color(0xFFEDF7EE),
                      text: const Color(0xFF143020),
                      highlight: const Color(0xFFA7F3D0),
                      setSheetState: setSheetState,
                    ),
                    const SizedBox(width: 8),
                    _presetThemeCard(
                      name: 'قهوة عتيقة',
                      page: const Color(0xFFEFE6DD),
                      text: const Color(0xFF2B2018),
                      highlight: const Color(0xFFF59E0B),
                      setSheetState: setSheetState,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'تخصيص يدوي مع حماية التباين',
                style: TextStyle(
                  fontFamily: 'IBM',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              _colorChoiceButton(
                'لون الصفحة',
                _pageColor,
                (color) {
                  _updateState(() {
                    _pageColor = color;
                    final l1 = color.computeLuminance();
                    final l2 = _textColor.computeLuminance();
                    final ratio =
                        (math.max(l1, l2) + 0.05) /
                        (math.min(l1, l2) + 0.05);
                    if (ratio < 3.2) {
                      _textColor = _foregroundFor(color);
                    }
                  });
                  setSheetState(() {});
                  _schedulePreferencesSave();
                },
              ),
              _colorChoiceButton(
                'لون النص',
                _textColor,
                (color) {
                  _updateState(() => _textColor = color);
                  setSheetState(() {});
                  _schedulePreferencesSave();
                },
                contrastAgainst: _pageColor,
                contrastLabel: 'لون الصفحة',
                minContrastRatio: 3.5,
              ),
              _colorChoiceButton(
                'لون الهايلايت',
                _highlightColor,
                (color) {
                  _updateState(() => _highlightColor = color);
                  setSheetState(() {});
                  _schedulePreferencesSave();
                },
                contrastAgainst: _pageColor,
                contrastLabel: 'لون الصفحة',
                minContrastRatio: 1.35,
              ),
              TextButton.icon(
                onPressed: () async {
                  Navigator.of(sheetContext).pop();
                  await _pickBackground();
                },
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: const Text('اختيار صورة من الهاتف'),
              ),
              if (_backgroundPath != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 150,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(_backgroundPath!), fit: BoxFit.cover),
                          Align(
                            alignment: AlignmentDirectional.topEnd,
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Material(
                                color: Colors.black54,
                                shape: const CircleBorder(),
                                child: IconButton(
                                  tooltip: 'إلغاء صورة الخلفية',
                                  color: Colors.white,
                                  onPressed: () {
                                    _updateState(() => _backgroundPath = null);
                                    setSheetState(() {});
                                    _schedulePreferencesSave();
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );

  String _normalizeWord(String word) => normalizeNovelWord(word);
}
