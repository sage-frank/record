import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../models/user_profile.dart';
import '../theme/app_theme.dart';
import '../utils/error_reporter.dart';
import '../widgets/app_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final storage = context.read<StorageService>();
    final api = context.read<ApiService>();
    try {
      final json = await api.getProfile();
      final profile = UserProfile.fromJson(json);
      await storage.saveProfile(profile);
      if (!mounted) return;
      setState(() { _profile = profile; _loading = false; });
    } catch (e, st) {
      // 网络失败回退到本地缓存，但异常必须上报，不允许吞掉
      ErrorReporter.reportError(
        message: '加载个人档案失败，回退本地缓存',
        source: 'profile_screen',
        error: e,
        stackTrace: st,
        url: '/api/profile',
      );
      final profile = await storage.loadProfile();
      if (!mounted) return;
      setState(() { _profile = profile; _loading = false; });
    }
  }

  double get _bmi {
    final p = _profile;
    if (p == null) return 0;
    final h = p.heightCm / 100;
    return p.currentWeightKg / (h * h);
  }

  String get _bmiCategory {
    final b = _bmi;
    if (b < 18.5) return '偏瘦';
    if (b < 24) return '正常';
    if (b < 28) return '偏胖';
    return '肥胖';
  }

  Color get _bmiColor {
    final b = _bmi;
    if (b < 18.5) return C.steel;
    if (b < 24) return C.limeDim;
    if (b < 28) return C.coral;
    return C.coralDim;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final p = _profile!;

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _load,
        color: C.limeDim,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          children: [
            _profileHeader(p),
            const SizedBox(height: 20),
            _bmiCard(),
            const SizedBox(height: 16),
            SectionHeader(title: '身体数据'),
            _bodyMetricsGrid(p),
            const SizedBox(height: 16),
            SectionHeader(title: '代谢与目标'),
            _metabolismCard(p),
            const SizedBox(height: 20),
            _actionButtons(p),
          ],
        ),
      ),
    );
  }

  // ─── Profile header ──────────────────────────────────────

  Widget _profileHeader(UserProfile p) {
    return Container(
      decoration: const BoxDecoration(color: C.ink),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: C.lime, width: 2),
                    ),
                    child: Center(
                      child: Text(
                        p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                        style: T.h2.copyWith(color: C.lime),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name.isNotEmpty ? p.name : '未设置姓名',
                          style: T.h2.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '目标 ${p.targetWeightKg.toStringAsFixed(1)} kg · 已坚持 ${p.daysSinceStart} 天',
                          style: T.bodyS.copyWith(color: C.slate),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit, color: C.lime),
                    onPressed: _showEditSheet,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── BMI card ────────────────────────────────────────────

  Widget _bmiCard() {
    return AppCard(
      child: Row(
        children: [
          ProgressRing(
            progress: (_bmi / 40).clamp(0.0, 1.0),
            size: 80,
            strokeWidth: 7,
            color: _bmiColor,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedNumber(value: _bmi, decimals: 1, style: T.numSm.copyWith(fontSize: 18)),
                Text('BMI', style: T.caption),
              ],
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_bmiCategory, style: T.h3.copyWith(color: _bmiColor)),
                const SizedBox(height: 4),
                Text(
                  'BMI = 体重 / 身高²\n正常范围 18.5–24',
                  style: T.bodyS,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Body metrics grid ───────────────────────────────────

  Widget _bodyMetricsGrid(UserProfile p) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: StatTile(label: '当前体重', value: p.currentWeightKg.toStringAsFixed(1), unit: 'kg', icon: Icons.monitor_weight, accent: C.steel)),
            const SizedBox(width: 12),
            Expanded(child: StatTile(label: '目标体重', value: p.targetWeightKg.toStringAsFixed(1), unit: 'kg', icon: Icons.flag, accent: C.limeDim)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: StatTile(label: '身高', value: p.heightCm.toStringAsFixed(0), unit: 'cm', icon: Icons.height, accent: C.slate)),
            const SizedBox(width: 12),
            Expanded(child: StatTile(label: '还需减重', value: p.weightToLose.toStringAsFixed(1), unit: 'kg', icon: Icons.trending_down, accent: C.coral)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: StatTile(label: '年龄', value: '${p.age}', unit: '岁', icon: Icons.cake, accent: C.slate)),
            const SizedBox(width: 12),
            Expanded(child: StatTile(label: '性别', value: p.gender == 'male' ? '男' : '女', icon: p.gender == 'male' ? Icons.male : Icons.female, accent: C.steel)),
          ],
        ),
      ],
    );
  }

  // ─── Metabolism card ─────────────────────────────────────

  Widget _metabolismCard(UserProfile p) {
    return AppCard(
      child: Column(
        children: [
          _metricRow('基础代谢 (BMR)', '${p.bmr} kcal/天', C.coral),
          const Divider(),
          _metricRow('每日摄入目标', '${p.dailyCalorieGoal} kcal', C.limeDim),
          const Divider(),
          _metricRow('每日热量缺口', '${p.bmr - p.dailyCalorieGoal} kcal', C.steel),
        ],
      ),
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: T.bodyM),
          const Spacer(),
          Text(value, style: T.numSm.copyWith(color: color)),
        ],
      ),
    );
  }

  // ─── Action buttons ──────────────────────────────────────

  Widget _actionButtons(UserProfile p) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: _showEditSheet,
          icon: const Icon(Icons.edit),
          label: const Text('编辑个人资料'),
          style: ElevatedButton.styleFrom(
            backgroundColor: C.ink, foregroundColor: C.lime, elevation: 0,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: _showWeightDialog,
          icon: const Icon(Icons.monitor_weight),
          label: const Text('更新体重'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: const BorderSide(color: C.line),
          ),
        ),
      ],
    );
  }

  // ─── Edit sheet ──────────────────────────────────────────

  void _showEditSheet() {
    final p = _profile!;
    final nameCtrl = TextEditingController(text: p.name);
    final heightCtrl = TextEditingController(text: p.heightCm.toStringAsFixed(0));
    final ageCtrl = TextEditingController(text: p.age.toString());
    final targetCtrl = TextEditingController(text: p.targetWeightKg.toStringAsFixed(1));
    final calCtrl = TextEditingController(text: p.dailyCalorieGoal.toString());
    var gender = p.gender;

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
                  Text('编辑个人资料', style: T.h3),
                  const SizedBox(height: 16),
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '姓名')),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: heightCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '身高 (cm)'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: ageCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '年龄'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(child: TextField(controller: targetCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: '目标体重 (kg)'))),
                      const SizedBox(width: 10),
                      Expanded(child: TextField(controller: calCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: '每日卡路里目标'))),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('性别', style: T.label),
                      const SizedBox(width: 12),
                      ChoiceChip(label: const Text('男'), selected: gender == 'male', onSelected: (_) => setSheet(() => gender = 'male')),
                      const SizedBox(width: 8),
                      ChoiceChip(label: const Text('女'), selected: gender == 'female', onSelected: (_) => setSheet(() => gender = 'female')),
                    ],
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
                      onPressed: () async {
                        final updated = UserProfile(
                          name: nameCtrl.text.trim(),
                          heightCm: double.tryParse(heightCtrl.text) ?? p.heightCm,
                          age: int.tryParse(ageCtrl.text) ?? p.age,
                          targetWeightKg: double.tryParse(targetCtrl.text) ?? p.targetWeightKg,
                          dailyCalorieGoal: int.tryParse(calCtrl.text) ?? p.dailyCalorieGoal,
                          currentWeightKg: p.currentWeightKg,
                          gender: gender,
                        );
                        try {
                          await context.read<ApiService>().updateProfile(updated.toApiJson());
                          await context.read<StorageService>().saveProfile(updated);
                          if (ctx.mounted) Navigator.pop(ctx);
                          _load();
                        } catch (e, st) {
                          ErrorReporter.reportError(
                            message: '保存个人档案失败',
                            source: 'profile_screen',
                            error: e,
                            stackTrace: st,
                            url: '/api/profile',
                          );
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

  void _showWeightDialog() {
    final ctrl = TextEditingController(text: _profile!.currentWeightKg.toStringAsFixed(1));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('更新体重', style: T.h3),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '当前体重 (kg)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: C.ink, foregroundColor: C.lime, elevation: 0),
            onPressed: () async {
              final w = double.tryParse(ctrl.text);
              if (w == null) return;
              final old = _profile!;
              final updated = UserProfile(
                name: old.name, currentWeightKg: w, targetWeightKg: old.targetWeightKg,
                heightCm: old.heightCm, age: old.age, gender: old.gender, dailyCalorieGoal: old.dailyCalorieGoal,
              );
              try {
                await context.read<ApiService>().addWeightRecord(w);
                await context.read<ApiService>().updateProfile(updated.toApiJson());
                await context.read<StorageService>().saveProfile(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } catch (e, st) {
                ErrorReporter.reportError(
                  message: '更新体重失败',
                  source: 'profile_screen',
                  error: e,
                  stackTrace: st,
                  url: '/api/weight-history',
                );
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('更新失败: $e')));
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }
}
