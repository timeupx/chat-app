import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';

/// AR makeup drawn into published camera frames (Android native).
class MakeupService {
  MakeupService._() {
    if (isSupported) {
      _channel.setMethodCallHandler(_onNativeCall);
    }
  }

  static final MakeupService instance = MakeupService._();

  static const _channel = MethodChannel('app/makeup');

  bool get isSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  String? _attachedTrackId;

  /// Fired when the camera scene is too dark — host UI should pause makeup.
  void Function()? onLowLight;

  /// Fired when light is good again after [onLowLight] — makeup auto-resumes.
  void Function()? onLightRestored;

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'lowLight':
        onLowLight?.call();
        break;
      case 'lightRestored':
        onLightRestored?.call();
        break;
    }
  }

  Future<bool> attach(String? trackId) async {
    if (!isSupported || trackId == null || trackId.isEmpty) return false;
    if (_attachedTrackId == trackId) return true;
    try {
      final ok = await _channel.invokeMethod<bool>('attach', {
        'trackId': trackId,
      });
      if (ok == true) _attachedTrackId = trackId;
      return ok == true;
    } on PlatformException catch (e) {
      debugPrint('makeup attach failed: ${e.message}');
      return false;
    }
  }

  Future<void> detach() async {
    if (!isSupported || _attachedTrackId == null) return;
    _attachedTrackId = null;
    try {
      await _channel.invokeMethod<bool>('detach');
    } on PlatformException catch (e) {
      debugPrint('makeup detach failed: ${e.message}');
    }
  }

  /// [color] null turns lipstick off.
  Future<void> setLipstick(Color? color, {double strength = 0.55}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('setLipstick', {
        'enabled': color != null,
        'red': (color?.r ?? 0).toDouble(),
        'green': (color?.g ?? 0).toDouble(),
        'blue': (color?.b ?? 0).toDouble(),
        'strength': strength,
      });
    } on PlatformException catch (e) {
      debugPrint('makeup setLipstick failed: ${e.message}');
    }
  }

  /// Cheek blush — same native pipeline as lipstick. [color] null turns it off.
  Future<void> setBlush(Color? color, {double strength = 0.24}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('setBlush', {
        'enabled': color != null,
        'red': (color?.r ?? 0).toDouble(),
        'green': (color?.g ?? 0).toDouble(),
        'blue': (color?.b ?? 0).toDouble(),
        'strength': strength,
      });
    } on PlatformException catch (e) {
      debugPrint('makeup setBlush failed: ${e.message}');
    }
  }

  /// Soft under-eye brightening / concealer for dark circles.
  Future<void> setUnderEye(Color? color, {double strength = 0.28}) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<bool>('setUnderEye', {
        'enabled': color != null,
        'red': (color?.r ?? 0).toDouble(),
        'green': (color?.g ?? 0).toDouble(),
        'blue': (color?.b ?? 0).toDouble(),
        'strength': strength,
      });
    } on PlatformException catch (e) {
      debugPrint('makeup setUnderEye failed: ${e.message}');
    }
  }

}
