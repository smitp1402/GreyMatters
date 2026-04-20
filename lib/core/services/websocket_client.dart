// lib/core/services/websocket_client.dart

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/feature_flags.dart';
import '../models/attention_state.dart';
import 'attention_stream.dart';
import 'demo_attention_controller.dart';

/// Connection status for the EEG headset daemon link.
enum HeadsetConnectionStatus {
  /// No connection attempt yet.
  disconnected,

  /// Attempting to connect / reconnecting.
  connecting,

  /// WebSocket open and receiving data.
  connected,
}

/// Singleton WebSocket client that connects to the Python EEG daemon
/// on `ws://localhost:8765` (or a remote IP for iPad).
///
/// Parses incoming JSON into [AttentionState] and pushes it to
/// [AttentionStream]. Auto-reconnects on disconnect with a 3-second delay.
///
/// Exposes [statusStream] so widgets can display headset connection state.
class WebSocketClient {
  WebSocketClient._();
  static final instance = WebSocketClient._();

  WebSocketChannel? _channel;
  bool _disposed = false;

  final _statusController =
      StreamController<HeadsetConnectionStatus>.broadcast();

  HeadsetConnectionStatus _status = HeadsetConnectionStatus.disconnected;

  /// Broadcast stream of connection status changes.
  Stream<HeadsetConnectionStatus> get statusStream => _statusController.stream;

  /// Current connection status (synchronous read).
  HeadsetConnectionStatus get status => _status;

  void _setStatus(HeadsetConnectionStatus s) {
    if (_status == s) return;
    _status = s;
    _statusController.add(s);
  }

  /// Default daemon address — desktop connects to localhost,
  /// iPad connects to the desktop's local IP.
  static const defaultUrl = 'ws://localhost:8765';

  /// Connect to the daemon WebSocket server.
  ///
  /// When [FeatureFlags.useEegTrigger] is off, this short-circuits: no
  /// WebSocket is opened, the status is set to "connected", and the
  /// [DemoAttentionController] emits an initial frame so listeners that
  /// gate on "first message received" (like the crown-connection screen)
  /// still advance. Spacebar presses then drive state via the app-root
  /// keyboard shortcut wired up in [main.dart].
  Future<void> connect([String url = defaultUrl]) async {
    _disposed = false;

    if (!FeatureFlags.useEegTrigger) {
      // Demo mode — bypass the Crown + daemon entirely. The connection
      // "succeeds" instantly so the UI can progress to the lesson.
      _setStatus(HeadsetConnectionStatus.connected);
      // Defer the emit to the next microtask so subscribers that are
      // attaching right now (e.g., in initState of the calling screen)
      // don't miss it.
      scheduleMicrotask(DemoAttentionController.instance.emitInitial);
      return;
    }

    _setStatus(HeadsetConnectionStatus.connecting);
    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      // Wait for the connection to actually open (catches web errors)
      await channel.ready;
      _channel = channel;
      _channel!.stream.listen(
        _onMessage,
        onError: (Object e) => _reconnect(url),
        onDone: () => _reconnect(url),
      );
    } catch (e) {
      // Connection failed — don't crash, just schedule retry
      _setStatus(HeadsetConnectionStatus.disconnected);
      await _reconnect(url);
    }
  }

  void _onMessage(dynamic raw) {
    // First successful message means connection is live.
    if (_status != HeadsetConnectionStatus.connected) {
      _setStatus(HeadsetConnectionStatus.connected);
    }
    try {
      final json = jsonDecode(raw as String) as Map<String, dynamic>;
      final state = AttentionState.fromJson(json);
      AttentionStream.instance.emit(state);
    } catch (e) {
      // Malformed message — skip silently, don't crash the stream.
      // In debug builds this could be logged.
    }
  }

  Future<void> _reconnect(String url) async {
    if (_disposed) return;
    _setStatus(HeadsetConnectionStatus.connecting);
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!_disposed) await connect(url);
  }

  /// Send a message to the daemon (e.g. calibrate command).
  void send(String message) {
    _channel?.sink.add(message);
  }

  /// Gracefully close the connection.
  void dispose() {
    _disposed = true;
    _setStatus(HeadsetConnectionStatus.disconnected);
    _channel?.sink.close();
  }
}
