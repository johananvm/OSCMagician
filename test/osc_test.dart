import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:osc_magician/osc.dart';

void main() {
  test('encodes and decodes a float message roundtrip', () {
    final msg = OscMessage('/page1/fader1', [0.75]);
    final decoded = OscMessage.decode(msg.encode());
    expect(decoded, isNotNull);
    expect(decoded!.address, '/page1/fader1');
    expect(decoded.firstNumeric, closeTo(0.75, 1e-6));
  });

  test('encodes and decodes int and string args', () {
    final msg = OscMessage('/x', [42, 'hello']);
    final decoded = OscMessage.decode(msg.encode())!;
    expect(decoded.arguments, [42, 'hello']);
    expect(decoded.firstNumeric, 42.0);
  });

  test('encoded message is 4-byte aligned per OSC spec', () {
    final bytes = OscMessage('/abc', [1.0]).encode();
    expect(bytes.length % 4, 0);
    // '/abc' + null + pad -> 8 bytes, ',f' + null + pad -> 4 bytes, float 4
    expect(bytes.length, 16);
  });

  test('rejects data that is not an OSC message', () {
    expect(OscMessage.decode(Uint8List.fromList([1, 2, 3, 4])), isNull);
    expect(OscMessage.decode(Uint8List.fromList('hello'.codeUnits)), isNull);
  });

  test('negative values and wide ranges survive roundtrip', () {
    final msg = OscMessage('/pan', [-1.0]);
    final decoded = OscMessage.decode(msg.encode())!;
    expect(decoded.firstNumeric, closeTo(-1.0, 1e-6));
  });
}
