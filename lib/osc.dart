import 'dart:convert';
import 'dart:typed_data';

/// Minimal OSC 1.0 message codec (messages with float/int/string args).
class OscMessage {
  OscMessage(this.address, this.arguments);

  final String address;
  final List<Object> arguments;

  /// First numeric argument as double, if any.
  double? get firstNumeric {
    for (final a in arguments) {
      if (a is double) return a;
      if (a is int) return a.toDouble();
    }
    return null;
  }

  Uint8List encode() {
    final builder = BytesBuilder();
    builder.add(_paddedString(address));
    final typeTags = StringBuffer(',');
    final argBytes = BytesBuilder();
    for (final arg in arguments) {
      if (arg is double) {
        typeTags.write('f');
        final bd = ByteData(4)..setFloat32(0, arg, Endian.big);
        argBytes.add(bd.buffer.asUint8List());
      } else if (arg is int) {
        typeTags.write('i');
        final bd = ByteData(4)..setInt32(0, arg, Endian.big);
        argBytes.add(bd.buffer.asUint8List());
      } else if (arg is String) {
        typeTags.write('s');
        argBytes.add(_paddedString(arg));
      } else if (arg is bool) {
        typeTags.write(arg ? 'T' : 'F');
      }
    }
    builder.add(_paddedString(typeTags.toString()));
    builder.add(argBytes.toBytes());
    return builder.toBytes();
  }

  static OscMessage? decode(Uint8List data) {
    try {
      var offset = 0;
      final (address, o1) = _readString(data, offset);
      offset = o1;
      if (!address.startsWith('/')) return null;
      var typeTags = '';
      if (offset < data.length && data[offset] == 0x2C /* ',' */ ) {
        final (tags, o2) = _readString(data, offset);
        typeTags = tags.substring(1);
        offset = o2;
      }
      final args = <Object>[];
      final bd = ByteData.sublistView(data);
      for (final tag in typeTags.split('')) {
        switch (tag) {
          case 'f':
            args.add(bd.getFloat32(offset, Endian.big));
            offset += 4;
          case 'i':
            args.add(bd.getInt32(offset, Endian.big));
            offset += 4;
          case 'd':
            args.add(bd.getFloat64(offset, Endian.big));
            offset += 8;
          case 's':
          case 'S':
            final (s, o) = _readString(data, offset);
            args.add(s);
            offset = o;
          case 'T':
            args.add(true);
          case 'F':
            args.add(false);
          default:
            // Unsupported tag: stop parsing args.
            return OscMessage(address, args);
        }
      }
      return OscMessage(address, args);
    } catch (_) {
      return null;
    }
  }

  static Uint8List _paddedString(String s) {
    final bytes = utf8.encode(s);
    final padded = Uint8List((bytes.length + 4) & ~3); // +1 null, pad to 4
    padded.setAll(0, bytes);
    return padded;
  }

  static (String, int) _readString(Uint8List data, int offset) {
    var end = offset;
    while (end < data.length && data[end] != 0) {
      end++;
    }
    final s = utf8.decode(data.sublist(offset, end));
    final next = (end + 4) & ~3;
    return (s, next);
  }
}
