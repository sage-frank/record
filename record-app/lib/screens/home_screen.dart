import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/storage_service.dart';
import '../models/user_profile.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  double _todayCalories = 0;
  List<Map<String, dynamic>> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final storage = context.read<StorageService>();
    final profile = await storage.loadProfile();
    final calories = await storage.getTodayCalories();
    final history = await storage.loadWeightHistory();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _todayCalories = calories;
      _weightHistory = history;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    if (p == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(
        title: const Text('减重助手'),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 问候语
            _greeting(p),
            const SizedBox(height: 16),
            // 今日卡路里环
            _calorieRing(p),
            const SizedBox(height: 16),
            // 快捷指标
            _quickStats(p),
            const SizedBox(height: 16),
            // 体重趋势
            _weightTrend(),
          ],
        ),
      ),
    );
  }

  Widget _greeting(UserProfile p) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? '早上好' : hour < 18 ? '下午好' : '晚上好';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting${p.name.isNotEmpty ? "，${p.name}" : ""}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '目标体重 ${p.targetWeightKg.toStringAsFixed(1)} kg · '
                    '还需减 ${p.weightToLose.toStringAsFixed(1)} kg',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _calorieRing(UserProfile p) {
    final progress = (_todayCalories / p.dailyCalorieGoal).clamp(0.0, 1.0);
    final remaining = p.dailyCalorieGoal - _todayCalories.toInt();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 80,
                    height: 80,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 8,
                      backgroundColor: Colors.grey[200],
                      valueColor: AlwaysStoppedAnimation(
                        progress > 1.0
                            ? Colors.redAccent
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${_todayCalories.toInt()}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'kcal',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '今日摄入',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '目标 ${p.dailyCalorieGoal} kcal',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                  Text(
                    remaining > 0
                        ? '还可摄入 $remaining kcal'
                        : '已超出 ${-remaining} kcal',
                    style: TextStyle(
                      fontSize: 13,
                      color: remaining > 0 ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickStats(UserProfile p) {
    return Row(
      children: [
        Expanded(
          child: _statCard('基础代谢', '${p.bmr}', 'kcal/天', Icons.local_fire_department),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            '当前体重',
            p.currentWeightKg.toStringAsFixed(1),
            'kg',
            Icons.monitor_weight,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _statCard(
            '目标',
            p.targetWeightKg.toStringAsFixed(1),
            'kg',
            Icons.flag,
          ),
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, String unit, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(unit, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _weightTrend() {
    if (_weightHistory.length < 2) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Icon(Icons.show_chart, size: 40, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                '记录体重后这里将显示趋势图',
                style: TextStyle(color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    // 取最近 14 条
    final data = _weightHistory.length > 14
        ? _weightHistory.sublist(_weightHistory.length - 14)
        : _weightHistory;
    final minWeight = data.map((e) => e['weight'] as double).reduce(
          (a, b) => a < b ? a : b,
        );
    final maxWeight = data.map((e) => e['weight'] as double).reduce(
          (a, b) => a > b ? a : b,
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '体重趋势',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: const Size(double.infinity, 140),
                painter: _WeightChartPainter(
                  data: data,
                  minWeight: minWeight - 1,
                  maxWeight: maxWeight + 1,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${maxWeight.toStringAsFixed(1)} kg',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
                Text(
                  '${minWeight.toStringAsFixed(1)} kg',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minWeight;
  final double maxWeight;
  final Color color;

  _WeightChartPainter({
    required this.data,
    required this.minWeight,
    required this.maxWeight,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();

    final range = maxWeight - minWeight;
    if (range == 0) return;

    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final weight = data[i]['weight'] as double;
      final y = size.height - ((weight - minWeight) / range) * size.height;

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots
    final dotPaint = Paint()..color = color;
    for (int i = 0; i < data.length; i++) {
      final x = size.width * i / (data.length - 1);
      final weight = data[i]['weight'] as double;
      final y = size.height - ((weight - minWeight) / range) * size.height;
      canvas.drawCircle(Offset(x, y), 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightChartPainter old) =>
      old.data != data || old.color != color;
}
