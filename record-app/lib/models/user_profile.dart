/// 用户档案（本地持久化）
class UserProfile {
  String name;
  double currentWeightKg;
  double targetWeightKg;
  double heightCm;
  int age;
  String gender; // 'male' | 'female'
  int dailyCalorieGoal;
  DateTime updatedAt;

  UserProfile({
    this.name = '',
    this.currentWeightKg = 70.0,
    this.targetWeightKg = 60.0,
    this.heightCm = 170.0,
    this.age = 30,
    this.gender = 'male',
    this.dailyCalorieGoal = 2000,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// BMR 基础代谢（Mifflin-St Jeor 公式）
  int get bmr {
    if (gender == 'female') {
      return (10 * currentWeightKg + 6.25 * heightCm - 5 * age - 161).round();
    }
    return (10 * currentWeightKg + 6.25 * heightCm - 5 * age + 5).round();
  }

  double get weightToLose => (currentWeightKg - targetWeightKg).clamp(0, 999);
  double get weightProgress =>
      currentWeightKg <= targetWeightKg
          ? 1.0
          : (weightToLose / (currentWeightKg - targetWeightKg + 1)).clamp(0, 1);

  Map<String, dynamic> toJson() => {
    'name': name,
    'currentWeightKg': currentWeightKg,
    'targetWeightKg': targetWeightKg,
    'heightCm': heightCm,
    'age': age,
    'gender': gender,
    'dailyCalorieGoal': dailyCalorieGoal,
    'updatedAt': updatedAt.toIso8601String(),
  };

  Map<String, dynamic> toApiJson() => {
    'name': name,
    'current_weight_kg': currentWeightKg,
    'target_weight_kg': targetWeightKg,
    'height_cm': heightCm,
    'age': age,
    'gender': gender,
    'daily_calorie_goal': dailyCalorieGoal,
    'updated_at': updatedAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    name: json['name'] as String? ?? '',
    currentWeightKg:
        ((json['currentWeightKg'] ?? json['current_weight_kg']) as num?)
            ?.toDouble() ??
        70,
    targetWeightKg:
        ((json['targetWeightKg'] ?? json['target_weight_kg']) as num?)
            ?.toDouble() ??
        60,
    heightCm:
        ((json['heightCm'] ?? json['height_cm']) as num?)?.toDouble() ?? 170,
    age: (json['age'] as num?)?.toInt() ?? 30,
    gender: json['gender'] as String? ?? 'male',
    dailyCalorieGoal:
        ((json['dailyCalorieGoal'] ?? json['daily_calorie_goal']) as num?)
            ?.toInt() ??
        2000,
    updatedAt:
        (json['updatedAt'] ?? json['updated_at']) != null
            ? DateTime.parse(
              (json['updatedAt'] ?? json['updated_at']) as String,
            )
            : DateTime.now(),
  );
}
