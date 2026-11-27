import 'package:flutter/material.dart';

import '../models.dart';

const _palette = <Color>[
  Colors.teal,
  Colors.cyan,
  Colors.blue,
  Colors.indigo,
  Colors.purple,
  Colors.pink,
  Colors.red,
  Colors.orange,
  Colors.amber,
  Colors.lime,
  Colors.green,
  Colors.white,
];

/// Bottom sheet for editing a control's properties.
/// Returns 'delete' if the control should be removed, 'ok' if saved.
Future<String?> showControlEditor(
  BuildContext context,
  OscControl control, {
  int gridCols = kGridCols,
  int gridRows = kGridRows,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _ControlEditor(
      control: control,
      gridCols: gridCols,
      gridRows: gridRows,
    ),
  );
}

class _ControlEditor extends StatefulWidget {
  const _ControlEditor({
    required this.control,
    required this.gridCols,
    required this.gridRows,
  });

  final OscControl control;
  final int gridCols;
  final int gridRows;

  @override
  State<_ControlEditor> createState() => _ControlEditorState();
}

class _ControlEditorState extends State<_ControlEditor> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late Color _color;
  late int _gridX, _gridY, _gridW, _gridH;
  late bool _receiveOscText;

  OscControl get c => widget.control;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: c.name);
    _address = TextEditingController(text: c.address);
    _min = TextEditingController(text: _num(c.min));
    _max = TextEditingController(text: _num(c.max));
    _color = c.color;
    _receiveOscText = c.receiveOscText;
    _gridX = c.gridX;
    _gridY = c.gridY;
    _gridW = c.gridW;
    _gridH = c.gridH;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  void _save() {
    c.name = _name.text.trim();
    var addr = _address.text.trim();
    if (addr.isEmpty) addr = '/control';
    if (!addr.startsWith('/')) addr = '/$addr';
    c.address = addr;
    c.receiveOscText = _receiveOscText;
    c.min = double.tryParse(_min.text.replaceAll(',', '.')) ?? c.min;
    c.max = double.tryParse(_max.text.replaceAll(',', '.')) ?? c.max;
    c.color = _color;
    c.gridX = _gridX;
    c.gridY = _gridY;
    c.gridW = _gridW;
    c.gridH = _gridH;
    Navigator.pop(context, 'ok');
  }

  Widget _stepper(
    String label,
    int value,
    int minV,
    int maxV,
    void Function(int) onChanged,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(width: 56, child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          onPressed: value > minV
              ? () => setState(() => onChanged(value - 1))
              : null,
        ),
        SizedBox(width: 24, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          onPressed: value < maxV
              ? () => setState(() => onChanged(value + 1))
              : null,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    c.type.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Delete control',
                  onPressed: () => Navigator.pop(context, 'delete'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              minLines: 1,
              maxLines: c.type == ControlType.text ? 4 : 1,
              keyboardType: c.type == ControlType.text
                  ? TextInputType.multiline
                  : TextInputType.text,
              decoration: InputDecoration(
                labelText: c.type == ControlType.text
                    ? 'Text'
                    : 'Name (shown on screen)',
                border: const OutlineInputBorder(),
              ),
            ),
            if (c.type == ControlType.text)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Update text from OSC'),
                value: _receiveOscText,
                onChanged: (value) => setState(() => _receiveOscText = value),
              ),
            if (!c.type.isDecoration ||
                (c.type == ControlType.text && _receiveOscText)) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _address,
                decoration: InputDecoration(
                  labelText: c.type.isMeter || c.type == ControlType.text
                      ? 'OSC address (received)'
                      : 'OSC address',
                  hintText: '/fader1',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
            if (!c.type.isDecoration) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _min,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Min value',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _max,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Max value',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            const Text('Color'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final color in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == color
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Position & size (grid cells)'),
            Wrap(
              children: [
                _stepper(
                  'Col',
                  _gridX,
                  0,
                  widget.gridCols - _gridW,
                  (v) => _gridX = v,
                ),
                _stepper(
                  'Row',
                  _gridY,
                  0,
                  widget.gridRows - _gridH,
                  (v) => _gridY = v,
                ),
                _stepper(
                  'Width',
                  _gridW,
                  1,
                  widget.gridCols - _gridX,
                  (v) => _gridW = v,
                ),
                _stepper(
                  'Height',
                  _gridH,
                  1,
                  widget.gridRows - _gridY,
                  (v) => _gridH = v,
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
