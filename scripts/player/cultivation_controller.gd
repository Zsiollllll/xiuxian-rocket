## CultivationController — 修仙体系战斗控制器
## 核心机制：灵力管理 + 法术连击 + 元素反应(后期解锁)
## 单手竖屏操作：点击=灵气弹 / 滑动=闪避 / 按钮=释放法术
class_name CultivationController
extends CharacterBody2D

# === 外部依赖 ===
const CombatDataClass = preload("res://resources/combat_data.gd")
const CombatSystemClass = preload("res://scripts/systems/combat_system.gd")
const EnemyBaseClass = preload("res://scripts/enemy/enemy_base.gd")

# === 信号 ===
signal health_changed(current_hp: float, max_hp: float)
signal qi_changed(current_qi: float, max_qi: float)
signal player_died
signal skill_used(skill_name: String, cooldown: float)
signal dodge_used(cooldown: float)
signal combo_changed(combo_count: int)

# === 属性 ===
@export var combat_data: Resource  ## CombatData 实例

## 当前血量
var current_hp: float = 0.0
## 灵力（替代MP，自动回复）
var current_qi: float = 0.0
var max_qi: float = 100.0
## 连击计数
var combo_count: int = 0
var _combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 3.0  ## 连击超时(秒)

# === 战斗状态 ===
enum CombatState { IDLE, ATTACKING, DODGING, CASTING, DEAD, STUNNED }
var _state: CombatState = CombatState.IDLE
var _attack_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _skill_cooldown_timer: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _is_invincible: bool = false
var _invincible_timer: float = 0.0
var _stun_timer: float = 0.0

# === 法术系统 ===
enum ElementType { NONE, FIRE, ICE, THUNDER }
var _current_element: ElementType = ElementType.NONE
var _element_unlocked: bool = false  ## 化神期解锁

# === 节点引用 ===
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _hitbox: Area2D = $Hitbox
@onready var _invincible_timer_node: Timer = $InvincibleTimer

# === EventBus 缓存 ===
var _eb = null

# === 灵力恢复 ===
const QI_REGEN_RATE: float = 5.0  ## 每秒恢复5点灵力

# ============================================
# 生命周期
# ============================================
func _ready() -> void:
	_initialize()

func _initialize() -> void:
	_eb = get_node_or_null("/root/EventBus")
	
	# 显式获取节点引用（set_script后@onready可能失效）
	_sprite = get_node_or_null("Sprite2D")
	_animation_player = get_node_or_null("AnimationPlayer")
	_hitbox = get_node_or_null("Hitbox")
	_invincible_timer_node = get_node_or_null("InvincibleTimer")
	
	if not combat_data or not (combat_data is CombatDataClass):
		combat_data = CombatDataClass.new()
	
	current_hp = combat_data.player_max_hp
	max_qi = 100.0
	current_qi = max_qi
	_state = CombatState.IDLE
	
	if _invincible_timer_node:
		if not _invincible_timer_node.timeout.is_connected(_on_invincible_end):
			_invincible_timer_node.timeout.connect(_on_invincible_end)
	
	health_changed.emit(current_hp, combat_data.player_max_hp)
	qi_changed.emit(current_qi, max_qi)

func _physics_process(delta: float) -> void:
	if _state == CombatState.DEAD:
		return
	
	_update_qi(delta)
	_update_timers(delta)
	_update_combo(delta)
	_update_state(delta)
	_handle_movement(delta)

# ============================================
# 灵力系统
# ============================================
func _update_qi(delta: float) -> void:
	if current_qi < max_qi:
		current_qi = minf(current_qi + QI_REGEN_RATE * delta, max_qi)
		qi_changed.emit(current_qi, max_qi)

func consume_qi(amount: float) -> bool:
	if current_qi >= amount:
		current_qi -= amount
		qi_changed.emit(current_qi, max_qi)
		return true
	return false

# ============================================
# 连击系统
# ============================================
func _update_combo(delta: float) -> void:
	if combo_count > 0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			combo_count = 0
			combo_changed.emit(combo_count)

func add_combo() -> void:
	combo_count += 1
	_combo_timer = COMBO_TIMEOUT
	combo_changed.emit(combo_count)

func get_combo_bonus() -> float:
	## 每层连击 +8% 伤害，上限 5 层 = +40%
	return 1.0 + minf(combo_count, 5) * 0.08

# ============================================
# 元素系统
# ============================================
func set_element(element: ElementType) -> void:
	if not _element_unlocked:
		return
	_current_element = element

func _get_element_color() -> Color:
	match _current_element:
		ElementType.FIRE: return Color(1.0, 0.3, 0.1)
		ElementType.ICE: return Color(0.3, 0.7, 1.0)
		ElementType.THUNDER: return Color(0.8, 0.3, 1.0)
		_: return Color(0.3, 0.6, 1.0)  ## 默认青色

func _apply_element_effect(damage: float) -> float:
	match _current_element:
		ElementType.FIRE:
			return damage * 1.15  ## 火：+15% 伤害
		ElementType.ICE:
			return damage * 0.9  ## 冰：伤害略低但减速敌人(由敌人端处理)
		ElementType.THUNDER:
			return damage * 1.0  ## 雷：正常伤害但有连锁效果
		_:
			return damage

# ============================================
# 计时器
# ============================================
func _update_timers(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
	
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		if _dodge_timer <= 0.0:
			_dodge_timer = 0.0
			if _state == CombatState.DODGING:
				_set_state(CombatState.IDLE)
	
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer -= delta
	
	if _skill_cooldown_timer > 0.0:
		_skill_cooldown_timer -= delta
	
	if _is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			_is_invincible = false
			_set_sprite_alpha(1.0)
	
	if _state == CombatState.STUNNED:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_set_state(CombatState.IDLE)

func _update_state(_delta: float) -> void:
	if _state == CombatState.DODGING:
		velocity = _dodge_direction * combat_data.player_dodge_speed
		move_and_slide()

func _handle_movement(_delta: float) -> void:
	if _state in [CombatState.DODGING, CombatState.STUNNED, CombatState.DEAD]:
		return
	velocity = Vector2.ZERO
	move_and_slide()

# ============================================
# 输入处理
# ============================================
func on_touch_event(event_type: String, _position: Vector2, swipe_direction: Vector2 = Vector2.ZERO) -> void:
	if _state == CombatState.DEAD:
		return
	
	match event_type:
		"tap":
			_try_attack()
		"swipe":
			_try_dodge(swipe_direction)

func _try_attack() -> void:
	if _state in [CombatState.ATTACKING, CombatState.DODGING, CombatState.STUNNED, CombatState.CASTING]:
		return
	if _attack_timer > 0.0:
		return
	
	_set_state(CombatState.ATTACKING)
	_attack_timer = combat_data.player_attack_speed
	
	_perform_attack()

func _perform_attack() -> void:
	## 灵气弹：基础攻击，不消耗灵力
	var enemies: Array[Area2D] = _hitbox.get_overlapping_areas()
	
	for area in enemies:
		if area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy is EnemyBaseClass:
				var base_damage: float = combat_data.player_attack * get_combo_bonus()
				base_damage = _apply_element_effect(base_damage)
				
				var result: Dictionary = CombatSystemClass.calculate_damage(
					base_damage,
					enemy.combat_data.enemy_defense if enemy.combat_data else 5.0
				)
				enemy.take_damage(result["damage"])
				add_combo()
				
				if _eb:
					_eb.damage_number_request.emit(
						result["damage"],
						enemy.global_position + Vector2(0, -40),
						result["is_critical"]
					)
	
	if _animation_player and _animation_player.has_animation("attack"):
		_animation_player.play("attack")

func _try_dodge(direction: Vector2) -> void:
	if _state == CombatState.DODGING or _dodge_cooldown_timer > 0.0:
		return
	if _state in [CombatState.STUNNED, CombatState.ATTACKING, CombatState.CASTING]:
		return
	if not consume_qi(15.0):  ## 闪避消耗灵力
		return
	
	_set_state(CombatState.DODGING)
	_dodge_timer = combat_data.player_dodge_duration
	_dodge_cooldown_timer = combat_data.player_dodge_cooldown
	_dodge_direction = direction.normalized()
	
	_activate_invincibility(combat_data.player_dodge_invincible_duration)
	
	if _animation_player and _animation_player.has_animation("dodge"):
		_animation_player.play("dodge")
	
	dodge_used.emit(combat_data.player_dodge_cooldown)

## 释放法术（替代通用技能）
func cast_spell() -> void:
	if _state in [CombatState.DODGING, CombatState.STUNNED, CombatState.DEAD]:
		return
	if _skill_cooldown_timer > 0.0:
		return
	if not consume_qi(30.0):
		return  ## 灵力不足
	
	_set_state(CombatState.CASTING)
	_skill_cooldown_timer = combat_data.skill_cooldown
	
	var enemies: Array[Area2D] = _hitbox.get_overlapping_areas()
	
	for area in enemies:
		if area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy is EnemyBaseClass:
				var base_damage: float = combat_data.player_attack * combat_data.skill_damage_multiplier
				base_damage *= get_combo_bonus()
				base_damage = _apply_element_effect(base_damage)
				
				var result: Dictionary = CombatSystemClass.calculate_damage(
					base_damage,
					enemy.combat_data.enemy_defense if enemy.combat_data else 5.0
				)
				enemy.take_damage(result["damage"])
				add_combo()
				
				if _eb:
					_eb.damage_number_request.emit(
						result["damage"],
						enemy.global_position + Vector2(0, -40),
						result["is_critical"]
					)
	
	if _animation_player and _animation_player.has_animation("skill"):
		_animation_player.play("skill")
	
	skill_used.emit(_get_spell_name(), combat_data.skill_cooldown)
	
	await get_tree().create_timer(0.3).timeout
	if _state == CombatState.CASTING:
		_set_state(CombatState.IDLE)

func _get_spell_name() -> String:
	match _current_element:
		ElementType.FIRE: return "火球术"
		ElementType.ICE: return "冰霜箭"
		ElementType.THUNDER: return "雷霆击"
		_: return combat_data.skill_name

# ============================================
# 受伤/死亡
# ============================================
func take_damage(damage: float) -> void:
	if _is_invincible or _state == CombatState.DEAD:
		return
	if _state == CombatState.DODGING:
		return
	
	current_hp = maxf(current_hp - damage, 0.0)
	health_changed.emit(current_hp, combat_data.player_max_hp)
	
	if _eb:
		_eb.player_damaged.emit(damage, current_hp)
	
	_flash_red()
	## 受伤重置连击
	combo_count = 0
	combo_changed.emit(combo_count)
	
	if current_hp <= 0.0:
		_die()
	else:
		_stun_timer = 0.2
		_set_state(CombatState.STUNNED)

func _die() -> void:
	_set_state(CombatState.DEAD)
	player_died.emit()
	if _eb:
		_eb.player_died.emit()
	
	if _animation_player and _animation_player.has_animation("death"):
		_animation_player.play("death")

func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, combat_data.player_max_hp)
	health_changed.emit(current_hp, combat_data.player_max_hp)

func reset() -> void:
	current_hp = combat_data.player_max_hp
	current_qi = max_qi
	combo_count = 0
	_set_state(CombatState.IDLE)
	_attack_timer = 0.0
	_dodge_timer = 0.0
	_dodge_cooldown_timer = 0.0
	_skill_cooldown_timer = 0.0
	_is_invincible = false
	health_changed.emit(current_hp, combat_data.player_max_hp)
	qi_changed.emit(current_qi, max_qi)
	combo_changed.emit(0)

# ============================================
# 辅助方法
# ============================================
func _set_state(new_state: CombatState) -> void:
	_state = new_state

func _activate_invincibility(duration: float) -> void:
	_is_invincible = true
	_invincible_timer = duration
	_set_sprite_alpha(0.4)
	if _invincible_timer_node:
		_invincible_timer_node.start(duration)

func _on_invincible_end() -> void:
	_is_invincible = false
	_set_sprite_alpha(1.0)

func _set_sprite_alpha(alpha: float) -> void:
	if _sprite:
		_sprite.modulate.a = alpha

func _flash_red() -> void:
	if _sprite:
		var tween: Tween = create_tween()
		tween.tween_property(_sprite, "modulate", Color.RED, 0.1)
		tween.tween_property(_sprite, "modulate", _get_element_color(), 0.2)

func get_state_info() -> Dictionary:
	return {
		"state": _state,
		"system": "cultivation",
		"qi_current": current_qi,
		"qi_max": max_qi,
		"combo": combo_count,
		"element": _current_element,
		"attack_ready": _attack_timer <= 0.0 and _state not in [CombatState.DODGING, CombatState.STUNNED],
		"dodge_ready": _dodge_cooldown_timer <= 0.0,
		"dodge_cooldown_remaining": _dodge_cooldown_timer,
		"dodge_cooldown_max": combat_data.player_dodge_cooldown,
		"spell_ready": _skill_cooldown_timer <= 0.0,
		"spell_cooldown_remaining": _skill_cooldown_timer,
		"spell_cooldown_max": combat_data.skill_cooldown,
	}
