## GameController — 战斗流程控制器
## 管理波次、敌人刷新、胜利/失败判定。
class_name GameController
extends Node

# === 外部依赖 preload（headless 兼容：class_name 无法跨文件解析） ===
const PlayerControllerClass = preload("res://scripts/player/player_controller.gd")
const BattleHUDClass = preload("res://scripts/ui/battle_hud.gd")
const EnemyBaseClass = preload("res://scripts/enemy/enemy_base.gd")

# === 波次配置 ===
@export var waves: Array[WaveConfig] = []

# === 引用 ===
var _player = null
var _hud = null
var _enemy_spawn: Marker2D = null
var _current_wave: int = 0
var _total_waves: int = 3
var _alive_enemies: int = 0
var _wave_active: bool = false

# === EventBus 缓存 (headless兼容) ===
var _eb = null

# === 敌人场景 ===
var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

func _ready() -> void:
	# 延迟一帧初始化，确保HUD的@onready变量已就绪
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	_eb = get_node_or_null("/root/EventBus")
	_initialize_references()
	_connect_signals()
	_start_first_wave()

func _initialize_references() -> void:
	# 查找节点
	var arena: Node = get_parent().get_node_or_null("BattleArena")
	if arena:
		var player_node = arena.get_node_or_null("Player")
		if player_node and player_node is PlayerControllerClass:
			_player = player_node
		_enemy_spawn = arena.get_node_or_null("EnemySpawn") as Marker2D
	
	var hud_node = get_parent().get_node_or_null("HUD")
	if hud_node and hud_node is BattleHUDClass:
		_hud = hud_node
	
	if not _player or not _hud:
		push_error("GameController: 无法找到Player或HUD节点！")
		return

func _connect_signals() -> void:
	# 绑定HUD
	_hud.bind_player(_player)
	
	# 玩家死亡
	_player.player_died.connect(_on_player_died)
	
	# 敌人死亡
	if _eb: _eb.enemy_died.connect(_on_enemy_died)

# === 波次管理 ===
func _start_first_wave() -> void:
	_total_waves = waves.size() if waves.size() > 0 else 3
	_start_wave(1)

func _start_wave(wave_num: int) -> void:
	_current_wave = wave_num
	_wave_active = true
	_hud.set_wave(wave_num, _total_waves)
	
	# 获取波次配置或使用默认
	if wave_num <= waves.size():
		var config: WaveConfig = waves[wave_num - 1]
		_spawn_wave_enemies(config)
	else:
		# 默认：每波 wave_num 个敌人
		_spawn_default_wave(wave_num)

func _spawn_default_wave(wave_num: int) -> void:
	var enemy_count: int = wave_num + 1  # 第1波2个，第2波3个...
	
	for i in range(enemy_count):
		# 错开刷新位置
		var offset_x: float = (i - (enemy_count - 1) / 2.0) * 80.0
		var spawn_pos: Vector2 = _enemy_spawn.global_position + Vector2(offset_x, 0)
		_spawn_enemy(spawn_pos)

func _spawn_wave_enemies(config: WaveConfig) -> void:
	for spawn_data in config.enemy_spawns:
		_spawn_enemy(spawn_data.position, spawn_data.enemy_type)

func _spawn_enemy(position: Vector2, enemy_type: String = "basic") -> void:
	var enemy = _enemy_scene.instantiate()
	if not enemy or not (enemy is EnemyBaseClass):
		push_error("GameController: 无法实例化敌人！")
		return
	
	get_parent().get_node("BattleArena").add_child(enemy)
	enemy.global_position = position
	
	# 连接敌人信号
	enemy.enemy_died.connect(func(_name: String): _on_enemy_died(_name))
	
	_alive_enemies += 1
	
	# 如果是第一个敌人，绑定到HUD
	if _alive_enemies == 1 and _hud:
		_hud.bind_enemy(enemy)

# === 事件处理 ===
func _on_enemy_died(_enemy_name: String) -> void:
	_alive_enemies -= 1
	
	if _alive_enemies <= 0:
		_check_wave_complete()

func _on_player_died() -> void:
	_wave_active = false
	
	# 延迟显示失败
	await get_tree().create_timer(1.5).timeout
	if _eb: _eb.stage_failed.emit()

func _check_wave_complete() -> void:
	_wave_active = false
	
	if _current_wave >= _total_waves:
		# 全部通关
		var stars: int = _calculate_stars()
		if _eb: _eb.stage_completed.emit(stars)
	else:
		# 下一波
		await get_tree().create_timer(1.0).timeout
		_start_wave(_current_wave + 1)

func _calculate_stars() -> int:
	# 根据剩余血量评定星级
	if not _player:
		return 3
	var hp_ratio: float = _player.current_hp / _player.combat_data.player_max_hp
	if hp_ratio > 0.8:
		return 3
	elif hp_ratio > 0.4:
		return 2
	else:
		return 1

# === 波次配置资源 ===
class WaveConfig:
	extends Resource
	@export var enemy_spawns: Array[EnemySpawnData] = []

class EnemySpawnData:
	extends Resource
	@export var position: Vector2 = Vector2.ZERO
	@export var enemy_type: String = "basic"
