import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../data/models/app_gate_config.dart';
import '../../data/services/app_gate_service.dart';
import '../screens/force_update_gate_screen.dart';
import '../screens/maintenance_gate_screen.dart';

class AppGate extends StatefulWidget {
  const AppGate({super.key, required this.child});

  final Widget child;

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> with WidgetsBindingObserver {
  final AppGateService _service = AppGateService();
  AppGateDecision _decision = const AppGateDecision.open();
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initialize());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refresh());
  }

  Future<void> _initialize() async {
    await _apply(_service.readCached());
    await _refresh();
  }

  Future<void> _refresh() async {
    if (_isRetrying) return;
    if (mounted) setState(() => _isRetrying = true);
    try {
      final config = await _service.refresh();
      await _apply(config);
    } catch (_) {
      // A network/Supabase failure never clears a previously cached gate.
      await _apply(_service.readCached());
    } finally {
      if (mounted) setState(() => _isRetrying = false);
    }
  }

  Future<void> _apply(AppGateConfig? config) async {
    final decision = await _service.decide(config);
    if (mounted) setState(() => _decision = decision);
  }

  @override
  Widget build(BuildContext context) {
    final config = _decision.config;
    return switch (_decision.mode) {
      AppGateMode.maintenance when config != null => MaintenanceGateScreen(
        config: config,
        onRetry: _refresh,
        isRetrying: _isRetrying,
      ),
      AppGateMode.forceUpdate when config != null => ForceUpdateGateScreen(
        config: config,
      ),
      _ => widget.child,
    };
  }
}
