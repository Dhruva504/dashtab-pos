import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/demo_data.dart';

/// Whether the whole app is locked behind the POS quick-login PIN.
/// Set by [AppLockNotifier.lockIfPinSet] right after the session is
/// restored, cleared when the correct PIN is entered.
class AppLockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  /// Locks the workspace when a PIN is configured (called after login /
  /// session restore). No PIN means no lock — nothing to verify against.
  void lockIfPinSet() => state = demo.hasPin;

  void unlock() => state = false;

  /// Manual lock (topbar / sidebar action).
  void lock() => state = demo.hasPin;
}

final appLockProvider =
    NotifierProvider<AppLockNotifier, bool>(AppLockNotifier.new);

/// Whether the POS terminal has been unlocked with the PIN in this session.
/// The gate only appears when a PIN is configured, so workspaces without a
/// PIN keep the old behaviour.
class PosUnlockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void unlock() => state = true;
  void lock() => state = false;
}

final posUnlockedProvider =
    NotifierProvider<PosUnlockNotifier, bool>(PosUnlockNotifier.new);
