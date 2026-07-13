/// 饮食记录
class DietRecord {
  final String id;
  final DateTime date;
  final String mealType; // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  final String foodName;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;

  const DietRecord({
    required this.id,
    required this.date,
    required this.mealType,
    required this.foodName,
    required this.calories,
    this.proteinG = 0,
    this.carbsG = 0,
    this.fatG = 0,
  });

  String get mealTypeLabel {
    switch (mealType) {
      case 'breakfast':
        return '早餐';
      case 'lunch':
        return '午餐';
      case 'dinner':
        return '晚餐';
      case 'snack':
        return '加餐';
      default:
        return mealType;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'mealType': mealType,
    'foodName': foodName,
    'calories': calories,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
  };

  factory DietRecord.fromJson(Map<String, dynamic> json) => DietRecord(
    id: json['id'] as String,
    date: DateTime.parse(json['date'] as String),
    mealType: json['mealType'] as String,
    foodName: json['foodName'] as String,
    calories: (json['calories'] as num).toDouble(),
    proteinG: (json['proteinG'] as num?)?.toDouble() ?? 0,
    carbsG: (json['carbsG'] as num?)?.toDouble() ?? 0,
    fatG: (json['fatG'] as num?)?.toDouble() ?? 0,
  );
}
