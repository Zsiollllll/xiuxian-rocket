## MainMenuController — 主菜单流程控制
## 管理：标题画面 → 路线选择 → 进入战斗 的完整流程
class_name MainMenuController
extends Control

const SaveSystemClass = preload("res://scripts/systems/save_system.gd")

# === 节点（在_ready中初始化） ===
var _title_page = null
var _route_select_page = null
var _loading_page = null
var _btn_new_game = null
var _btn_continue = null
var _btn_settings = null
var _version_label = null
var _btn_cultivation = null
var _btn_tech = null
var _btn_back = null
var _cultivation_desc = null
var _tech_desc = null
var _loading_label = null
var _loading_bar = null

var _selected_route: String = ""
var _save_data = null

func _ready() -> void:
	_init_nodes()
	_initialize_ui()
	_connect_signals()

func _init_nodes() -> void:
	_title_page = get_node_or_null("TitlePage")
	_route_select_page = get_node_or_null("RouteSelectPage")
	_loading_page = get_node_or_null("LoadingPage")
	
	if _title_page:
		_btn_new_game = _title_page.get_node_or_null("BtnNewGame")
		_btn_continue = _title_page.get_node_or_null("BtnContinue")
		_btn_settings = _title_page.get_node_or_null("BtnSettings")
		_version_label = _title_page.get_node_or_null("VersionLabel")
	
	if _route_select_page:
		_btn_cultivation = _route_select_page.get_node_or_null("BtnCultivation")
		_btn_tech = _route_select_page.get_node_or_null("BtnTech")
		_btn_back = _route_select_page.get_node_or_null("BtnBack")
		_cultivation_desc = _route_select_page.get_node_or_null("CultivationDesc")
		_tech_desc = _route_select_page.get_node_or_null("TechDesc")
	
	if _loading_page:
		_loading_label = _loading_page.get_node_or_null("LoadingLabel")
		_loading_bar = _loading_page.get_node_or_null("LoadingBar")

func _initialize_ui() -> void:
	if _title_page: _title_page.visible = true
	if _route_select_page: _route_select_page.visible = false
	if _loading_page: _loading_page.visible = false
	
	if _btn_continue:
		_btn_continue.visible = SaveSystemClass.has_any_save()
	if _version_label:
		_version_label.text = "v0.1.0 原型版"

func _connect_signals() -> void:
	if _btn_new_game: _btn_new_game.pressed.connect(_on_new_game)
	if _btn_continue: _btn_continue.pressed.connect(_on_continue)
	if _btn_cultivation: _btn_cultivation.pressed.connect(_on_select_cultivation)
	if _btn_tech: _btn_tech.pressed.connect(_on_select_tech)
	if _btn_back: _btn_back.pressed.connect(_on_back_to_title)

func _show_title() -> void:
	if _title_page: _title_page.visible = true
	if _route_select_page: _route_select_page.visible = false
	if _loading_page: _loading_page.visible = false
	if _btn_continue: _btn_continue.visible = SaveSystemClass.has_any_save()

func _show_route_select() -> void:
	if _title_page: _title_page.visible = false
	if _route_select_page: _route_select_page.visible = true
	if _loading_page: _loading_page.visible = false
	if _cultivation_desc: _cultivation_desc.text = _get_cultivation_desc()
	if _tech_desc: _tech_desc.text = _get_tech_desc()

func _show_loading() -> void:
	if _title_page: _title_page.visible = false
	if _route_select_page: _route_select_page.visible = false
	if _loading_page: _loading_page.visible = true
	if _loading_label: _loading_label.text = "世界构建中..."
	if _loading_bar: _loading_bar.value = 0.0

func _on_new_game() -> void:
	_show_route_select()

func _on_continue() -> void:
	for i in range(3, 0, -1):
		var info: Dictionary = SaveSystemClass.get_slot_info(i)
		if info["exists"]:
			_save_data = SaveSystemClass.load_game(i)
			_selected_route = _save_data.route
			_show_loading()
			_start_battle()
			return
	_show_title()

func _on_select_cultivation() -> void:
	_selected_route = "cultivation"
	_save_data = SaveSystemClass.create_new_data("cultivation")
	_show_loading()
	_start_battle()

func _on_select_tech() -> void:
	_selected_route = "tech"
	_save_data = SaveSystemClass.create_new_data("tech")
	_show_loading()
	_start_battle()

func _on_back_to_title() -> void:
	_show_title()

func _start_battle() -> void:
	if _loading_bar:
		var tween: Tween = create_tween()
		tween.tween_property(_loading_bar, "value", 1.0, 1.5)
		tween.tween_callback(_launch_battle_scene)
	else:
		_launch_battle_scene()

func _launch_battle_scene() -> void:
	var eb = get_node_or_null("/root/EventBus")
	if eb:
		eb.set_meta("selected_route", _selected_route)
	get_tree().change_scene_to_file("res://scenes/battle_arena.tscn")

func _get_cultivation_desc() -> String:
	return """[center][b][color=#4fc3f7]🏯 修仙之路[/color][/b][/center]

[b]修炼体系[/b]
  炼气 → 筑基 → 金丹 → 元婴
  → 化神 → 渡劫 → 大乘

[b]核心机制[/b]
  · 灵力管理 — 自动回复，消耗施法
  · 法术连击 — 连续命中伤害递增
  · 元素反应 — 火冰雷相互配合
  · 法宝养成 — 多种法宝自由搭配

[b]战斗风格[/b]
  爆发型输出，灵活闪避
  适合喜欢[color=#4fc3f7]技能连招[/color]的玩家"""

func _get_tech_desc() -> String:
	return """[center][b][color=#ff6b35]🔧 军工之路[/color][/b][/center]

[b]科技体系[/b]
  基础工坊 → 精密加工 → 动力核心
  → 机甲原型 → 重工量产
  → 核聚变引擎 → 星际科技

[b]核心机制[/b]
  · 弹药管理 — 弹匣换弹，资源规划
  · 过热系统 — 控制热量，防止宕机
  · 武器切换 — 多武器应对不同敌人
  · 重型火力 — 核弹级范围打击

[b]战斗风格[/b]
  持续输出型，高攻脆皮
  适合喜欢[color=#ff6b35]策略规划[/color]的玩家"""
