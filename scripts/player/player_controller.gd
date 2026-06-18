## PlayerController — 玩家战斗控制器
## 处理所有玩家输入和战斗状态。
## 竖屏单手操作：点击普攻 / 滑动闪避 / 按钮释放技能
class_name PlayerController
extends CharacterBody2D

# === 外部依赖 preload（headless 兼容：class_name 无法跨文件解析） ===
const CombatDataClass = preload("res://resources/combat_data.gd")
const CombatSystemClass = preload("res://scripts/systems/combat_system.gd")
const EnemyBaseClass = preload("res://scripts/enemy/enemy_base.gd")

# === 信号 ===
signal health_changed(current_hp: float, max_hp: float)
signal player_died
signal skill_used(skill_name: String, cooldown: float)
signal dodge_used(cooldown: float)

# === 属性 ===
@export var combat_data: Resource  ## CombatData 实例

## 当前血量
var current_hp: float = 0.0

# === 战斗状态 ===
enum CombatState { IDLE, ATTACKING, DODGING, USING_SKILL, DEAD, STUNNED }

var _state: CombatState = CombatState.IDLE
var _attack_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _skill_cooldown_timer: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _is_invincible: bool = false
var _invincible_timer: float = 0.0
var _stun_timer: float = 0.0

# === 节点引用 ===
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _hitbox: Area2D = $Hitbox
@onready var _invincible_timer_node: Timer = $InvincibleTimer

# === 触摸输入变量 ===
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_active: bool = false
var _is_tap: bool = false
var _swipe_threshold: float = 30.0  ## 滑动判定阈值(像素)

# === EventBus 缓存 (headless兼容) ===
var _eb = null

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	_eb = get_node_or_null("/root/EventBus")
	if not combat_data or not (combat_data is CombatDataClass):
		combat_data = CombatDataClass.new()
	
	current_hp = combat_data.player_max_hp
	_state = CombatState.IDLE
	
	# 连接无敌计时器
	if _invincible_timer_node:
		_invincible_timer_node.timeout.connect(_on_invincible_end)
	
	health_changed.emit(current_hp, combat_data.player_max_hp)

func _physics_process(delta: float) -> void:
	if _state == CombatState.DEAD:
		return
	
	_update_timers(delta)
	_update_state(delta)
	_handle_movement(delta)

# === 计时器更新 ===
func _update_timers(delta: float) -> void:
	# 攻击冷却
	if _attack_timer > 0.0:
		_attack_timer -= delta
	
	# 闪避持续时间
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		if _dodge_timer <= 0.0:
			_dodge_timer = 0.0
			if _state == CombatState.DODGING:
				_set_state(CombatState.IDLE)
	
	# 闪避冷却
	if _dodge_cooldown_timer > 0.0:
		_dodge_cooldown_timer -= delta
	
	# 技能冷却
	if _skill_cooldown_timer > 0.0:
		_skill_cooldown_timer -= delta
	
	# 无敌帧
	if _is_invincible:
		_invincible_timer -= delta
		if _invincible_timer <= 0.0:
			_is_invincible = false
			_set_sprite_alpha(1.0)
	
	# 眩晕
	if _state == CombatState.STUNNED:
		_stun_timer -= delta
		if _stun_timer <= 0.0:
			_set_state(CombatState.IDLE)

# === 状态更新 ===
func _update_state(_delta: float) -> void:
	match _state:
		CombatState.ATTACKING:
			if _attack_timer <= 0.0:
				_set_state(CombatState.IDLE)
		CombatState.DODGING:
			# 执行闪避位移
			velocity = _dodge_direction * combat_data.player_dodge_speed
			move_and_slide()

# === 移动处理 ===
func _handle_movement(delta: float) -> void:
	if _state == CombatState.DODGING or _state == CombatState.STUNNED or _state == CombatState.DEAD:
		return
	
	# 默认站桩，由触摸/键盘控制移动（后续可扩展虚拟摇杆）
	# 目前原型阶段：角色静止，专注战斗交互
	velocity = Vector2.ZERO
	move_and_slide()

# === 输入处理 ===

## 触摸输入（由TouchArea转发）
func on_touch_event(event_type: String, position: Vector2, swipe_direction: Vector2 = Vector2.ZERO) -> void:
	if _state == CombatState.DEAD:
		return
	
	match event_type:
		"tap":
			_try_attack()
		"swipe":
			_try_dodge(swipe_direction)

## 尝试普攻
func _try_attack() -> void:
	if _state in [CombatState.ATTACKING, CombatState.DODGING, CombatState.STUNNED]:
		return
	if _attack_timer > 0.0:
		return
	
	_set_state(CombatState.ATTACKING)
	_attack_timer = combat_data.player_attack_speed
	
	# 攻击判定
	_perform_attack()

## 执行攻击
func _perform_attack() -> void:
	# 获取攻击范围内的敌人
	var enemies: Array[Area2D] = _hitbox.get_overlapping_areas()
	
	for area in enemies:
		if area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy and enemy is EnemyBaseClass:
				var result: Dictionary = CombatSystemClass.calculate_damage(
					combat_data.player_attack,
					enemy.combat_data.enemy_defense if enemy.combat_data else 5.0
				)
				enemy.take_damage(result["damage"])
				if _eb: _eb.damage_number_request.emit(
					result["damage"],
					enemy.global_position + Vector2(0, -40),
					result["is_critical"]
				)
	
	# 播放攻击动画
	if _animation_player and _animation_player.has_animation("attack"):
		_animation_player.play("attack")

## 尝试闪避
func _try_dodge(direction: Vector2) -> void:
	if _state == CombatState.DODGING:
		return
	if _dodge_cooldown_timer > 0.0:
		return
	if _state in [CombatState.STUNNED, CombatState.ATTACKING]:
		return
	
	_set_state(CombatState.DODGING)
	_dodge_timer = combat_data.player_dodge_duration
	_dodge_cooldown_timer = combat_data.player_dodge_cooldown
	_dodge_direction = direction.normalized()
	
	# 激活无敌帧
	_activate_invincibility(combat_data.player_dodge_invincible_duration)
	
	# 播放闪避动画
	if _animation_player and _animation_player.has_animation("dodge"):
		_animation_player.play("dodge")
	
	dodge_used.emit(combat_data.player_dodge_cooldown)

## 使用技能
func use_skill() -> void:
	if _state in [CombatState.DODGING, CombatState.STUNNED, CombatState.DEAD]:
		return
	if _skill_cooldown_timer > 0.0:
		return
	
	_set_state(CombatState.USING_SKILL)
	_skill_cooldown_timer = combat_data.skill_cooldown
	
	# 技能伤害：对更大范围造成伤害
	var enemies: Array[Area2D] = _hitbox.get_overlapping_areas()
	
	for area in enemies:
		if area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy and enemy is EnemyBaseClass:
				var result: Dictionary = CombatSystemClass.calculate_damage(
					combat_data.player_attack,
					enemy.combat_data.enemy_defense if enemy.combat_data else 5.0,
					0.01,
					combat_data.skill_damage_multiplier
				)
				enemy.take_damage(result["damage"])
				if _eb: _eb.damage_number_request.emit(
					result["damage"],
					enemy.global_position + Vector2(0, -40),
					result["is_critical"]
				)
	
	# 播放技能动画
	if _animation_player and _animation_player.has_animation("skill"):
		_animation_player.play("skill")
	
	skill_used.emit(combat_data.skill_name, combat_data.skill_cooldown)
	
	# 技能后短暂延迟回到待机
	await get_tree().create_timer(0.3).timeout
	if _state == CombatState.USING_SKILL:
		_set_state(CombatState.IDLE)

# === 受伤处理 ===
func take_damage(damage: float) -> void:
	if _is_invincible or _state == CombatState.DEAD:
		return
	if _state == CombatState.DODGING:
		return  # 闪避期间无敌
	
	current_hp = maxf(current_hp - damage, 0.0)
	health_changed.emit(current_hp, combat_data.player_max_hp)
	if _eb: _eb.player_damaged.emit(damage, current_hp)
	
	# 受伤闪烁
	_flash_red()
	
	if current_hp <= 0.0:
		_die()
	else:
		# 受伤硬直
		_stun_timer = 0.2
		_set_state(CombatState.STUNNED)

func _die() -> void:
	_set_state(CombatState.DEAD)
	player_died.emit()
	if _eb: _eb.player_died.emit()
	
	if _animation_player and _animation_player.has_animation("death"):
		_animation_player.play("death")

# === 恢复 ===
func heal(amount: float) -> void:
	current_hp = minf(current_hp + amount, combat_data.player_max_hp)
	health_changed.emit(current_hp, combat_data.player_max_hp)

## 重置玩家状态（关卡重开时）
func reset() -> void:
	current_hp = combat_data.player_max_hp
	_set_state(CombatState.IDLE)
	_attack_timer = 0.0
	_dodge_timer = 0.0
	_dodge_cooldown_timer = 0.0
	_skill_cooldown_timer = 0.0
	_is_invincible = false
	health_changed.emit(current_hp, combat_data.player_max_hp)

# === 辅助方法 ===
func _set_state(new_state: CombatState) -> void:
	_state = new_state

func _activate_invincibility(duration: float) -> void:
	_is_invincible = true
	_invincible_timer = duration
	_set_sprite_alpha(0.5)
	
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
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.2)

## 获取当前状态信息（供HUD查询）
func get_state_info() -> Dictionary:
	return {
		"state": _state,
		"attack_ready": _attack_timer <= 0.0 and _state not in [CombatState.DODGING, CombatState.STUNNED],
		"dodge_ready": _dodge_cooldown_timer <= 0.0,
		"dodge_cooldown_remaining": _dodge_cooldown_timer,
		"dodge_cooldown_max": combat_data.player_dodge_cooldown,
		"skill_ready": _skill_cooldown_timer <= 0.0,
		"skill_cooldown_remaining": _skill_cooldown_timer,
		"skill_cooldown_max": combat_data.skill_cooldown,
	}
