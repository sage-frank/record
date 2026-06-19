import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<ApiService>();
      final sessions = await api.getSessions();
      setState(() {
        _sessions = sessions;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.cloud_off, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('加载失败', style: TextStyle(color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      FilledButton.tonal(
                        onPressed: _loadSessions,
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                )
              : _sessions.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 48, color: Colors.grey[400]),
                          const SizedBox(height: 16),
                          Text('暂无运动记录', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (context, index) {
                          final session = _sessions[index];
                          return _buildSessionCard(session);
                        },
                      ),
                    ),
    );
  }

  Widget _buildSessionCard(Map<String, dynamic> session) {
    final sessionId = session['session_id'] as String;
    final startTime = session['start_time'] as String;
    final endTime = session['end_time'] as String;
    final pointCount = session['point_count'] as int;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SessionDetailScreen(
                sessionId: sessionId,
                startTime: startTime,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.directions_run,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDateTime(startTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pointCount 个轨迹点',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDateTime(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

/// 会话详情 - 展示轨迹地图
class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final String startTime;

  const SessionDetailScreen({
    super.key,
    required this.sessionId,
    required this.startTime,
  });

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  List<Map<String, dynamic>> _points = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    try {
      final api = context.read<ApiService>();
      final data = await api.getSessionTrackPoints(widget.sessionId);
      setState(() {
        _points = List<Map<String, dynamic>>.from(data['points']);
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('轨迹详情'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _points.isEmpty
              ? const Center(child: Text('暂无轨迹数据'))
              : Column(
                  children: [
                    Expanded(
                      child: _buildMap(),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildInfoChip('轨迹点数', '${_points.length}'),
                          _buildInfoChip('会话ID',
                              widget.sessionId.substring(0, 8)),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildMap() {
    final positions = _points
        .map((p) => LatLng(
              (p['latitude'] as num).toDouble(),
              (p['longitude'] as num).toDouble(),
            ))
        .toList();

    if (positions.isEmpty) return const SizedBox();

    final avgLat =
        positions.map((p) => p.latitude).reduce((a, b) => a + b) /
            positions.length;
    final avgLng =
        positions.map((p) => p.longitude).reduce((a, b) => a + b) /
            positions.length;

    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(avgLat, avgLng),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.record.app',
        ),
        if (positions.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(
                points: positions,
                color: Colors.teal,
                strokeWidth: 4,
              ),
            ],
          ),
        if (positions.isNotEmpty)
          MarkerLayer(
            markers: [
              Marker(
                point: positions.first,
                width: 30,
                height: 30,
                child:
                    const Icon(Icons.place, color: Colors.green, size: 30),
              ),
              Marker(
                point: positions.last,
                width: 30,
                height: 30,
                child: const Icon(Icons.place, color: Colors.red, size: 30),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
