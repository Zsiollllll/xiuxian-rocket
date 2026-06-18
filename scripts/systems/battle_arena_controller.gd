## BattleArenaController — 双路线战斗竞技场
## 根据玩家选择的路线加载对应的控制器和HUD
class_name BattleArenaController
extends Node

const CultivationControllerClass = preload("res://scripts/player/cultivation_controller.gd")
const TechControllerClass = preload("res://scripts/player/tech_controller.gd")
const EnemyBaseClass = preload("res://scripts/enemy/enemy_base.gd")

var _player = null
var _hud = null
var _current_enemy = null
var _battle_arena = null

var _current_wave: int = 0
var _total_waves: int = 3
var _alive_enemies: int = 0
var _wave_active: bool = false
var _eb = null

var _enemy_scene: PackedScene = preload("res://scenes/enemy.tscn")

func _ready() -> void:
	call_deferred("_deferred_init")

func _deferred_init() -> void:
	_eb = get_node_or_null("/root/EventBus")
	
	var route: String = ""
	if _eb and _eb.has_meta("selected_route"):
		route = _eb.get_meta("selected_route")
	
	_setup_player(route)
	_setup_hud()
	_connect_signals()
	_start_first_wave()

func _setup_player(route: String) -> void:
	_battle_arena = get_node_or_null("../BattleArena")
	if not _battle_arena:
		_battle_arena = get_parent().get_node_or_null("BattleArena")
	if not _battle_arena:
		return
	
	var spawn = _battle_arena.get_node_or_null("PlayerSpawn")
	if not spawn:
		return
	
	var player_node = spawn.get_node_or_null("Player")
	if not player_node:
		return
	
	if route == "tech":
		player_node.set_script(TechControllerClass)
	else:
		player_node.set_script(CultivationControllerClass)
	
	_player = player_node
	if _player and _player.has_method("_initialize"):
		_player._initialize()

func _setup_hud() -> void:
	_hud = get_node_or_null("../HUD")
	if not _hud:
		_hud = get_parent().get_node_or_null("HUD")
	if not _hud or not _player:
		return
	
	if _player is CultivationControllerClass:
		if _hud.has_method("bind_cultivation_player"):
			_hud.bind_cultivation_player(_player)
	elif _player is TechControllerClass:
		if _hud.has_method("bind_tech_player"):
			_hud.bind_tech_player(_player)

func _connect_signals() -> void:
	if _eb:
		if not _eb.enemy_died.is_connected(_on_enemy_died):
			_eb.enemy_died.connect(_on_enemy_died)
	
	if _player:
		if not _player.player_died.is_connected(_on_player_died):
			_player.player_died.connect(_on_player_died)

func _start_first_wave() -> void:
	_start_wave(1)

func _start_wave(wave_num: int) -> void:
	_current_wave = wave_num
	_wave_active = true
	
	if _hud and _hud.has_method("set_wave"):
		_hud.set_wave(wave_num, _total_waves)
	
	var enemy_count: int = wave_num + 1
	for i in range(enemy_count):
		var offset_x: float = (i - (enemy_count - 1) / 2.0) * 80.0
		var spawn_pos: Vector2 = Vector2(195 + offset_x, 200)
		_spawn_enemy(spawn_pos)

func _spawn_enemy(position: Vector2) -> void:
	if not _battle_arena:
		return
	
	var enemy = _enemy_scene.instantiate()
	_battle_arena.add_child(enemy)
	enemy.global_position = position
	
	if not enemy.enemy_died.is_connected(_on_single_enemy_died):
		enemy.enemy_died.connect(_on_single_enemy_died)
	
	_alive_enemies += 1
	
	if _alive_enemies == 1 and _hud and _hud.has_method("bind_enemy"):
		_hud.bind_enemy(enemy)

func _on_single_enemy_died(_name: String) -> void:
	pass

func _on_enemy_died(_name: String) -> void:
	_alive_enemies -= 1
	if _alive_enemies <= 0:
		_check_wave_complete()

func _on_player_died() -> void:
	_wave_active = false

func _check_wave_complete() -> void:
	_wave_active = false
	if _current_wave >= _total_waves:
		if _eb:
			_eb.stage_completed.emit(_calculate_stars())
	else:
		await get_tree().create_timer(1.0).timeout
		_start_wave(_current_wave + 1)

func _calculate_stars() -> int:
	if not _player:
		return 3
	var hp_ratio: float = _player.current_hp / _player.combat_data.player_max_hp
	if hp_ratio > 0.8: return 3
	elif hp_ratio > 0.4: return 2
	else: return 1
