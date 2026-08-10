import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';

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
    setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<ApiService>();
      final sessions = await api.getSessions();
      setState(() { _sessions = sessions; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('历史记录', style: T.h3)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(icon: Icons.cloud_off, title: '加载失败', hint: _error, actionLabel: '重试', onAction: _loadSessions)
              : _sessions.isEmpty
                  ? const EmptyState(icon: Icons.history, title: '暂无运动记录')
                  : RefreshIndicator(
                      onRefresh: _loadSessions,
                      color: C.limeDim,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _sessions.length,
                        itemBuilder: (ctx, i) => _sessionCard(_sessions[i]),
                      ),
                    ),
    );
  }

  Widget _sessionCard(Map<String, dynamic> session) {
    final sessionId = session['session_id'] as String;
    final startTime = session['start_time'] as String;
    final pointCount = session['point_count'] as int;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => SessionDetailScreen(sessionId: sessionId, startTime: startTime),
      )),
      child: Row(
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: C.steel.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.directions_run, color: C.steel),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_fmt(startTime), style: T.h4),
                const SizedBox(height: 2),
                Text('$pointCount 个轨迹点', style: T.bodyS),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: C.slate),
        ],
      ),
    );
  }

  String _fmt(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) { return iso; }
  }
}

/// 会话详情 - 展示轨迹地图
class SessionDetailScreen extends StatefulWidget {
  final String sessionId;
  final String startTime;

  const SessionDetailScreen({super.key, required this.sessionId, required this.startTime});

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
      setState(() { _points = List<Map<String, dynamic>>.from(data['points']); _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('轨迹详情', style: T.h3)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _points.isEmpty
              ? const EmptyState(icon: Icons.map, title: '暂无轨迹数据')
              : Column(
                  children: [
                    Expanded(child: _map()),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _chip('轨迹点数', '${_points.length}'),
                          _chip('会话', widget.sessionId.substring(0, 8)),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _map() {
    final positions = _points.map((p) => LatLng(
      (p['latitude'] as num).toDouble(),
      (p['longitude'] as num).toDouble(),
    )).toList();

    if (positions.isEmpty) return const SizedBox();

    final avgLat = positions.map((p) => p.latitude).reduce((a, b) => a + b) / positions.length;
    final avgLng = positions.map((p) => p.longitude).reduce((a, b) => a + b) / positions.length;

    return FlutterMap(
      options: MapOptions(initialCenter: LatLng(avgLat, avgLng), initialZoom: 14),
      children: [
        TileLayer(
          urlTemplate: 'https://webrd0{s}.is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x={x}&y={y}&z={z}',
          subdomains: const ['1', '2', '3', '4'],
          userAgentPackageName: 'com.record.app',
        ),
        if (positions.length >= 2)
          PolylineLayer(polylines: [Polyline(points: positions, color: C.steel, strokeWidth: 4)]),
        if (positions.isNotEmpty)
          MarkerLayer(markers: [
            Marker(point: positions.first, width: 30, height: 30, child: const Icon(Icons.place, color: C.limeDim, size: 30)),
            Marker(point: positions.last, width: 30, height: 30, child: const Icon(Icons.place, color: C.coral, size: 30)),
          ]),
      ],
    );
  }

  Widget _chip(String label, String value) {
    return Column(
      children: [
        Text(value, style: T.numMd),
        Text(label, style: T.caption),
      ],
    );
  }
}
