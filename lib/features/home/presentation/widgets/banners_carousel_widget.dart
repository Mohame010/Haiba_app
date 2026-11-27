import 'dart:async';
import 'dart:math' as math;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../../core/theme/app_colors.dart';
import '../../domain/entities/banner_entity.dart';

class BannersCarouselWidget extends StatefulWidget {
  final List<BannerEntity> banners;
  final Function(BannerEntity)? onBannerTap;

  const BannersCarouselWidget({
    super.key,
    required this.banners,
    this.onBannerTap,
  });

  @override
  State<BannersCarouselWidget> createState() => _BannersCarouselWidgetState();
}

class _BannersCarouselWidgetState extends State<BannersCarouselWidget> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentPage = 1000;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: _currentPage,
      viewportFraction: 0.94,
    );
    _startAutoPlay();
  }

  @override
  void didUpdateWidget(covariant BannersCarouselWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    if (widget.banners.length <= 1) return;

    _autoPlayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_pageController.hasClients) return;
      _currentPage++;
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 850),
        curve: Curves.easeInOutQuart,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    final actualCount = widget.banners.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 195.h,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            allowImplicitScrolling: true,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final banner = widget.banners[index % actualCount];
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  final page =
                      _pageController.hasClients &&
                              _pageController.position.hasContentDimensions
                          ? (_pageController.page ?? _currentPage.toDouble())
                          : _currentPage.toDouble();
                  final distance = (page - index).abs().clamp(0.0, 1.0).toDouble();
                  final scale = 1.0 - math.min<double>(distance * 0.045, 0.045);
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: 1 - (distance * 0.12),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6.w),
                  child: _buildBannerItem(banner),
                ),
              );
            },
          ),
        ),
        SizedBox(height: 12.h),

        // Indicator using custom AppColors
        AnimatedSmoothIndicator(
          activeIndex: _currentPage % actualCount,
          count: actualCount,
          effect: WormEffect(
            dotHeight: 7.w,
            dotWidth: 7.w,
            spacing: 6.w,
            dotColor: AppColors.indicatorInactive,
            activeDotColor: AppColors.indicatorActive,
          ),
        ),
      ],
    );
  }

  Widget _buildBannerItem(BannerEntity banner) {
    final imageUrl = banner.imageUrl?.trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF111827).withAlpha(35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onBannerTap == null
                ? null
                : () => widget.onBannerTap!(banner),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppColors.bannerBlueGradient,
                  ),
                ),
                if (imageUrl != null && imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    cacheWidth: 800,
                    filterQuality: FilterQuality.medium,
                    frameBuilder: (context, child, frame, _) => AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 450),
                      curve: Curves.easeOut,
                      child: child,
                    ),
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: AlignmentDirectional.centerStart,
                      end: AlignmentDirectional.centerEnd,
                      colors: [
                        Colors.black.withAlpha(200),
                        Colors.black.withAlpha(110),
                        Colors.transparent,
                      ],
                      stops: const [0, 0.65, 1],
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 18.h,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: 0.72,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            banner.title,
                            style: TextStyle(
                              fontSize: 17.5.sp,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.35,
                              fontFamily: 'IBM',
                              shadows: const [
                                Shadow(color: Colors.black45, blurRadius: 6),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            banner.subtitle,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withAlpha(235),
                              height: 1.45,
                              fontFamily: 'IBM',
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 14.h),
                          Container(
                            constraints: BoxConstraints(minHeight: 34.h),
                            padding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 7.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(25),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  banner.buttonText,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF172554),
                                    fontFamily: 'IBM',
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Icon(
                                  Icons.arrow_back_rounded,
                                  size: 14.sp,
                                  color: const Color(0xFF172554),
                                ),
                              ],
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
  }
}
