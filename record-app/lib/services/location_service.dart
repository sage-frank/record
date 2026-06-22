import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:uuid/uuid.dart';
import '../models/run_result.dart';
import '../utils/coord_transform.dart';
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
  StreamSubscription<Position>? _positionSubscription;
  Timer? _uploadTimer;
  ApiService? _apiService;
  int _lastUploadedIndex = 0;

  double _totalDistance = 0;
  int _totalSteps = 0;
  DateTime? _startTime;
  Duration _elapsed = Duration.zero;
  DateTime? _pausedAt;
  Duration _totalPausedDuration = Duration.zero;
  bool _hasPermission = false;
  bool _permissionChecked = false;

  // Pedometer 相关
  StreamSubscription<StepCount>? _stepCountSubscription;
  int _stepCountAtStart = 0; // 开始记录时的系统步数基准

  // 上传状态
  String _uploadStatus = '';
  String get uploadStatus => _uploadStatus;

  // GPS 错误信息（暴露给 UI）
  String _lastGpsError = '';
  String get lastGpsError => _lastGpsError;

  // 计步器错误信息
  String _lastPedometerError = '';
  String get lastPedometerError => _lastPedometerError;

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
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
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
    debugPrint('[LocationService] checkPermission 结果: $permResult');
    if (permResult != 'ok') return permResult;

    await _positionSubscription?.cancel();
    _uploadTimer?.cancel();
    _stopPedometer();

    _apiService = api;
    _sessionId = _uuid.v4();
    _currentTrack.clear();
    _totalDistance = 0;
    _totalSteps = 0;
    _stepCountAtStart = 0;
    _lastUploadedIndex = 0;
    _startTime = DateTime.now();
    _elapsed = Duration.zero;
    _pausedAt = null;
    _totalPausedDuration = Duration.zero;
    _state = RecordingState.recording;
    _uploadStatus = '';
    _lastGpsError = '';
    _lastPedometerError = '';
    notifyListeners();

    debugPrint(
      '[LocationService] 开始记录 session=$_sessionId startTime=$_startTime',
    );

    // 启动计步器监听（真实步数）
    try {
      _startPedometer();
    } catch (e) {
      debugPrint('[LocationService] 计步器启动失败: $e');
      _lastPedometerError = e.toString();
      notifyListeners();
    }

    await _startPositionTracking();
    _startUploadTimer();

    return 'ok';
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
        intervalDuration: Duration(seconds: 10),
        foregroundNotificationConfig: ForegroundNotificationConfig(
          notificationTitle: '运动记录进行中',
          notificationText: '正在后台记录你的跑步轨迹',
          enableWakeLock: true,
        ),
      );
    }

    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        activityType: ActivityType.fitness,
        distanceFilter: 10,
        pauseLocationUpdatesAutomatically: true,
        showBackgroundLocationIndicator: false,
      );
    }

    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
  }

  Future<void> _startPositionTracking() async {
    await _positionSubscription?.cancel();
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(
      _handlePosition,
      onError: (Object error) {
        final errStr = error.toString();
        debugPrint('定位失败: $errStr');
        _lastGpsError = 'GPS: $errStr';
        _syncElapsed();
        notifyListeners();
      },
    );
  }

  void _handlePosition(Position position) {
    if (_state != RecordingState.recording) {
      return;
    }

    if (_lastGpsError.isNotEmpty) {
      _lastGpsError = '';
    }

    final gcj = wgs84ToGcj02(position.latitude, position.longitude);
    final point = TrackPoint(
      latitude: gcj.latitude,
      longitude: gcj.longitude,
      altitude: position.altitude,
      speed: position.speed,
      steps: _totalSteps,
      timestamp: DateTime.now(),
    );

    if (_currentTrack.isNotEmpty) {
      final last = _currentTrack.last;
      _totalDistance += _haversineKm(
        last.latitude,
        last.longitude,
        point.latitude,
        point.longitude,
      );
    }

    _currentTrack.add(point);
    _syncElapsed();
    notifyListeners();
  }

  void _startUploadTimer() {
    _uploadTimer?.cancel();
    _uploadTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _uploadPendingPoints();
    });
  }

  void _syncElapsed([DateTime? now]) {
    if (_startTime == null) {
      return;
    }

    final currentTime = now ?? DateTime.now();
    _elapsed = currentTime.difference(_startTime!) - _totalPausedDuration;
    if (_elapsed.isNegative) {
      _elapsed = Duration.zero;
    }
  }

  /// 启动计步器，监听系统步数变化
  void _startPedometer() {
    _stepCountSubscription?.cancel();
    _stepCountSubscription = Pedometer.stepCountStream.listen(
      (StepCount event) {
        if (_stepCountAtStart == 0) {
          // 首次获取系统步数作为基准
          _stepCountAtStart = event.steps;
        }
        // 实时步数 = 当前系统步数 - 基准步数
        _totalSteps = (event.steps - _stepCountAtStart).clamp(0, 999999);
        notifyListeners();
      },
      onError: (error) {
        final errStr = error.toString();
        debugPrint('计步器错误: $errStr');
        _lastPedometerError = errStr;
        notifyListeners();
      },
    );
  }

  /// 停止计步器监听
  void _stopPedometer() {
    _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
  }

  Future<void> _uploadPendingPoints() async {
    final api = _apiService;
    final sessionId = _sessionId;
    if (api == null || sessionId == null || _currentTrack.isEmpty) {
      return;
    }

    final startIndex = _lastUploadedIndex;
    if (startIndex >= _currentTrack.length) {
      return;
    }

    final pendingPoints = _currentTrack.sublist(startIndex);

    try {
      debugPrint(
        '[LocationService] 增量上传: session=$sessionId start=$startIndex count=${pendingPoints.length}',
      );
      await api.uploadTrackPoints(
        sessionId: sessionId,
        points: pendingPoints.map((p) => p.toJson()).toList(),
      );
      _lastUploadedIndex = startIndex + pendingPoints.length;
      _uploadStatus = '已同步 $_lastUploadedIndex 个点';
      notifyListeners();
    } catch (e) {
      _uploadStatus = '同步失败: $e';
      debugPrint('[LocationService] 增量上传失败: $e');
      notifyListeners();
    }
  }

  /// 暂停/恢复
  void togglePause() {
    if (_state == RecordingState.recording) {
      _pausedAt = DateTime.now();
      _syncElapsed(_pausedAt);
      _positionSubscription?.cancel();
      _positionSubscription = null;
      _uploadTimer?.cancel();
      _stopPedometer();
      _state = RecordingState.paused;
    } else if (_state == RecordingState.paused) {
      if (_pausedAt != null) {
        _totalPausedDuration += DateTime.now().difference(_pausedAt!);
        _pausedAt = null;
      }
      _state = RecordingState.recording;
      _startPedometer();
      unawaited(_startPositionTracking());
      _startUploadTimer();
    }
    notifyListeners();
  }

  /// 停止并最终上传
  Future<RunResult> stopAndUpload(ApiService api) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _uploadTimer?.cancel();
    _stopPedometer();
    if (_pausedAt != null) {
      _totalPausedDuration += DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
    }
    _syncElapsed();
    _state = RecordingState.idle;

    if (_currentTrack.isEmpty || _sessionId == null || _startTime == null) {
      debugPrint('[LocationService] 停止上传: 无数据');
      notifyListeners();
      throw Exception('没有轨迹数据可上传');
    }

    _apiService = api;
    debugPrint(
      '[LocationService] 停止上传: session=$_sessionId 总点数=${_currentTrack.length}',
    );
    try {
      await _uploadPendingPoints();
      _uploadStatus = '全部上传完成';
      final result = RunResult(
        sessionId: _sessionId!,
        startTime: _startTime!,
        endTime: DateTime.now(),
        totalDistanceKm: _totalDistance,
        totalSteps: _totalSteps,
        pointCount: _currentTrack.length,
      );
      notifyListeners();
      return result;
    } catch (e) {
      _uploadStatus = '上传失败';
      debugPrint('[LocationService] 停止上传失败: $e');
      notifyListeners();
      rethrow;
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
    _positionSubscription?.cancel();
    _uploadTimer?.cancel();
    _stepCountSubscription?.cancel();
    super.dispose();
  }
}
