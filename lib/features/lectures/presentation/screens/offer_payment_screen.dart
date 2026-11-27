import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/helpers/app_logger.dart';
import '../../../core/theme/app_colors.dart';
import '../../data/services/commerce_offer_service.dart';

class OfferPaymentScreen extends StatefulWidget {
  final String paymentUrl;
  final String attemptId;
  final String title;

  const OfferPaymentScreen({
    super.key,
    required this.paymentUrl,
    required this.attemptId,
    required this.title,
  });

  @override
  State<OfferPaymentScreen> createState() => _OfferPaymentScreenState();
}

class _OfferPaymentScreenState extends State<OfferPaymentScreen> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  int _progress = 0;
  bool _checking = false;
  bool _finished = false;
  bool? _paymentSucceeded;
  bool _confirmationDelayed = false;

  @override
  void initState() {
    super.initState();
    AppLogger.authLog(
      '[PAYMENT_SCREEN] Opening checkout',
      data: {'attemptId': widget.attemptId, 'paymentUrl': widget.paymentUrl},
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) {
            if (mounted) setState(() => _progress = value);
          },
          onPageStarted: (url) {
            AppLogger.authLog(
              '[PAYMENT_SCREEN] Page started',
              data: {'url': url},
            );
            _handleRedirect(url);
          },
          onPageFinished: (url) {
            AppLogger.authLog(
              '[PAYMENT_SCREEN] Page finished',
              data: {'url': url},
            );
            _handleRedirect(url);
          },
          onWebResourceError: (error) {
            AppLogger.authLog(
              '[PAYMENT_SCREEN] WebView resource error',
              data: {
                'code': error.errorCode,
                'type': error.errorType?.name,
                'url': error.url,
              },
              error: error.description,
            );
          },
          onNavigationRequest: (request) {
            final handled = _handleRedirect(request.url);
            return handled
                ? NavigationDecision.prevent
                : NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
    _pollTimer = Timer.periodic(
      const Duration(seconds: 4),
      (_) => unawaited(_checkStatus()),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<bool> _checkStatus() async {
    if (_checking || _finished || !mounted) return false;
    _checking = true;
    try {
      final status = await CommerceOfferService.instance.getPaymentStatus(
        widget.attemptId,
      );
      if (!mounted || _finished) return false;
      if (status == 'paid') {
        _finish(true);
        return true;
      }
      if (status == 'failed' || status == 'expired') {
        _finish(false);
      }
      if (status == 'missing') {
        AppLogger.authLog(
          '[PAYMENT_SCREEN] Payment attempt is not visible/found',
          data: {'attemptId': widget.attemptId},
        );
      }
    } catch (error, stackTrace) {
      AppLogger.authLog(
        '[PAYMENT_SCREEN] Status check failed',
        data: {'attemptId': widget.attemptId},
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _checking = false;
    }
    return false;
  }

  bool _handleRedirect(String url) {
    if (_finished) return true;
    final lower = url.toLowerCase();
    if (lower.contains('/payment/success') ||
        lower.contains('/payment/pending') ||
        lower.contains('fawaterk.success') ||
        lower.contains('fawaterk.pending')) {
      _verifyAfterRedirect();
      return true;
    }
    if (lower.contains('/payment/fail') || lower.contains('fawaterk.fail')) {
      _finish(false);
      return true;
    }
    return false;
  }

  Future<void> _verifyAfterRedirect() async {
    if (_checking || _finished) return;
    _pollTimer?.cancel();
    if (mounted) setState(() => _confirmationDelayed = false);
    for (var attempt = 0; attempt < 6; attempt++) {
      if (attempt > 0) await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted || _finished) return;
      if (await _checkStatus()) return;
    }
    if (mounted && !_finished) {
      setState(() => _confirmationDelayed = true);
    }
  }

  void _finish(bool paid) {
    if (_finished || !mounted) return;
    _pollTimer?.cancel();
    AppLogger.authLog(
      '[PAYMENT_SCREEN] Checkout reached a final state',
      data: {'attemptId': widget.attemptId, 'paid': paid},
    );
    setState(() {
      _finished = true;
      _paymentSucceeded = paid;
      _confirmationDelayed = false;
    });
  }

  void _closeWithResult() {
    if (!mounted) return;
    AppLogger.authLog(
      '[PAYMENT_SCREEN] Returning checkout result to app',
      data: {'attemptId': widget.attemptId, 'paid': _paymentSucceeded},
    );
    Navigator.of(context).pop(_paymentSucceeded);
  }

  Future<void> _requestClose() async {
    AppLogger.authLog(
      '[PAYMENT_SCREEN] Close button pressed',
      data: {'attemptId': widget.attemptId},
    );
    if (_finished) {
      _closeWithResult();
      return;
    }
    final close = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إيقاف عملية الدفع؟'),
        content: const Text(
          'يمكنك الاستمرار في الدفع أو الرجوع وسيظل الطلب قيد المراجعة.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('استمرار'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('رجوع'),
          ),
        ],
      ),
    );
    if (close == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _requestClose();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          centerTitle: true,
          leading: IconButton(
            onPressed: _requestClose,
            icon: const Icon(Icons.close_rounded),
          ),
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_finished) _buildFinalResult(),
            if (_confirmationDelayed)
              ColoredBox(
                color: Colors.white,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(28.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 54,
                          color: AppColors.primary,
                        ),
                        SizedBox(height: 14.h),
                        Text(
                          'الدفع قيد التأكيد',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            fontFamily: 'IBM',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        const Text(
                          'لم يصل تأكيد بوابة الدفع بعد. لن يتم فتح المحتوى إلا بعد تأكيد العملية من الخادم.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontFamily: 'IBM'),
                        ),
                        SizedBox(height: 18.h),
                        FilledButton.icon(
                          onPressed: _verifyAfterRedirect,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('تحقق مرة أخرى'),
                        ),
                        TextButton(
                          onPressed: () => _finish(false),
                          child: const Text('العودة للتطبيق'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalResult() {
    final paid = _paymentSucceeded == true;
    final color = paid ? const Color(0xFF16A34A) : AppColors.error;
    return Positioned.fill(
      child: ColoredBox(
        color: Colors.white,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(28.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 92.w,
                    height: 92.w,
                    decoration: BoxDecoration(
                      color: color.withAlpha(24),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      paid ? Icons.check_circle_rounded : Icons.error_rounded,
                      size: 62.w,
                      color: color,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    paid ? 'تم الدفع بنجاح' : 'لم تكتمل عملية الدفع',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'IBM',
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    paid
                        ? 'تم شراء ${widget.title.replaceFirst('الدفع الإلكتروني - ', '')} وفتح المحتوى على حسابك.'
                        : 'لم يتم خصم أو تأكيد المبلغ. يمكنك الرجوع والمحاولة مرة أخرى، وإذا تم الخصم تواصل مع الدعم برقم العملية.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14.sp,
                      height: 1.6,
                      fontFamily: 'IBM',
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 24.h),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _closeWithResult,
                      style: FilledButton.styleFrom(
                        backgroundColor: color,
                        padding: EdgeInsets.symmetric(vertical: 14.h),
                      ),
                      icon: Icon(
                        paid
                            ? Icons.play_arrow_rounded
                            : Icons.arrow_back_rounded,
                      ),
                      label: Text(
                        paid ? 'فتح المحتوى' : 'العودة والمحاولة مرة أخرى',
                        style: const TextStyle(
                          fontFamily: 'IBM',
                          fontWeight: FontWeight.w800,
                        ),
                      ),
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
