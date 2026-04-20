// lib/data/motion_service.dart
import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

class MotionService {
  MotionService._();
  static final MotionService instance = MotionService._();

  static const double _walkingThreshold = 2.5;
  static const Duration _sampleWindow = Duration(milliseconds: 500);

  StreamSubscription<AccelerometerEvent>? _sub;
  double _lastMagnitude = 0;

  final StreamController<bool> _motionController =
      StreamController<bool>.broadcast();

  Stream<bool> get isMoving => _motionController.stream;

  void start() {
    _sub?.cancel();
    _sub = accelerometerEventStream(
      samplingPeriod: _sampleWindow,
    ).listen((AccelerometerEvent event) {
      final magnitude = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      final delta = (magnitude - _lastMagnitude).abs();
      _lastMagnitude = magnitude;
      if (!_motionController.isClosed) {
        _motionController.add(delta > _walkingThreshold);
      }
    });
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }
}