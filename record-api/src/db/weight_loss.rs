use crate::error::AppError;
use crate::models::weight_loss::{
    DietRecord, DietRecordInput, ExercisePlan, ExercisePlanInput, UserProfile, WeightRecord,
    WeightRecordInput,
};

use super::Database;

impl Database {
    pub fn get_profile(&self) -> Result<UserProfile, AppError> {
        let conn = self.lock()?;
        let mut stmt = conn.prepare(
            "SELECT name, current_weight_kg, target_weight_kg, height_cm, age, gender, daily_calorie_goal, updated_at FROM user_profile WHERE id = 1"
        )?;
        let profile = stmt.query_row([], |row| {
            Ok(UserProfile {
                name: row.get(0)?,
                current_weight_kg: row.get(1)?,
                target_weight_kg: row.get(2)?,
                height_cm: row.get(3)?,
                age: row.get(4)?,
                gender: row.get(5)?,
                daily_calorie_goal: row.get(6)?,
                updated_at: Some(row.get(7)?),
            })
        })?;
        Ok(profile)
    }

    pub fn update_profile(&self, profile: &UserProfile) -> Result<(), AppError> {
        let conn = self.lock()?;
        conn.execute(
            "UPDATE user_profile SET name=?1, current_weight_kg=?2, target_weight_kg=?3, height_cm=?4, age=?5, gender=?6, daily_calorie_goal=?7, updated_at=datetime('now') WHERE id=1",
            rusqlite::params![profile.name, profile.current_weight_kg, profile.target_weight_kg, profile.height_cm, profile.age, profile.gender, profile.daily_calorie_goal],
        )?;
        Ok(())
    }

    pub fn get_weight_history(&self) -> Result<Vec<WeightRecord>, AppError> {
        let conn = self.lock()?;
        let mut stmt = conn.prepare("SELECT id, weight_kg, recorded_at FROM weight_history ORDER BY recorded_at DESC LIMIT 90")?;
        let result: Vec<WeightRecord> = stmt
            .query_map([], |row| {
                Ok(WeightRecord {
                    id: row.get(0)?,
                    weight_kg: row.get(1)?,
                    recorded_at: row.get(2)?,
                })
            })?
            .filter_map(|r| r.ok())
            .collect();
        Ok(result)
    }

    pub fn add_weight_record(&self, input: &WeightRecordInput) -> Result<WeightRecord, AppError> {
        let conn = self.lock()?;
        conn.execute(
            "INSERT INTO weight_history (weight_kg) VALUES (?1)",
            [input.weight_kg],
        )?;
        let id = conn.last_insert_rowid();
        Ok(WeightRecord {
            id,
            weight_kg: input.weight_kg,
            recorded_at: String::new(),
        })
    }

    pub fn delete_weight_record(&self, id: i64) -> Result<(), AppError> {
        let conn = self.lock()?;
        conn.execute("DELETE FROM weight_history WHERE id = ?1", [id])?;
        Ok(())
    }

    pub fn get_diet_records(&self, date: Option<&str>) -> Result<Vec<DietRecord>, AppError> {
        let conn = self.lock()?;
        let sql = "SELECT id, date, meal_type, food_name, calories, protein_g, carbs_g, fat_g, created_at FROM diet_records";
        if let Some(d) = date {
            // 按日期前缀匹配：兼容带时间戳的旧数据（如 2026-08-12T10:55:05）与纯日期新数据
            // 按天范围查询：>= 当天 00:00:00 且 <= 当天 23:59:59（字符串比较与时序一致）
            let start = format!("{d} 00:00:00");
            let end = format!("{d} 23:59:59");
            let mut stmt = conn.prepare(&format!(
                "{sql} WHERE date >= ?1 AND date <= ?2 ORDER BY created_at DESC"
            ))?;
            return Ok(stmt
                .query_map(rusqlite::params![start, end], |row| {
                    Ok(DietRecord {
                        id: row.get(0)?,
                        date: row.get(1)?,
                        meal_type: row.get(2)?,
                        food_name: row.get(3)?,
                        calories: row.get(4)?,
                        protein_g: row.get(5)?,
                        carbs_g: row.get(6)?,
                        fat_g: row.get(7)?,
                        created_at: row.get(8)?,
                    })
                })?
                .filter_map(|r| r.ok())
                .collect());
        }
        let mut stmt = conn.prepare(&format!("{sql} ORDER BY created_at DESC LIMIT 100"))?;
        let result: Vec<DietRecord> = stmt
            .query_map([], |row| {
                Ok(DietRecord {
                    id: row.get(0)?,
                    date: row.get(1)?,
                    meal_type: row.get(2)?,
                    food_name: row.get(3)?,
                    calories: row.get(4)?,
                    protein_g: row.get(5)?,
                    carbs_g: row.get(6)?,
                    fat_g: row.get(7)?,
                    created_at: row.get(8)?,
                })
            })?
            .filter_map(|r| r.ok())
            .collect();
        Ok(result)
    }

    pub fn add_diet_record(&self, input: &DietRecordInput) -> Result<(), AppError> {
        let conn = self.lock()?;
        conn.execute(
            "INSERT OR REPLACE INTO diet_records (id, date, meal_type, food_name, calories, protein_g, carbs_g, fat_g) VALUES (?1,?2,?3,?4,?5,?6,?7,?8)",
            rusqlite::params![input.id, input.date, input.meal_type, input.food_name, input.calories, input.protein_g, input.carbs_g, input.fat_g],
        )?;
        Ok(())
    }

    pub fn delete_diet_record(&self, id: &str) -> Result<(), AppError> {
        let conn = self.lock()?;
        conn.execute("DELETE FROM diet_records WHERE id = ?1", [id])?;
        Ok(())
    }

    pub fn get_plans(&self) -> Result<Vec<ExercisePlan>, AppError> {
        let conn = self.lock()?;
        let mut stmt = conn.prepare("SELECT id, name, description, target_duration_min, target_distance_km, target_calories, weekdays, is_active, created_at FROM exercise_plans ORDER BY created_at DESC")?;
        let result: Vec<ExercisePlan> = stmt
            .query_map([], |row| {
                let w: String = row.get(6)?;
                Ok(ExercisePlan {
                    id: row.get(0)?,
                    name: row.get(1)?,
                    description: row.get(2)?,
                    target_duration_min: row.get(3)?,
                    target_distance_km: row.get(4)?,
                    target_calories: row.get(5)?,
                    weekdays: serde_json::from_str(&w).unwrap_or_default(),
                    is_active: row.get::<_, i32>(7)? != 0,
                    created_at: row.get(8)?,
                })
            })?
            .filter_map(|r| r.ok())
            .collect();
        Ok(result)
    }

    pub fn add_plan(&self, input: &ExercisePlanInput) -> Result<(), AppError> {
        let conn = self.lock()?;
        let w = serde_json::to_string(&input.weekdays).unwrap_or_default();
        conn.execute(
            "INSERT OR REPLACE INTO exercise_plans (id, name, description, target_duration_min, target_distance_km, target_calories, weekdays, is_active) VALUES (?1,?2,?3,?4,?5,?6,?7,?8)",
            rusqlite::params![input.id, input.name, input.description, input.target_duration_min, input.target_distance_km, input.target_calories, w, input.is_active as i32],
        )?;
        Ok(())
    }

    pub fn update_plan(&self, id: &str, input: &ExercisePlanInput) -> Result<(), AppError> {
        let conn = self.lock()?;
        let w = serde_json::to_string(&input.weekdays).unwrap_or_default();
        conn.execute(
            "UPDATE exercise_plans SET name=?1, description=?2, target_duration_min=?3, target_distance_km=?4, target_calories=?5, weekdays=?6, is_active=?7 WHERE id=?8",
            rusqlite::params![input.name, input.description, input.target_duration_min, input.target_distance_km, input.target_calories, w, input.is_active as i32, id],
        )?;
        Ok(())
    }

    pub fn delete_plan(&self, id: &str) -> Result<(), AppError> {
        let conn = self.lock()?;
        conn.execute("DELETE FROM exercise_plans WHERE id = ?1", [id])?;
        Ok(())
    }
}
