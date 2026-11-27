import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:osc_magician/app_state.dart';
import 'package:osc_magician/main.dart';
import 'package:osc_magician/models.dart';
import 'package:osc_magician/osc_service.dart';
import 'package:osc_magician/widgets/control_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  for (final keyboardHeight in [190.0, 300.0]) {
    testWidgets(
      'edits a control with a $keyboardHeight px landscape keyboard',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        tester.view.physicalSize = const Size(800, 400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);

        final control = OscControl(
          id: 'test',
          type: ControlType.hSlider,
          name: 'Fader',
        );
        final state = AppState(OscService())..editMode = true;
        state.currentPage.orientation = PageOrientation.landscape;
        state.currentPage.controls.add(control);
        addTearDown(state.dispose);

        await tester.pumpWidget(OscMagicianApp(state: state));
        await tester.pumpAndSettle();
        await tester.tapAt(tester.getCenter(find.byType(ControlWidget)));
        await tester.pumpAndSettle();

        final name = find.widgetWithText(TextField, 'Name (shown on screen)');
        await tester.tap(name);
        tester.view.viewInsets = FakeViewPadding(bottom: keyboardHeight);
        await tester.pumpAndSettle();
        expect(
          tester.getRect(name).bottom,
          lessThanOrEqualTo(400 - keyboardHeight),
        );
        await tester.enterText(name, 'Updated fader');
        await tester.pumpAndSettle();

        final address = find.widgetWithText(TextField, 'OSC address');
        await tester.ensureVisible(address);
        await tester.pumpAndSettle();
        await tester.tap(address);
        await tester.enterText(address, '/updated');
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Save'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(control.name, 'Updated fader');
        expect(control.address, '/updated');
      },
    );
  }

  testWidgets('add control sheet scrolls in landscape', (tester) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(800, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState(OscService())..editMode = true;
    state.currentPage.orientation = PageOrientation.landscape;
    addTearDown(state.dispose);

    await tester.pumpWidget(OscMagicianApp(state: state));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Add control'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final last = find.text(ControlType.values.last.label);
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(state.currentPage.controls.single.type, ControlType.values.last);
  });

  testWidgets('toggle switches landscape editing orientation', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final requested = <List<dynamic>>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          requested.add(call.arguments as List<dynamic>);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    final state = AppState(OscService());
    state.currentPage.orientation = PageOrientation.landscape;
    addTearDown(state.dispose);
    await tester.pumpWidget(OscMagicianApp(state: state));
    state.toggleEditMode();
    await tester.pumpAndSettle();
    expect(requested.last.first, 'DeviceOrientation.portraitUp');

    await tester.tap(find.byTooltip('Edit in landscape'));
    await tester.pumpAndSettle();
    expect(requested.last.first, 'DeviceOrientation.landscapeLeft');
    expect(state.settings.editInPortrait, isFalse);
    expect(find.byTooltip('Edit in portrait'), findsOneWidget);
  });

  testWidgets('settings open from the overflow menu', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(OscService());
    addTearDown(state.dispose);
    await tester.pumpWidget(OscMagicianApp(state: state));
    expect(find.byType(NavigationBar), findsNothing);

    await tester.tap(find.byIcon(Icons.more_vert).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Settings'), findsOneWidget);
  });

  testWidgets('portrait edit preview matches landscape play with bars', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final state = AppState(OscService());
    state.currentPage.orientation = PageOrientation.landscape;
    state.currentPage.controls.add(
      OscControl(
        id: 'full',
        type: ControlType.shape,
        gridW: state.currentPage.gridCols,
        gridH: state.currentPage.gridRows,
      ),
    );
    addTearDown(state.dispose);

    tester.view.physicalSize = const Size(800, 400);
    await tester.pumpWidget(OscMagicianApp(state: state));
    await tester.pumpAndSettle();
    final play = tester.getSize(find.byType(ControlWidget));

    state.toggleEditMode();
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();
    final edit = tester.getSize(find.byType(ControlWidget));

    expect(edit.width, 400);
    expect(edit.width / edit.height, closeTo(play.width / play.height, 0.01));
  });

  testWidgets('a shape stays behind the controls it groups', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(OscService())..editMode = true;
    addTearDown(state.dispose);
    state.addControl(ControlType.hSlider);
    state.addControl(ControlType.shape);
    final shape = state.currentPage.controls.last;
    // Shapes may overlap other controls instead of being pushed aside.
    expect((shape.gridX, shape.gridY), (0, 0));

    await tester.pumpWidget(OscMagicianApp(state: state));
    await tester.pumpAndSettle();
    await tester.tapAt(
      tester.getCenter(find.byType(ControlWidget).last) + const Offset(0, 8),
    );
    await tester.pumpAndSettle();
    expect(find.text(ControlType.hSlider.label), findsWidgets);
    expect(find.text('OSC address'), findsOneWidget);
  });

  testWidgets('long press selects a fully covered shape for editing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(OscService())..editMode = true;
    addTearDown(state.dispose);
    final shape = OscControl(
      id: 'shape',
      type: ControlType.shape,
      name: 'Group',
      gridW: 4,
      gridH: 2,
    );
    state.currentPage.controls.addAll([
      shape,
      OscControl(
        id: 'shape2',
        type: ControlType.shape,
        name: 'Other group',
        gridW: 4,
        gridH: 2,
      ),
      OscControl(
        id: 'slider',
        type: ControlType.hSlider,
        name: 'Fader',
        gridW: 4,
        gridH: 2,
      ),
    ]);

    await tester.pumpWidget(OscMagicianApp(state: state));
    await tester.pumpAndSettle();
    final slider = find.byWidgetPredicate(
      (widget) => widget is ControlWidget && widget.control.id == 'slider',
    );
    await tester.longPressAt(tester.getCenter(slider));
    await tester.pumpAndSettle();
    expect(find.text('Select control to edit'), findsOneWidget);
    expect(find.text('Other group'), findsWidgets);
    await tester.tap(find.widgetWithText(ListTile, 'Group'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name (shown on screen)'),
      'Updated group',
    );
    final col = find.ancestor(of: find.text('Col'), matching: find.byType(Row));
    final add = find.descendant(
      of: col.first,
      matching: find.byIcon(Icons.add_circle_outline),
    );
    await tester.ensureVisible(add);
    await tester.tap(add);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(shape.name, 'Updated group');
    expect(shape.gridX, 1);

    await tester.tapAt(tester.getCenter(slider) + const Offset(0, 8));
    await tester.pumpAndSettle();
    expect(find.text('OSC address'), findsOneWidget);
    expect(
      find.widgetWithText(TextField, 'Name (shown on screen)'),
      findsOneWidget,
    );
  });

  testWidgets('label editor hides OSC fields', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(OscService())..editMode = true;
    addTearDown(state.dispose);
    state.addControl(ControlType.text);

    await tester.pumpWidget(OscMagicianApp(state: state));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(ControlWidget)));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Text'), findsOneWidget);
    expect(find.text('OSC address'), findsNothing);
    expect(find.text('Min value'), findsNothing);
  });

  testWidgets('label editor enables OSC and saves multiline text', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState(OscService())..editMode = true;
    addTearDown(state.dispose);
    state.addControl(ControlType.text);
    final control = state.currentPage.controls.single;

    await tester.pumpWidget(OscMagicianApp(state: state));
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(find.byType(ControlWidget)));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Text'),
      'First line\nSecond line',
    );
    await tester.tap(find.text('Update text from OSC'));
    await tester.pumpAndSettle();
    final address = find.widgetWithText(TextField, 'OSC address (received)');
    await tester.ensureVisible(address);
    await tester.enterText(address, 'status');
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(control.name, 'First line\nSecond line');
    expect(control.address, '/status');
    expect(control.receiveOscText, isTrue);
    expect(find.text('First line\nSecond line'), findsOneWidget);
    final restored = OscControl.fromJson(control.toJson());
    expect(restored.receiveOscText, isTrue);
    expect(restored.address, '/status');
    expect(restored.name, 'First line\nSecond line');
    final oldJson = control.toJson()..remove('receiveOscText');
    expect(OscControl.fromJson(oldJson).receiveOscText, isFalse);

    await tester.tapAt(tester.getCenter(find.byType(ControlWidget)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Update text from OSC'));
    await tester.pumpAndSettle();
    expect(find.text('OSC address (received)'), findsNothing);
    await tester.ensureVisible(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(control.receiveOscText, isFalse);
    expect(control.address, '/status');
  });

  testWidgets('label wraps within its grid width', (tester) async {
    final control = OscControl(
      id: 'label',
      type: ControlType.text,
      name: 'one two three four five six',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 100,
            child: ControlWidget(
              control: control,
              enabled: true,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text(control.name),
    );
    expect(
      paragraph
          .getBoxesForSelection(
            TextSelection(baseOffset: 0, extentOffset: control.name.length),
          )
          .length,
      greaterThan(1),
    );
    expect(tester.takeException(), isNull);
  });

  for (final type in ControlType.values) {
    testWidgets('${type.label} renders at small and large sizes', (
      tester,
    ) async {
      final control = OscControl(
        id: 'test',
        type: type,
        name: 'Name',
        value: 0.7,
      );
      for (final size in [const Size(40, 20), const Size(200, 300)]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox.fromSize(
                size: size,
                child: ControlWidget(
                  control: control,
                  enabled: true,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
      }
    });
  }

  testWidgets('a named control fits in a short grid cell', (tester) async {
    final control = OscControl(
      id: 'test',
      type: ControlType.hSlider,
      name: 'Fader',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 100,
            height: 20,
            child: ControlWidget(
              control: control,
              enabled: false,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a named slider fills the cell height as it grows', (
    tester,
  ) async {
    final control = OscControl(
      id: 'test',
      type: ControlType.vSlider,
      name: 'Fader',
    );
    for (final height in [100.0, 300.0]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: SizedBox(
              width: 100,
              height: height,
              child: ControlWidget(
                control: control,
                enabled: false,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      final slider = find.descendant(
        of: find.byType(ControlWidget),
        matching: find.byType(CustomPaint),
      );
      // Only the border, padding and label should take space from the slider.
      expect(tester.getSize(slider.last).height, greaterThan(height - 30));
    }
  });
}
