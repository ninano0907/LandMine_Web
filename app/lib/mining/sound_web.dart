import 'dart:js_interop';

@JS('landmineBeep')
external void _beep();

class DetectorSound {
  static Future<void> beep() async {
    _beep();
  }
}
