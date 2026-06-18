## TechController — 军工体系战斗控制器
## 核心机制：弹药管理 + 过热系统 + 武器切换
## 单手竖屏操作：点击=射击 / 滑动=闪避 / 按钮=重武器
class_name TechController
extends CharacterBody2D

# === 外部依赖 ===
const CombatDataClass = preload("res://resources/combat_data.gd")
const CombatSystemClass = preload("res://scripts/systems/combat_system.gd")
const EnemyBaseClass = preload("res://scripts/enemy/enemy_base.gd")

# === 信号 ===
signal health_changed(current_hp: float, max_hp: float)
signal ammo_changed(current: int, maximum: int)
signal overheat_changed(heat: float, max_heat: float)
signal player_died
signal skill_used(skill_name: String, cooldown: float)
signal dodge_used(cooldown: float)
signal weapon_switched(weapon_name: String)

# === 属性 ===
@export var combat_data: Resource  ## CombatData 实例

## 当前血量
var current_hp: float = 0.0

# === 弹药系统 ===
enum AmmoType { NORMAL, ARMOR_PIERCING, EXPLOSIVE, ENERGY }
var _current_ammo_type: AmmoType = AmmoType.NORMAL
var _magazine_current: int = 12
var _magazine_max: int = 12
var _ammo_reserves: Dictionary = {
	AmmoType.NORMAL: 100,
	AmmoType.ARMOR_PIERCING: 40,
	AmmoType.EXPLOSIVE: 25,
	AmmoType.ENERGY: 60,
}
var _reloading: bool = false
var _reload_timer: float = 0.0
const RELOAD_TIME: float = 1.8  ## 换弹时间(秒)

# === 过热系统 ===
var _heat: float = 0.0
var _max_heat: float = 100.0
var _overheated: bool = false
var _overheat_cooldown_timer: float = 0.0
const HEAT_PER_SHOT: float = 5.0
const HEAT_COOLDOWN_RATE: float = 15.0  ## 每秒散热
const OVERHEAT_PENALTY_TIME: float = 2.5  ## 过热强制冷却时间

# === 战斗状态 ===
enum CombatState { IDLE, ATTACKING, DODGING, USING_SKILL, RELOADING, OVERHEATED, DEAD, STUNNED }
var _state: CombatState = CombatState.IDLE
var _attack_timer: float = 0.0
var _dodge_timer: float = 0.0
var _dodge_cooldown_timer: float = 0.0
var _skill_cooldown_timer: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _is_invincible: bool = false
var _invincible_timer: float = 0.0
var _stun_timer: float = 0.0

# === 武器系统 ===
enum WeaponType { RIFLE, SHOTGUN, ENERGY_RIFLE, GRENADE_LAUNCHER }
var _current_weapon: WeaponType = WeaponType.RIFLE
var _weapons_unlocked: Array[WeaponType] = [WeaponType.RIFLE]
var _turret_active: bool = false
var _turret_count: int = 0

# === 节点引用 ===
@onready var _sprite: Sprite2D = $Sprite2D
@onready var _animation_player: AnimationPlayer = $AnimationPlayer
@onready var _hitbox: Area2D = $Hitbox
@onready var _invincible_timer_node: Timer = $InvincibleTimer

# === EventBus 缓存 ===
var _eb = null

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
	_heat = 0.0
	_magazine_current = _magazine_max
	_state = CombatState.IDLE
	
	if _invincible_timer_node:
		_invincible_timer_node.timeout.connect(_on_invincible_end)
	
	health_changed.emit(current_hp, combat_data.player_max_hp)
	ammo_changed.emit(_magazine_current, _magazine_max)
	overheat_changed.emit(_heat, _max_heat)

func _physics_process(delta: float) -> void:
	if _state == CombatState.DEAD:
		return
	
	_update_heat(delta)
	_update_timers(delta)
	_update_state(delta)
	_handle_movement(delta)

# ============================================
# 热量管理
# ============================================
func _update_heat(delta: float) -> void:
	if _state == CombatState.OVERHEATED:
		_overheat_cooldown_timer -= delta
		if _overheat_cooldown_timer <= 0.0:
			_overheated = false
			_heat = 60.0  ## 冷却到60%
			_set_state(CombatState.IDLE)
			overheat_changed.emit(_heat, _max_heat)
		return
	
	if _heat > 0.0 and _state != CombatState.ATTACKING:
		_heat = maxf(_heat - HEAT_COOLDOWN_RATE * delta, 0.0)
		overheat_changed.emit(_heat, _max_heat)

func add_heat(amount: float) -> void:
	if _overheated:
		return
	
	_heat = minf(_heat + amount, _max_heat)
	overheat_changed.emit(_heat, _max_heat)
	
	if _heat >= _max_heat:
		_overheat()

func _overheat() -> void:
	_overheated = true
	_overheat_cooldown_timer = OVERHEAT_PENALTY_TIME
	_set_state(CombatState.OVERHEATED)
	overheat_changed.emit(_heat, _max_heat)

func manual_cooldown() -> void:
	## 主动散热（技能）
	if _heat > 30.0:
		_heat = maxf(_heat - 40.0, 0.0)
		overheat_changed.emit(_heat, _max_heat)

# ============================================
# 弹药系统
# ============================================
func _use_ammo() -> bool:
	if _reloading or _magazine_current <= 0:
		return false
	
	_magazine_current -= 1
	ammo_changed.emit(_magazine_current, _magazine_max)
	return true

func reload() -> void:
	if _reloading or _magazine_current >= _magazine_max:
		return
	if _state in [CombatState.DODGING, CombatState.STUNNED, CombatState.DEAD]:
		return
	
	var reserve: int = _ammo_reserves.get(_current_ammo_type, 0)
	if reserve <= 0:
		return  ## 备用弹药耗尽
	
	_reloading = true
	_reload_timer = RELOAD_TIME
	_set_state(CombatState.RELOADING)
	
	await get_tree().create_timer(RELOAD_TIME).timeout
	
	var needed: int = _magazine_max - _magazine_current
	var to_load: int = mini(needed, reserve)
	_magazine_current += to_load
	_ammo_reserves[_current_ammo_type] = reserve - to_load
	_reloading = false
	
	if _state == CombatState.RELOADING:
		_set_state(CombatState.IDLE)
	
	ammo_changed.emit(_magazine_current, _magazine_max)

func switch_ammo(new_type: AmmoType) -> void:
	if _reloading or _state == CombatState.OVERHEATED:
		return
	_current_ammo_type = new_type
	_magazine_current = 0  ## 切换弹药需重新装填
	ammo_changed.emit(_magazine_current, _magazine_max)
	reload()

func _get_ammo_damage_mult() -> float:
	match _current_ammo_type:
		AmmoType.ARMOR_PIERCING: return 0.85  ## 穿甲弹减伤输出但无视40%护甲
		AmmoType.EXPLOSIVE: return 1.3  ## 爆裂弹更高伤害
		AmmoType.ENERGY: return 1.0  ## 能量弹正常但发热
		_: return 1.0

# ============================================
# 计时器
# ============================================
func _update_timers(delta: float) -> void:
	if _attack_timer > 0.0:
		_attack_timer -= delta
	
	if _dodge_timer > 0.0:
		_dodge_timer -= delta
		if _dodge_timer <= 0.0:
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
	if _state in [CombatState.ATTACKING, CombatState.DODGING, CombatState.STUNNED, CombatState.RELOADING, CombatState.OVERHEATED]:
		return
	if _attack_timer > 0.0:
		return
	if _reloading:
		return
	
	if _magazine_current <= 0:
		reload()
		return
	
	if not _use_ammo():
		return
	
	_set_state(CombatState.ATTACKING)
	_attack_timer = combat_data.player_attack_speed
	
	_perform_attack()

func _perform_attack() -> void:
	var enemies: Array[Area2D] = _hitbox.get_overlapping_areas()
	
	for area in enemies:
		if area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy is EnemyBaseClass:
				var base_damage: float = combat_data.player_attack * _get_ammo_damage_mult()
				
				## 穿甲弹：无视部分护甲
				var enemy_def: float = enemy.combat_data.enemy_defense if enemy.combat_data else 5.0
				if _current_ammo_type == AmmoType.ARMOR_PIERCING:
					enemy_def *= 0.6  ## 无视40%护甲
				
				var result: Dictionary = CombatSystemClass.calculate_damage(
					base_damage, enemy_def
				)
				enemy.take_damage(result["damage"])
				
				if _eb:
					_eb.damage_number_request.emit(
						result["damage"],
						enemy.global_position + Vector2(0, -40),
						result["is_critical"]
					)
	
	## 能量武器产热更多
	if _current_ammo_type == AmmoType.ENERGY:
		add_heat(HEAT_PER_SHOT * 1.5)
	else:
		add_heat(HEAT_PER_SHOT)
	
	if _animation_player and _animation_player.has_animation("attack"):
		_animation_player.play("attack")

func _try_dodge(direction: Vector2) -> void:
	if _state == CombatState.DODGING or _dodge_cooldown_timer > 0.0:
		return
	if _state in [CombatState.STUNNED, CombatState.ATTACKING, CombatState.RELOADING, CombatState.OVERHEATED]:
		return
	
	_set_state(CombatState.DODGING)
	_dodge_timer = combat_data.player_dodge_duration
	_dodge_cooldown_timer = combat_data.player_dodge_cooldown
	_dodge_direction = direction.normalized()
	
	_activate_invincibility(combat_data.player_dodge_invincible_duration)
	
	if _animation_player and _animation_player.has_animation("dodge"):
		_animation_player.play("dodge")
	
	dodge_used.emit(combat_data.player_dodge_cooldown)

## 使用重武器（替代通用技能）
func use_heavy_weapon() -> void:
	if _state in [CombatState.DODGING, CombatState.STUNNED, CombatState.DEAD, CombatState.OVERHEATED]:
		return
	if _skill_cooldown_timer > 0.0:
		return
	if _reloading:
		return
	
	_set_state(CombatState.USING_SKILL)
	_skill_cooldown_timer = combat_data.skill_cooldown
	
	var enemies: Array[Area2D] = _hitbox.get_overlapping_areas()
	
	for area in enemies:
		if area.is_in_group("enemy_hurtbox"):
			var enemy = area.get_parent()
			if enemy is EnemyBaseClass:
				var result: Dictionary = CombatSystemClass.calculate_damage(
					combat_data.player_attack,
					enemy.combat_data.enemy_defense if enemy.combat_data else 5.0,
					0.01,
					combat_data.skill_damage_multiplier
				)
				enemy.take_damage(result["damage"])
				
				if _eb:
					_eb.damage_number_request.emit(
						result["damage"],
						enemy.global_position + Vector2(0, -40),
						result["is_critical"]
					)
	
	add_heat(30.0)  ## 重武器产生大量热量
	
	var weapon_name: String = "导弹发射器"
	match _current_weapon:
		WeaponType.GRENADE_LAUNCHER: weapon_name = "榴弹炮"
		_: weapon_name = "导弹发射器"
	
	skill_used.emit(weapon_name, combat_data.skill_cooldown)
	
	await get_tree().create_timer(0.4).timeout
	if _state == CombatState.USING_SKILL:
		_set_state(CombatState.IDLE)

## 切换武器
func switch_weapon(new_weapon: WeaponType) -> void:
	if not new_weapon in _weapons_unlocked:
		return
	_current_weapon = new_weapon
	_magazine_current = _magazine_max
	weapon_switched.emit(_get_weapon_name())

func _get_weapon_name() -> String:
	match _current_weapon:
		WeaponType.RIFLE: return "突击步枪"
		WeaponType.SHOTGUN: return "霰弹枪"
		WeaponType.ENERGY_RIFLE: return "脉冲步枪"
		WeaponType.GRENADE_LAUNCHER: return "榴弹发射器"
		_: return "火铳"

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
	
	if current_hp <= 0.0:
		_die()
	else:
		_stun_timer = 0.15
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
	_heat = 0.0
	_magazine_current = _magazine_max
	_set_state(CombatState.IDLE)
	_attack_timer = 0.0
	_dodge_timer = 0.0
	_dodge_cooldown_timer = 0.0
	_skill_cooldown_timer = 0.0
	_is_invincible = false
	health_changed.emit(current_hp, combat_data.player_max_hp)
	ammo_changed.emit(_magazine_current, _magazine_max)
	overheat_changed.emit(_heat, _max_heat)

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
		tween.tween_property(_sprite, "modulate", Color.ORANGE, 0.2)

func get_state_info() -> Dictionary:
	return {
		"state": _state,
		"system": "tech",
		"ammo_current": _magazine_current,
		"ammo_max": _magazine_max,
		"ammo_type": _current_ammo_type,
		"heat": _heat,
		"max_heat": _max_heat,
		"weapon": _current_weapon,
		"attack_ready": _attack_timer <= 0.0 and _state not in [CombatState.DODGING, CombatState.STUNNED, CombatState.RELOADING],
		"dodge_ready": _dodge_cooldown_timer <= 0.0,
		"dodge_cooldown_remaining": _dodge_cooldown_timer,
		"dodge_cooldown_max": combat_data.player_dodge_cooldown,
		"heavy_ready": _skill_cooldown_timer <= 0.0,
		"heavy_cooldown_remaining": _skill_cooldown_timer,
		"heavy_cooldown_max": combat_data.skill_cooldown,
	}
