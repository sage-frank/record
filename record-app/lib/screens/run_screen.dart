import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/exercise_plan.dart';
import 'tracking_screen.dart';
import 'history_screen.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<ExercisePlan> _plans = [];
  List<Map<String, dynamic>> _sessions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final storage = context.read<StorageService>();
    final api = context.read<ApiService>();
    try {
      final planJsonList = await api.getPlans();
      final plans = planJsonList.map(ExercisePlan.fromJson).toList();
      final sessions = await api.getSessions();
      await storage.savePlans(plans);
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _sessions = sessions;
        _loading = false;
      });
    } catch (_) {
      final plans = await storage.loadPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        _sessions = [];
        _loading = false;
      });
    }
  }

  Future<void> _deleteSession(String sessionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('确认删除'),
            content: const Text('确定要删除这条跑步记录吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('删除'),
              ),
            ],
          ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    final api = context.read<ApiService>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await api.deleteSession(sessionId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Future<void> _togglePlanActive(ExercisePlan plan, bool active) async {
    final api = context.read<ApiService>();
    final storage = context.read<StorageService>();
    final messenger = ScaffoldMessenger.of(context);
    final updated = ExercisePlan(
      id: plan.id,
      name: plan.name,
      description: plan.description,
      targetDurationMin: plan.targetDurationMin,
      targetDistanceKm: plan.targetDistanceKm,
      targetCalories: plan.targetCalories,
      weekdays: plan.weekdays,
      isActive: active,
      createdAt: plan.createdAt,
    );
    try {
      await api.updatePlan(plan.id, updated.toApiJson());
      await storage.savePlans(
        _plans.map((p) => p.id == plan.id ? updated : p).toList(),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text('更新失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('跑步'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [Tab(text: '跑步计划'), Tab(text: '历史记录')],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_buildPlansTab(), _buildHistoryTab()],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TrackingScreen()),
          );
          _load();
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始跑步'),
      ),
    );
  }

  // ─── 跑步计划 Tab ─────────────────────────────

  Widget _buildPlansTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return _plans.isEmpty
        ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_month, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('暂无跑步计划', style: TextStyle(color: Colors.grey[500])),
              const SizedBox(height: 20),
              FilledButton.tonal(
                onPressed: () => _showPlanDialog(),
                child: const Text('创建计划'),
              ),
            ],
          ),
        )
        : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _plans.length,
          itemBuilder: (context, index) {
            final plan = _plans[index];
            final today = DateTime.now().weekday; // 1=Mon
            final isToday = plan.weekdays.contains(today);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          plan.isActive
                              ? Icons.directions_run
                              : Icons.pause_circle,
                          color:
                              plan.isActive && isToday
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            plan.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: plan.isActive,
                          onChanged: (v) => _togglePlanActive(plan, v),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: () async {
                            final api = context.read<ApiService>();
                            final storage = context.read<StorageService>();
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              await api.deletePlan(plan.id);
                              await storage.savePlans(
                                _plans.where((p) => p.id != plan.id).toList(),
                              );
                              _load();
                            } catch (e) {
                              if (!mounted) return;
                              messenger.showSnackBar(
                                SnackBar(content: Text('删除失败: $e')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    if (plan.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        plan.description,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _planChip(
                          '${plan.targetDistanceKm} km',
                          Icons.straighten,
                        ),
                        const SizedBox(width: 8),
                        _planChip('${plan.targetDurationMin} 分钟', Icons.timer),
                        const SizedBox(width: 8),
                        _planChip(
                          '${plan.targetCalories} kcal',
                          Icons.local_fire_department,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          plan.weekdayLabel,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                        const Spacer(),
                        if (isToday && plan.isActive)
                          Chip(
                            label: const Text(
                              '今天',
                              style: TextStyle(fontSize: 11),
                            ),
                            backgroundColor:
                                Theme.of(context).colorScheme.primaryContainer,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
  }

  Widget _planChip(String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        ],
      ),
    );
  }

  // ─── 历史记录 Tab ─────────────────────────────

  Widget _buildHistoryTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return _sessions.isEmpty
        ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.history, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text('暂无跑步记录', style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        )
        : RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _sessions.length,
            itemBuilder: (context, index) {
              final session = _sessions[index];
              return Dismissible(
                key: Key(session['session_id'] as String),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.red[400],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed:
                    (_) => _deleteSession(session['session_id'] as String),
                confirmDismiss: (_) async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (ctx) => AlertDialog(
                          title: const Text('确认删除'),
                          content: const Text('确定要删除这条跑步记录吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                  );
                  return confirmed ?? false;
                },
                child: _buildHistoryCard(session),
              );
            },
          ),
        );
  }

  Widget _buildHistoryCard(Map<String, dynamic> session) {
    final startTime = session['start_time'] as String;
    final pointCount = session['point_count'] as int;
    final steps = session['total_steps'] as int? ?? 0;
    final distance = session['total_distance_km'] as num?;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (_) => SessionDetailScreen(
                    sessionId: session['session_id'] as String,
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.directions_run,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatDate(startTime),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$pointCount 轨迹点 · $steps 步'
                      '${distance != null ? " · ${distance.toStringAsFixed(2)} km" : ""}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 13),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return DateFormat('MM-dd HH:mm').format(dt);
    } catch (_) {
      return iso;
    }
  }

  void _showPlanDialog() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final distCtrl = TextEditingController(text: '5');
    final durCtrl = TextEditingController(text: '30');
    final calCtrl = TextEditingController(text: '300');
    final selectedDays = <int>[1, 3, 5]; // Mon, Wed, Fri

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheetState) => Padding(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    20,
                    20,
                    MediaQuery.of(ctx).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '创建跑步计划',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          labelText: '计划名称',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descCtrl,
                        decoration: const InputDecoration(
                          labelText: '描述（可选）',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: distCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '目标距离 (km)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: durCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: '时长 (分钟)',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: calCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '目标卡路里',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '选择日期',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        children: [
                          for (final d in [1, 2, 3, 4, 5, 6, 7])
                            FilterChip(
                              label: Text(
                                ['一', '二', '三', '四', '五', '六', '日'][d - 1],
                              ),
                              selected: selectedDays.contains(d),
                              onSelected:
                                  (v) => setSheetState(() {
                                    v
                                        ? selectedDays.add(d)
                                        : selectedDays.remove(d);
                                  }),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed:
                              selectedDays.isEmpty
                                  ? null
                                  : () async {
                                    final api = context.read<ApiService>();
                                    final storage =
                                        context.read<StorageService>();
                                    final messenger = ScaffoldMessenger.of(
                                      context,
                                    );
                                    final plan = ExercisePlan(
                                      id: const Uuid().v4(),
                                      name:
                                          nameCtrl.text.trim().isEmpty
                                              ? '跑步计划'
                                              : nameCtrl.text.trim(),
                                      description: descCtrl.text.trim(),
                                      targetDistanceKm:
                                          double.tryParse(distCtrl.text) ?? 5,
                                      targetDurationMin:
                                          int.tryParse(durCtrl.text) ?? 30,
                                      targetCalories:
                                          int.tryParse(calCtrl.text) ?? 300,
                                      weekdays: selectedDays..sort(),
                                    );
                                    try {
                                      await api.addPlan(plan.toApiJson());
                                      _plans.insert(0, plan);
                                      await storage.savePlans(_plans);
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      _load();
                                    } catch (e) {
                                      if (!mounted) return;
                                      messenger.showSnackBar(
                                        SnackBar(content: Text('保存失败: $e')),
                                      );
                                    }
                                  },
                          child: const Text('保存'),
                        ),
                      ),
                    ],
                  ),
                ),
          ),
    );
  }
}
