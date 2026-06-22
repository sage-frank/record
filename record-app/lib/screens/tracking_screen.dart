import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/location_service.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final _mapController = MapController();
  bool _isUploading = false;
  String _permissionMsg = '';
  String _gpsError = '';

  @override
  void initState() {
    super.initState();
    final locService = context.read<LocationService>();
    final apiService = context.read<ApiService>();
    if (locService.state == RecordingState.idle) {
      _startWithPermission(locService, apiService);
    }
    // 监听 GPS 错误
    locService.addListener(_onLocServiceChanged);
  }

  @override
  void dispose() {
    context.read<LocationService>().removeListener(_onLocServiceChanged);
    super.dispose();
  }

  void _onLocServiceChanged() {
    if (!mounted) return;
    final locService = context.read<LocationService>();
    if (locService.lastGpsError != _gpsError) {
      setState(() => _gpsError = locService.lastGpsError);
    }
    if (locService.lastPedometerError.isNotEmpty && mounted) {
      _showErrorDialog('计步器错误', locService.lastPedometerError);
    }
  }

  Future<void> _startWithPermission(
      LocationService locService, ApiService api) async {
    try {
      final result = await locService.startRecording(api);
      if (!mounted) return;
      if (result != 'ok') {
        setState(() => _permissionMsg = result);
        // 权限失败后延迟返回
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _permissionMsg = '启动失败: $e');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) Navigator.pop(context);
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(fontSize: 14)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showUploadResult(bool success, [String? errorMsg]) {
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('上传成功！'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.pop(context);
    } else {
      _showErrorDialog('上传失败', errorMsg ?? '未知错误');
    }
  }

  @override
  Widget build(BuildContext context) {
    final locService = context.watch<LocationService>();
    final apiService = context.read<ApiService>();
    final track = locService.currentTrack;

    // 权限检查中或失败
    if (!locService.permissionChecked || _permissionMsg.isNotEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('跑步中')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!locService.permissionChecked)
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在获取位置权限...'),
                  ],
                )
              else ...[
                const Icon(Icons.location_off, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(_permissionMsg,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // 计算地图中心点
    LatLng mapCenter;
    double mapZoom;
    if (track.isNotEmpty) {
      final avgLat =
          track.map((p) => p.latitude).reduce((a, b) => a + b) / track.length;
      final avgLng =
          track.map((p) => p.longitude).reduce((a, b) => a + b) / track.length;
      mapCenter = LatLng(avgLat, avgLng);
      mapZoom = 16;
    } else {
      mapCenter = const LatLng(39.9042, 116.4074);
      mapZoom = 14;
    }

    // 地图跟随最新位置
    if (track.isNotEmpty) {
      final last = track.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mapController.move(LatLng(last.latitude, last.longitude), mapZoom);
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('跑步中'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (locService.state == RecordingState.idle) {
              Navigator.pop(context);
            } else {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('结束运动？'),
                  content: const Text('确定要结束当前运动记录吗？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('取消'),
                    ),
                    FilledButton(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        setState(() => _isUploading = true);
                        try {
                          debugPrint('[TrackingScreen] 点击 结束并上传');
                          final success =
                              await locService.stopAndUpload(apiService);
                          setState(() => _isUploading = false);
                          _showUploadResult(success);
                        } catch (e) {
                          debugPrint('[TrackingScreen] 结束并上传 异常: $e');
                          setState(() => _isUploading = false);
                          _showUploadResult(false, e.toString());
                        }
                      },
                      child: const Text('结束并上传'),
                    ),
                  ],
                ),
              );
            }
          },
        ),
        actions: [
          if (locService.state == RecordingState.idle)
            IconButton(
              icon: const Icon(Icons.upload),
              onPressed: _isUploading
                  ? null
                  : () async {
                      setState(() => _isUploading = true);
                      try {
                        debugPrint('[TrackingScreen] 点击上传按钮');
                        final success =
                            await locService.stopAndUpload(apiService);
                        setState(() => _isUploading = false);
                        _showUploadResult(success);
                      } catch (e) {
                        debugPrint('[TrackingScreen] 上传按钮 异常: $e');
                        setState(() => _isUploading = false);
                        _showUploadResult(false, e.toString());
                      }
                    },
            ),
        ],
      ),
      body: Column(
        children: [
          // 地图区域
          Expanded(
            flex: 3,
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: mapCenter,
                initialZoom: mapZoom,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
                  subdomains: const ['1', '2', '3', '4'],
                  userAgentPackageName: 'com.record.app',
                ),
                if (track.length >= 2)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: track
                            .map((p) => LatLng(p.latitude, p.longitude))
                            .toList(),
                        color: Colors.teal,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                if (track.isNotEmpty)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: LatLng(
                          track.first.latitude,
                          track.first.longitude,
                        ),
                        width: 30,
                        height: 30,
                        child: const Icon(Icons.place,
                            color: Colors.green, size: 30),
                      ),
                      Marker(
                        point: LatLng(
                          track.last.latitude,
                          track.last.longitude,
                        ),
                        width: 30,
                        height: 30,
                        child: const Icon(Icons.place,
                            color: Colors.red, size: 30),
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // 底部控制栏
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 数据指标
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMetric(
                      icon: Icons.route,
                      label: '距离 (km)',
                      value: locService.totalDistance.toStringAsFixed(2),
                    ),
                    _buildMetric(
                      icon: Icons.timer,
                      label: '时间',
                      value: _formatDuration(locService.elapsed),
                    ),
                    _buildMetric(
                      icon: Icons.speed,
                      label: '配速',
                      value: locService.pace,
                    ),
                    _buildMetric(
                      icon: Icons.directions_walk,
                      label: '步数',
                      value: '${locService.totalSteps}',
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // GPS 错误提示
                if (_gpsError.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.gps_off, size: 14, color: Colors.orange),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            _gpsError,
                            style: const TextStyle(fontSize: 12, color: Colors.orange),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                // 上传状态
                if (locService.uploadStatus.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          locService.uploadStatus.contains('失败')
                              ? Icons.cloud_off
                              : Icons.cloud_done,
                          size: 14,
                          color: locService.uploadStatus.contains('失败')
                              ? Colors.red
                              : Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            locService.uploadStatus,
                            style: TextStyle(
                              fontSize: 12,
                              color: locService.uploadStatus.contains('失败')
                                  ? Colors.red
                                  : Colors.green,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                // 控制按钮
                if (locService.state != RecordingState.idle)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildControlButton(
                        icon: locService.state == RecordingState.recording
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.orange,
                        onPressed: locService.togglePause,
                      ),
                      const SizedBox(width: 32),
                      _buildControlButton(
                        icon: Icons.stop,
                        color: Colors.red,
                        onPressed: () async {
                          setState(() => _isUploading = true);
                          try {
                            debugPrint('[TrackingScreen] 点击停止按钮');
                            final success =
                                await locService.stopAndUpload(apiService);
                            setState(() => _isUploading = false);
                            _showUploadResult(success);
                          } catch (e) {
                            debugPrint('[TrackingScreen] 停止按钮 异常: $e');
                            setState(() => _isUploading = false);
                            _showUploadResult(false, e.toString());
                          }
                        },
                      ),
                    ],
                  ),

                if (_isUploading)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: LinearProgressIndicator(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
