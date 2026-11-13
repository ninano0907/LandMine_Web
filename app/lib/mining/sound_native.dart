import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';

class DetectorSound {
  static const _channel = MethodChannel('mining/detector');
  static final _tone = _makeTone();
  static bool _unavailable = false;
  static Future<void> beep() async {
    if (_unavailable) return;
    try {
      await _channel.invokeMethod<void>('beep', _tone);
    } on MissingPluginException {
      _unavailable = true;
    } on PlatformException {
      _unavailable = true;
    }
  }

  static Uint8List _makeTone() {
    const rate = 22050, count = 1764;
    final bytes = ByteData(44 + count * 2);
    void tag(int at, String value) {
      for (var i = 0; i < value.length; i++) {
        bytes.setUint8(at + i, value.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    bytes.setUint32(4, 36 + count * 2, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little);
    bytes.setUint16(22, 1, Endian.little);
    bytes.setUint32(24, rate, Endian.little);
    bytes.setUint32(28, rate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    bytes.setUint32(40, count * 2, Endian.little);
    for (var i = 0; i < count; i++) {
      final envelope = min(1.0, min(i / 100, (count - i) / 100));
      bytes.setInt16(
        44 + i * 2,
        (sin(2 * pi * 880 * i / rate) * 6000 * envelope).round(),
        Endian.little,
      );
    }
    return bytes.buffer.asUint8List();
  }
}
