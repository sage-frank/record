import 'package:intl/intl.dart';

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

  /// 全端统一日期格式：yyyy-MM-dd HH:mm:ss
  static const String _dateFormat = 'yyyy-MM-dd HH:mm:ss';

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
    'date': DateFormat(_dateFormat).format(date),
    'mealType': mealType,
    'foodName': foodName,
    'calories': calories,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
  };

  Map<String, dynamic> toApiJson() => {
    'id': id,
    // 全端统一 yyyy-MM-dd HH:mm:ss（后端按天范围查询）
    'date': DateFormat(_dateFormat).format(date),
    'meal_type': mealType,
    'food_name': foodName,
    'calories': calories,
    'protein_g': proteinG == 0 ? null : proteinG,
    'carbs_g': carbsG == 0 ? null : carbsG,
    'fat_g': fatG == 0 ? null : fatG,
  };

  factory DietRecord.fromJson(Map<String, dynamic> json) => DietRecord(
    id: json['id'] as String,
    date: _parseDate(json['date'] as String),
    mealType: (json['mealType'] ?? json['meal_type']) as String,
    foodName: (json['foodName'] ?? json['food_name']) as String,
    calories: (json['calories'] as num).toDouble(),
    proteinG:
        ((json['proteinG'] ?? json['protein_g']) as num?)?.toDouble() ?? 0,
    carbsG: ((json['carbsG'] ?? json['carbs_g']) as num?)?.toDouble() ?? 0,
    fatG: ((json['fatG'] ?? json['fat_g']) as num?)?.toDouble() ?? 0,
  );

  /// 解析日期：优先统一格式 yyyy-MM-dd HH:mm:ss，兼容历史 ISO 格式
  static DateTime _parseDate(String raw) {
    try {
      return DateFormat(_dateFormat).parse(raw);
    } catch (_) {
      return DateTime.parse(raw);
    }
  }
}
