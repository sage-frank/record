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

  @override
  void initState() {
    super.initState();
    final locService = context.read<LocationService>();
    if (locService.state == RecordingState.idle) {
      locService.startRecording();
    }
  }

  void _showUploadResult(bool success) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '上传成功！' : '上传失败，请稍后重试'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    if (success) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final locService = context.watch<LocationService>();
    final apiService = context.read<ApiService>();
    final track = locService.currentTrack;

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
      mapCenter = const LatLng(39.9042, 116.4074); // 默认北京
      mapZoom = 12;
    }

    // 地图中心变化时自动跟随
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
                        final success =
                            await locService.stopAndUpload(apiService);
                        setState(() => _isUploading = false);
                        _showUploadResult(success);
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
                      final success =
                          await locService.stopAndUpload(apiService);
                      setState(() => _isUploading = false);
                      _showUploadResult(success);
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
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.record.app',
                ),
                // 轨迹线
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
                // 起点标记
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
                      context,
                      icon: Icons.route,
                      label: '距离 (km)',
                      value: locService.totalDistance.toStringAsFixed(2),
                    ),
                    _buildMetric(
                      context,
                      icon: Icons.timer,
                      label: '时间',
                      value: _formatDuration(locService.elapsed),
                    ),
                    _buildMetric(
                      context,
                      icon: Icons.speed,
                      label: '配速',
                      value: locService.pace,
                    ),
                    _buildMetric(
                      context,
                      icon: Icons.gps_fixed,
                      label: '点数',
                      value: '${track.length}',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 控制按钮
                if (locService.state != RecordingState.idle)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // 暂停/继续
                      _buildControlButton(
                        icon: locService.state == RecordingState.recording
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.orange,
                        onPressed: locService.togglePause,
                      ),
                      const SizedBox(width: 32),
                      // 结束
                      _buildControlButton(
                        icon: Icons.stop,
                        color: Colors.red,
                        onPressed: () async {
                          setState(() => _isUploading = true);
                          final success =
                              await locService.stopAndUpload(apiService);
                          setState(() => _isUploading = false);
                          _showUploadResult(success);
                        },
                      ),
                    ],
                  ),

                // 上传中
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

  Widget _buildMetric(BuildContext context,
      {required IconData icon,
      required String label,
      required String value}) {
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

  Widget _buildControlButton(
      {required IconData icon,
      required Color color,
      required VoidCallback onPressed}) {
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
