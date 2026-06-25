import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/run_result.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import 'history_screen.dart';
import 'run_summary_screen.dart';

class TrackingScreen extends StatefulWidget {
  const TrackingScreen({super.key});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  bool _isUploading = false;
  String _permissionMsg = '';
  String _gpsError = '';
  String _lastShownPedometerError = '';

  @override
  void initState() {
    super.initState();
    final locService = context.read<LocationService>();
    final apiService = context.read<ApiService>();
    if (locService.state == RecordingState.idle) {
      _startWithPermission(locService, apiService);
    }
    locService.addListener(_onLocServiceChanged);
  }

  @override
  void dispose() {
    context.read<LocationService>().removeListener(_onLocServiceChanged);
    super.dispose();
  }

  void _onLocServiceChanged() {
    if (!mounted) {
      return;
    }

    final locService = context.read<LocationService>();
    if (locService.lastGpsError != _gpsError) {
      setState(() => _gpsError = locService.lastGpsError);
    }

    if (locService.lastPedometerError.isNotEmpty &&
        locService.lastPedometerError != _lastShownPedometerError) {
      _lastShownPedometerError = locService.lastPedometerError;
      _showErrorDialog('计步器错误', locService.lastPedometerError);
    }
  }

  Future<void> _startWithPermission(
    LocationService locService,
    ApiService api,
  ) async {
    try {
      final result = await locService.startRecording(api);
      if (!mounted) {
        return;
      }

      if (result != 'ok') {
        setState(() => _permissionMsg = result);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _permissionMsg = '启动失败: $e');
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      builder:
          (ctx) => AlertDialog(
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

  Future<void> _finishRun(
    LocationService locService,
    ApiService apiService,
  ) async {
    setState(() => _isUploading = true);
    try {
      final result = await locService.stopAndUpload(apiService);
      if (!mounted) {
        return;
      }

      setState(() => _isUploading = false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => RunSummaryScreen(result: result)),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() => _isUploading = false);
      _showErrorDialog('上传失败', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final locService = context.watch<LocationService>();
    final apiService = context.read<ApiService>();

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
                Text(
                  _permissionMsg,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('跑步中'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (locService.state == RecordingState.idle) {
              Navigator.pop(context);
              return;
            }

            showDialog<void>(
              context: context,
              builder:
                  (ctx) => AlertDialog(
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
                          await _finishRun(locService, apiService);
                        },
                        child: const Text('结束并上传'),
                      ),
                    ],
                  ),
            );
          },
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildStatusCard(locService),
          const SizedBox(height: 16),
          _buildMetricsGrid(locService),
          const SizedBox(height: 16),
          _buildSyncCard(locService),
          const SizedBox(height: 16),
          _buildDebugPanel(locService),
          if (_gpsError.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildWarningCard(_gpsError),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed:
                      locService.state == RecordingState.idle
                          ? null
                          : locService.togglePause,
                  icon: Icon(
                    locService.state == RecordingState.recording
                        ? Icons.pause
                        : Icons.play_arrow,
                  ),
                  label: Text(
                    locService.state == RecordingState.recording ? '暂停' : '继续',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed:
                      _isUploading || locService.state == RecordingState.idle
                          ? null
                          : () => _finishRun(locService, apiService),
                  icon: const Icon(Icons.stop),
                  label: const Text('结束并上传'),
                ),
              ),
            ],
          ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              final text = _buildShareDraft(
                RunResult(
                  sessionId: locService.sessionId ?? 'draft',
                  startTime: DateTime.now().subtract(locService.elapsed),
                  endTime: DateTime.now(),
                  totalDistanceKm: locService.totalDistance,
                  totalSteps: locService.totalSteps,
                  pointCount: locService.currentTrack.length,
                ),
              );
              await Clipboard.setData(ClipboardData(text: text));
              if (!mounted) {
                return;
              }
              messenger.showSnackBar(
                const SnackBar(content: Text('分享文案已复制，后续可直接接入朋友圈分享')),
              );
            },
            icon: const Icon(Icons.ios_share),
            label: const Text('预览分享文案'),
          ),
          const SizedBox(height: 8),
          Text(
            '跑步过程中不再实时绘制地图，轨迹会在后台持续记录，结束后可在结果页和历史记录中查看。',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(LocationService locService) {
    final isRecording = locService.state == RecordingState.recording;
    final color = isRecording ? Colors.teal : Colors.orange;
    final title = isRecording ? '后台记录中' : '记录已暂停';
    final subtitle =
        isRecording ? '已切换为后台定位模式，减少实时 UI 绘制带来的耗电。' : '暂停后将停止定位与上传，继续后恢复后台记录。';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(
                isRecording ? Icons.directions_run : Icons.pause,
                color: color,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricsGrid(LocationService locService) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: [
        _buildMetricCard(
          icon: Icons.route,
          label: '距离',
          value: '${locService.totalDistance.toStringAsFixed(2)} km',
        ),
        _buildMetricCard(
          icon: Icons.timer,
          label: '时间',
          value: _formatDuration(locService.elapsed),
        ),
        _buildMetricCard(
          icon: Icons.speed,
          label: '配速',
          value: locService.pace,
        ),
        _buildMetricCard(
          icon: Icons.directions_walk,
          label: '步数',
          value: '${locService.totalSteps}',
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.teal),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _buildSyncCard(LocationService locService) {
    final hasFailure = locService.uploadStatus.contains('失败');
    return Card(
      child: ListTile(
        leading: Icon(
          hasFailure ? Icons.cloud_off : Icons.cloud_done,
          color: hasFailure ? Colors.red : Colors.green,
        ),
        title: Text(
          locService.uploadStatus.isEmpty ? '等待首次同步' : locService.uploadStatus,
        ),
        subtitle: Text('轨迹点数 ${locService.currentTrack.length}'),
        trailing: IconButton(
          icon: const Icon(Icons.history),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const HistoryScreen()),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDebugPanel(LocationService locService) {
    final lastPosition = locService.lastRawPosition;
    final lastPointAt = locService.lastPointAt;
    final debugEvents = locService.debugEvents;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bug_report, color: Colors.deepPurple),
                const SizedBox(width: 8),
                Text(
                  '运行诊断',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDebugRow('记录状态', locService.debugStateLabel),
            _buildDebugRow('权限检查', '${locService.permissionChecked}'),
            _buildDebugRow('定位权限', locService.debugPermissionLabel),
            _buildDebugRow('定位服务', '${locService.locationServiceEnabled}'),
            _buildDebugRow('后台定位权限', locService.backgroundLocationPermission),
            _buildDebugRow('运动权限', locService.pedometerPermission),
            _buildDebugRow('会话 ID', locService.sessionId ?? '--'),
            _buildDebugRow('轨迹点数', '${locService.currentTrack.length}'),
            _buildDebugRow(
              '已上传点数',
              _extractUploadedCount(locService.uploadStatus),
            ),
            _buildDebugRow('最近采点时间', lastPointAt?.toIso8601String() ?? '--'),
            _buildDebugRow('距离上次采点', _formatSince(lastPointAt)),
            _buildDebugRow(
              '最近原始坐标',
              lastPosition == null
                  ? '--'
                  : '${lastPosition.latitude.toStringAsFixed(6)}, ${lastPosition.longitude.toStringAsFixed(6)}',
            ),
            _buildDebugRow(
              '最近速度',
              lastPosition?.speed == null
                  ? '--'
                  : '${lastPosition!.speed.toStringAsFixed(2)} m/s',
            ),
            _buildDebugRow(
              'GPS 错误',
              locService.lastGpsError.isEmpty ? '--' : locService.lastGpsError,
            ),
            _buildDebugRow(
              '计步器错误',
              locService.lastPedometerError.isEmpty
                  ? '--'
                  : locService.lastPedometerError,
            ),
            const SizedBox(height: 12),
            Text(
              '事件日志',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  debugEvents.isEmpty
                      ? const Text('暂无日志')
                      : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children:
                            debugEvents
                                .take(12)
                                .map(
                                  (event) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      event,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                )
                                .toList(),
                      ),
            ),
            const SizedBox(height: 8),
            Text(
              '当前版本仅用于真机调试，下一版会移除该诊断面板。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDebugRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  String _extractUploadedCount(String uploadStatus) {
    if (uploadStatus.isEmpty) {
      return '--';
    }
    final match = RegExp(r'(\d+)').firstMatch(uploadStatus);
    return match?.group(1) ?? uploadStatus;
  }

  String _formatSince(DateTime? time) {
    if (time == null) {
      return '--';
    }
    return '${DateTime.now().difference(time).inSeconds}s';
  }

  Widget _buildWarningCard(String message) {
    return Card(
      color: Colors.orange.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.gps_off, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  String _buildShareDraft(RunResult result) {
    return '${result.shareTitle}\n${result.shareSubtitle}\n'
        '轨迹已记录完成，后续将支持一键分享到朋友圈。';
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:'
          '${m.toString().padLeft(2, '0')}:'
          '${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
