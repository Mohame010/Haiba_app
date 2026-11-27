import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../novels/data/novels_repository.dart';
import '../../../novels/domain/novel_entities.dart';
import '../../../novels/presentation/widgets/novel_saved_words_screen.dart';
import '../../../novels/presentation/widgets/novel_subscription_sheet.dart';
import '../../data/repositories/poetry_repository.dart';

class PoetryListScreen extends StatefulWidget {
  const PoetryListScreen({super.key, this.initialLevel});

  final String? initialLevel;

  @override
  State<PoetryListScreen> createState() => _PoetryListScreenState();
}

class _PoetryListScreenState extends State<PoetryListScreen> {
  final _repository = PoetryRepository();
  final _novelsRepo = NovelsRepository();
  final _scrollController = ScrollController();

  String? _level;
  bool _hasSubscription = false;
  bool _subscriptionLoading = true;
  List<Novel> _poems = const [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _level = widget.initialLevel;
    _loadPoems();
    _loadSubscription();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadPoems() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final poems = await _repository.fetchPoems(level: _level);
      if (!mounted) return;
      setState(() {
        _poems = poems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تحميل القصائد الآن. يرجى المحاولة لاحقاً.';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadSubscription() async {
    try {
      final subscribed = await _novelsRepo.hasActiveSubscription();
      if (mounted) setState(() => _hasSubscription = subscribed);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _subscriptionLoading = false);
    }
  }

  void _changeLevel(String? newLevel) {
    if (_level == newLevel && !_isLoading) return;
    setState(() => _level = newLevel);
    _loadPoems();
  }

  Future<void> _openPoem(Novel poem) async {
    if (poem.isFree || _hasSubscription) {
      if (mounted) context.push(AppRoutes.novelReader, extra: poem.id);
      return;
    }
    final paid = await NovelSubscriptionSheet.show(context);
    if (paid == true && mounted) {
      setState(() => _hasSubscription = true);
      context.push(AppRoutes.novelReader, extra: poem.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'قصائد وأشعار إنجليزية',
          style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'حصيلة كلماتي',
            icon: const Icon(Icons.collections_bookmark_rounded),
            onPressed: () => NovelSavedWordsScreen.open(context),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _loadPoems,
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
                      _buildFilterBar(),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else if (_errorMessage != null && _poems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.wifi_off_rounded,
                          size: 48.sp,
                          color: AppColors.error,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          _errorMessage!,
                          style: TextStyle(
                            fontFamily: 'IBM',
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton(
                          onPressed: _loadPoems,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_poems.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history_edu_rounded,
                          size: 48.sp,
                          color: AppColors.textMuted,
                        ),
                        SizedBox(height: 12.h),
                        Text(
                          'لا توجد قصائد متاحة لهذا المستوى حالياً',
                          style: TextStyle(
                            fontFamily: 'IBM',
                            fontSize: 14.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        SizedBox(height: 12.h),
                        TextButton(
                          onPressed: () => _changeLevel(null),
                          child: const Text('عرض كل المستويات'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 24.h),
                  sliver: SliverList.separated(
                    itemCount: _poems.length,
                    separatorBuilder: (_, _) => SizedBox(height: 14.h),
                    itemBuilder: (context, index) {
                      final poem = _poems[index];
                      final isLocked = !poem.isFree && !_hasSubscription;
                      return _buildPoemCard(poem, isLocked);
                    },
                  ),
                ),
            ],
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
          colors: [Color(0xFF5B21B6), Color(0xFF7C3AED)],
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C3AED).withAlpha(50),
            blurRadius: 16,
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
                  Icons.history_edu_rounded,
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
                      'استمتع بأعذب القصائد الإنجليزية',
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      'أبيات مختارة حسب المستويات لتعزيز تذوقك اللغوي',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white.withAlpha(220),
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
                label: 'ترجمة سياقية لكل بيت',
              ),
              _buildFeatureBadge(
                icon: Icons.record_voice_over_rounded,
                label: 'نطق صوتي فوري',
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

  Widget _buildFeatureBadge({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(22),
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
                    vertical: 7.h,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF7C3AED) : Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF7C3AED)
                          : AppColors.border,
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFF7C3AED).withAlpha(50),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    item.$2,
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontSize: 12.5.sp,
                      fontWeight:
                          isSelected ? FontWeight.w800 : FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textPrimary,
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

  Widget _buildPoemCard(Novel poem, bool isLocked) {
    Color levelColor;
    String levelLabel;
    switch (poem.level.toLowerCase()) {
      case 'beginner':
        levelColor = const Color(0xFF059669);
        levelLabel = 'مبتدئ A1-A2';
        break;
      case 'intermediate':
        levelColor = const Color(0xFFD97706);
        levelLabel = 'متوسط B1-B2';
        break;
      case 'advanced':
      default:
        levelColor = const Color(0xFF7C3AED);
        levelLabel = 'متقدم C1';
        break;
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      elevation: 0,
      child: InkWell(
        onTap: () => _openPoem(poem),
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: AppColors.border.withAlpha(120)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(6),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cover
              ClipRRect(
                borderRadius: BorderRadius.circular(14.r),
                child: SizedBox(
                  width: 80.w,
                  height: 105.h,
                  child: poem.coverUrl != null && poem.coverUrl!.isNotEmpty
                      ? Image.network(
                          poem.coverUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFFEDE9FE),
                            child: const Center(
                              child: Icon(
                                Icons.history_edu_rounded,
                                color: Color(0xFF7C3AED),
                              ),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFFEDE9FE),
                          child: const Center(
                            child: Icon(
                              Icons.history_edu_rounded,
                              color: Color(0xFF7C3AED),
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 3.h,
                          ),
                          decoration: BoxDecoration(
                            color: levelColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(6.r),
                          ),
                          child: Text(
                            levelLabel,
                            style: TextStyle(
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w700,
                              color: levelColor,
                              fontFamily: 'IBM',
                            ),
                          ),
                        ),
                        const Spacer(),
                        if (isLocked)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withAlpha(25),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lock_rounded,
                                  size: 11.sp,
                                  color: const Color(0xFFD97706),
                                ),
                                SizedBox(width: 3.w),
                                Text(
                                  'مشتركين',
                                  style: TextStyle(
                                    fontSize: 9.5.sp,
                                    color: const Color(0xFFD97706),
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 7.w,
                              vertical: 2.h,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(20),
                              borderRadius: BorderRadius.circular(6.r),
                            ),
                            child: Text(
                              'مجاني',
                              style: TextStyle(
                                fontSize: 9.5.sp,
                                color: const Color(0xFF059669),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      poem.title,
                      style: TextStyle(
                        fontFamily: 'IBM',
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      poem.description,
                      style: TextStyle(
                        fontSize: 11.5.sp,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Icon(
                          Icons.play_circle_fill_rounded,
                          size: 16.sp,
                          color: const Color(0xFF7C3AED),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'قراءة واستماع تفاعلي',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF7C3AED),
                            fontFamily: 'IBM',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
