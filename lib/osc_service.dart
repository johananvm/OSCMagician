import 'dart:async';
import 'dart:io';

import 'osc.dart';

/// Handles UDP sending and listening for OSC messages.
class OscService {
  RawDatagramSocket? _socket;
  int? _boundPort;

  final _incoming = StreamController<OscMessage>.broadcast();
  Stream<OscMessage> get incoming => _incoming.stream;

  String? _lastError;
  String? get lastError => _lastError;
  int? get boundPort => _boundPort;

  /// (Re)binds the listening socket. The same socket is used for sending.
  Future<void> bind(int listenPort) async {
    if (_boundPort == listenPort && _socket != null) return;
    _socket?.close();
    _socket = null;
    _boundPort = null;
    try {
      final socket =
          await RawDatagramSocket.bind(InternetAddress.anyIPv4, listenPort);
      socket.broadcastEnabled = true;
      socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = socket.receive();
          if (datagram == null) return;
          final msg = OscMessage.decode(datagram.data);
          if (msg != null) _incoming.add(msg);
        }
      });
      _socket = socket;
      _boundPort = listenPort;
      _lastError = null;
    } catch (e) {
      _lastError = 'Could not bind port $listenPort: $e';
    }
  }

  void send(OscMessage message, String targetIp, int targetPort) {
    final socket = _socket;
    if (socket == null) return;
    try {
      socket.send(message.encode(), InternetAddress(targetIp), targetPort);
    } catch (_) {
      // Invalid address or transient network error; ignore.
    }
  }

  /// Returns the device's local IPv4 addresses (e.g. Wi-Fi IP).
  static Future<List<String>> localIpAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
          type: InternetAddressType.IPv4, includeLoopback: false);
      return [
        for (final iface in interfaces)
          for (final addr in iface.addresses) addr.address
      ];
    } catch (_) {
      return [];
    }
  }

  void dispose() {
    _socket?.close();
    _incoming.close();
  }
}
