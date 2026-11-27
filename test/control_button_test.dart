import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osc_magician/models.dart';
import 'package:osc_magician/widgets/control_widget.dart';

void main() {
  for (final type in [ControlType.holdButton, ControlType.pushButton]) {
    testWidgets('${type.label} stays on until release or cancellation', (
      tester,
    ) async {
      final control = OscControl(id: 'button', type: type, min: -1, max: 2);
      final values = <double>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 120,
              height: 100,
              child: StatefulBuilder(
                builder: (context, setState) => ControlWidget(
                  control: control,
                  enabled: true,
                  onChanged: (value) => setState(() {
                    control.value = value;
                    values.add(value);
                  }),
                ),
              ),
            ),
          ),
        ),
      );
      final center = tester.getCenter(find.byType(ControlWidget));
      final pointer = await tester.startGesture(center);
      await tester.pump(const Duration(seconds: 2));
      expect(values, [2]);
      expect(control.value, 2);

      await pointer.moveBy(const Offset(200, 200));
      await tester.pump(const Duration(seconds: 1));
      expect(values, [2]);
      await pointer.up();
      await tester.pump();
      expect(values, [2, -1]);

      final cancelled = await tester.startGesture(center);
      await tester.pump();
      await cancelled.cancel();
      await tester.pump();
      expect(values, [2, -1, 2, -1]);
    });
  }

  testWidgets('a second pointer cannot release a held button', (tester) async {
    final control = OscControl(id: 'button', type: ControlType.holdButton);
    final values = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 100,
            child: ControlWidget(
              control: control,
              enabled: true,
              onChanged: values.add,
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(ControlWidget));
    final first = await tester.startGesture(center, pointer: 1);
    final second = await tester.startGesture(center, pointer: 2);
    await second.up();
    expect(values, [1]);
    await first.up();
    expect(values, [1, 0]);
  });

  testWidgets('toggle button still switches on each tap', (tester) async {
    final control = OscControl(id: 'toggle', type: ControlType.toggleButton);
    final values = <double>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 120,
            height: 100,
            child: StatefulBuilder(
              builder: (context, setState) => ControlWidget(
                control: control,
                enabled: true,
                onChanged: (value) => setState(() {
                  control.value = value;
                  values.add(value);
                }),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(ControlWidget));
    await tester.pump();
    await tester.tap(find.byType(ControlWidget));
    await tester.pump();
    expect(values, [1, 0]);
  });
}
