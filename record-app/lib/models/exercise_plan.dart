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

  ExercisePlan({
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

  Map<String, dynamic> toApiJson() => {
    'id': id,
    'name': name,
    'description': description,
    'target_duration_min': targetDurationMin,
    'target_distance_km': targetDistanceKm,
    'target_calories': targetCalories,
    'weekdays': weekdays,
    'is_active': isActive,
  };

  factory ExercisePlan.fromJson(Map<String, dynamic> json) => ExercisePlan(
    id: json['id'] as String,
    name: json['name'] as String,
    description: json['description'] as String? ?? '',
    targetDurationMin:
        ((json['targetDurationMin'] ?? json['target_duration_min']) as num?)
            ?.toInt() ??
        30,
    targetDistanceKm:
        ((json['targetDistanceKm'] ?? json['target_distance_km']) as num?)
            ?.toDouble() ??
        5.0,
    targetCalories:
        ((json['targetCalories'] ?? json['target_calories']) as num?)
            ?.toInt() ??
        300,
    weekdays: (json['weekdays'] as List<dynamic>?)?.cast<int>() ?? [1, 3, 5],
    isActive: (json['isActive'] ?? json['is_active']) as bool? ?? true,
    createdAt:
        (json['createdAt'] ?? json['created_at']) != null
            ? DateTime.parse(
              (json['createdAt'] ?? json['created_at']) as String,
            )
            : DateTime.now(),
  );
}
