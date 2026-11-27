import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:osc_magician/app_state.dart';
import 'package:osc_magician/main.dart';
import 'package:osc_magician/models.dart';
import 'package:osc_magician/osc.dart';
import 'package:osc_magician/osc_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

Uint8List bundle(List<Uint8List> elements) {
  final bytes = BytesBuilder()
    ..add(ascii.encode('#bundle\u0000'))
    ..add([0, 0, 0, 0, 0, 0, 0, 1]);
  for (final element in elements) {
    final size = ByteData(4)..setInt32(0, element.length, Endian.big);
    bytes
      ..add(size.buffer.asUint8List())
      ..add(element);
  }
  return bytes.toBytes();
}

void main() {
  test('decodes single messages and ordered nested bundles', () {
    final meter = OscMessage('/GlobalRackspace/outvol1/SetValue', [0.75]);
    final key = OscMessage('/GlobalRackspace/THIS_SONGKEYName', ['C']);
    final other = OscMessage('/other', [1]);

    expect(OscMessage.decodePacket(meter.encode()).single.firstNumeric, 0.75);
    final decoded = OscMessage.decodePacket(
      bundle([
        meter.encode(),
        bundle([key.encode(), other.encode()]),
      ]),
    );
    expect(decoded.map((m) => m.address), [
      meter.address,
      key.address,
      other.address,
    ]);
    expect(decoded[1].arguments, ['C']);
  });

  test('rejects malformed or truncated bundles without partial updates', () {
    final valid = OscMessage('/valid', [0.5]).encode();
    final packet = bundle([valid, valid]);
    expect(
      OscMessage.decodePacket(
        Uint8List.sublistView(packet, 0, packet.length - 1),
      ),
      isEmpty,
    );
    final invalidSize = bundle([valid]);
    ByteData.sublistView(invalidSize).setInt32(16, 0, Endian.big);
    expect(OscMessage.decodePacket(invalidSize), isEmpty);
    expect(
      OscMessage.decodePacket(
        Uint8List.fromList(ascii.encode('#bundle\u0000')),
      ),
      isEmpty,
    );
  });

  testWidgets('a UDP bundle updates a meter and a text label', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final reservation = await tester.runAsync(
      () => RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0),
    );
    final port = reservation!.port;
    reservation.close();
    final state = AppState(OscService());
    state.settings.listenPort = port;
    final label = OscControl(
      id: 'label',
      type: ControlType.text,
      name: 'Initial',
      address: '/GlobalRackspace/THIS_SONGKEYName',
      receiveOscText: true,
    );
    final meter = OscControl(
      id: 'meter',
      type: ControlType.hMeter,
      address: '/GlobalRackspace/outvol1/SetValue',
      gridY: 2,
    );
    state.pages.first.controls.addAll([label, meter]);
    addTearDown(state.dispose);
    await tester.runAsync(() => state.init());
    expect(state.oscError, isNull);
    await tester.pumpWidget(OscMagicianApp(state: state));
    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      final changed = Completer<void>();
      void listener() {
        if (label.name == 'C' && meter.value == 0.75 && !changed.isCompleted) {
          changed.complete();
        }
      }

      state.addListener(listener);
      final sender = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      try {
        sender.send(
          bundle([
            OscMessage('/GlobalRackspace/THIS_SONGKEY/SetValue', [
              0.0,
            ]).encode(),
            OscMessage(label.address, ['C']).encode(),
            OscMessage(meter.address, [0.75]).encode(),
          ]),
          InternetAddress.loopbackIPv4,
          port,
        );
        await changed.future.timeout(const Duration(seconds: 3));
      } finally {
        state.removeListener(listener);
        sender.close();
      }
    });
    await tester.pump();
    expect(find.text('C'), findsOneWidget);
    expect(meter.value, 0.75);
  });
}
