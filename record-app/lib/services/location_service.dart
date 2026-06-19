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
  final int steps;
  final DateTime timestamp;

  TrackPoint({
    required this.latitude,
    required this.longitude,
    this.altitude,
    this.speed,
    required this.steps,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        if (altitude != null) 'altitude': altitude,
        if (speed != null) 'speed': speed,
        'steps': steps,
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
  Timer? _uploadTimer;

  double _totalDistance = 0;
  int _totalSteps = 0;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  bool _hasPermission = false;
  bool _permissionChecked = false;

  // 上传状态
  String _uploadStatus = '';
  String get uploadStatus => _uploadStatus;

  RecordingState get state => _state;
  String? get sessionId => _sessionId;
  List<TrackPoint> get currentTrack => List.unmodifiable(_currentTrack);
  double get totalDistance => _totalDistance;
  int get totalSteps => _totalSteps;
  Duration get elapsed => _elapsed;
  bool get hasPermission => _hasPermission;
  bool get permissionChecked => _permissionChecked;

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

  /// 检查并请求位置权限，返回权限状态说明
  Future<String> checkPermission() async {
    _permissionChecked = true;
    notifyListeners();

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _hasPermission = false;
      notifyListeners();
      return '请开启手机定位服务';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _hasPermission = false;
        notifyListeners();
        return '位置权限被拒绝，请在设置中开启';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _hasPermission = false;
      notifyListeners();
      return '位置权限已被永久拒绝，请在系统设置中开启';
    }

    _hasPermission = true;
    notifyListeners();
    return 'ok';
  }

  /// 开始记录
  Future<String> startRecording(ApiService api) async {
    final permResult = await checkPermission();
    if (permResult != 'ok') return permResult;

    _sessionId = _uuid.v4();
    _currentTrack.clear();
    _totalDistance = 0;
    _totalSteps = 0;
    _startTime = DateTime.now();
    _elapsed = Duration.zero;
    _state = RecordingState.recording;
    _uploadStatus = '';
    notifyListeners();

    // 每 3 秒采集一次位置 + 模拟步数
    _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      await _collectPoint();
    });

    // 每 5 秒上传一次到服务器
    _uploadTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _uploadToServer(api);
    });

    return 'ok';
  }

  Future<void> _collectPoint() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      // Demo 模式：模拟步数，每秒约 2-3 步
      _totalSteps += (2 + (math.Random().nextInt(2))); // 每次采集加 2-3 步

      final point = TrackPoint(
        latitude: position.latitude,
        longitude: position.longitude,
        altitude: position.altitude,
        speed: position.speed,
        steps: _totalSteps,
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
  }

  Future<void> _uploadToServer(ApiService api) async {
    if (_currentTrack.isEmpty || _sessionId == null) return;
    try {
      // 只上传未上传过的点（这里简化为上传全部最新点）
      final lastPoints = _currentTrack.length > 2
          ? _currentTrack.sublist(_currentTrack.length - 2)
          : _currentTrack;
      await api.uploadTrackPoints(
        sessionId: _sessionId!,
        points: lastPoints.map((p) => p.toJson()).toList(),
      );
      _uploadStatus = '已同步 ${_currentTrack.length} 个点';
      notifyListeners();
    } catch (e) {
      _uploadStatus = '同步失败';
      debugPrint('上传失败: $e');
      notifyListeners();
    }
  }

  /// 暂停/恢复
  void togglePause() {
    if (_state == RecordingState.recording) {
      _locationTimer?.cancel();
      _uploadTimer?.cancel();
      _state = RecordingState.paused;
    } else if (_state == RecordingState.paused) {
      _state = RecordingState.recording;
      _locationTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
        await _collectPoint();
      });
      _uploadTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
        // 需要通过某种方式获取 api，这里暂时跳过
      });
    }
    notifyListeners();
  }

  /// 停止并最终上传
  Future<bool> stopAndUpload(ApiService api) async {
    _locationTimer?.cancel();
    _uploadTimer?.cancel();
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
      _uploadStatus = '全部上传完成';
      notifyListeners();
      return true;
    } catch (e) {
      _uploadStatus = '上传失败';
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
    _uploadTimer?.cancel();
    super.dispose();
  }
}
