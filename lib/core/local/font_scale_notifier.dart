import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'font_scale_service.dart';

part 'font_scale_notifier.g.dart';

/// Exposes the current in-app font scale factor and persists changes via
/// [FontScaleService]. Initial value is read synchronously from Hive in
/// [build] — safe because the `app_prefs` box is opened in `main.dart`
/// before `runApp`.
@Riverpod(keepAlive: true)
class FontScaleNotifier extends _$FontScaleNotifier {
  late final FontScaleService _service;

  @override
  double build() {
    _service = FontScaleService();
    return _service.scale;
  }

  Future<void> setScale(double value) async {
    await _service.setScale(value);
    state = _service.scale;
  }
}
