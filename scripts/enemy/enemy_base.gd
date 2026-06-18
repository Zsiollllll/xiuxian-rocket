## EnemyBase — 敌人基类
## 定义敌人的通用行为：AI状态机、追踪、攻击、受击。
## 具体敌人通过继承此基类或修改导出参数来差异化。
class_name EnemyBase
extends CharacterBody2D

# === 外部依赖 preload（headless 兼容：class_name 无法跨文件解析） ===
const CombatDataClass = preload("res://resources/combat_data.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const CombatSystemClass = preload("res://scripts/systems/combat_system.gd")

# === 信号 ===
signal health_changed(current_hp: float, max_hp: float)
signal enemy_died(enemy_name: String)
signal enemy_attack_started

# === 属性 ===
@export var combat_data: Resource  ## CombatData 实例
@export var enemy_display_name: String = "妖兽"
@export var enemy_type: String = "basic"  ## 敌人类型标识
@export var detection_range: float = 400.0
@export var attack_range: float = 80.0

## 当前血量
var current_hp: float = 0.0
var _target = null

# === EventBus 缓存 (headless兼容) ===
var _eb = null

# === AI状态 ===
enum AIState { IDLE, CHASE, ATTACK, HURT, DEAD }
var _ai_state: AIState = AIState.IDLE
var _attack_cooldown_timer: float = 0.0
var _hurt_timer: float = 0.0

# === 节点引用 ===
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _detection_area: Area2D = $DetectionArea
@onready var _hurtbox: Area2D = $Hurtbox

func _ready() -> void:
	_initialize()

func _initialize() -> void:
	_eb = get_node_or_null("/root/EventBus")
	if not combat_data or not (combat_data is CombatDataClass):
		combat_data = CombatDataClass.new()
	
	current_hp = combat_data.enemy_max_hp
	
	# 将受伤判定区加入组，供玩家攻击检测
	if _hurtbox:
		_hurtbox.add_to_group("enemy_hurtbox")
	
	# 连接检测区域信号
	if _detection_area:
		_detection_area.body_entered.connect(_on_body_entered_detection)
		_detection_area.body_exited.connect(_on_body_exited_detection)
	
	health_changed.emit(current_hp, combat_data.enemy_max_hp)

func _physics_process(delta: float) -> void:
	if _ai_state == AIState.DEAD:
		return
	
	_update_timers(delta)
	_update_ai(delta)
	move_and_slide()

# === 计时器 ===
func _update_timers(delta: float) -> void:
	if _attack_cooldown_timer > 0.0:
		_attack_cooldown_timer -= delta
	
	if _ai_state == AIState.HURT:
		_hurt_timer -= delta
		if _hurt_timer <= 0.0:
			_ai_state = AIState.CHASE if _target else AIState.IDLE

# === AI逻辑 ===
func _update_ai(_delta: float) -> void:
	if _ai_state in [AIState.HURT, AIState.DEAD]:
		return
	
	match _ai_state:
		AIState.IDLE:
			_ai_idle()
		AIState.CHASE:
			_ai_chase()
		AIState.ATTACK:
			_ai_attack()

func _ai_idle() -> void:
	velocity = Vector2.ZERO
	
	if _target:
		var dist: float = CombatSystemClass.distance_between(self, _target)
		if dist <= attack_range and _attack_cooldown_timer <= 0.0:
			_ai_state = AIState.ATTACK
		elif dist <= detection_range:
			_ai_state = AIState.CHASE

func _ai_chase() -> void:
	if not _target:
		_ai_state = AIState.IDLE
		return
	
	var dist: float = CombatSystemClass.distance_between(self, _target)
	
	if dist <= attack_range:
		if _attack_cooldown_timer <= 0.0:
			_ai_state = AIState.ATTACK
			velocity = Vector2.ZERO
		else:
			# 等待攻击冷却，保持距离
			velocity = Vector2.ZERO
	elif dist > detection_range * 1.5:
		# 超出追击范围，回到待机
		_target = null
		_ai_state = AIState.IDLE
		velocity = Vector2.ZERO
	else:
		var dir: Vector2 = CombatSystemClass.direction_to(self, _target)
		velocity = dir * combat_data.enemy_move_speed
		
		# 翻转精灵朝向
		if _sprite:
			_sprite.flip_h = dir.x < 0

func _ai_attack() -> void:
	if not _target:
		_ai_state = AIState.IDLE
		return
	
	if _attack_cooldown_timer > 0.0:
		_ai_state = AIState.CHASE
		return
	
	var dist: float = CombatSystemClass.distance_between(self, _target)
	
	if dist > attack_range * 1.5:
		_ai_state = AIState.CHASE
		return
	
	# 执行攻击
	_attack_cooldown_timer = combat_data.enemy_attack_cooldown
	enemy_attack_started.emit()
	
	if _animation_player and _animation_player.has_animation("attack"):
		_animation_player.play("attack")
	
	# 短暂延迟后造成伤害
	await get_tree().create_timer(0.3).timeout
	
	if _ai_state == AIState.DEAD:
		return
	
	if _target and CombatSystemClass.distance_between(self, _target) <= attack_range * 1.5:
		var result: Dictionary = CombatSystemClass.calculate_damage(
			combat_data.enemy_attack,
			10.0  # 玩家默认防御
		)
		_target.take_damage(result["damage"])
		if _eb: _eb.damage_number_request.emit(
			result["damage"],
			_target.global_position + Vector2(0, -40),
			result["is_critical"]
		)
	
	_ai_state = AIState.CHASE

# === 受击 ===
func take_damage(damage: float) -> void:
	if _ai_state == AIState.DEAD:
		return
	
	current_hp = maxf(current_hp - damage, 0.0)
	health_changed.emit(current_hp, combat_data.enemy_max_hp)
	
	# 受击反馈
	_flash_white()
	
	if current_hp <= 0.0:
		_die()
	else:
		_ai_state = AIState.HURT
		_hurt_timer = 0.3  # 0.3秒硬直

func _die() -> void:
	_ai_state = AIState.DEAD
	enemy_died.emit(enemy_display_name)
	if _eb: _eb.enemy_died.emit(enemy_display_name)
	
	if _animation_player and _animation_player.has_animation("death"):
		_animation_player.play("death")
	
	# 延迟移除
	await get_tree().create_timer(0.5).timeout
	queue_free()

# === 碰撞检测 ===
func _on_body_entered_detection(body: Node2D) -> void:
	if body is PlayerControllerClass:
		_target = body
		if _ai_state == AIState.IDLE:
			_ai_state = AIState.CHASE

func _on_body_exited_detection(body: Node2D) -> void:
	if body == _target:
		_target = null
		if _ai_state != AIState.HURT:
			_ai_state = AIState.IDLE

# === 视觉效果 ===
func _flash_white() -> void:
	if _sprite:
		var tween: Tween = create_tween()
		tween.tween_property(_sprite, "modulate", Color.WHITE * 1.5, 0.05)
		tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)

## 获取AI状态信息（供调试/HUD）
func get_ai_info() -> Dictionary:
	return {
		"state": _ai_state,
		"current_hp": current_hp,
		"max_hp": combat_data.enemy_max_hp if combat_data else 200.0,
		"attack_ready": _attack_cooldown_timer <= 0.0,
	}
