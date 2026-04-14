// lib/core/services/eeg_service.dart

import 'dart:io';

/// Manages the Python EEG daemon subprocess on desktop platforms.
///
/// On desktop (Windows/macOS), the Flutter app spawns the Python daemon
/// which connects to the Neurosity Crown and broadcasts AttentionState
/// over WebSocket on port 8765.
///
/// On mobile (iPad/Android), the daemon runs on a separate desktop machine
/// and the app connects to it over WiFi. This service is a no-op on mobile.
class EEGService {
  EEGService._();
  static final instance = EEGService._();

  Process? _daemonProcess;

  /// True if running on a desktop platform that can spawn the daemon.
  bool get isDesktop =>
      Platform.isWindows || Platform.isMacOS || Platform.isLinux;

  /// Start the Python daemon subprocess.
  /// No-op on mobile platforms.
  Future<void> startDaemon() async {
    if (!isDesktop) return;

    // Daemon lives at <project_root>/daemon/attention_engine.py
    // In production, this would be a PyInstaller-frozen executable.
    _daemonProcess = await Process.start(
      'python',
      ['daemon/attention_engine.py'],
      mode: ProcessStartMode.detached,
    );
  }

  /// Stop the daemon subprocess.
  void stopDaemon() {
    _daemonProcess?.kill();
    _daemonProcess = null;
  }
}
