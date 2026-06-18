## BattleHUD — 战斗界面控制器
## 管理所有战斗UI元素：血条、技能按钮、闪避冷却、伤害数字。
class_name BattleHUD
extends Control

# === 外部依赖 preload（headless 兼容：class_name 无法跨文件解析） ===
const TouchInputAreaClass = preload("res://scripts/ui/touch_input_area.gd")
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const EnemyBaseClass = preload("res://scripts/enemy/enemy_base.gd")
const DamageNumberClass = preload("res://scripts/ui/damage_number.gd")

# === 节点引用 ===
@onready var _player_hp_bar: ProgressBar = $PlayerInfo/HPBar
@onready var _player_hp_label: Label = $PlayerInfo/HPLabel
@onready var _skill_button: Button = $SkillPanel/SkillButton
@onready var _skill_cooldown_label: Label = $SkillPanel/CooldownLabel
@onready var _dodge_indicator: ColorRect = $DodgeIndicator
@onready var _dodge_label: Label = $DodgeIndicator/Label
@onready var _touch_area = $TouchArea
@onready var _damage_layer: Control = $DamageLayer
@onready var _enemy_hp_bar: ProgressBar = $EnemyInfo/HPBar
@onready var _enemy_hp_label: Label = $EnemyInfo/HPLabel
@onready var _enemy_name_label: Label = $EnemyInfo/NameLabel
@onready var _wave_label: Label = $WaveInfo/WaveLabel

# === 引用到游戏对象 ===
var _player = null
var _current_enemy = null

# === EventBus 缓存 (headless兼容) ===
var _eb = null

# === 伤害数字预制体 ===
var _damage_number_scene: PackedScene = preload("res://scenes/damage_number.tscn")

func _ready() -> void:
	_eb = get_node_or_null("/root/EventBus")
	_connect_signals()
	_initialize_ui()

func _initialize_ui() -> void:
	if _player_hp_bar:
		_player_hp_bar.value = 100.0
	if _skill_button:
		_skill_button.disabled = false
	if _skill_cooldown_label:
		_skill_cooldown_label.visible = false
	if _dodge_indicator:
		_dodge_indicator.visible = false
	if _enemy_hp_bar:
		_enemy_hp_bar.visible = false
	_enemy_info_visible(false)

func _connect_signals() -> void:
	# 触摸输入 → 转发给玩家
	_touch_area.touch_event.connect(_on_touch_event)
	
	# 技能按钮
	_skill_button.pressed.connect(_on_skill_pressed)
	
	# EventBus
	if _eb: _eb.damage_number_request.connect(_on_damage_number_request)
	if _eb: _eb.enemy_died.connect(_on_enemy_died)
	if _eb: _eb.player_damaged.connect(_on_player_damaged)
	if _eb: _eb.player_died.connect(_on_player_died)

# === 外部接口 ===

## 绑定玩家
func bind_player(player) -> void:
	_player = player
	if _player and _player_hp_bar:
		_player.health_changed.connect(_on_player_health_changed)
		_player.skill_used.connect(_on_skill_used)
		_player.dodge_used.connect(_on_dodge_used)
		_player_hp_bar.max_value = _player.combat_data.player_max_hp
		_player_hp_bar.value = _player.current_hp
		_update_hp_label(_player_hp_label, _player.current_hp, _player.combat_data.player_max_hp)

## 绑定当前敌人
func bind_enemy(enemy) -> void:
	if _current_enemy:
		_current_enemy.health_changed.disconnect(_on_enemy_health_changed)
	
	_current_enemy = enemy
	if _current_enemy and _enemy_hp_bar:
		_current_enemy.health_changed.connect(_on_enemy_health_changed)
		_enemy_hp_bar.max_value = _current_enemy.combat_data.enemy_max_hp
		_enemy_hp_bar.value = _current_enemy.current_hp
		_enemy_name_label.text = _current_enemy.enemy_display_name
		_enemy_info_visible(true)
		_update_hp_label(_enemy_hp_label, _current_enemy.current_hp, _current_enemy.combat_data.enemy_max_hp)

## 设置波次信息
func set_wave(current: int, total: int) -> void:
	if _wave_label:
		_wave_label.text = "第 %d / %d 波" % [current, total]

# === 信号处理 ===
func _on_touch_event(event_type: String, position: Vector2, direction: Vector2) -> void:
	if _player:
		_player.on_touch_event(event_type, position, direction)

func _on_skill_pressed() -> void:
	if _player:
		_player.use_skill()

func _on_player_health_changed(current_hp: float, max_hp: float) -> void:
	if not _player_hp_bar:
		return
	_player_hp_bar.value = current_hp
	_update_hp_label(_player_hp_label, current_hp, max_hp)
	
	# 低血量警告
	if max_hp > 0 and current_hp / max_hp < 0.3:
		_player_hp_bar.add_theme_color_override("font_color", Color.RED)
	else:
		_player_hp_bar.remove_theme_color_override("font_color")

func _on_enemy_health_changed(current_hp: float, max_hp: float) -> void:
	if not _enemy_hp_bar:
		return
	_enemy_hp_bar.value = current_hp
	_update_hp_label(_enemy_hp_label, current_hp, max_hp)

func _on_skill_used(skill_name: String, cooldown: float) -> void:
	if _skill_button:
		_skill_button.disabled = true
	if _skill_cooldown_label:
		_skill_cooldown_label.visible = true
		_skill_cooldown_label.text = "%.1fs" % cooldown
	
	# 冷却倒计时
	var timer: SceneTreeTimer = get_tree().create_timer(cooldown)
	timer.timeout.connect(_on_skill_ready)

func _on_skill_ready() -> void:
	if _skill_button:
		_skill_button.disabled = false
	if _skill_cooldown_label:
		_skill_cooldown_label.visible = false

func _on_dodge_used(cooldown: float) -> void:
	if _dodge_indicator:
		_dodge_indicator.visible = true
	if _dodge_label:
		_dodge_label.text = "闪避冷却 %.1fs" % cooldown
	
	var timer: SceneTreeTimer = get_tree().create_timer(cooldown)
	timer.timeout.connect(_on_dodge_ready)

func _on_dodge_ready() -> void:
	if _dodge_indicator:
		_dodge_indicator.visible = false

func _on_damage_number_request(damage: float, position: Vector2, is_critical: bool) -> void:
	_spawn_damage_number(damage, position, is_critical)

func _on_enemy_died(enemy_name: String) -> void:
	_enemy_info_visible(false)
	_current_enemy = null

func _on_player_damaged(damage: float, current_hp: float) -> void:
	pass  # 已通过health_changed处理UI更新

func _on_player_died() -> void:
	if _skill_button:
		_skill_button.disabled = true
	# 显示死亡/复活弹窗（原型阶段简单处理）
	var label: Label = Label.new()
	label.text = "你倒下了..."
	label.add_theme_font_size_override("font_size", 36)
	label.add_theme_color_override("font_color", Color.RED)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(300, 100)
	label.position = Vector2(45, 350)
	add_child(label)

# === 辅助方法 ===
func _spawn_damage_number(damage: float, world_pos: Vector2, is_critical: bool) -> void:
	if not _damage_layer:
		return
	var dn = _damage_number_scene.instantiate()
	_damage_layer.add_child(dn)
	
	# 世界坐标转UI坐标（简化：直接使用相对于DamageLayer的坐标）
	dn.position = world_pos - Vector2(0, 60)
	dn.setup(damage, is_critical)

func _update_hp_label(label: Label, current: float, maximum: float) -> void:
	if label:
		label.text = "%d / %d" % [int(current), int(maximum)]

func _enemy_info_visible(visible: bool) -> void:
	if _enemy_hp_bar:
		_enemy_hp_bar.visible = visible
	if _enemy_hp_label:
		_enemy_hp_label.visible = visible
	if _enemy_name_label:
		_enemy_name_label.visible = visible
