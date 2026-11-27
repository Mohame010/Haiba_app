import 'dart:async';
import 'dart:math';

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/theme/app_colors.dart';
import '../../data/abu_al_areef_question_bank.dart';
import '../../domain/abu_al_areef_question.dart';

class AbuAlAreefGameScreen extends StatefulWidget {
  final AbuAlAreefConfig config;

  const AbuAlAreefGameScreen({super.key, required this.config});

  @override
  State<AbuAlAreefGameScreen> createState() => _AbuAlAreefGameScreenState();
}

class _AbuAlAreefGameScreenState extends State<AbuAlAreefGameScreen> {
  late final List<AbuAlAreefQuestion> _questions;
  int _round = 0;
  int _firstScore = 0;
  int _secondScore = 0;
  bool _roundLocked = false;
  final Set<int> _answeredPlayers = {};
  int? _player1SelectedOption;
  int? _player2SelectedOption;
  String? _roundMessage;

  AbuAlAreefQuestion get _question => _questions[_round];

  @override
  void initState() {
    super.initState();
    _initGame();
  }

  void _initGame() {
    final shuffled = [...abuAlAreefQuestions]..shuffle(Random());
    _questions = shuffled.take(widget.config.rounds).toList();
    _round = 0;
    _firstScore = 0;
    _secondScore = 0;
    _roundLocked = false;
    _answeredPlayers.clear();
    _player1SelectedOption = null;
    _player2SelectedOption = null;
    _roundMessage = null;
  }

  void _restartGame() {
    setState(() {
      _initGame();
    });
  }

  Future<void> _answer(int player, int option) async {
    if (_roundLocked || _answeredPlayers.contains(player)) return;

    final correct = option == _question.correctOption;

    setState(() {
      _answeredPlayers.add(player);
      if (player == 1) {
        _player1SelectedOption = option;
      } else {
        _player2SelectedOption = option;
      }

      if (correct) {
        _roundLocked = true;
        if (player == 1) {
          _firstScore++;
        } else {
          _secondScore++;
        }
        _roundMessage = widget.config.multiplayer
            ? '${player == 1 ? widget.config.firstPlayer : widget.config.secondPlayer} كسب الجولة!'
            : 'إجابة صحيحة! أحسنت';
      } else {
        if (!widget.config.multiplayer) {
          _roundLocked = true;
          _roundMessage = 'إجابة غير صحيحة';
        } else {
          if (_answeredPlayers.length == 2) {
            _roundLocked = true;
            _roundMessage = 'كلا المتسابقين أخطأ في الإجابة!';
          } else {
            final otherPlayer = player == 1
                ? widget.config.secondPlayer
                : widget.config.firstPlayer;
            _roundMessage = 'إجابة غير صحيحة، الفرصة الآن لـ $otherPlayer';
          }
        }
      }
    });

    if (_roundLocked) {
      await Future<void>.delayed(const Duration(milliseconds: 1400));
      if (!mounted) return;

      if (_round == _questions.length - 1) {
        _showResult();
      } else {
        setState(() {
          _round++;
          _roundLocked = false;
          _answeredPlayers.clear();
          _player1SelectedOption = null;
          _player2SelectedOption = null;
          _roundMessage = null;
        });
      }
    }
  }

  void _showResult() {
    final multiplayer = widget.config.multiplayer;
    final total = _questions.length;

    String winnerTitle;
    String winnerSubtitle;

    if (multiplayer) {
      if (_firstScore == _secondScore) {
        winnerTitle = 'تعادل بين المتنافسين!';
        winnerSubtitle = 'مستوى متقارب وأداء ممتاز من كلا اللاعبين';
      } else if (_firstScore > _secondScore) {
        winnerTitle = '${widget.config.firstPlayer} هو أبو العريف!';
        winnerSubtitle = 'فاز بالجولة بجدارة واستحقاق';
      } else {
        winnerTitle = '${widget.config.secondPlayer} هو أبو العريف!';
        winnerSubtitle = 'فاز بالجولة بجدارة واستحقاق';
      }
    } else {
      final percentage = ((_firstScore / total) * 100).round();
      if (percentage >= 80) {
        winnerTitle = 'أداء أسطوري! أحسنت';
      } else if (percentage >= 50) {
        winnerTitle = 'مستوى رائع ومتميز!';
      } else {
        winnerTitle = 'محاولة جيدة، تدرب أكثر!';
      }
      winnerSubtitle = 'حققت $_firstScore إجابات صحيحة من إجمالي $total';
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24.r),
            ),
            contentPadding: EdgeInsets.all(24.w),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.emoji_events_rounded,
                    color: Color(0xFFD97706),
                    size: 42,
                  ),
                ),
                SizedBox(height: 16.h),
                Text(
                  winnerTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  winnerSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'IBM',
                    fontSize: 12.5.sp,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: 20.h),
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: multiplayer
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildScoreSummary(
                              name: widget.config.firstPlayer,
                              score: _firstScore,
                              isWinner: _firstScore >= _secondScore,
                            ),
                            Container(
                              width: 1,
                              height: 36.h,
                              color: AppColors.border,
                            ),
                            _buildScoreSummary(
                              name: widget.config.secondPlayer,
                              score: _secondScore,
                              isWinner: _secondScore >= _firstScore,
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatBadge(
                              title: 'الإجابات الصحيحة',
                              value: '$_firstScore',
                              color: AppColors.success,
                            ),
                            Container(
                              width: 1,
                              height: 36.h,
                              color: AppColors.border,
                            ),
                            _buildStatBadge(
                              title: 'النسبة المئوية',
                              value:
                                  '${((_firstScore / total) * 100).round()}%',
                              color: AppColors.primary,
                            ),
                          ],
                        ),
                ),
                SizedBox(height: 22.h),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    _restartGame();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 20),
                  label: const Text(
                    'العب من جديد',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: Size.fromHeight(48.h),
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    minimumSize: Size.fromHeight(44.h),
                  ),
                  child: const Text(
                    'العودة للإعدادات',
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
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

  Widget _buildScoreSummary({
    required String name,
    required int score,
    required bool isWinner,
  }) {
    return Column(
      children: [
        Text(
          name,
          style: TextStyle(
            fontFamily: 'IBM',
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: isWinner ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          '$score نقاط',
          style: TextStyle(
            fontFamily: 'IBM',
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
            color: isWinner ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatBadge({
    required String title,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: TextStyle(
            fontFamily: 'IBM',
            fontSize: 11.5.sp,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontFamily: 'IBM',
            fontSize: 17.sp,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<bool> _onWillPop() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        title: const Text(
          'إنهاء التحدي الحالي؟',
          style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'إذا خرجت الآن ستفقد تقدم الجولة والنتيجة الحالية.',
          style: TextStyle(fontFamily: 'IBM', height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text(
              'متابعة اللعب',
              style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w700),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.r),
              ),
            ),
            child: const Text(
              'إنهاء وخروج',
              style: TextStyle(fontFamily: 'IBM', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.config.multiplayer) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final shouldPop = await _onWillPop();
          if (shouldPop && context.mounted) {
            Navigator.pop(context);
          }
        },
        child: Scaffold(
          backgroundColor: AppColors.background,
          appBar: AppBar(
            title: Text(
              'الجولة ${_round + 1} من ${_questions.length}',
              style: const TextStyle(
                fontFamily: 'IBM',
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.white,
            foregroundColor: AppColors.textPrimary,
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(4.h),
              child: LinearProgressIndicator(
                value: (_round + 1) / _questions.length,
                backgroundColor: AppColors.indicatorInactive,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppColors.primary,
                ),
                minHeight: 4.h,
              ),
            ),
          ),
          body: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: _PlayerPanel(
                  name: widget.config.firstPlayer,
                  score: _firstScore,
                  roundNumber: _round + 1,
                  totalRounds: _questions.length,
                  question: _question,
                  disabled: _roundLocked || _answeredPlayers.contains(1),
                  selectedOption: _player1SelectedOption,
                  revealCorrectAnswer: _roundLocked,
                  message: _roundMessage,
                  onAnswer: (option) => _answer(1, option),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: RotatedBox(
                  quarterTurns: 2,
                  child: _PlayerPanel(
                    name: widget.config.secondPlayer,
                    score: _secondScore,
                    roundNumber: _round + 1,
                    totalRounds: _questions.length,
                    question: _question,
                    disabled: _roundLocked || _answeredPlayers.contains(2),
                    selectedOption: _player2SelectedOption,
                    revealCorrectAnswer: _roundLocked,
                    message: _roundMessage,
                    compact: true,
                    onAnswer: (option) => _answer(2, option),
                  ),
                ),
              ),
              Container(
                height: 42.h,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1E1B4B), Color(0xFF312E81)],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '${widget.config.secondPlayer}: $_secondScore',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'IBM',
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      'الجولة ${_round + 1} / ${_questions.length}',
                      style: TextStyle(
                        color: const Color(0xFFFDE68A),
                        fontFamily: 'IBM',
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '${widget.config.firstPlayer}: $_firstScore',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'IBM',
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _PlayerPanel(
                  name: widget.config.firstPlayer,
                  score: _firstScore,
                  roundNumber: _round + 1,
                  totalRounds: _questions.length,
                  question: _question,
                  disabled: _roundLocked || _answeredPlayers.contains(1),
                  selectedOption: _player1SelectedOption,
                  revealCorrectAnswer: _roundLocked,
                  message: _roundMessage,
                  compact: true,
                  onAnswer: (option) => _answer(1, option),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayerPanel extends StatelessWidget {
  final String name;
  final int score;
  final int roundNumber;
  final int totalRounds;
  final AbuAlAreefQuestion question;
  final bool disabled;
  final int? selectedOption;
  final bool revealCorrectAnswer;
  final String? message;
  final bool compact;
  final ValueChanged<int> onAnswer;

  const _PlayerPanel({
    required this.name,
    required this.score,
    required this.roundNumber,
    required this.totalRounds,
    required this.question,
    required this.disabled,
    required this.selectedOption,
    required this.revealCorrectAnswer,
    required this.message,
    required this.onAnswer,
    this.compact = false,
  });

  static const List<String> _optionLetters = ['A', 'B', 'C', 'D'];

  Color _getLevelColor(AbuAlAreefLevel level) {
    switch (level) {
      case AbuAlAreefLevel.beginner:
        return const Color(0xFF16A34A);
      case AbuAlAreefLevel.intermediate:
        return const Color(0xFF2563EB);
      case AbuAlAreefLevel.distinguished:
        return const Color(0xFFD97706);
      case AbuAlAreefLevel.legendary:
        return const Color(0xFF9333EA);
    }
  }

  @override
  Widget build(BuildContext context) {
    final levelColor = _getLevelColor(question.level);

    return Container(
      color: compact ? const Color(0xFFF8FAFC) : Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12.w : 20.w,
        vertical: compact ? 8.h : 16.h,
      ),
      child: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8.w : 12.w,
                    vertical: compact ? 3.h : 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_rounded,
                        color: const Color(0xFFFDE68A),
                        size: compact ? 13 : 16,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '$score',
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'IBM',
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 11.sp : 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'IBM',
                      fontWeight: FontWeight.w800,
                      fontSize: compact ? 13.sp : 16.sp,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6.w : 8.w,
                    vertical: compact ? 2.h : 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: levelColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    question.level.arabicLabel,
                    style: TextStyle(
                      color: levelColor,
                      fontFamily: 'IBM',
                      fontSize: compact ? 9.5.sp : 11.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                SizedBox(width: 4.w),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 6.w : 8.w,
                    vertical: compact ? 2.h : 3.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    question.category,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: compact ? 9.5.sp : 11.sp,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'IBM',
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: compact ? 6.h : 12.h),

            // Question Card + Options
            if (compact) ...[
              // Compact Split-screen Duel mode (fits inside half-screen)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Text(
                        question.prompt,
                        textDirection: TextDirection.ltr,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5.sp,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1E1B4B),
                          fontFamily: 'IBM',
                        ),
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Expanded(
                      child: Column(
                        children: List.generate(question.options.length, (
                          index,
                        ) {
                          return Expanded(
                            child: Padding(
                              padding: EdgeInsets.only(
                                bottom: index < question.options.length - 1
                                    ? 5.h
                                    : 0,
                              ),
                              child: _buildOptionButton(
                                index: index,
                                isThisSelected: selectedOption == index,
                                isCorrect: index == question.correctOption,
                                revealCorrectAnswer: revealCorrectAnswer,
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Single Player Mode (Balanced, elegant quiz cards with natural height, centered on phones & tablets)
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 580),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Question Card
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 20.w,
                              vertical: 18.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18.r),
                              border: Border.all(color: AppColors.border),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Text(
                              question.prompt,
                              textDirection: TextDirection.ltr,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16.5.sp,
                                height: 1.4,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF1E1B4B),
                                fontFamily: 'IBM',
                              ),
                            ),
                          ),
                          SizedBox(height: 14.h),

                          // Options with natural comfortable height
                          for (int i = 0; i < question.options.length; i++) ...[
                            Padding(
                              padding: EdgeInsets.only(
                                bottom: i < question.options.length - 1
                                    ? 10.h
                                    : 0,
                              ),
                              child: _buildOptionButton(
                                index: i,
                                isThisSelected: selectedOption == i,
                                isCorrect: i == question.correctOption,
                                revealCorrectAnswer: revealCorrectAnswer,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],

            // Message banner at bottom
            if (message != null)
              Container(
                padding: EdgeInsets.symmetric(
                  vertical: compact ? 4.h : 8.h,
                  horizontal: 10.w,
                ),
                margin: EdgeInsets.only(top: compact ? 4.h : 8.h),
                decoration: BoxDecoration(
                  color:
                      message!.contains('غير') ||
                          message!.contains('أخطأ') ||
                          message!.contains('لم ينجح')
                      ? const Color(0xFFFEE2E2)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:
                        message!.contains('غير') ||
                            message!.contains('أخطأ') ||
                            message!.contains('لم ينجح')
                        ? const Color(0xFFB91C1C)
                        : const Color(0xFF15803D),
                    fontFamily: 'IBM',
                    fontWeight: FontWeight.w800,
                    fontSize: compact ? 10.5.sp : 13.sp,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required int index,
    required bool isThisSelected,
    required bool isCorrect,
    required bool revealCorrectAnswer,
  }) {
    Color btnBg = Colors.white;
    Color btnBorder = AppColors.border;
    Color textColor = AppColors.textPrimary;
    Color letterBg = const Color(0xFFF1F5F9);
    Color letterTextColor = AppColors.textSecondary;
    Widget? trailingIcon;

    if (isThisSelected) {
      if (revealCorrectAnswer) {
        if (isCorrect) {
          btnBg = const Color(0xFFDCFCE7);
          btnBorder = const Color(0xFF22C55E);
          textColor = const Color(0xFF15803D);
          letterBg = const Color(0xFF16A34A);
          letterTextColor = Colors.white;
          trailingIcon = Icon(
            Icons.check_circle_rounded,
            color: const Color(0xFF16A34A),
            size: compact ? 16 : 22,
          );
        } else {
          btnBg = const Color(0xFFFEE2E2);
          btnBorder = const Color(0xFFEF4444);
          textColor = const Color(0xFFB91C1C);
          letterBg = const Color(0xFFDC2626);
          letterTextColor = Colors.white;
          trailingIcon = Icon(
            Icons.cancel_rounded,
            color: const Color(0xFFDC2626),
            size: compact ? 16 : 22,
          );
        }
      } else {
        btnBg = AppColors.primary.withValues(alpha: 0.08);
        btnBorder = AppColors.primary;
        textColor = AppColors.primary;
        letterBg = AppColors.primary;
        letterTextColor = Colors.white;
      }
    } else if (revealCorrectAnswer && isCorrect) {
      btnBg = const Color(0xFFDCFCE7);
      btnBorder = const Color(0xFF22C55E);
      textColor = const Color(0xFF15803D);
      letterBg = const Color(0xFF16A34A);
      letterTextColor = Colors.white;
      trailingIcon = Icon(
        Icons.check_circle_rounded,
        color: const Color(0xFF16A34A),
        size: compact ? 16 : 22,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : () => onAnswer(index),
        borderRadius: BorderRadius.circular(compact ? 10.r : 14.r),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          constraints: BoxConstraints(minHeight: compact ? 38.h : 54.h),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10.w : 16.w,
            vertical: compact ? 6.h : 12.h,
          ),
          decoration: BoxDecoration(
            color: btnBg,
            borderRadius: BorderRadius.circular(compact ? 10.r : 14.r),
            border: Border.all(
              color: btnBorder,
              width: isThisSelected || (revealCorrectAnswer && isCorrect)
                  ? 1.8
                  : 1,
            ),
            boxShadow: isThisSelected
                ? [
                    BoxShadow(
                      color: btnBorder.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 26.w : 36.w,
                height: compact ? 26.w : 36.w,
                decoration: BoxDecoration(
                  color: letterBg,
                  borderRadius: BorderRadius.circular(compact ? 6.r : 10.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  _optionLetters[index],
                  style: TextStyle(
                    color: letterTextColor,
                    fontWeight: FontWeight.w900,
                    fontSize: compact ? 10.5.sp : 14.sp,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
              SizedBox(width: compact ? 8.w : 14.w),
              Expanded(
                child: Text(
                  question.options[index],
                  textDirection: TextDirection.ltr,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: compact ? 11.5.sp : 15.sp,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontFamily: 'IBM',
                  ),
                ),
              ),
              ?trailingIcon,
            ],
          ),
        ),
      ),
    );
  }
}
