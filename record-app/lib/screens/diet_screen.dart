import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/diet_record.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_widgets.dart';

class DietScreen extends StatefulWidget {
  const DietScreen({super.key});

  @override
  State<DietScreen> createState() => _DietScreenState();
}

class _DietScreenState extends State<DietScreen> {
  List<DietRecord> _records = [];
  UserProfile? _profile;
  bool _loading = true;
  String _selectedDate = '';

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
  static const _mealLabels = {'breakfast': '早餐', 'lunch': '午餐', 'dinner': '晚餐', 'snack': '加餐'};
  static const _mealIcons = {
    'breakfast': Icons.wb_sunny,
    'lunch': Icons.light_mode,
    'dinner': Icons.nights_stay,
    'snack': Icons.coffee,
  };

  @override
  void initState() {
    super.initState();
    _selectedDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _load();
  }

  Future<void> _load() async {
    final storage = context.read<StorageService>();
    final api = context.read<ApiService>();
    try {
      final recordJsonList = await api.getDietRecords(date: _selectedDate);
      final records = recordJsonList.map(DietRecord.fromJson).toList();
      final profileJson = await api.getProfile();
      final profile = UserProfile.fromJson(profileJson);
      await storage.saveDietRecords(records);
      await storage.saveProfile(profile);
      if (!mounted) return;
      setState(() { _records = records; _profile = profile; _loading = false; });
    } catch (e, st) {
      // 网络失败回退到本地缓存，但异常必须上报，不允许吞掉
      ErrorReporter.reportError(
        message: '加载饮食记录失败，回退本地缓存',
        source: 'diet_screen',
        error: e,
        stackTrace: st,
        url: '/api/diet-records',
      );
      final records = await storage.loadDietRecords();
      final profile = await storage.loadProfile();
      if (!mounted) return;
      setState(() { _records = records; _profile = profile; _loading = false; });
    }
  }

  double get _todayCalories => _records
      .where((r) => DateFormat('yyyy-MM-dd').format(r.date) == _selectedDate)
      .fold(0.0, (s, r) => s + r.calories);

  double _mealCalories(String mt) => _records
      .where((r) => r.mealType == mt && DateFormat('yyyy-MM-dd').format(r.date) == _selectedDate)
      .fold(0.0, (s, r) => s + r.calories);

  int get _mealCount => _records
      .where((r) => DateFormat('yyyy-MM-dd').format(r.date) == _selectedDate)
      .length;

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final goal = _profile?.dailyCalorieGoal ?? 2000;
    final todayKcal = _todayCalories;
    final remaining = goal - todayKcal.toInt();
    final progress = (todayKcal / goal).clamp(0.0, 1.0);

    return Scaffold(
      body: Column(
        children: [
          // Header with calorie summary
          _calorieHeader(goal, todayKcal, remaining, progress),
          // Meals list
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              color: C.limeDim,
              child: _records.isEmpty
                  ? EmptyState(
                      icon: Icons.restaurant_menu,
                      title: '今日暂无饮食记录',
                      hint: '点击右下角按钮记录第一餐',
                    )
                  : AnimationLimiter(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: _mealTypes.length,
                        itemBuilder: (ctx, i) => AnimationConfiguration.staggeredList(
                          position: i,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 30,
                            child: FadeInAnimation(child: _buildMealGroup(_mealTypes[i])),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSheet,
        icon: const Icon(Icons.add),
        label: const Text('记录饮食'),
        backgroundColor: C.ink,
        foregroundColor: C.lime,
      ),
    );
  }

  // ─── Calorie header ─────────────────────────────────────

  Widget _calorieHeader(int goal, double todayKcal, int remaining, double progress) {
    final over = remaining < 0;
    return Container(
      decoration: const BoxDecoration(color: C.ink),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            children: [
              Row(
                children: [
                  Text('饮食记录', style: T.h2.copyWith(color: Colors.white)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showDatePicker(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: C.ink2,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 14, color: C.slate),
                          const SizedBox(width: 4),
                          Text(
                            _selectedDate == DateFormat('yyyy-MM-dd').format(DateTime.now())
                                ? '今天'
                                : _selectedDate.substring(5),
                            style: T.bodyS.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ProgressRing(
                    progress: progress,
                    size: 80,
                    strokeWidth: 7,
                    color: over ? C.coral : C.lime,
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedNumber(value: todayKcal.toInt(), style: T.numSm.copyWith(color: Colors.white)),
                        Text('kcal', style: T.caption.copyWith(color: C.slate)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_mealCount} 条记录', style: T.bodyS.copyWith(color: C.slate)),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              over ? '${-remaining}' : '$remaining',
                              style: T.numLg.copyWith(color: over ? C.coral : C.lime),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(' kcal', style: T.bodyS.copyWith(color: C.slate)),
                            ),
                          ],
                        ),
                        Text(
                          over ? '已超出目标' : '距目标还剩',
                          style: T.bodyS.copyWith(color: C.slate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Meal group ──────────────────────────────────────────

  Widget _buildMealGroup(String mealType) {
    final items = _records
        .where((r) => r.mealType == mealType && DateFormat('yyyy-MM-dd').format(r.date) == _selectedDate)
        .toList();

    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: AppCard(
          onTap: () => _showAddSheet(initialMeal: mealType),
          color: C.paper,
          flat: true,
          child: Row(
            children: [
              Icon(_mealIcons[mealType], size: 20, color: C.slate),
              const SizedBox(width: 10),
              Text(_mealLabels[mealType]!, style: T.labelSlate),
              const Spacer(),
              const Icon(Icons.add, size: 18, color: C.slate),
            ],
          ),
        ),
      );
    }

    final totalCal = items.fold(0.0, (s, r) => s + r.calories);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_mealIcons[mealType], size: 18, color: C.steel),
              const SizedBox(width: 8),
              Text(_mealLabels[mealType]!, style: T.h4),
              const Spacer(),
              Text('${totalCal.toInt()} kcal', style: T.numSm.copyWith(color: C.slate)),
            ],
          ),
          const SizedBox(height: 8),
          ...items.map((r) => AppCard(
            margin: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.foodName, style: T.bodyM),
                      if (r.proteinG > 0 || r.carbsG > 0 || r.fatG > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'P${r.proteinG.toStringAsFixed(0)} C${r.carbsG.toStringAsFixed(0)} F${r.fatG.toStringAsFixed(0)}',
                            style: T.caption,
                          ),
                        ),
                    ],
                  ),
                ),
                Text('${r.calories.toInt()}', style: T.numSm.copyWith(color: C.coral)),
                Text(' kcal', style: T.caption),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteRecord(r.id),
                  child: const Icon(Icons.close, size: 18, color: C.slate),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  // ─── Actions ─────────────────────────────────────────────

  Future<void> _deleteRecord(String id) async {
    final api = context.read<ApiService>();
    final storage = context.read<StorageService>();
    try {
      await api.deleteDietRecord(id);
    } catch (e, st) {
      // 服务器删除失败：上报异常并回退到本地删除
      ErrorReporter.reportError(
        message: '删除饮食记录失败，回退本地删除',
        source: 'diet_screen',
        error: e,
        stackTrace: st,
        url: '/api/diet-records/$id',
        context: {'record_id': id},
      );
      await storage.deleteDietRecord(id);
    }
    await _load();
  }

  void _showDatePicker() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_selectedDate),
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = DateFormat('yyyy-MM-dd').format(picked);
        _loading = true;
      });
      _load();
    }
  }

  void _showAddSheet({String initialMeal = 'breakfast'}) {
    final nameCtrl = TextEditingController();
    final calCtrl = TextEditingController();
    final proteinCtrl = TextEditingController();
    final carbsCtrl = TextEditingController();
    final fatCtrl = TextEditingController();
    String mealType = initialMeal;

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
                  Text('记录饮食', style: T.h3),
                  const SizedBox(height: 16),
                  // Meal type selector
                  Row(
                    children: _mealTypes.map((mt) {
                      final selected = mealType == mt;
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: GestureDetector(
                            onTap: () => setSheet(() => mealType = mt),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: selected ? C.ink : C.paper,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: selected ? C.ink : C.line),
                              ),
                              child: Center(
                                child: Text(
                                  _mealLabels[mt]!,
                                  style: T.bodyS.copyWith(
                                    color: selected ? C.lime : C.slate,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: '食物名称'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: calCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: '卡路里 (kcal)'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(
                        controller: proteinCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '蛋白质 (g)'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(
                        controller: carbsCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '碳水 (g)'),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(
                        controller: fatCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: '脂肪 (g)'),
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: C.ink,
                        foregroundColor: C.lime,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () async {
                        final name = nameCtrl.text.trim();
                        final cal = double.tryParse(calCtrl.text.trim());
                        if (name.isEmpty || cal == null) return;
                        final record = DietRecord(
                          id: const Uuid().v4(),
                          date: DateTime.now(),
                          mealType: mealType,
                          foodName: name,
                          calories: cal,
                          proteinG: double.tryParse(proteinCtrl.text) ?? 0,
                          carbsG: double.tryParse(carbsCtrl.text) ?? 0,
                          fatG: double.tryParse(fatCtrl.text) ?? 0,
                        );
                        try {
                          await context.read<ApiService>().addDietRecord(record.toApiJson());
                          await context.read<StorageService>().addDietRecord(record);
                          if (ctx.mounted) Navigator.pop(ctx);
                          await _load();
                        } catch (e, st) {
                          // 保存失败：上报异常后仍需提示用户
                          ErrorReporter.reportError(
                            message: '添加饮食记录失败',
                            source: 'diet_screen',
                            error: e,
                            stackTrace: st,
                            url: '/api/diet-records',
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败: $e')));
                          }
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
