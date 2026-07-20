import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_widgets.dart';

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
    final api = context.read<ApiService>();
    try {
      final profileJson = await api.getProfile();
      final profile = UserProfile.fromJson(profileJson);

      final today = DateTime.now().toIso8601String().substring(0, 10);
      final dietRecords = await api.getDietRecords(date: today);
      final calories = dietRecords.fold<double>(
        0,
        (sum, r) => sum + (r['calories'] as num).toDouble(),
      );

      final weightHistory = await api.getWeightHistory();
      final mappedHistory =
          weightHistory
              .map(
                (r) => {
                  'id': r['id'],
                  'weight': (r['weight_kg'] as num).toDouble(),
                  'date': r['recorded_at'],
                },
              )
              .toList();

      await storage.saveProfile(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _todayCalories = calories;
        _weightHistory = mappedHistory;
      });
    } catch (_) {
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
  }

  Future<void> _deleteWeightRecord(int id) async {
    try {
      await context.read<ApiService>().deleteWeightRecord(id);
      await _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _profile;
    if (p == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
          ),
          child: const Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
        ),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _loadData,
            child: CustomScrollView(
              slivers: [
                // 自定义AppBar
                SliverAppBar(
                  expandedHeight: 120,
                  floating: true,
                  pinned: true,
                  elevation: 0,
                  backgroundColor: Colors.transparent,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      '减重助手',
                      style: AppTextStyles.heading2.copyWith(
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.black.withOpacity(0.3),
                            offset: const Offset(0, 1),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    background: Container(
                      decoration: const BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                      ),
                    ),
                  ),
                ),
                // 内容区域
                SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      AnimatedListView(
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
                    ]),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _greeting(UserProfile p) {
    final hour = DateTime.now().hour;
    final greeting =
        hour < 12
            ? '早上好'
            : hour < 18
            ? '下午好'
            : '晚上好';
    
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: AppTheme.primaryGradient,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryGreen.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Text(
                p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$greeting, ${p.name.isNotEmpty ? p.name : '用户'}',
                  style: AppTextStyles.heading1,
                ),
                const SizedBox(height: 4),
                Text(
                  '今天是迈向健康目标的第 ${p.daysSinceStart} 天',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _calorieRing(UserProfile p) {
    final progress = (_todayCalories / p.dailyCalorieGoal).clamp(0.0, 1.0);
    final remaining = p.dailyCalorieGoal - _todayCalories.toInt();

    return ProgressCard(
      title: '今日卡路里摄入',
      progress: progress,
      current: _todayCalories.toInt().toString(),
      target: p.dailyCalorieGoal.toString(),
      progressColor: progress > 1.0 ? AppTheme.softRed : AppTheme.primaryGreen,
      centerWidget: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CountUpAnimation(
            targetValue: _todayCalories,
            textStyle: AppTextStyles.heading2.copyWith(
              color: progress > 1.0 ? AppTheme.softRed : AppTheme.primaryGreen,
            ),
          ),
          Text(
            'kcal',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStats(UserProfile p) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: '基础代谢',
                value: '${p.bmr}',
                unit: 'kcal/天',
                icon: Icons.local_fire_department,
                iconColor: AppTheme.warmOrange,
                onTap: () {
                  // 可以添加详细信息页面跳转
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                title: '当前体重',
                value: p.currentWeightKg.toStringAsFixed(1),
                unit: 'kg',
                icon: Icons.monitor_weight,
                iconColor: AppTheme.accentBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatsCard(
                title: '目标体重',
                value: p.targetWeightKg.toStringAsFixed(1),
                unit: 'kg',
                icon: Icons.flag,
                iconColor: AppTheme.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatsCard(
                title: '还需减重',
                value: p.weightToLose.toStringAsFixed(1),
                unit: 'kg',
                icon: Icons.trending_down,
                iconColor: AppTheme.softPurple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _weightTrend() {
    if (_weightHistory.length < 2) {
      return ModernCard(
        onTap: _weightHistory.isEmpty ? null : () => _showWeightHistorySheet(),
        child: SizedBox(
          height: 150,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: AppTheme.textHint,
              ),
              const SizedBox(height: 12),
              Text(
                _weightHistory.isEmpty ? '记录体重后这里将显示趋势图' : '点击查看体重记录',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // 取最近14条数据
    final data = _weightHistory.length > 14
        ? _weightHistory.sublist(_weightHistory.length - 14)
        : _weightHistory;

    return ModernCard(
      onTap: _showWeightHistorySheet,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '体重趋势',
                style: AppTextStyles.subtitle1,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '最近${data.length}天',
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: data.asMap().entries.map((entry) {
                      return FlSpot(entry.key.toDouble(), entry.value['weight'] as double);
                    }).toList(),
                    isCurved: true,
                    gradient: AppTheme.primaryGradient,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        return FlDotCirclePainter(
                          radius: 4,
                          color: AppTheme.primaryGreen,
                          strokeWidth: 2,
                          strokeColor: Colors.white,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.primaryGreen.withOpacity(0.2),
                          AppTheme.primaryGreen.withOpacity(0.05),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showWeightHistorySheet() {
    final items = [..._weightHistory].reversed.toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '体重历史记录',
                    style: AppTextStyles.heading3,
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      '关闭',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppTheme.primaryGreen,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final id = item['id'];
                  final date = item['date'] as String?;
                  final weight = item['weight'] as double;
                  
                  return ModernCard(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.primaryGradient,
                          ),
                          child: Center(
                            child: Text(
                              '${weight.toStringAsFixed(1).split('.')[0]}',
                              style: AppTextStyles.labelSmall.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${weight.toStringAsFixed(1)} kg',
                                style: AppTextStyles.subtitle2,
                              ),
                              Text(
                                date ?? '--',
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (id != null)
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _deleteWeightRecord(id as int);
                            },
                            icon: const Icon(Icons.delete_outline),
                            color: AppTheme.softRed,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}