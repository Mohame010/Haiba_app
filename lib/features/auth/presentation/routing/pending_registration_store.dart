import '../../domain/entities/register_params.dart';

/// Keeps sensitive registration data out of GoRouter's serialized state.
final class PendingRegistrationStore {
  PendingRegistrationStore._();

  static final Map<String, RegisterParams> _pending = {};
  static int _nextId = 0;

  static String save(RegisterParams params) {
    // Only one registration flow can be active in the app at a time.
    _pending.clear();
    final key = 'pending-registration-${_nextId++}';
    _pending[key] = params;
    return key;
  }

  static RegisterParams? take(String key) => _pending.remove(key);

  static void clear() => _pending.clear();
}
