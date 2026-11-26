import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'osc.dart';
import 'osc_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._osc);

  final OscService _osc;
  StreamSubscription<OscMessage>? _oscSub;

  AppSettings settings = AppSettings();
  final List<OscPage> pages = [OscPage(name: 'Page 1')];
  int currentPageIndex = 0;
  bool editMode = false;
  bool hideBars = false;
  List<String> localIps = [];

  OscPage get currentPage => pages[currentPageIndex];
  String? get oscError => _osc.lastError;

  Future<void> init() async {
    await _load();
    await _osc.bind(settings.listenPort);
    localIps = await OscService.localIpAddresses();
    _oscSub = _osc.incoming.listen(_onIncoming);
    _applyOrientation();
    notifyListeners();
  }

  Future<void> refreshLocalIps() async {
    localIps = await OscService.localIpAddresses();
    notifyListeners();
  }

  void _onIncoming(OscMessage msg) {
    final v = msg.firstNumeric;
    if (v == null) return;
    var changed = false;
    for (final page in pages) {
      for (final control in page.controls) {
        if (control.address == msg.address) {
          control.value = v.clamp(control.min, control.max);
          changed = true;
        }
      }
    }
    if (changed) {
      notifyListeners();
      _save();
    }
  }

  /// Called by control widgets when the user changes a value in play mode.
  void controlChanged(OscControl control, double newValue, {bool send = true}) {
    control.value = newValue.clamp(control.min, control.max);
    if (send) {
      _osc.send(OscMessage(control.address, [control.value]),
          settings.targetIp, settings.targetPort);
    }
    notifyListeners();
    _saveDebounced();
  }

  // ---- edit operations ----

  void toggleEditMode() {
    editMode = !editMode;
    if (editMode) hideBars = false;
    notifyListeners();
    _save();
  }

  void toggleHideBars() {
    hideBars = !hideBars;
    notifyListeners();
  }

  void addControl(ControlType type) {
    final page = currentPage;
    final control = OscControl(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: type,
      name: type.label,
      address: '/page${currentPageIndex + 1}/control${page.controls.length + 1}',
    );
    _placeInFreeSpot(control, page);
    page.controls.add(control);
    notifyListeners();
    _save();
  }

  void _placeInFreeSpot(OscControl control, OscPage page) {
    for (var y = 0; y <= page.gridRows - control.gridH; y++) {
      for (var x = 0; x <= page.gridCols - control.gridW; x++) {
        control.gridX = x;
        control.gridY = y;
        if (!_overlapsAny(control, page)) return;
      }
    }
    control.gridX = 0;
    control.gridY = 0;
  }

  bool _overlapsAny(OscControl control, OscPage page) {
    for (final other in page.controls) {
      if (other.id == control.id) continue;
      final overlapX = control.gridX < other.gridX + other.gridW &&
          other.gridX < control.gridX + control.gridW;
      final overlapY = control.gridY < other.gridY + other.gridH &&
          other.gridY < control.gridY + control.gridH;
      if (overlapX && overlapY) return true;
    }
    return false;
  }

  void moveControl(OscControl control, int gridX, int gridY) {
    final page = currentPage;
    control.gridX = gridX.clamp(0, page.gridCols - control.gridW);
    control.gridY = gridY.clamp(0, page.gridRows - control.gridH);
    notifyListeners();
    _saveDebounced();
  }

  void updateControl(OscControl control) {
    final page = currentPage;
    control.gridW = control.gridW.clamp(1, page.gridCols);
    control.gridH = control.gridH.clamp(1, page.gridRows);
    control.gridX = control.gridX.clamp(0, page.gridCols - control.gridW);
    control.gridY = control.gridY.clamp(0, page.gridRows - control.gridH);
    control.value = control.value.clamp(
        control.min <= control.max ? control.min : control.max,
        control.min <= control.max ? control.max : control.min);
    notifyListeners();
    _save();
  }

  void removeControl(OscControl control) {
    currentPage.controls.remove(control);
    notifyListeners();
    _save();
  }

  void addPage() {
    pages.add(OscPage(name: 'Page ${pages.length + 1}'));
    currentPageIndex = pages.length - 1;
    _applyOrientation();
    notifyListeners();
    _save();
  }

  void renamePage(int index, String name) {
    pages[index].name = name;
    notifyListeners();
    _save();
  }

  void removePage(int index) {
    if (pages.length <= 1) return;
    pages.removeAt(index);
    if (currentPageIndex >= pages.length) currentPageIndex = pages.length - 1;
    _applyOrientation();
    notifyListeners();
    _save();
  }

  void selectPage(int index) {
    currentPageIndex = index;
    _applyOrientation();
    notifyListeners();
  }

  void setPageOrientation(int index, PageOrientation orientation) {
    final page = pages[index];
    page.orientation = orientation;
    // Keep all controls inside the new grid bounds.
    for (final c in page.controls) {
      c.gridW = c.gridW.clamp(1, page.gridCols);
      c.gridH = c.gridH.clamp(1, page.gridRows);
      c.gridX = c.gridX.clamp(0, page.gridCols - c.gridW);
      c.gridY = c.gridY.clamp(0, page.gridRows - c.gridH);
    }
    if (index == currentPageIndex) _applyOrientation();
    notifyListeners();
    _save();
  }

  void _applyOrientation() {
    SystemChrome.setPreferredOrientations(
      currentPage.orientation == PageOrientation.landscape
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
  }

  // ---- export / import ----

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
        'settings': settings.toJson(),
        'pages': pages.map((p) => p.toJson()).toList(),
      });

  /// Returns null on success, or an error message.
  String? importJson(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final loadedPages = (json['pages'] as List<dynamic>)
          .map((p) => OscPage.fromJson(p as Map<String, dynamic>))
          .toList();
      if (loadedPages.isEmpty) return 'File contains no pages';
      if (json['settings'] is Map<String, dynamic>) {
        settings =
            AppSettings.fromJson(json['settings'] as Map<String, dynamic>);
        _osc.bind(settings.listenPort);
      }
      pages
        ..clear()
        ..addAll(loadedPages);
      currentPageIndex = 0;
      _applyOrientation();
      notifyListeners();
      _save();
      return null;
    } catch (e) {
      return 'Invalid file: $e';
    }
  }

  Future<void> updateSettings(
      {String? targetIp, int? targetPort, int? listenPort}) async {
    if (targetIp != null) settings.targetIp = targetIp;
    if (targetPort != null) settings.targetPort = targetPort;
    if (listenPort != null && listenPort != settings.listenPort) {
      settings.listenPort = listenPort;
      await _osc.bind(listenPort);
    }
    notifyListeners();
    await _save();
  }

  // ---- persistence ----

  Timer? _saveTimer;
  void _saveDebounced() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 1), _save);
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'project',
        jsonEncode({
          'settings': settings.toJson(),
          'pages': pages.map((p) => p.toJson()).toList(),
        }));
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('project');
    if (raw == null) return;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      settings =
          AppSettings.fromJson(json['settings'] as Map<String, dynamic>);
      final loadedPages = (json['pages'] as List<dynamic>)
          .map((p) => OscPage.fromJson(p as Map<String, dynamic>))
          .toList();
      if (loadedPages.isNotEmpty) {
        pages
          ..clear()
          ..addAll(loadedPages);
      }
    } catch (_) {
      // Corrupt save: start fresh.
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _oscSub?.cancel();
    _osc.dispose();
    super.dispose();
  }
}
