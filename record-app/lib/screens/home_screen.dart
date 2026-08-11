import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_widgets.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  UserProfile? _profile;
  double _todayCalories = 0;
  List<Map<String, dynamic>> _weightHistory = [];
  bool _loading = true;

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
        0, (s, r) => s + (r['calories'] as num).toDouble(),
      );

      final wh = await api.getWeightHistory();
      final mapped = wh.map((r) => {
        'id': r['id'],
        'weight': (r['weight_kg'] as num).toDouble(),
        'date': r['recorded_at'],
      }).toList();

      await storage.saveProfile(profile);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _todayCalories = calories;
        _weightHistory = mapped;
        _loading = false;
      });
    } catch (e, st) {
      // 网络失败回退到本地缓存，但异常必须上报，不允许吞掉
      ErrorReporter.reportError(
        message: '加载首页数据失败，回退本地缓存',
        source: 'home_screen',
        error: e,
        stackTrace: st,
        url: '/api/profile',
      );
      final profile = await storage.loadProfile();
      final calories = await storage.getTodayCalories();
      final history = await storage.loadWeightHistory();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _todayCalories = calories;
        _weightHistory = history;
        _loading = false;
      });
    }
  }

  Future<void> _deleteWeightRecord(int id) async {
    try {
      await context.read<ApiService>().deleteWeightRecord(id);
      await _loadData();
    } catch (e, st) {
      ErrorReporter.reportError(
        message: '删除体重记录失败',
        source: 'home_screen',
        error: e,
        stackTrace: st,
        url: '/api/weight-history/$id',
        context: {'record_id': id},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  double get _bmi {
    final p = _profile;
    if (p == null) return 0;
    final h = p.heightCm / 100;
    return p.currentWeightKg / (h * h);
  }

  double? get _weightDelta {
    if (_weightHistory.length < 2) return null;
    final list = _weightHistory;
    return (list.last['weight'] as double) - (list[list.length - 2]['weight'] as double);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final p = _profile!;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _loadData,
        color: C.limeDim,
        child: CustomScrollView(
          slivers: [
            _sliverHeader(p),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _scaleCard(p),
                  const SizedBox(height: 16),
                  _calorieSection(p),
                  const SizedBox(height: 16),
                  _statsGrid(p),
                  const SizedBox(height: 16),
                  _weightTrendSection(),
                  const SizedBox(height: 16),
                  _quickActions(),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────

  SliverAppBar _sliverHeader(UserProfile p) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? '早安' : hour < 18 ? '午安' : '晚安';

    return SliverAppBar(
      expandedHeight: 140,
      floating: true,
      snap: true,
      backgroundColor: C.ink,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(color: C.ink),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: C.lime, width: 2),
                        ),
                        child: Center(
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: T.h3.copyWith(color: C.lime),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(greeting, style: T.bodyS.copyWith(color: C.slate)),
                          Text(
                            p.name.isNotEmpty ? p.name : '用户',
                            style: T.h3.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // Streak indicator
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('连续记录', style: T.caption.copyWith(color: C.slate)),
                          Row(
                            children: [
                              const Icon(Icons.local_fire_department, size: 16, color: C.coral),
                              const SizedBox(width: 2),
                              Text(
                                '${p.daysSinceStart}',
                                style: T.numSm.copyWith(color: C.coral),
                              ),
                              Text(' 天', style: T.caption.copyWith(color: C.slate)),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Scale Card (signature element) ─────────────────────

  Widget _scaleCard(UserProfile p) {
    final delta = _weightDelta;

    return AppCard(
      color: C.ink,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('当前体重', style: T.bodyS.copyWith(color: C.slate)),
              const Spacer(),
              if (delta != null)
                Row(
                  children: [
                    Icon(
                      delta < 0 ? Icons.south : Icons.north,
                      size: 16,
                      color: delta < 0 ? C.lime : C.coral,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${delta.abs().toStringAsFixed(1)} kg',
                      style: T.bodyS.copyWith(
                        color: delta < 0 ? C.lime : C.coral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Big scale readout
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                p.currentWeightKg.toStringAsFixed(1),
                style: T.numXl.copyWith(color: Colors.white),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 6),
                child: Text('kg', style: T.bodyM.copyWith(color: C.slate)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Progress bar to target
          _weightProgressBar(p),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('起始 ${p.currentWeightKg.toStringAsFixed(1)}', style: T.caption.copyWith(color: C.slate)),
              const Spacer(),
              Text('目标 ${p.targetWeightKg.toStringAsFixed(1)} kg', style: T.caption.copyWith(color: C.lime)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _weightProgressBar(UserProfile p) {
    final start = p.currentWeightKg;
    final target = p.targetWeightKg;
    final range = (start - target).abs();
    if (range == 0) return const SizedBox.shrink();
    final progress = ((start - p.currentWeightKg) / range).clamp(0.0, 1.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: progress,
        minHeight: 6,
        backgroundColor: C.ink2,
        valueColor: const AlwaysStoppedAnimation(C.lime),
      ),
    );
  }

  // ─── Calorie section ─────────────────────────────────────

  Widget _calorieSection(UserProfile p) {
    final progress = (_todayCalories / p.dailyCalorieGoal).clamp(0.0, 1.0);
    final remaining = p.dailyCalorieGoal - _todayCalories.toInt();
    final over = remaining < 0;

    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            progress: progress,
            size: 90,
            color: over ? C.coral : C.limeDim,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedNumber(
                  value: _todayCalories.toInt(),
                  style: T.numMd.copyWith(fontSize: 20),
                ),
                Text('kcal', style: T.caption),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('今日摄入', style: T.h4),
                const SizedBox(height: 4),
                Text('目标 ${p.dailyCalorieGoal} kcal', style: T.bodyS),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (over ? C.coral : C.limeDim).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    over ? '超出 ${-remaining} kcal' : '剩余 $remaining kcal',
                    style: T.bodyS.copyWith(
                      color: over ? C.coral : C.limeDim,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Stats grid ──────────────────────────────────────────

  Widget _statsGrid(UserProfile p) {
    return Column(
      children: [
        SectionHeader(title: '身体数据'),
        Row(
          children: [
            Expanded(child: StatTile(
              label: 'BMI',
              value: _bmi.toStringAsFixed(1),
              icon: Icons.accessibility_new,
              accent: C.steel,
            )),
            const SizedBox(width: 12),
            Expanded(child: StatTile(
              label: '基础代谢',
              value: '${p.bmr}',
              unit: 'kcal',
              icon: Icons.local_fire_department,
              accent: C.coral,
            )),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: StatTile(
              label: '还需减重',
              value: p.weightToLose.toStringAsFixed(1),
              unit: 'kg',
              icon: Icons.trending_down,
              accent: C.limeDim,
            )),
            const SizedBox(width: 12),
            Expanded(child: StatTile(
              label: '已坚持',
              value: '${p.daysSinceStart}',
              unit: '天',
              icon: Icons.event_available,
              accent: C.steel,
            )),
          ],
        ),
      ],
    );
  }

  // ─── Weight trend ────────────────────────────────────────

  Widget _weightTrendSection() {
    final weights = _weightHistory.map((e) => e['weight'] as double).toList();
    final recent = weights.length > 14 ? weights.sublist(weights.length - 14) : weights;

    return Column(
      children: [
        SectionHeader(
          title: '体重趋势',
          action: _weightHistory.isNotEmpty ? '查看记录' : null,
          onAction: _weightHistory.isNotEmpty ? _showWeightSheet : null,
        ),
        AppCard(
          onTap: _weightHistory.length >= 2 ? _showWeightSheet : null,
          child: recent.length >= 2
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          recent.last.toStringAsFixed(1),
                          style: T.numMd,
                        ),
                        Text(' kg', style: T.bodyS),
                        const Spacer(),
                        Text('近${recent.length}天', style: T.caption),
                      ],
                    ),
                    const SizedBox(height: 12),
                    WeightChart(weights: recent, height: 140),
                  ],
                )
              : SizedBox(
                  height: 120,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.show_chart, size: 40, color: C.slate),
                        const SizedBox(height: 8),
                        Text('记录体重后显示趋势', style: T.bodyS),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  // ─── Quick actions ───────────────────────────────────────

  Widget _quickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: '快捷操作'),
        Row(
          children: [
            Expanded(child: _actionButton('记录体重', Icons.monitor_weight, C.steel, () => _showWeightDialog())),
            const SizedBox(width: 12),
            Expanded(child: _actionButton('更新目标', Icons.flag, C.coral, () => _showTargetDialog())),
          ],
        ),
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Text(label, style: T.label),
          const Spacer(),
          const Icon(Icons.chevron_right, size: 18, color: C.slate),
        ],
      ),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────

  void _showWeightDialog() {
    final ctrl = TextEditingController(text: _profile!.currentWeightKg.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('记录体重', style: T.h3),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '体重 (kg)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final w = double.tryParse(ctrl.text);
              if (w == null) return;
              final api = context.read<ApiService>();
              final storage = context.read<StorageService>();
              final old = _profile!;
              final updated = UserProfile(
                name: old.name,
                currentWeightKg: w,
                targetWeightKg: old.targetWeightKg,
                heightCm: old.heightCm,
                age: old.age,
                gender: old.gender,
                dailyCalorieGoal: old.dailyCalorieGoal,
              );
              try {
                await api.addWeightRecord(w);
                await api.updateProfile(updated.toApiJson());
                await storage.saveProfile(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadData();
              } catch (e, st) {
                ErrorReporter.reportError(
                  message: '保存体重失败',
                  source: 'home_screen',
                  error: e,
                  stackTrace: st,
                  url: '/api/weight-history',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showTargetDialog() {
    final ctrl = TextEditingController(text: _profile!.targetWeightKg.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('设置目标体重', style: T.h3),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '目标体重 (kg)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              final w = double.tryParse(ctrl.text);
              if (w == null) return;
              final api = context.read<ApiService>();
              final storage = context.read<StorageService>();
              final old = _profile!;
              final updated = UserProfile(
                name: old.name,
                currentWeightKg: old.currentWeightKg,
                targetWeightKg: w,
                heightCm: old.heightCm,
                age: old.age,
                gender: old.gender,
                dailyCalorieGoal: old.dailyCalorieGoal,
              );
              try {
                await api.updateProfile(updated.toApiJson());
                await storage.saveProfile(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                await _loadData();
              } catch (e, st) {
                ErrorReporter.reportError(
                  message: '更新目标体重失败',
                  source: 'home_screen',
                  error: e,
                  stackTrace: st,
                  url: '/api/profile',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
                }
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  void _showWeightSheet() {
    final items = [..._weightHistory].reversed.toList();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scroll) {
          return Column(
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: C.line, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text('体重记录', style: T.h3),
                    const Spacer(),
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  itemCount: items.length,
                  itemBuilder: (ctx, i) {
                    final item = items[i];
                    final id = item['id'];
                    final date = item['date'] as String?;
                    final weight = item['weight'] as double;
                    return AppCard(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Text(weight.toStringAsFixed(1), style: T.numMd),
                          Text(' kg', style: T.bodyS),
                          const Spacer(),
                          Text(date?.substring(0, 10) ?? '--', style: T.caption),
                          if (id != null) ...[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(ctx);
                                _deleteWeightRecord(id as int);
                              },
                              child: const Icon(Icons.delete_outline, size: 18, color: C.coral),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
