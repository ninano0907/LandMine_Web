import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

/// Owns decoded images and reloads them independently; one failure cannot hide a unit.
class UnitSprites extends ChangeNotifier {
  static const idleAsset = 'assets/units/1900/engineer_idle.png';
  static const barracksAsset = 'assets/buildings/barracks_bottle_range.png';
  static const carryAsset = 'assets/units/1900/engineer_walk_loaded.png';
  static const walkAsset = 'assets/units/1900/engineer_walk_empty.png';
  static const workAsset = 'assets/units/1900/engineer_repair.png';
  static const mineAsset = 'assets/units/1900/engineer_mine.png';
  static const factoryAsset =
      'assets/buildings/command_center_wash_plant_compact_twin.png';
  static const pistolWalkAsset = 'assets/units/1900/infantry/pistol_walk.png';
  static const pistolFireAsset = 'assets/units/1900/infantry/pistol_fire.png';
  static const shotgunWalkAsset = 'assets/units/1900/infantry/shotgun_walk.png';
  static const shotgunFireAsset = 'assets/units/1900/infantry/shotgun_fire.png';
  final _images = <String, ui.Image>{};
  bool _closed = false;
  bool _loading = false;
  String? error;
  ui.Image? operator [](String asset) => _images[asset];

  Future<void> load() async {
    if (_loading || _closed) return;
    _loading = true;
    final failed = <String>[];
    try {
      for (final asset in [
        idleAsset,
        walkAsset,
        carryAsset,
        workAsset,
        mineAsset,
        factoryAsset,
        barracksAsset,
        pistolWalkAsset,
        pistolFireAsset,
        shotgunWalkAsset,
        shotgunFireAsset,
      ]) {
        try {
          final data = await rootBundle.load(asset);
          final codec = await ui.instantiateImageCodec(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          );
          late final ui.Image image;
          try {
            image = (await codec.getNextFrame()).image;
          } finally {
            codec.dispose();
          }
          if (_closed) {
            image.dispose();
            return;
          }
          final old = _images[asset];
          _images[asset] = image;
          notifyListeners();
          if (old != null) {
            SchedulerBinding.instance.addPostFrameCallback(
              (_) => old.dispose(),
            );
          }
        } catch (exception) {
          failed.add(asset);
          debugPrint('Unit sprite load failed ($asset): $exception');
        }
      }
      if (!_closed) {
        error = failed.isEmpty
            ? null
            : '일부 이미지 로딩 실패: ${failed.join(", ")}. 종료 후 다시 실행하거나 이미지 재시도를 눌러 주세요.';
        notifyListeners();
      }
    } finally {
      _loading = false;
    }
  }

  @override
  void dispose() {
    _closed = true;
    for (final image in _images.values) {
      image.dispose();
    }
    _images.clear();
    super.dispose();
  }
}
