import 'package:flutter/material.dart';

/// Number of columns/rows in the layout grid (portrait orientation).
const int kGridCols = 8;
const int kGridRows = 12;

enum PageOrientation { portrait, landscape }

enum ControlType {
  hSlider('Horizontal slider'),
  vSlider('Vertical slider'),
  pushButton('Push button (on/off)'),
  holdButton('Hold button'),
  toggleButton('Toggle button'),
  knob('Turnable knob'),
  hMeter('Horizontal meter'),
  vMeter('Vertical meter'),
  text('Label'),
  shape('Shape');

  const ControlType(this.label);
  final String label;

  /// Labels and shapes have no numeric value controls.
  bool get isDecoration => this == text || this == shape;

  bool get isMeter => this == hMeter || this == vMeter;
}

class OscControl {
  OscControl({
    required this.id,
    required this.type,
    this.name = '',
    this.address = '/control',
    this.receiveOscText = false,
    this.min = 0.0,
    this.max = 1.0,
    this.color = Colors.teal,
    this.gridX = 0,
    this.gridY = 0,
    int? gridW,
    int? gridH,
    double? value,
  }) : gridW = gridW ?? _defaultW(type),
       gridH = gridH ?? _defaultH(type) {
    this.value = value ?? min;
  }

  final String id;
  ControlType type;
  String name;
  String address;
  bool receiveOscText;
  double min;
  double max;
  Color color;
  int gridX;
  int gridY;
  int gridW;
  int gridH;

  /// Current value, always within [min, max].
  late double value;

  static int _defaultW(ControlType t) => switch (t) {
    ControlType.hSlider => 4,
    ControlType.vSlider => 2,
    ControlType.knob => 2,
    ControlType.hMeter => 4,
    ControlType.vMeter => 1,
    ControlType.text => 3,
    ControlType.shape => 4,
    _ => 2,
  };

  static int _defaultH(ControlType t) => switch (t) {
    ControlType.hSlider => 2,
    ControlType.vSlider => 4,
    ControlType.knob => 3,
    ControlType.hMeter => 1,
    ControlType.vMeter => 4,
    ControlType.text => 1,
    ControlType.shape => 4,
    _ => 2,
  };

  /// Normalized value 0..1 for rendering.
  double get normalized =>
      max == min ? 0 : ((value - min) / (max - min)).clamp(0.0, 1.0);

  set normalized(double n) => value = min + (max - min) * n.clamp(0.0, 1.0);

  bool get isOn => normalized >= 0.5;

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'name': name,
    'address': address,
    'receiveOscText': receiveOscText,
    'min': min,
    'max': max,
    'color': color.toARGB32(),
    'gridX': gridX,
    'gridY': gridY,
    'gridW': gridW,
    'gridH': gridH,
    'value': value,
  };

  factory OscControl.fromJson(Map<String, dynamic> json) => OscControl(
    id: json['id'] as String,
    type: ControlType.values.firstWhere(
      (t) => t.name == json['type'],
      orElse: () => ControlType.hSlider,
    ),
    name: json['name'] as String? ?? '',
    address: json['address'] as String? ?? '/control',
    receiveOscText: json['receiveOscText'] as bool? ?? false,
    min: (json['min'] as num?)?.toDouble() ?? 0.0,
    max: (json['max'] as num?)?.toDouble() ?? 1.0,
    color: Color(json['color'] as int? ?? Colors.teal.toARGB32()),
    gridX: json['gridX'] as int? ?? 0,
    gridY: json['gridY'] as int? ?? 0,
    gridW: json['gridW'] as int?,
    gridH: json['gridH'] as int?,
    value: (json['value'] as num?)?.toDouble(),
  );
}

class OscPage {
  OscPage({
    required this.name,
    List<OscControl>? controls,
    this.orientation = PageOrientation.portrait,
  }) : controls = controls ?? [];

  String name;
  final List<OscControl> controls;
  PageOrientation orientation;

  int get gridCols =>
      orientation == PageOrientation.portrait ? kGridCols : kGridRows;
  int get gridRows =>
      orientation == PageOrientation.portrait ? kGridRows : kGridCols;

  Map<String, dynamic> toJson() => {
    'name': name,
    'orientation': orientation.name,
    'controls': controls.map((c) => c.toJson()).toList(),
  };

  factory OscPage.fromJson(Map<String, dynamic> json) => OscPage(
    name: json['name'] as String? ?? 'Page',
    orientation: PageOrientation.values.firstWhere(
      (o) => o.name == json['orientation'],
      orElse: () => PageOrientation.portrait,
    ),
    controls: (json['controls'] as List<dynamic>? ?? [])
        .map((c) => OscControl.fromJson(c as Map<String, dynamic>))
        .toList(),
  );
}

class AppSettings {
  AppSettings({
    this.targetIp = '192.168.1.100',
    this.targetPort = 8000,
    this.listenPort = 9000,
    this.editInPortrait = true,
  });

  String targetIp;
  int targetPort;
  int listenPort;

  /// Edit landscape pages with the phone held upright.
  bool editInPortrait;

  Map<String, dynamic> toJson() => {
    'targetIp': targetIp,
    'targetPort': targetPort,
    'listenPort': listenPort,
    'editInPortrait': editInPortrait,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
    targetIp: json['targetIp'] as String? ?? '192.168.1.100',
    targetPort: json['targetPort'] as int? ?? 8000,
    listenPort: json['listenPort'] as int? ?? 9000,
    editInPortrait: json['editInPortrait'] as bool? ?? true,
  );
}
