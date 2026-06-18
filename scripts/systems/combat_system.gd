## CombatSystem — 战斗计算工具类
## 纯函数，无状态，处理伤害计算、暴击判定。
class_name CombatSystem
extends RefCounted

## 计算最终伤害
## [param base_attack] 攻击方基础攻击力
## [param target_defense] 受击方防御力
## [param defense_reduction] 每点防御的减伤比例
## [param skill_multiplier] 技能倍率
static func calculate_damage(
	base_attack: float,
	target_defense: float,
	defense_reduction: float = 0.01,
	skill_multiplier: float = 1.0
) -> Dictionary:
	# 防御减伤 = 防御力 * 减伤比例，上限80%
	var reduction: float = minf(target_defense * defense_reduction, 0.8)
	var raw_damage: float = base_attack * skill_multiplier
	
	# 暴击判定
	var is_critical: bool = _roll_critical()
	var final_damage: float = raw_damage * (1.0 - reduction)
	
	if is_critical:
		final_damage *= 1.8  # 暴击倍率
	
	return {
		"damage": maxf(ceilf(final_damage), 1.0),
		"raw_damage": raw_damage,
		"reduction": reduction,
		"is_critical": is_critical
	}

## 暴击判定 — 10%基础暴击率
static func _roll_critical(base_chance: float = 0.1) -> bool:
	return randf() < base_chance

## 判断两个节点之间的距离
static func distance_between(a: Node2D, b: Node2D) -> float:
	return a.global_position.distance_to(b.global_position)

## 获取从a指向b的单位方向向量
static func direction_to(from: Node2D, to: Node2D) -> Vector2:
	return from.global_position.direction_to(to.global_position)

## 检查目标是否在范围内
static func is_in_range(attacker: Node2D, target: Node2D, attack_range: float) -> bool:
	return distance_between(attacker, target) <= attack_range
