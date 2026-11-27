import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:shimmer/shimmer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/novels_repository.dart';
import '../../data/mediapipe_novel_audio_service.dart';
import '../../domain/novel_entities.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../widgets/novel_subscription_sheet.dart';
import '../widgets/novel_saved_words_screen.dart';

class NovelsListScreen extends StatefulWidget {
  const NovelsListScreen({super.key});
  @override
  State<NovelsListScreen> createState() => _NovelsListScreenState();
}

class _NovelsListScreenState extends State<NovelsListScreen> {
  final _repository = NovelsRepository();
  final _speech = MediaPipeNovelAudioService();
  final _wordPlayer = just_audio.AudioPlayer();
  final _scrollController = ScrollController();

  String? _level;
  bool _hasSubscription = false;
  bool _subscriptionLoading = true;
  bool _bannerVisible = true;
  List<Novel> _novels = const [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _errorMessage;

  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadNovels(reset: true);
    _loadSubscription();
    _loadBannerSettings();
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _wordPlayer.dispose();
    _speech.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 240) {
      _loadMore();
    }
  }

  Future<void> _loadNovels({bool reset = false}) async {
    if (reset) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _hasMore = true;
      });
    }

    try {
      final offset = reset ? 0 : _novels.length;
      final newNovels = await _repository.fetchNovels(
        level: _level,
        offset: offset,
        limit: _pageSize,
      );

      if (!mounted) return;
      setState(() {
        if (reset) {
          _novels = newNovels;
        } else {
          _novels = [..._novels, ...newNovels];
        }
        _hasMore = newNovels.length >= _pageSize;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage =
            'تعذر تحميل الروايات الآن. يرجى التحقق من اتصالك بالإنترنت.';
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    await _loadNovels(reset: false);
  }

  Future<void> _loadSubscription() async {
    try {
      final subscribed = await _repository.hasActiveSubscription();
      if (mounted) setState(() => _hasSubscription = subscribed);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر التحقق من الاشتراك: $error',
              style: const TextStyle(fontFamily: 'IBM'),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _subscriptionLoading = false);
    }
  }

  Future<void> _loadBannerSettings() async {
    try {
      final row = await Supabase.instance.client
          .from('library_subscription_settings')
          .select('banner_visible')
          .eq('id', true)
          .maybeSingle();
      if (mounted && row != null)
        setState(() => _bannerVisible = row['banner_visible'] != false);
    } catch (_) {
      // Keep the banner visible when settings are unavailable.
    }
  }

  Future<void> _openNovel(Novel novel) async {
    if (novel.isFree || _hasSubscription) {
      if (mounted) context.push(AppRoutes.novelReader, extra: novel.id);
      return;
    }
    final paid = await NovelSubscriptionSheet.show(context);
    if (paid == true && mounted) {
      setState(() => _hasSubscription = true);
      context.push(AppRoutes.novelReader, extra: novel.id);
    }
  }

  void _changeLevel(String? value) {
    if (_level == value && !_isLoading) return;
    setState(() {
      _level = value;
    });
    _loadNovels(reset: true);
  }

  void _openSavedWords() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NovelSavedWordsScreen(
          loadPage:
              ({required int offset, required int limit, String? queryText}) =>
                  _repository.loadSavedWords(
                    offset: offset,
                    limit: limit,
                    queryText: queryText,
                  ),
          pronounceWord: (word, {VoidCallback? onPlaybackStarted}) async {
            try {
              final audio = await _speech.synthesizeWord(word: word);
              await _wordPlayer.stop();
              await _wordPlayer.setFilePath(audio.path);
              final completed = _wordPlayer.processingStateStream.firstWhere(
                (state) => state == just_audio.ProcessingState.completed,
              );
              await _wordPlayer.play();
              onPlaybackStarted?.call();
              await completed;
            } catch (_) {
              try {
                final googleUrl =
                    'https://translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=en&q=${Uri.encodeComponent(word.trim())}';
                await _wordPlayer.stop();
                await _wordPlayer.setUrl(googleUrl);
                final completed = _wordPlayer.processingStateStream.firstWhere(
                  (state) => state == just_audio.ProcessingState.completed,
                );
                await _wordPlayer.play();
                onPlaybackStarted?.call();
                await completed;
              } catch (_) {}
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'روايات إنجليزية تفاعلية',
          style: TextStyle(
            fontSize: 17.5.sp,
            fontWeight: FontWeight.w800,
            fontFamily: 'IBM',
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'حصيلة كلماتي',
            icon: const Icon(Icons.collections_bookmark_rounded),
            onPressed: _openSavedWords,
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => _loadNovels(reset: true),
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroCard(),
                          SizedBox(height: 16.h),
                          if (_bannerVisible &&
                              !_subscriptionLoading &&
                              !_hasSubscription) ...[
                            _buildSubscriptionBanner(),
                            SizedBox(height: 16.h),
                          ],
                          _buildFilterBar(),
                        ],
                      ),
                    ),
                  ),
                  if (_isLoading)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                        child: _buildSectionShimmer(),
                      ),
                    )
                  else if (_errorMessage != null && _novels.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessageState(
                        icon: Icons.wifi_off_rounded,
                        title: 'تعذر تحميل الروايات الآن',
                        subtitle:
                            'يرجى التحقق من اتصالك بالإنترنت ثم إعادة المحاولة.',
                        actionText: 'إعادة المحاولة',
                        action: () => _loadNovels(reset: true),
                      ),
                    )
                  else if (_novels.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _MessageState(
                        icon: Icons.menu_book_rounded,
                        title: 'لم تُضف روايات لهذا المستوى بعد',
                        subtitle:
                            'يمكنك اختيار مستوى آخر أو عرض جميع الروايات المتاحة.',
                        actionText: 'عرض كل المستويات',
                        action: () => _changeLevel(null),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                      sliver: SliverList.builder(
                        itemCount: _novels.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _novels.length) {
                            return Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.h),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            );
                          }
                          final novel = _novels[index];
                          final isLocked =
                              !novel.isFree &&
                              !_hasSubscription &&
                              !_subscriptionLoading;
                          return _NovelCard(
                            novel: novel,
                            isLocked: isLocked,
                            onTap: _subscriptionLoading && !novel.isFree
                                ? () => ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'جارٍ التحقق من حالة الاشتراك',
                                            style: TextStyle(fontFamily: 'IBM'),
                                          ),
                                        ),
                                      )
                                : () => _openNovel(novel),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFF312E81), Color(0xFF6D28D9)],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withAlpha(45),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44.w,
                height: 44.w,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(28),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: const Icon(
                  Icons.auto_stories_rounded,
                  color: Color(0xFFFDE68A),
                  size: 24,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اقرأ، اسمع، وتعلّم يوميًا',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.5.sp,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'IBM',
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'اضغط على أي كلمة لمعرفة معناها وسماع نطقها',
                      style: TextStyle(
                        color: Colors.white.withAlpha(210),
                        fontSize: 11.5.sp,
                        fontFamily: 'IBM',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _buildFeatureBadge(
                icon: Icons.translate_rounded,
                label: 'ترجمة فورية سياقية',
              ),
              _buildFeatureBadge(
                icon: Icons.record_voice_over_rounded,
                label: 'نطق صوتي دقيق',
              ),
              _buildFeatureBadge(
                icon: Icons.bookmark_add_rounded,
                label: 'حفظ المفردات',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureBadge({required IconData icon, required String label}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12.sp, color: const Color(0xFFFDE68A)),
          SizedBox(width: 4.w),
          Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w600,
              fontFamily: 'IBM',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionBanner() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          final paid = await NovelSubscriptionSheet.show(context);
          if (paid == true && mounted) {
            setState(() => _hasSubscription = true);
          }
        },
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [Color(0xFFFEF3C7), Color(0xFFFDE68A)],
            ),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFF59E0B).withAlpha(80)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFF59E0B).withAlpha(25),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'اشتراك مكتبة الروايات',
                      style: TextStyle(
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF78350F),
                        fontFamily: 'IBM',
                      ),
                    ),
                    Text(
                      'افتح كل الفصول واستمع بلا حدود يومية',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: const Color(0xFF92400E),
                        fontFamily: 'IBM',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: const Color(0xFF92400E),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  'عرض الباقات',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar() {
    final filters = [
      (null, 'كل المستويات'),
      ('beginner', 'مبتدئ A1-A2'),
      ('intermediate', 'متوسط B1-B2'),
      ('advanced', 'متقدم C1'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: filters.map((item) {
          final isSelected = _level == item.$1;
          return Padding(
            padding: EdgeInsetsDirectional.only(end: 8.w),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12.r),
                onTap: () => _changeLevel(item.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14.w,
                    vertical: 8.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border.withAlpha(120),
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: isSelected
                          ? FontWeight.w800
                          : FontWeight.w600,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontFamily: 'IBM',
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSectionShimmer() {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Column(
        children: List.generate(
          3,
          (_) => Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: Container(
              height: 104.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18.r),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(20.w),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            Container(
              height: 120.h,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20.r),
              ),
            ),
            SizedBox(height: 16.h),
            Row(
              children: List.generate(
                3,
                (_) => Padding(
                  padding: EdgeInsetsDirectional.only(end: 8.w),
                  child: Container(
                    width: 90.w,
                    height: 36.h,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            ...List.generate(
              3,
              (_) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: Container(
                  height: 104.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NovelCard extends StatelessWidget {
  const _NovelCard({
    required this.novel,
    required this.isLocked,
    required this.onTap,
  });

  final Novel novel;
  final bool isLocked;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18.r),
        side: BorderSide(color: AppColors.border.withAlpha(120)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cover image
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Container(
                  width: 66.w,
                  height: 88.h,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                      colors: [Color(0xFF1E1B4B), Color(0xFF4338CA)],
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: novel.coverUrl != null && novel.coverUrl!.isNotEmpty
                      ? Image.network(
                          novel.coverUrl!,
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                          errorBuilder: (_, _, _) => Center(
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 30.sp,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            Icons.menu_book_rounded,
                            size: 30.sp,
                            color: Colors.white70,
                          ),
                        ),
                ),
              ),
              SizedBox(width: 14.w),

              // Info & Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(
                        novel.title,
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15.5.sp,
                          fontFamily: 'IBM',
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (novel.description.isNotEmpty) ...[
                      SizedBox(height: 4.h),
                      Text(
                        novel.description,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: AppColors.textSecondary,
                          height: 1.35,
                          fontFamily: 'IBM',
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 10.h),

                    // Badges row
                    Wrap(
                      spacing: 6.w,
                      runSpacing: 4.h,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Level badge
                        _buildBadge(
                          text: _levelName(novel.level),
                          backgroundColor: _levelColor(
                            novel.level,
                          ).withAlpha(20),
                          textColor: _levelColor(novel.level),
                        ),

                        // Chapters count
                        _buildBadge(
                          text: '${novel.chapters.length} فصول',
                          backgroundColor: const Color(0xFFF1F5F9),
                          textColor: const Color(0xFF475569),
                          icon: Icons.layers_rounded,
                        ),

                        // Access status badge
                        if (novel.isFree)
                          _buildBadge(
                            text: 'مجانية',
                            backgroundColor: const Color(0xFFDCFCE7),
                            textColor: const Color(0xFF047857),
                            icon: Icons.check_circle_outline_rounded,
                          )
                        else if (isLocked)
                          _buildBadge(
                            text: 'تحتاج اشتراك',
                            backgroundColor: const Color(0xFFFEF3C7),
                            textColor: const Color(0xFFB45309),
                            icon: Icons.lock_outline_rounded,
                          )
                        else
                          _buildBadge(
                            text: 'مفتوحة باشتراكك',
                            backgroundColor: const Color(0xFFF3E8FF),
                            textColor: const Color(0xFF7E22CE),
                            icon: Icons.verified_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14.sp,
                color: Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge({
    required String text,
    required Color backgroundColor,
    required Color textColor,
    IconData? icon,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10.sp, color: textColor),
            SizedBox(width: 3.w),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
              fontFamily: 'IBM',
            ),
          ),
        ],
      ),
    );
  }

  String _levelName(String level) => switch (level.toLowerCase()) {
    'beginner' => 'مبتدئ',
    'intermediate' => 'متوسط',
    'advanced' => 'متقدم',
    _ => level,
  };

  Color _levelColor(String level) => switch (level.toLowerCase()) {
    'beginner' => const Color(0xFF0D9488),
    'intermediate' => const Color(0xFF2563EB),
    'advanced' => const Color(0xFF7C3AED),
    _ => AppColors.primary,
  };
}

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionText,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68.w,
              height: 68.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34.sp, color: AppColors.primary),
            ),
            SizedBox(height: 16.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15.5.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                fontFamily: 'IBM',
              ),
            ),
            if (subtitle != null) ...[
              SizedBox(height: 6.h),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontFamily: 'IBM',
                ),
              ),
            ],
            if (action != null && actionText != null) ...[
              SizedBox(height: 16.h),
              FilledButton(
                onPressed: action,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: EdgeInsets.symmetric(
                    horizontal: 24.w,
                    vertical: 10.h,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  actionText!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
