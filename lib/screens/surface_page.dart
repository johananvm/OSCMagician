import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets/control_editor.dart';
import '../widgets/control_widget.dart';
import 'settings_page.dart';

/// The OSC control surface: a grid of controls with edit/play modes
/// and page navigation at the bottom.
class SurfacePage extends StatelessWidget {
  const SurfacePage({super.key});

  Future<void> _addControl(BuildContext context, AppState state) async {
    final type = await showModalBottomSheet<ControlType>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Add control',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final t in ControlType.values)
                ListTile(
                  leading: Icon(_iconFor(t)),
                  title: Text(t.label),
                  onTap: () => Navigator.pop(context, t),
                ),
            ],
          ),
        ),
      ),
    );
    if (type != null) state.addControl(type);
  }

  static IconData _iconFor(ControlType t) => switch (t) {
    ControlType.hSlider => Icons.swap_horiz,
    ControlType.vSlider => Icons.swap_vert,
    ControlType.pushButton => Icons.radio_button_checked,
    ControlType.holdButton => Icons.touch_app,
    ControlType.toggleButton => Icons.power_settings_new,
    ControlType.knob => Icons.tune,
    ControlType.hMeter => Icons.linear_scale,
    ControlType.vMeter => Icons.equalizer,
    ControlType.text => Icons.text_fields,
    ControlType.shape => Icons.crop_square,
  };

  Future<void> _editControl(
    BuildContext context,
    AppState state,
    OscControl control,
  ) async {
    final page = state.currentPage;
    final result = await showControlEditor(
      context,
      control,
      gridCols: page.gridCols,
      gridRows: page.gridRows,
    );
    if (result == 'delete') {
      state.removeControl(control);
    } else if (result == 'ok') {
      state.updateControl(control);
    }
  }

  Future<void> _editControlAt(
    BuildContext context,
    AppState state,
    double gridX,
    double gridY,
  ) async {
    final controls = state.currentPage.controls
        .where(
          (c) =>
              gridX >= c.gridX &&
              gridX < c.gridX + c.gridW &&
              gridY >= c.gridY &&
              gridY < c.gridY + c.gridH,
        )
        .toList();
    if (controls.length == 1) {
      await _editControl(context, state, controls.single);
    } else if (controls.isNotEmpty) {
      final selected = await showModalBottomSheet<OscControl>(
        context: context,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text(
                    'Select control to edit',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                for (final (index, control) in controls.indexed)
                  ListTile(
                    leading: Icon(_iconFor(control.type)),
                    title: Text(
                      control.name.isEmpty ? control.type.label : control.name,
                    ),
                    subtitle: Text(
                      '#${index + 1} - ${control.type.label} - '
                      'Col ${control.gridX}, Row ${control.gridY}',
                    ),
                    onTap: () => Navigator.pop(context, control),
                  ),
              ],
            ),
          ),
        ),
      );
      if (selected != null && context.mounted) {
        await _editControl(context, state, selected);
      }
    }
  }

  Future<void> _export(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final uri = await FilePicker.saveFile(
        dialogTitle: 'Export screens',
        fileName: 'osc-magician-screens.json',
        mimeType: 'application/json',
        bytes: Uint8List.fromList(utf8.encode(state.exportJson())),
      );
      if (uri != null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Screens exported')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _import(BuildContext context, AppState state) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final file = await FilePicker.pickFile(
        dialogTitle: 'Import screens',
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      final error = state.importJson(utf8.decode(bytes));
      messenger.showSnackBar(
        SnackBar(content: Text(error ?? 'Screens imported')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _pageMenu(
    BuildContext context,
    AppState state,
    int index,
  ) async {
    final page = state.pages[index];
    final isLandscape = page.orientation == PageOrientation.landscape;
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Rename page'),
                onTap: () => Navigator.pop(context, 'rename'),
              ),
              ListTile(
                leading: Icon(
                  isLandscape
                      ? Icons.stay_current_portrait
                      : Icons.stay_current_landscape,
                ),
                title: Text(
                  isLandscape ? 'Switch to portrait' : 'Switch to landscape',
                ),
                onTap: () => Navigator.pop(context, 'orientation'),
              ),
              if (state.pages.length > 1)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete page'),
                  onTap: () => Navigator.pop(context, 'delete'),
                ),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted) return;
    if (action == 'delete') {
      state.removePage(index);
    } else if (action == 'orientation') {
      state.setPageOrientation(
        index,
        isLandscape ? PageOrientation.portrait : PageOrientation.landscape,
      );
    } else if (action == 'rename') {
      final controller = TextEditingController(text: state.pages[index].name);
      final name = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Rename page'),
          content: TextField(controller: controller, autofocus: true),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (name != null && name.isNotEmpty) state.renamePage(index, name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final page = state.currentPage;
    final fullscreen = state.hideBars && !state.editMode;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: fullscreen
          ? null
          : AppBar(
              title: Text(page.name),
              actions: [
                if (state.editMode)
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Add control',
                    onPressed: () => _addControl(context, state),
                  ),
                if (state.editMode &&
                    page.orientation == PageOrientation.landscape)
                  IconButton(
                    icon: Icon(
                      state.settings.editInPortrait
                          ? Icons.stay_current_landscape
                          : Icons.stay_current_portrait,
                    ),
                    tooltip: state.settings.editInPortrait
                        ? 'Edit in landscape'
                        : 'Edit in portrait',
                    onPressed: state.toggleEditInPortrait,
                  ),
                if (!state.editMode)
                  IconButton(
                    icon: const Icon(Icons.fullscreen),
                    tooltip: 'Hide bars',
                    onPressed: state.toggleHideBars,
                  ),
                IconButton(
                  icon: Icon(state.editMode ? Icons.play_arrow : Icons.edit),
                  tooltip: state.editMode ? 'Play' : 'Edit',
                  onPressed: state.toggleEditMode,
                ),
                PopupMenuButton<String>(
                  onSelected: (action) {
                    if (action == 'export') _export(context, state);
                    if (action == 'import') _import(context, state);
                    if (action == 'settings') {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SettingsPage(),
                        ),
                      );
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'export',
                      child: ListTile(
                        leading: Icon(Icons.upload_file),
                        title: Text('Export screens'),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'import',
                      child: ListTile(
                        leading: Icon(Icons.download),
                        title: Text('Import screens'),
                      ),
                    ),
                    PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'settings',
                      child: ListTile(
                        leading: Icon(Icons.settings),
                        title: Text('Settings'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, outer) {
            final grid = LayoutBuilder(
              builder: (context, constraints) {
                final cellW = constraints.maxWidth / page.gridCols;
                final cellH = constraints.maxHeight / page.gridRows;
                return Stack(
                  children: [
                    if (state.editMode)
                      Positioned.fill(
                        child: CustomPaint(painter: _GridPainter(cellW, cellH)),
                      ),
                    // Shapes first so they sit behind the controls they group.
                    for (final control in [
                      ...page.controls.where(
                        (c) => c.type == ControlType.shape,
                      ),
                      ...page.controls.where(
                        (c) => c.type != ControlType.shape,
                      ),
                    ])
                      Positioned(
                        left: control.gridX * cellW,
                        top: control.gridY * cellH,
                        width: control.gridW * cellW,
                        height: control.gridH * cellH,
                        child: state.editMode
                            ? _EditableControl(
                                control: control,
                                cellW: cellW,
                                cellH: cellH,
                                onTap: () =>
                                    _editControl(context, state, control),
                                onLongPress: (position) => _editControlAt(
                                  context,
                                  state,
                                  control.gridX + position.dx / cellW,
                                  control.gridY + position.dy / cellH,
                                ),
                                onMoved: (x, y) =>
                                    state.moveControl(control, x, y),
                              )
                            : ControlWidget(
                                control: control,
                                enabled: true,
                                onChanged: (v) =>
                                    state.controlChanged(control, v),
                              ),
                      ),
                    if (page.controls.isEmpty)
                      Center(
                        child: Text(
                          state.editMode
                              ? 'Tap + to add a control'
                              : 'No controls yet.\nTap the pencil to edit.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ),
                    // Compact overlay to switch pages / exit fullscreen.
                    if (fullscreen)
                      Positioned(
                        right: 4,
                        bottom: 4,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black45,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (state.pages.length > 1)
                                for (var i = 0; i < state.pages.length; i++)
                                  GestureDetector(
                                    onTap: () => state.selectPage(i),
                                    child: Padding(
                                      padding: const EdgeInsets.all(6),
                                      child: CircleAvatar(
                                        radius: 10,
                                        backgroundColor:
                                            i == state.currentPageIndex
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : Colors.white24,
                                        child: Text(
                                          '${i + 1}',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: i == state.currentPageIndex
                                                ? Colors.black87
                                                : Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.fullscreen_exit,
                                  size: 20,
                                ),
                                tooltip: 'Show bars',
                                onPressed: state.toggleHideBars,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
            // Editing a landscape page on a portrait screen: show the page at
            // the shape it gets in landscape Play mode with bars visible. The
            // bars take the same space in both orientations, so measure them
            // here in portrait and subtract them from the landscape size.
            final landscapeInPortrait =
                page.orientation == PageOrientation.landscape &&
                outer.maxWidth < outer.maxHeight;
            if (!landscapeInPortrait) return grid;
            final screen = MediaQuery.sizeOf(context);
            final playW = screen.height - (screen.width - outer.maxWidth);
            final playH = screen.width - (screen.height - outer.maxHeight);
            if (playH <= 0) return grid;
            return Center(
              child: AspectRatio(
                aspectRatio: playW / playH,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                  ),
                  child: grid,
                ),
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: fullscreen
          ? null
          : SafeArea(
              child: Container(
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < state.pages.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                child: ChoiceChip(
                                  label: Text(state.pages[i].name),
                                  selected: i == state.currentPageIndex,
                                  onSelected: (_) => state.selectPage(i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (state.editMode) ...[
                      IconButton(
                        icon: const Icon(Icons.more_vert),
                        tooltip: 'Page options',
                        onPressed: () =>
                            _pageMenu(context, state, state.currentPageIndex),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_box_outlined),
                        tooltip: 'Add page',
                        onPressed: state.addPage,
                      ),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// Wraps a control in edit mode: drag to move on the grid, tap to edit.
class _EditableControl extends StatefulWidget {
  const _EditableControl({
    required this.control,
    required this.cellW,
    required this.cellH,
    required this.onTap,
    required this.onLongPress,
    required this.onMoved,
  });

  final OscControl control;
  final double cellW;
  final double cellH;
  final VoidCallback onTap;
  final void Function(Offset position) onLongPress;
  final void Function(int gridX, int gridY) onMoved;

  @override
  State<_EditableControl> createState() => _EditableControlState();
}

class _EditableControlState extends State<_EditableControl> {
  double _dx = 0, _dy = 0;
  int _startX = 0, _startY = 0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPressStart: (details) => widget.onLongPress(details.localPosition),
      onPanStart: (_) {
        _startX = widget.control.gridX;
        _startY = widget.control.gridY;
        _dx = 0;
        _dy = 0;
      },
      onPanUpdate: (d) {
        _dx += d.delta.dx;
        _dy += d.delta.dy;
        final newX = _startX + (_dx / widget.cellW).round();
        final newY = _startY + (_dy / widget.cellH).round();
        if (newX != widget.control.gridX || newY != widget.control.gridY) {
          widget.onMoved(newX, newY);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ControlWidget(
                control: widget.control,
                enabled: false,
                onChanged: (_) {},
              ),
            ),
          ),
          const Positioned(
            left: 2,
            bottom: 2,
            child: Icon(Icons.open_with, size: 14, color: Colors.white38),
          ),
          // Dedicated edit button with a generous hit area.
          Positioned(
            right: -6,
            top: -6,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: widget.onTap,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(color: Colors.black54, blurRadius: 4),
                    ],
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 15,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter(this.cellW, this.cellH);

  final double cellW;
  final double cellH;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white12
      ..strokeWidth = 1;
    if (cellW > 0) {
      for (var x = 0.0; x <= size.width + 0.5; x += cellW) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
      }
    }
    if (cellH > 0) {
      for (var y = 0.0; y <= size.height + 0.5; y += cellH) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.cellW != cellW || old.cellH != cellH;
}
