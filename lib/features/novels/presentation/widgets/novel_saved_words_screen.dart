import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:just_audio/just_audio.dart' as just_audio;

import '../../../../core/services/tts_cache_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/novels_repository.dart';
import '../../domain/novel_entities.dart';

typedef SavedWordsPageLoader =
    Future<List<NovelWord>> Function({
      required int offset,
      required int limit,
      String? queryText,
    });

typedef SavedWordPronouncer =
    Future<void> Function(String word, {VoidCallback? onPlaybackStarted});

class NovelSavedWordsScreen extends StatelessWidget {
  const NovelSavedWordsScreen({
    super.key,
    required this.loadPage,
    required this.pronounceWord,
    this.initialQuery = '',
  });

  final SavedWordsPageLoader loadPage;
  final SavedWordPronouncer pronounceWord;
  final String initialQuery;

  static Future<void> open(
    BuildContext context, {
    String initialQuery = '',
    bool openDirectlyAsPage = false,
  }) async {
    final repository = NovelsRepository();
    final player = just_audio.AudioPlayer();
    var shouldOpenAsPage = openDirectlyAsPage;
    var searchQuery = initialQuery;

    Future<List<NovelWord>> loadPage({
      required int offset,
      required int limit,
      String? queryText,
    }) => repository.loadSavedWords(
      offset: offset,
      limit: limit,
      queryText: queryText,
    );

    Future<void> pronounceWord(
      String word, {
      VoidCallback? onPlaybackStarted,
    }) => TtsCacheService.instance.pronounce(
      player,
      word,
      onPlaybackStarted: onPlaybackStarted,
    );

    try {
      if (!openDirectlyAsPage) {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          useSafeArea: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
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
              builder: (ctx, scrollController) => Directionality(
                textDirection: TextDirection.rtl,
                child: NovelSavedWordsCollection(
                  loadPage: loadPage,
                  pronounceWord: pronounceWord,
                  scrollController: scrollController,
                  initialQuery: searchQuery,
                  onQueryChanged: (value) => searchQuery = value,
                ),
              ),
            ),
          ),
        );
      }

      if (context.mounted && shouldOpenAsPage) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => NovelSavedWordsScreen(
              initialQuery: searchQuery,
              loadPage: loadPage,
              pronounceWord: pronounceWord,
            ),
          ),
        );
      }
    } finally {
      await player.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(
            'حصيلة الكلمات المحفوظة',
            style: TextStyle(
              fontSize: 17.5.sp,
              fontWeight: FontWeight.w800,
              fontFamily: 'IBM',
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: NovelSavedWordsCollection(
                loadPage: loadPage,
                pronounceWord: pronounceWord,
                initialQuery: initialQuery,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NovelSavedWordsCollection extends StatefulWidget {
  const NovelSavedWordsCollection({
    super.key,
    required this.loadPage,
    required this.pronounceWord,
    this.initialQuery = '',
    this.scrollController,
    this.onQueryChanged,
    this.showTitle = false,
  });

  final SavedWordsPageLoader loadPage;
  final SavedWordPronouncer pronounceWord;
  final String initialQuery;
  final ScrollController? scrollController;
  final ValueChanged<String>? onQueryChanged;
  final bool showTitle;

  @override
  State<NovelSavedWordsCollection> createState() =>
      _NovelSavedWordsCollectionState();
}

class _NovelSavedWordsCollectionState extends State<NovelSavedWordsCollection> {
  static const _pageSize = 30;
  static const _prefetchDistance = 280.0;

  final _searchController = TextEditingController();
  final List<NovelWord> _words = [];
  ScrollController? _ownedScrollController;
  Timer? _searchDebounce;
  String _query = '';
  Object? _loadError;
  int _requestGeneration = 0;
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  ScrollController get _listController =>
      widget.scrollController ?? _ownedScrollController!;

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery;
    _searchController.text = _query;
    if (widget.scrollController == null) {
      _ownedScrollController = ScrollController();
    }
    unawaited(_loadPage(reset: true));
  }

  @override
  void didUpdateWidget(covariant NovelSavedWordsCollection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      _ownedScrollController?.dispose();
      _ownedScrollController = widget.scrollController == null
          ? ScrollController()
          : null;
    }
  }

  @override
  void dispose() {
    _requestGeneration++;
    _searchDebounce?.cancel();
    _searchController.dispose();
    _ownedScrollController?.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _query = value;
    widget.onQueryChanged?.call(value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_loadPage(reset: true)),
    );
    setState(() {});
  }

  Future<void> _loadPage({bool reset = false}) async {
    if (!reset && (_isLoadingMore || !_hasMore)) return;
    final generation = reset ? ++_requestGeneration : _requestGeneration;
    final offset = reset ? 0 : _words.length;
    setState(() {
      _isLoading = reset;
      _isLoadingMore = true;
      _loadError = null;
      if (reset) {
        _words.clear();
        _hasMore = true;
      }
    });

    try {
      final page = await widget.loadPage(
        offset: offset,
        limit: _pageSize,
        queryText: _query.trim().isEmpty ? null : _query.trim(),
      );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _words.addAll(page);
        _hasMore = page.length == _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
      _schedulePrefetchIfNeeded(generation);
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _schedulePrefetchIfNeeded(int generation) {
    if (!_hasMore) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          generation != _requestGeneration ||
          !_listController.hasClients ||
          _listController.position.extentAfter >= _prefetchDistance) {
        return;
      }
      unawaited(_loadPage());
    });
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis == Axis.vertical &&
        notification.metrics.extentAfter < _prefetchDistance) {
      unawaited(_loadPage());
    }
    return false;
  }

  Widget _buildList() {
    if (_words.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_words.isEmpty && _loadError != null) {
      return _buildError(isInitial: true);
    }
    if (_words.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(28.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64.w,
                height: 64.w,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(16),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.collections_bookmark_rounded,
                  size: 30.sp,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                _query.trim().isEmpty
                    ? 'لم تحفظ أي كلمات من الروايات بعد'
                    : 'لا توجد كلمات مطابقة لبحثك',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w800,
                  fontFamily: 'IBM',
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 6.h),
              Text(
                _query.trim().isEmpty
                    ? 'أثناء قراءة أي رواية، اضغط على أي كلمة تود حفظها ومراجعتها لاحقًا.'
                    : 'جرّب البحث باسم كلمة أخرى أو اسم رواية مختلفة.',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  fontFamily: 'IBM',
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              if (_query.trim().isNotEmpty) ...[
                SizedBox(height: 14.h),
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _onQueryChanged('');
                  },
                  child: const Text('مسح البحث'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: ListView.separated(
        controller: _listController,
        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
        itemCount: _words.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          if (index == _words.length) {
            if (_isLoadingMore) {
              return Padding(
                padding: EdgeInsets.all(16.h),
                child: const Center(child: CircularProgressIndicator()),
              );
            }
            if (_loadError != null) return _buildError(isInitial: false);
            return Center(
              child: TextButton(
                onPressed: () => unawaited(_loadPage()),
                child: const Text('تحميل المزيد'),
              ),
            );
          }
          return _SavedWordTile(
            word: _words[index],
            pronounceWord: widget.pronounceWord,
          );
        },
      ),
    );
  }

  Widget _buildError({required bool isInitial}) => Center(
    child: Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.error_outline_rounded, size: 40.sp, color: AppColors.error),
          SizedBox(height: 10.h),
          Text(
            'تعذر تحميل حصيلة الكلمات.',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              fontFamily: 'IBM',
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 12.h),
          FilledButton(
            onPressed: () => unawaited(_loadPage(reset: isInitial)),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showTitle)
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 6.h),
            child: Text(
              'حصيلة الكلمات المحفوظة',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                fontFamily: 'IBM',
                color: AppColors.textPrimary,
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 10.h),
          child: TextField(
            controller: _searchController,
            onChanged: _onQueryChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchController.clear();
                        _onQueryChanged('');
                      },
                    )
                  : null,
              hintText: 'ابحث عن كلمة، أو اسم الرواية، أو رقم الفصل...',
              hintStyle: TextStyle(
                fontSize: 12.5.sp,
                color: AppColors.textMuted,
                fontFamily: 'IBM',
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide(color: AppColors.border.withAlpha(120)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: BorderSide(color: AppColors.border.withAlpha(120)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14.r),
                borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
        ),
        Expanded(child: _buildList()),
      ],
    );
  }
}

class _SavedWordTile extends StatefulWidget {
  const _SavedWordTile({required this.word, required this.pronounceWord});

  final NovelWord word;
  final SavedWordPronouncer pronounceWord;

  @override
  State<_SavedWordTile> createState() => _SavedWordTileState();
}

class _SavedWordTileState extends State<_SavedWordTile> {
  bool _isSpeaking = false;

  Future<void> _speak() async {
    if (_isSpeaking) return;
    setState(() => _isSpeaking = true);
    var playbackStarted = false;
    try {
      await widget.pronounceWord(
        widget.word.word,
        onPlaybackStarted: () {
          playbackStarted = true;
          if (mounted) setState(() => _isSpeaking = false);
        },
      );
    } finally {
      if (!playbackStarted && mounted) {
        setState(() => _isSpeaking = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.border.withAlpha(100)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          widget.word.word,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16.sp,
                            fontFamily: 'IBM',
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      if (widget.word.transcription.isNotEmpty) ...[
                        SizedBox(width: 8.w),
                        Text(
                          widget.word.transcription,
                          style: TextStyle(
                            fontSize: 11.5.sp,
                            color: AppColors.textSecondary,
                            fontFamily: 'IBM',
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    widget.word.arabicMeaning,
                    style: TextStyle(
                      fontSize: 13.5.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBM',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (widget.word.contextMeaning.isNotEmpty &&
                      widget.word.contextMeaning != widget.word.arabicMeaning) ...[
                    SizedBox(height: 3.h),
                    Text(
                      'في السياق: ${widget.word.contextMeaning}',
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary,
                        fontFamily: 'IBM',
                        height: 1.35,
                      ),
                    ),
                  ],
                  if (widget.word.novelTitle != null && widget.word.novelTitle!.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                      decoration: BoxDecoration(
                        color: (widget.word.chapterNumber == null || widget.word.chapterNumber! <= 0)
                            ? const Color(0xFFFEF2F2)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6.r),
                        border: (widget.word.chapterNumber == null || widget.word.chapterNumber! <= 0)
                            ? Border.all(color: const Color(0xFFFECACA), width: 0.8)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.word.chapterNumber == null || widget.word.chapterNumber! <= 0) ...[
                            Icon(
                              Icons.picture_as_pdf_rounded,
                              size: 13.sp,
                              color: const Color(0xFFDC2626),
                            ),
                            SizedBox(width: 4.w),
                            Flexible(
                              child: Text(
                                widget.word.novelTitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  color: const Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'IBM',
                                ),
                              ),
                            ),
                          ] else ...[
                            Flexible(
                              child: Text(
                                '${widget.word.novelTitle} • الفصل ${widget.word.chapterNumber}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5.sp,
                                  color: const Color(0xFF475569),
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'IBM',
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(width: 8.w),
            _isSpeaking
                ? SizedBox(
                    width: 44.w,
                    height: 44.w,
                    child: Center(
                      child: SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'نطق الكلمة',
                    onPressed: _speak,
                    icon: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(16),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.volume_up_rounded,
                        color: AppColors.primary,
                        size: 20.sp,
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
