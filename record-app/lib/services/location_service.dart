import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';
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
  final List<String> _debugEvents = [];
  static const Duration _locationInterval = Duration(seconds: 5);
  static const Duration _locationFallbackThreshold = Duration(seconds: 8);

  RecordingState _state = RecordingState.idle;
  String? _sessionId;
  final List<TrackPoint> _currentTrack = [];
  StreamSubscription<Position>? _positionSubscription;
  Timer? _uploadTimer;
  Timer? _locationFallbackTimer;
  ApiService? _apiService;
  int _lastUploadedIndex = 0;
  bool _isFetchingCurrentPosition = false;

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
  String _pedometerPermission = 'unknown';
  String get pedometerPermission => _pedometerPermission;
  String _backgroundLocationPermission = 'unknown';
  String get backgroundLocationPermission => _backgroundLocationPermission;
  bool _locationServiceEnabled = false;
  bool get locationServiceEnabled => _locationServiceEnabled;
  Position? _lastRawPosition;
  Position? get lastRawPosition => _lastRawPosition;
  DateTime? _lastPointAt;
  DateTime? get lastPointAt => _lastPointAt;
  List<String> get debugEvents => List.unmodifiable(_debugEvents);

  RecordingState get state => _state;
  String? get sessionId => _sessionId;
  List<TrackPoint> get currentTrack => List.unmodifiable(_currentTrack);
  double get totalDistance => _totalDistance;
  int get totalSteps => _totalSteps;
  Duration get elapsed => _elapsed;
  bool get hasPermission => _hasPermission;
  bool get permissionChecked => _permissionChecked;
  String get debugStateLabel => switch (_state) {
    RecordingState.idle => 'idle',
    RecordingState.recording => 'recording',
    RecordingState.paused => 'paused',
  };
  String get debugPermissionLabel => _hasPermission ? 'granted' : 'not_granted';

  void _pushDebugEvent(String message) {
    final ts = DateTime.now().toIso8601String();
    _debugEvents.insert(0, '[$ts] $message');
    if (_debugEvents.length > 40) {
      _debugEvents.removeRange(40, _debugEvents.length);
    }
    debugPrint('[LocationService][debug] $message');
  }

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
    _pushDebugEvent('开始检查定位权限');
    notifyListeners();

    _locationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    _pushDebugEvent('定位服务状态: $_locationServiceEnabled');
    if (!_locationServiceEnabled) {
      _hasPermission = false;
      _pushDebugEvent('定位服务未开启');
      notifyListeners();
      return '请开启手机定位服务';
    }

    LocationPermission permission = await Geolocator.checkPermission();
    _pushDebugEvent('当前位置权限: $permission');
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      _pushDebugEvent('请求后的权限结果: $permission');
      if (permission == LocationPermission.denied) {
        _hasPermission = false;
        _pushDebugEvent('用户拒绝定位权限');
        notifyListeners();
        return '位置权限被拒绝，请在设置中开启';
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _hasPermission = false;
      _pushDebugEvent('定位权限被永久拒绝');
      notifyListeners();
      return '位置权限已被永久拒绝，请在系统设置中开启';
    }

    _hasPermission = true;
    _pushDebugEvent('定位权限检查通过');
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
    _locationFallbackTimer?.cancel();
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
    _lastRawPosition = null;
    _lastPointAt = null;
    _backgroundLocationPermission = 'unknown';
    _debugEvents.clear();
    _pushDebugEvent('开始记录，会话已创建: $_sessionId');
    notifyListeners();

    debugPrint(
      '[LocationService] 开始记录 session=$_sessionId startTime=$_startTime',
    );

    // 启动计步器监听（真实步数）
    try {
      final pedometerOk = await _ensurePedometerPermission();
      if (pedometerOk) {
        _startPedometer();
      }
    } catch (e) {
      debugPrint('[LocationService] 计步器启动失败: $e');
      _lastPedometerError = e.toString();
      _pushDebugEvent('计步器启动失败: $e');
      notifyListeners();
    }

    await _ensureBackgroundLocationPermission();
    await _captureCurrentPositionOnce();
    await _startPositionTracking();
    _startLocationFallbackTimer();
    _startUploadTimer();

    return 'ok';
  }

  LocationSettings _buildLocationSettings() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
        intervalDuration: _locationInterval,
        forceLocationManager: true,
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
        distanceFilter: 3,
        pauseLocationUpdatesAutomatically: false,
        showBackgroundLocationIndicator: false,
      );
    }

    return LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 3,
      timeLimit: const Duration(seconds: 15),
    );
  }

  Future<void> _startPositionTracking() async {
    await _positionSubscription?.cancel();
    _pushDebugEvent('开始订阅后台定位流');
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: _buildLocationSettings(),
    ).listen(
      _handlePosition,
      onError: (Object error) {
        final errStr = error.toString();
        debugPrint('定位失败: $errStr');
        _lastGpsError = 'GPS: $errStr';
        _pushDebugEvent('定位流错误: $errStr');
        _syncElapsed();
        notifyListeners();
      },
    );
  }

  Future<void> _captureCurrentPositionOnce() async {
    if (_isFetchingCurrentPosition) {
      _pushDebugEvent('跳过主动补采: 上一次定位仍在进行');
      return;
    }

    _isFetchingCurrentPosition = true;
    try {
      _pushDebugEvent('开始获取首次定位点');
      final position = await Geolocator.getCurrentPosition(
        locationSettings: _buildLocationSettings(),
      );
      _pushDebugEvent('首次定位成功');
      _appendPosition(position);
    } catch (e) {
      final errStr = e.toString();
      debugPrint('首次定位失败: $errStr');
      _lastGpsError = 'GPS: $errStr';
      _pushDebugEvent('首次定位失败: $errStr');
      _syncElapsed();
      notifyListeners();
    } finally {
      _isFetchingCurrentPosition = false;
    }
  }

  void _appendPosition(Position position) {
    if (_state != RecordingState.recording) {
      return;
    }

    _lastRawPosition = position;
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
    _lastPointAt = point.timestamp;
    _syncElapsed();
    if (_lastGpsError.isNotEmpty) {
      _lastGpsError = '';
    }
    _pushDebugEvent(
      '采集轨迹点成功: count=${_currentTrack.length} lat=${point.latitude.toStringAsFixed(6)} lng=${point.longitude.toStringAsFixed(6)} speed=${point.speed?.toStringAsFixed(2) ?? "--"}',
    );
    notifyListeners();
  }

  void _handlePosition(Position position) {
    _appendPosition(position);
  }

  void _startUploadTimer() {
    _uploadTimer?.cancel();
    _pushDebugEvent('启动上传定时器: 30s');
    _uploadTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _uploadPendingPoints();
    });
  }

  void _startLocationFallbackTimer() {
    _locationFallbackTimer?.cancel();
    _pushDebugEvent('启动定位补采定时器: ${_locationFallbackThreshold.inSeconds}s');
    _locationFallbackTimer = Timer.periodic(_locationInterval, (_) async {
      await _capturePositionIfStale();
    });
  }

  Future<void> _capturePositionIfStale() async {
    if (_state != RecordingState.recording) {
      return;
    }

    final now = DateTime.now();
    final lastPointAt = _lastPointAt;
    final shouldCapture =
        lastPointAt == null ||
        now.difference(lastPointAt) >= _locationFallbackThreshold;

    if (!shouldCapture) {
      return;
    }

    _pushDebugEvent(
      lastPointAt == null
          ? '定位补采触发: 仍未拿到首个轨迹点'
          : '定位补采触发: 已 ${now.difference(lastPointAt).inSeconds}s 无新点',
    );
    await _captureCurrentPositionOnce();
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
        _pushDebugEvent('步数更新: $_totalSteps');
        notifyListeners();
      },
      onError: (error) {
        final errStr = error.toString();
        debugPrint('计步器错误: $errStr');
        _lastPedometerError = errStr;
        _pushDebugEvent('计步器错误: $errStr');
        notifyListeners();
      },
    );
  }

  Future<bool> _ensurePedometerPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final status = await Permission.activityRecognition.request();
      _pedometerPermission = status.name;
      if (status.isGranted) {
        _pushDebugEvent('运动权限: granted');
        return true;
      }
      _lastPedometerError = '运动权限未授权: ${status.name}';
      _pushDebugEvent(_lastPedometerError);
      notifyListeners();
      return false;
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final status = await Permission.sensors.request();
      _pedometerPermission = status.name;
      if (status.isGranted) {
        _pushDebugEvent('运动权限: granted');
        return true;
      }
      _lastPedometerError = '运动权限未授权: ${status.name}';
      _pushDebugEvent(_lastPedometerError);
      notifyListeners();
      return false;
    }

    _pedometerPermission = 'not_supported';
    return true;
  }

  Future<bool> _ensureBackgroundLocationPermission() async {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      _backgroundLocationPermission = 'not_supported';
      return true;
    }

    final status = await Permission.locationAlways.request();
    _backgroundLocationPermission = status.name;
    if (status.isGranted) {
      _pushDebugEvent('后台定位权限: granted');
      notifyListeners();
      return true;
    }

    _pushDebugEvent('后台定位权限未授权: ${status.name}');
    notifyListeners();
    return false;
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
      _pushDebugEvent('跳过上传: 没有新增轨迹点');
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
      _pushDebugEvent(
        '上传成功: 本次=${pendingPoints.length} 总计=$_lastUploadedIndex',
      );
      notifyListeners();
    } catch (e) {
      _uploadStatus = '同步失败: $e';
      debugPrint('[LocationService] 增量上传失败: $e');
      _pushDebugEvent('上传失败: $e');
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
      _locationFallbackTimer?.cancel();
      _stopPedometer();
      _state = RecordingState.paused;
      _pushDebugEvent('记录已暂停');
    } else if (_state == RecordingState.paused) {
      if (_pausedAt != null) {
        _totalPausedDuration += DateTime.now().difference(_pausedAt!);
        _pausedAt = null;
      }
      _state = RecordingState.recording;
      _startPedometer();
      unawaited(_startPositionTracking());
      _startLocationFallbackTimer();
      _startUploadTimer();
      _pushDebugEvent('记录已恢复');
    }
    notifyListeners();
  }

  /// 停止并最终上传
  Future<RunResult> stopAndUpload(ApiService api) async {
    await _positionSubscription?.cancel();
    _positionSubscription = null;
    _uploadTimer?.cancel();
    _locationFallbackTimer?.cancel();
    _stopPedometer();
    if (_pausedAt != null) {
      _totalPausedDuration += DateTime.now().difference(_pausedAt!);
      _pausedAt = null;
    }
    _syncElapsed();
    _state = RecordingState.idle;
    _pushDebugEvent('开始结束流程，准备停止上传');

    if (_currentTrack.isEmpty) {
      _state = RecordingState.recording;
      _pushDebugEvent('结束前没有轨迹点，尝试补采一个定位点');
      await _captureCurrentPositionOnce();
      _state = RecordingState.idle;
    }

    if (_currentTrack.isEmpty || _sessionId == null || _startTime == null) {
      debugPrint('[LocationService] 停止上传: 无数据');
      _pushDebugEvent('结束失败: 没有轨迹数据可上传');
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
      _pushDebugEvent('结束上传完成');
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
      _pushDebugEvent('结束上传失败: $e');
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
    _locationFallbackTimer?.cancel();
    _stepCountSubscription?.cancel();
    super.dispose();
  }
}
