import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/exercise_plan.dart';
import '../theme/app_theme.dart';
import '../widgets/app_widgets.dart';
import 'tracking_screen.dart';
import 'history_screen.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> with SingleTickerProviderStateMixin {
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
      setState(() { _plans = plans; _sessions = sessions; _loading = false; });
    } catch (_) {
      final plans = await storage.loadPlans();
      if (!mounted) return;
      setState(() { _plans = plans; _sessions = []; _loading = false; });
    }
  }

  // Stats
  int get _totalRuns => _sessions.length;
  double get _totalDistance => _sessions.fold(0.0, (s, r) => s + ((r['total_distance_km'] as num?)?.toDouble() ?? 0));
  int get _totalSteps => _sessions.fold(0, (s, r) => s + ((r['total_steps'] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Dark header
          Container(
            decoration: const BoxDecoration(color: C.ink),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Row(
                      children: [
                        Text('跑步', style: T.h2.copyWith(color: Colors.white)),
                        const Spacer(),
                        if (!_loading && _totalRuns > 0)
                          Text('累计 $_totalRuns 次', style: T.bodyS.copyWith(color: C.slate)),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabCtrl,
                    indicatorColor: C.lime,
                    labelColor: C.lime,
                    unselectedLabelColor: C.slate,
                    labelStyle: T.label,
                    tabs: const [Tab(text: '今日计划'), Tab(text: '跑步历史')],
                    dividerColor: Colors.transparent,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_plansTab(), _historyTab()],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingScreen()));
          _load();
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('开始跑步'),
        backgroundColor: C.ink,
        foregroundColor: C.lime,
      ),
    );
  }

  // ─── Plans tab ───────────────────────────────────────────

  Widget _plansTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return _plans.isEmpty
        ? EmptyState(
            icon: Icons.calendar_month,
            title: '暂无跑步计划',
            hint: '创建一个计划来安排你的跑步日程',
            actionLabel: '创建计划',
            onAction: _showPlanSheet,
          )
        : AnimationLimiter(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _plans.length + 1,
              itemBuilder: (ctx, i) {
                if (i == 0) return _runSummaryCard();
                final plan = _plans[i - 1];
                return AnimationConfiguration.staggeredList(
                  position: i,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 30,
                    child: FadeInAnimation(child: _planCard(plan)),
                  ),
                );
              },
            ),
          );
  }

  Widget _runSummaryCard() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AppCard(
        color: C.ink,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('累计数据', style: T.bodyS.copyWith(color: C.slate)),
            const SizedBox(height: 12),
            Row(
              children: [
                _summaryItem('总次数', '$_totalRuns', '次', C.lime),
                _summaryItem('总距离', _totalDistance.toStringAsFixed(1), 'km', C.steel),
                _summaryItem('总步数', '$_totalSteps', '步', C.coral),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, String unit, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: T.numMd.copyWith(color: color)),
          Text('$label · $unit', style: T.caption.copyWith(color: C.slate)),
        ],
      ),
    );
  }

  Widget _planCard(ExercisePlan plan) {
    final today = DateTime.now().weekday;
    final isToday = plan.weekdays.contains(today);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: isToday && plan.isActive
            ? () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const TrackingScreen()));
                _load();
              }
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(plan.name, style: T.h4),
                ),
                Switch(
                  value: plan.isActive,
                  onChanged: (v) => _togglePlan(plan, v),
                  activeTrackColor: C.lime.withOpacity(0.3),
                  activeColor: C.limeDim,
                ),
              ],
            ),
            if (plan.description.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(plan.description, style: T.bodyS),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                TagChip('${plan.targetDistanceKm} km', icon: Icons.straighten, color: C.steel),
                const SizedBox(width: 8),
                TagChip('${plan.targetDurationMin} 分钟', icon: Icons.timer, color: C.coral),
                const SizedBox(width: 8),
                TagChip('${plan.targetCalories} kcal', icon: Icons.local_fire_department, color: C.limeDim),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(plan.weekdayLabel, style: T.caption),
                const Spacer(),
                if (isToday && plan.isActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: C.lime.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow, size: 14, color: C.limeDim),
                        const SizedBox(width: 2),
                        Text('今天 · 点击开始', style: T.caption.copyWith(color: C.limeDim, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── History tab ─────────────────────────────────────────

  Widget _historyTab() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    return _sessions.isEmpty
        ? EmptyState(icon: Icons.history, title: '暂无跑步记录', hint: '完成一次跑步后这里会显示历史')
        : RefreshIndicator(
            onRefresh: _load,
            color: C.limeDim,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: _sessions.length,
              itemBuilder: (ctx, i) {
                final session = _sessions[i];
                return Dismissible(
                  key: Key(session['session_id'] as String),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: C.coral, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (_) => _confirmDelete(),
                  onDismissed: (_) => _deleteSession(session['session_id'] as String),
                  child: _historyCard(session),
                );
              },
            ),
          );
  }

  Widget _historyCard(Map<String, dynamic> session) {
    final startTime = session['start_time'] as String;
    final pointCount = session['point_count'] as int;
    final steps = session['total_steps'] as int? ?? 0;
    final distance = session['total_distance_km'] as num?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SessionDetailScreen(
            sessionId: session['session_id'] as String,
            startTime: startTime,
          )),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
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
                  Text(_formatDate(startTime), style: T.h4),
                  const SizedBox(height: 2),
                  Text(
                    '$pointCount 点 · $steps 步'
                    '${distance != null ? " · ${distance.toStringAsFixed(2)} km" : ""}',
                    style: T.bodyS,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: C.slate),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────

  String _formatDate(String iso) {
    try {
      return DateFormat('MM-dd HH:mm').format(DateTime.parse(iso));
    } catch (_) { return iso; }
  }

  Future<bool?> _confirmDelete() => showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('删除记录', style: T.h3),
      content: const Text('确定要删除这条跑步记录吗？'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: C.coral, foregroundColor: Colors.white),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('删除'),
        ),
      ],
    ),
  );

  Future<void> _deleteSession(String id) async {
    try {
      await context.read<ApiService>().deleteSession(id);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('删除失败: $e')));
    }
  }

  Future<void> _togglePlan(ExercisePlan plan, bool active) async {
    final api = context.read<ApiService>();
    final storage = context.read<StorageService>();
    final updated = ExercisePlan(
      id: plan.id, name: plan.name, description: plan.description,
      targetDurationMin: plan.targetDurationMin, targetDistanceKm: plan.targetDistanceKm,
      targetCalories: plan.targetCalories, weekdays: plan.weekdays,
      isActive: active, createdAt: plan.createdAt,
    );
    try {
      await api.updatePlan(plan.id, updated.toApiJson());
      await storage.savePlans(_plans.map((p) => p.id == plan.id ? updated : p).toList());
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
    }
  }

  void _showPlanSheet() {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final distCtrl = TextEditingController(text: '5');
    final durCtrl = TextEditingController(text: '30');
    final calCtrl = TextEditingController(text: '300');
    var selectedDays = <int>[1, 3, 5];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('创建跑步计划', style: T.h3),
                  const SizedBox(height: 16),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '计划名称')),
                  const SizedBox(height: 10),
                  TextField(controller: descCtrl, decoration: const InputDecoration(labelText: '描述（可选）')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: distCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '距离 (km)'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: durCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '时长 (分钟)'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: calCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '卡路里'))),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text('跑步日', style: T.label),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    children: [for (final d in [1, 2, 3, 4, 5, 6, 7])]
                      FilterChip(
                        label: Text(['一', '二', '三', '四', '五', '六', '日'][d - 1]),
                        selected: selectedDays.contains(d),
                        onSelected: (v) => setSheet(() => v ? selectedDays.add(d) : selectedDays.remove(d)),
                      ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.ink, foregroundColor: C.lime, elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: selectedDays.isEmpty ? null : () async {
                        final plan = ExercisePlan(
                          id: const Uuid().v4(),
                          name: nameCtrl.text.trim().isEmpty ? '跑步计划' : nameCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          targetDistanceKm: double.tryParse(distCtrl.text) ?? 5,
                          targetDurationMin: int.tryParse(durCtrl.text) ?? 30,
                          targetCalories: int.tryParse(calCtrl.text) ?? 300,
                          weekdays: selectedDays..sort(),
                        );
                        try {
                          await context.read<ApiService>().addPlan(plan.toApiJson());
                          _plans.insert(0, plan);
                          await context.read<StorageService>().savePlans(_plans);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        } catch (e) {
                          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
                        }
                      },
                      child: const Text('保存'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
