/// 运动计划
class ExercisePlan {
  final String id;
  final String name;
  final String description;
  final int targetDurationMin;
  final double targetDistanceKm;
  final int targetCalories;
  final List<int> weekdays; // 1=Mon..7=Sun
  final bool isActive;
  final DateTime createdAt;

  const ExercisePlan({
    required this.id,
    required this.name,
    this.description = '',
    this.targetDurationMin = 30,
    this.targetDistanceKm = 5.0,
    this.targetCalories = 300,
    this.weekdays = const [1, 3, 5],
    this.isActive = true,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  String get weekdayLabel {
    const labels = ['一', '二', '三', '四', '五', '六', '日'];
    return weekdays.map((d) => '周${labels[d - 1]}').join('、');
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'targetDurationMin': targetDurationMin,
    'targetDistanceKm': targetDistanceKm,
    'targetCalories': targetCalories,
    'weekdays': weekdays,
    'isActive': isActive,
    'createdAt': createdAt.toIso8601String(),
  };

  factory ExercisePlan.fromJson(Map<String, dynamic> json) => ExercisePlan(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    targetDurationMin: json['targetDurationMin'] as int? ?? 30,
    targetDistanceKm: (json['targetDistanceKm'] as num?)?.toDouble() ?? 5.0,
    targetCalories: json['targetCalories'] as int? ?? 300,
    weekdays:
        (json['weekdays'] as List<dynamic>?)?.cast<int>() ?? [1, 3, 5],
    isActive: json['isActive'] as bool? ?? true,
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
  );
}
