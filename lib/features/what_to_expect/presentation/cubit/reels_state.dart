import 'package:equatable/equatable.dart';

import '../../domain/entities/reel_entity.dart';

enum ReelsStatus { loading, ready, empty, failure }

class ReelsState extends Equatable {
  final ReelsStatus status;
  final List<ReelEntity> reels;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isOffline;
  final String? message;

  const ReelsState({
    this.status = ReelsStatus.loading,
    this.reels = const [],
    this.hasMore = true,
    this.isLoadingMore = false,
    this.isOffline = false,
    this.message,
  });

  ReelsState copyWith({
    ReelsStatus? status,
    List<ReelEntity>? reels,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isOffline,
    String? message,
    bool clearMessage = false,
  }) => ReelsState(
    status: status ?? this.status,
    reels: reels ?? this.reels,
    hasMore: hasMore ?? this.hasMore,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    isOffline: isOffline ?? this.isOffline,
    message: clearMessage ? null : message ?? this.message,
  );

  @override
  List<Object?> get props => [
    status,
    reels,
    hasMore,
    isLoadingMore,
    isOffline,
    message,
  ];
}
