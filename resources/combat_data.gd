## CombatData — 战斗数值配置资源
## 所有战斗相关数值的定义，策划可直接修改此文件调平衡。
class_name CombatData
extends Resource

# === 玩家基础属性 ===
@export var player_max_hp: float = 500.0
@export var player_attack: float = 30.0
@export var player_defense: float = 10.0
@export var player_move_speed: float = 200.0
@export var player_attack_speed: float = 0.8  ## 普攻间隔(秒)
@export var player_dodge_speed: float = 600.0  ## 闪避位移速度
@export var player_dodge_duration: float = 0.25  ## 闪避持续时间(秒)
@export var player_dodge_cooldown: float = 1.5  ## 闪避冷却(秒)
@export var player_dodge_invincible_duration: float = 0.25  ## 闪避无敌帧(秒)

# === 技能参数 ===
@export var skill_damage_multiplier: float = 2.5  ## 技能伤害倍率
@export var skill_cooldown: float = 6.0  ## 技能冷却(秒)
@export var skill_name: String = "灵气弹·强化"  ## 技能名称

# === 敌人属性(基础模板) ===
@export var enemy_max_hp: float = 200.0
@export var enemy_attack: float = 15.0
@export var enemy_defense: float = 5.0
@export var enemy_move_speed: float = 100.0
@export var enemy_attack_range: float = 80.0
@export var enemy_attack_cooldown: float = 2.0
@export var enemy_detect_range: float = 400.0

# === 通用战斗公式参数 ===
@export var defense_damage_reduction: float = 0.01  ## 每点防御减伤比例
@export var critical_chance: float = 0.1  ## 基础暴击率
@export var critical_multiplier: float = 1.8  ## 暴击倍率
