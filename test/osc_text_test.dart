import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:osc_magician/app_state.dart';
import 'package:osc_magician/models.dart';
import 'package:osc_magician/osc.dart';
import 'package:osc_magician/osc_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeOscService extends OscService {
  final messages = StreamController<OscMessage>.broadcast();
  final sent = <OscMessage>[];

  @override
  Stream<OscMessage> get incoming => messages.stream;

  @override
  Future<void> bind(int listenPort) async {}

  @override
  void send(OscMessage message, String targetIp, int targetPort) {
    sent.add(message);
  }

  @override
  void dispose() {
    messages.close();
    super.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'OSC strings update only opted-in labels across pages and persist',
    () async {
      SharedPreferences.setMockInitialValues({});
      final osc = _FakeOscService();
      final state = AppState(osc);
      await state.init();
      addTearDown(state.dispose);

      final dynamicLabel = OscControl(
        id: 'dynamic',
        type: ControlType.text,
        name: 'Original',
        address: '/status',
        receiveOscText: true,
      );
      final staticLabel = OscControl(
        id: 'static',
        type: ControlType.text,
        name: 'Static',
        address: '/status',
      );
      final meter = OscControl(
        id: 'meter',
        type: ControlType.hMeter,
        address: '/status',
      );
      final otherLabel = OscControl(
        id: 'other',
        type: ControlType.text,
        name: 'Other',
        address: '/other',
        receiveOscText: true,
      );
      state.currentPage.controls.addAll([
        dynamicLabel,
        staticLabel,
        meter,
        otherLabel,
      ]);
      final secondLabel = OscControl(
        id: 'second',
        type: ControlType.text,
        address: '/status',
        receiveOscText: true,
      );
      state.pages.add(OscPage(name: 'Second', controls: [secondLabel]));

      final message = OscMessage('/status', [0.75, 'Line 1\nLine 2']);
      osc.messages.add(OscMessage.decode(message.encode())!);
      await Future<void>.delayed(Duration.zero);
      expect(dynamicLabel.name, 'Line 1\nLine 2');
      expect(secondLabel.name, dynamicLabel.name);
      expect(staticLabel.name, 'Static');
      expect(otherLabel.name, 'Other');
      expect(meter.value, 0.75);
      expect(osc.sent, isEmpty);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('project'), contains(r'Line 1\nLine 2'));

      osc.messages.add(OscMessage('/status', [0.5]));
      await Future<void>.delayed(Duration.zero);
      expect(dynamicLabel.name, 'Line 1\nLine 2');
      expect(meter.value, 0.5);

      osc.messages.add(OscMessage('/status', ['']));
      await Future<void>.delayed(Duration.zero);
      expect(dynamicLabel.name, '');
      final restored = AppState(_FakeOscService());
      addTearDown(restored.dispose);
      expect(restored.importJson(prefs.getString('project')!), isNull);
      expect(restored.pages.first.controls.first.name, '');
      expect(restored.pages.first.controls.first.receiveOscText, isTrue);
    },
  );
}
