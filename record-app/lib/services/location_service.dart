import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import 'api_service.dart';

class TrackPoint {
  final double latitude;
  final double longitude;
  final double? altitude;
  final double? speed;
  final DateTime timestamp;

  TrackPoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (altitude != null) 'altitude': altitude,
        if (speed != null) 'speed': speed,
        'timestamp': timestamp.toIso8601String(),
      };
}

enum RecordingState { idle, recording, paused }

class LocationService extends ChangeNotifier {
  final _uuid = const Uuid();

  RecordingState _state = RecordingState.idle;
  String? _sessionId;
  final List<TrackPoint> _currentTrack = [];
  Timer? _locationTimer;

  double _totalDistance = 0;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;

  RecordingState get state => _state;
  String? get sessionId => _sessionId;
  List<TrackPoint> get currentTrack => List.unmodifiable(_currentTrack);
  double get totalDistance => _totalDistance;
  Duration get elapsed => _elapsed;

  /// 计算两点间距离（Haversine 公式），返回公里
  double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// 开始记录
  Future<bool> startRecording() async {
    // 检查权限
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    _sessionId = _uuid.v4();
    _currentTrack.clear();
    _totalDistance = 0;
    _startTime = DateTime.now();
    _elapsed = Duration.zero;
    _state = RecordingState.recording;
    notifyListeners();

    // 每 5 秒采集一次位置
    _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );

        final point = TrackPoint(
          latitude: position.latitude,
          longitude: position.longitude,
          altitude: position.altitude,
          speed: position.speed,
          timestamp: DateTime.now(),
        );

        // 计算距离增量
        if (_currentTrack.isNotEmpty) {
          final last = _currentTrack.last;
          _totalDistance += _haversineKm(
            last.latitude, last.longitude,
            point.latitude, point.longitude,
          );
        }

        _currentTrack.add(point);
        _elapsed = DateTime.now().difference(_startTime!);
        notifyListeners();
      } catch (e) {
        debugPrint('定位失败: $e');
      }
    });

    return true;
  }

  /// 暂停/恢复
  void togglePause() {
    if (_state == RecordingState.recording) {
      _locationTimer?.cancel();
      _state = RecordingState.paused;
    } else if (_state == RecordingState.paused) {
      _state = RecordingState.recording;
      _locationTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        try {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
          );
          final point = TrackPoint(
            latitude: position.latitude,
            longitude: position.longitude,
            altitude: position.altitude,
            speed: position.speed,
            timestamp: DateTime.now(),
          );
          if (_currentTrack.isNotEmpty) {
            final last = _currentTrack.last;
            _totalDistance += _haversineKm(
              last.latitude, last.longitude,
              point.latitude, point.longitude,
            );
          }
          _currentTrack.add(point);
          _elapsed = DateTime.now().difference(_startTime!);
          notifyListeners();
        } catch (e) {
          debugPrint('定位失败: $e');
        }
      });
    }
    notifyListeners();
  }

  /// 停止并上传
  Future<bool> stopAndUpload(ApiService api) async {
    _locationTimer?.cancel();
    _state = RecordingState.idle;

    if (_currentTrack.isEmpty || _sessionId == null) {
      notifyListeners();
      return false;
    }

    try {
      await api.uploadTrackPoints(
        sessionId: _sessionId!,
        points: _currentTrack.map((p) => p.toJson()).toList(),
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('上传失败: $e');
      notifyListeners();
      return false;
    }
  }

  /// 配速 (min/km)
  String get pace {
    if (_totalDistance <= 0 || _elapsed.inSeconds <= 0) return '--:--';
    final paceMinPerKm = (_elapsed.inSeconds / 60) / _totalDistance;
    final min = paceMinPerKm.floor();
    final sec = ((paceMinPerKm - min) * 60).floor();
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    super.dispose();
  }
}
