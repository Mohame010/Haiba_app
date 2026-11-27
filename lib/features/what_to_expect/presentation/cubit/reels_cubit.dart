import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/repositories/reels_repository.dart';
import '../../domain/entities/reel_entity.dart';
import 'reels_state.dart';

enum ReelLikeResult { updated, authRequired, failed }

class ReelsCubit extends Cubit<ReelsState> {
  static const _likeDebounce = Duration(milliseconds: 800);

  final ReelsRepositoryContract _repository;
  final bool firstVisit;
  final Map<String, Timer> _likeTimers = {};
  final Set<String> _syncingLikes = {};
  final Map<String, bool> _serverLiked = {};
  final Map<String, int> _serverLikeCounts = {};

  ReelsCubit(this._repository, {required this.firstVisit})
    : super(const ReelsState());

  Future<void> load() async {
    if (isClosed) return;
    emit(const ReelsState());
    try {
      // The screen is a vertical feed on every visit. Loading a single random
      // reel for returning users left the PageView with no second page, which
      // made a valid vertical drag look as if scrolling was broken.
      final page = await _repository.getPage();
      if (isClosed) return;
      _emitPage(page);
    } catch (_) {
      if (isClosed) return;
      final cached = await _repository.getCached();
      if (isClosed) return;
      final visible = cached;
      if (visible.isNotEmpty) {
        _rememberServerState(visible);
        emit(
          ReelsState(
            status: ReelsStatus.ready,
            reels: visible,
            hasMore: false,
            isOffline: true,
            message: 'أنت غير متصل. نعرض آخر فيديوهات محفوظة.',
          ),
        );
      } else {
        emit(
          const ReelsState(
            status: ReelsStatus.failure,
            hasMore: false,
            isOffline: true,
            message: 'تعذر تحميل الفيديوهات. تحقق من الإنترنت وحاول مجددًا.',
          ),
        );
      }
    }
  }

  Future<void> loadMore() async {
    if (isClosed) return;
    if (state.isLoadingMore || !state.hasMore || state.reels.isEmpty) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true, clearMessage: true));
    try {
      final page = await _repository.getPage(
        beforeSequence: state.reels.last.sequenceId,
      );
      if (isClosed) return;
      final known = state.reels.map((item) => item.id).toSet();
      final newItems = page.reels.where((item) => known.add(item.id));
      _rememberServerState(page.reels);
      emit(
        state.copyWith(
          reels: [...state.reels, ...newItems],
          hasMore: page.hasMore,
          isLoadingMore: false,
        ),
      );
    } catch (_) {
      if (isClosed) return;
      emit(
        state.copyWith(
          hasMore: false,
          isLoadingMore: false,
          message: 'تعذر تحميل فيديوهات إضافية الآن.',
        ),
      );
    }
  }

  Future<ReelLikeResult> toggleLike(String reelId) async {
    final index = state.reels.indexWhere((item) => item.id == reelId);
    if (index < 0) return ReelLikeResult.failed;
    if (!_repository.isAuthenticated) return ReelLikeResult.authRequired;

    final previous = state.reels[index];
    _serverLiked.putIfAbsent(reelId, () => previous.isLiked);
    _serverLikeCounts.putIfAbsent(reelId, () => previous.likesCount);
    final liked = !previous.isLiked;
    final updated = previous.copyWith(
      isLiked: liked,
      likesCount: (previous.likesCount + (liked ? 1 : -1)).clamp(0, 1 << 31),
    );
    final optimistic = [...state.reels]..[index] = updated;
    emit(state.copyWith(reels: optimistic, clearMessage: true));

    _likeTimers.remove(reelId)?.cancel();
    if (liked != _serverLiked[reelId] || _syncingLikes.contains(reelId)) {
      _scheduleLikeSync(reelId);
    }
    return ReelLikeResult.updated;
  }

  void _scheduleLikeSync(String reelId) {
    _likeTimers.remove(reelId)?.cancel();
    _likeTimers[reelId] = Timer(
      _likeDebounce,
      () => unawaited(_commitLike(reelId)),
    );
  }

  Future<void> _commitLike(String reelId) async {
    _likeTimers.remove(reelId)?.cancel();
    if (_syncingLikes.contains(reelId) || isClosed) return;
    final index = state.reels.indexWhere((item) => item.id == reelId);
    if (index < 0) return;
    final desired = state.reels[index].isLiked;
    if (desired == _serverLiked[reelId]) return;

    _syncingLikes.add(reelId);
    try {
      final snapshot = await _repository.setLiked(reelId, liked: desired);
      _serverLiked[reelId] = snapshot.isLiked;
      _serverLikeCounts[reelId] = snapshot.likesCount;
      if (isClosed) return;

      final currentIndex = state.reels.indexWhere((item) => item.id == reelId);
      if (currentIndex < 0) return;
      final current = state.reels[currentIndex];
      final displayCount = current.isLiked == snapshot.isLiked
          ? snapshot.likesCount
          : (snapshot.likesCount + (current.isLiked ? 1 : -1)).clamp(
              0,
              1 << 31,
            );
      final reconciled = [...state.reels]
        ..[currentIndex] = current.copyWith(likesCount: displayCount);
      emit(state.copyWith(reels: reconciled));
    } on ReelsAuthRequired {
      _revertLike(reelId, 'انتهت جلسة تسجيل الدخول. سجّل الدخول لحفظ الإعجاب.');
    } catch (_) {
      _revertLike(reelId, 'لم نتمكن من حفظ الإعجاب. حاول مرة أخرى.');
    } finally {
      _syncingLikes.remove(reelId);
      if (!isClosed) {
        final current = state.reels
            .where((item) => item.id == reelId)
            .firstOrNull;
        if (current != null && current.isLiked != _serverLiked[reelId]) {
          _scheduleLikeSync(reelId);
        }
      }
    }
  }

  void _revertLike(String reelId, String message) {
    if (isClosed) return;
    final index = state.reels.indexWhere((item) => item.id == reelId);
    if (index < 0) return;
    final reverted = [...state.reels]
      ..[index] = state.reels[index].copyWith(
        isLiked: _serverLiked[reelId] ?? false,
        likesCount: _serverLikeCounts[reelId] ?? state.reels[index].likesCount,
      );
    emit(state.copyWith(reels: reverted, message: message));
  }

  void _rememberServerState(Iterable<ReelEntity> reels) {
    for (final reel in reels) {
      _serverLiked[reel.id] = reel.isLiked;
      _serverLikeCounts[reel.id] = reel.likesCount;
    }
  }

  void _emitPage(ReelsPage page) {
    _rememberServerState(page.reels);
    emit(
      ReelsState(
        status: page.reels.isEmpty ? ReelsStatus.empty : ReelsStatus.ready,
        reels: page.reels,
        hasMore: page.hasMore,
      ),
    );
  }

  @override
  Future<void> close() async {
    for (final timer in _likeTimers.values) {
      timer.cancel();
    }
    _likeTimers.clear();
    await super.close();
  }
}
