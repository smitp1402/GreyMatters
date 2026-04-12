// lib/core/services/websocket_client.dart

import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/attention_state.dart';
import 'attention_stream.dart';

/// Singleton WebSocket client that connects to the Python EEG daemon
/// on `ws://localhost:8765` (or a remote IP for iPad).
///
/// Parses incoming JSON into [AttentionState] and pushes it to
/// [AttentionStream]. Auto-reconnects on disconnect with a 3-second delay.
class WebSocketClient {
  WebSocketClient._();
  static final instance = WebSocketClient._();

  WebSocketChannel? _channel;
  bool _disposed = false;

  /// Default daemon address — desktop connects to localhost,
  /// iPad connects to the desktop's local IP.
  static const defaultUrl = 'ws://localhost:8765';

  /// Connect to the daemon WebSocket server.
  Future<void> connect([String url = defaultUrl]) async {
    _disposed = false;
    try {
      _channel = WebSocketChannel.connect(Uri.parse(url));
      _channel!.stream.listen(
        _onMessage,
        onError: (Object e) => _reconnect(url),
        onDone: () => _reconnect(url),
      );
    } catch (e) {
      await _reconnect(url);
    }
  }

  void _onMessage(dynamic raw) {
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
    await Future<void>.delayed(const Duration(seconds: 3));
    if (!_disposed) await connect(url);
  }

  /// Gracefully close the connection.
  void dispose() {
    _disposed = true;
    _channel?.sink.close();
  }
}
