import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/services/app_preferences.dart';
import '../../domain/entities/reel_entity.dart';
import '../cubit/reels_cubit.dart';
import '../cubit/reels_state.dart';
import '../widgets/reel_video_surface.dart';

class WhatToExpectScreen extends StatefulWidget {
  final bool firstVisit;

  const WhatToExpectScreen({super.key, required this.firstVisit});

  @override
  State<WhatToExpectScreen> createState() => _WhatToExpectScreenState();
}

class _WhatToExpectScreenState extends State<WhatToExpectScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    AppPreferences.setWhatToExpectSeen();
    context.read<ReelsCubit>().load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index, int count) {
    setState(() => _currentIndex = index);
    if (index >= count - 3) context.read<ReelsCubit>().loadMore();
  }

  void _join() => context.go(AppRoutes.login);

  void _continue() {
    if (Supabase.instance.client.auth.currentUser != null) {
      context.go(AppRoutes.main);
    } else if (AppPreferences.isOnboardingCompleted()) {
      context.go(AppRoutes.login);
    } else {
      context.go(AppRoutes.onboarding);
    }
  }

  Future<void> _like(ReelEntity reel) async {
    final result = await context.read<ReelsCubit>().toggleLike(reel.id);
    if (!mounted) return;
    if (result == ReelLikeResult.authRequired) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('سجّل الدخول أولًا لحفظ إعجابك.'),
          action: SnackBarAction(label: 'تسجيل الدخول', onPressed: _join),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlocConsumer<ReelsCubit, ReelsState>(
          listenWhen: (previous, current) =>
              previous.message != current.message && current.message != null,
          listener: (context, state) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(state.message!)));
          },
          builder: (context, state) {
            return Stack(
              fit: StackFit.expand,
              children: [
                switch (state.status) {
                  ReelsStatus.loading => const _FeedLoading(),
                  ReelsStatus.ready => PageView.builder(
                    controller: _pageController,
                    scrollDirection: Axis.vertical,
                    itemCount: state.reels.length,
                    onPageChanged: (index) =>
                        _onPageChanged(index, state.reels.length),
                    itemBuilder: (context, index) {
                      final reel = state.reels[index];
                      return _ReelPage(
                        key: ValueKey(reel.id),
                        reel: reel,
                        isActive: index == _currentIndex,
                        shouldPrepare: (index - _currentIndex).abs() <= 1,
                        onLike: () => _like(reel),
                      );
                    },
                  ),
                  ReelsStatus.empty => _FeedMessage(
                    icon: Icons.video_library_outlined,
                    message: 'لا توجد فيديوهات منشورة حاليًا.',
                    onRetry: context.read<ReelsCubit>().load,
                  ),
                  ReelsStatus.failure => _FeedMessage(
                    icon: Icons.wifi_off_rounded,
                    message: state.message ?? 'تعذر تحميل الفيديوهات.',
                    onRetry: context.read<ReelsCubit>().load,
                  ),
                },
                SafeArea(
                  minimum: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Row(
                        textDirection: TextDirection.ltr,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _Brand(),
                          const SizedBox(width: 12),
                          if (widget.firstVisit)
                            _TopAction(
                              label: 'انضم إلينا',
                              icon: Icons.person_add_alt_1_rounded,
                              filled: true,
                              onPressed: _join,
                            )
                          else
                            _TopAction(
                              label: 'تخطي',
                              icon: Icons.skip_next_rounded,
                              onPressed: _continue,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state.status == ReelsStatus.ready)
                  const _SwipeUpHighlight(),
                if (state.status == ReelsStatus.failure ||
                    state.status == ReelsStatus.empty)
                  SafeArea(
                    minimum: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FilledButton(
                        onPressed: widget.firstVisit ? _join : _continue,
                        child: Text(
                          widget.firstVisit ? 'انضم إلينا' : 'متابعة',
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SwipeUpHighlight extends StatefulWidget {
  const _SwipeUpHighlight();

  @override
  State<_SwipeUpHighlight> createState() => _SwipeUpHighlightState();
}

class _SwipeUpHighlightState extends State<_SwipeUpHighlight>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _hideTimer;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, .45),
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 450),
          child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: .72 + (_controller.value * .28),
            child: Transform.translate(
              offset: Offset(0, -10 * _controller.value),
              child: child,
          ),
        ),
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xCC111827),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white38),
              boxShadow: const [
                BoxShadow(color: Color(0x55000000), blurRadius: 14),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_arrow_up_rounded,
                  color: Colors.white,
                  size: 32,
                ),
                Text(
                  'دي فيديوهات ريلز\nاسحب لأعلى لمشاهدة مقاطع أخرى',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'IBM',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
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
}

class _ReelPage extends StatelessWidget {
  final ReelEntity reel;
  final bool isActive;
  final bool shouldPrepare;
  final VoidCallback onLike;

  const _ReelPage({
    super.key,
    required this.reel,
    required this.isActive,
    required this.shouldPrepare,
    required this.onLike,
  });

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ReelVideoSurface(
        reel: reel,
        isActive: isActive,
        shouldPrepare: shouldPrepare,
      ),
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, .25, .58, 1],
              colors: [
                Color(0x77000000),
                Colors.transparent,
                Colors.transparent,
                Color(0xDD000000),
              ],
            ),
          ),
        ),
      ),
      SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 96, 20, 28),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reel.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                      ),
                    ),
                    if (reel.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        reel.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: .88),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _LikeButton(reel: reel, onPressed: onLike),
            ],
          ),
        ),
      ),
    ],
  );
}

class _LikeButton extends StatelessWidget {
  final ReelEntity reel;
  final VoidCallback onPressed;

  const _LikeButton({required this.reel, required this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: reel.isLiked ? 'إلغاء الإعجاب' : 'إعجاب',
    child: InkResponse(
      onTap: onPressed,
      radius: 36,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              reel.isLiked
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: reel.isLiked ? const Color(0xFFFF4D6D) : Colors.white,
              size: 36,
            ),
            const SizedBox(height: 4),
            Text(
              _compactCount(reel.likesCount),
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontFamily: 'IBM',
              ),
            ),
            const Text(
              'إعجاب',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontFamily: 'IBM',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) => Text(
    'What to\nExpect?',
    textDirection: TextDirection.ltr,
    maxLines: 2,
    style: Theme.of(context).textTheme.titleMedium?.copyWith(
      color: Colors.white,
      height: 1.05,
      fontWeight: FontWeight.w700,
      fontSize: 23,
      shadows: const [
        Shadow(color: Color(0xCC000000), blurRadius: 8, offset: Offset(0, 2)),
      ],
    ),
  );
}

class _TopAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool filled;
  final VoidCallback onPressed;

  const _TopAction({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: filled
        ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [Color(0x801E3A8A), Color(0x805B21B6)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                elevation: 0,
                shadowColor: Colors.transparent,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              icon: Icon(icon, size: 20),
              label: Text(label),
            ),
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              backgroundColor: Colors.black26,
              minimumSize: const Size(0, 48),
            ),
            icon: Icon(icon, size: 20),
            label: Text(label),
          ),
  );
}

class _FeedLoading extends StatelessWidget {
  const _FeedLoading();

  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF172554), Color(0xFF111827), Color(0xFF312E81)],
      ),
    ),
    child: Center(
      child: SizedBox(
        width: 160,
        child: LinearProgressIndicator(
          color: Colors.white,
          backgroundColor: Colors.white24,
        ),
      ),
    ),
  );
}

class _FeedMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final VoidCallback onRetry;

  const _FeedMessage({
    required this.icon,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.white70),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                height: 1.5,
                fontFamily: 'IBM',
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ],
        ),
      ),
    ),
  );
}

String _compactCount(int value) {
  if (value >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(value >= 10000000 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(value >= 10000 ? 0 : 1)}K';
  }
  return '$value';
}
