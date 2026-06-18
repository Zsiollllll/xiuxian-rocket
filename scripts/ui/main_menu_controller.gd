## MainMenuController — 主菜单流程控制（纯代码构建版）
## 所有UI元素在_ready()中动态创建，避免TSCN兼容性问题
class_name MainMenuController
extends Control

const SaveSystemClass = preload("res://scripts/systems/save_system.gd")

# UI 引用（动态创建）
var _title_page: Control = null
var _route_select_page: Control = null
var _loading_page: Control = null

var _btn_new_game: Button = null
var _btn_continue: Button = null
var _btn_settings: Button = null

var _btn_cultivation: Button = null
var _btn_tech: Button = null
var _btn_back: Button = null
var _cultivation_desc: RichTextLabel = null
var _tech_desc: RichTextLabel = null

var _loading_label: Label = null
var _loading_bar: ProgressBar = null

var _selected_route: String = ""
var _save_data = null

func _ready() -> void:
	_build_ui()
	_connect_signals()
	_initialize_ui()

## 动态构建所有UI
func _build_ui() -> void:
	# 背景
	var bg := ColorRect.new()
	bg.name = "Background"
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.02, 0.08)
	add_child(bg)
	
	# 标题页
	_title_page = Control.new()
	_title_page.name = "TitlePage"
	_title_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_title_page)
	
	# 标题
	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "修仙？我直接架火箭"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.3, 0.7, 1))
	title.position = Vector2(20, 150)
	title.size = Vector2(350, 60)
	_title_page.add_child(title)
	
	# 副标题
	var subtitle := Label.new()
	subtitle.name = "SubtitleLabel"
	subtitle.text = "穿越修仙世界，选择你的命运"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	subtitle.position = Vector2(40, 250)
	subtitle.size = Vector2(310, 30)
	_title_page.add_child(subtitle)
	
	# 新的旅程按钮
	_btn_new_game = Button.new()
	_btn_new_game.name = "BtnNewGame"
	_btn_new_game.text = "新的旅程"
	_btn_new_game.add_theme_font_size_override("font_size", 22)
	_btn_new_game.position = Vector2(80, 380)
	_btn_new_game.size = Vector2(230, 60)
	_title_page.add_child(_btn_new_game)
	
	# 继续修行按钮
	_btn_continue = Button.new()
	_btn_continue.name = "BtnContinue"
	_btn_continue.text = "继续修行"
	_btn_continue.add_theme_font_size_override("font_size", 22)
	_btn_continue.position = Vector2(80, 470)
	_btn_continue.size = Vector2(230, 60)
	_btn_continue.visible = false  # 默认隐藏，后面检查存档后显示
	_title_page.add_child(_btn_continue)
	
	# 设置按钮
	_btn_settings = Button.new()
	_btn_settings.name = "BtnSettings"
	_btn_settings.text = "设置"
	_btn_settings.add_theme_font_size_override("font_size", 16)
	_btn_settings.position = Vector2(130, 580)
	_btn_settings.size = Vector2(130, 40)
	_title_page.add_child(_btn_settings)
	
	# 版本号
	var version := Label.new()
	version.name = "VersionLabel"
	version.text = "v0.1.0 原型版"
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	version.position = Vector2(150, 800)
	version.size = Vector2(90, 20)
	_title_page.add_child(version)
	
	# 路线选择页
	_route_select_page = Control.new()
	_route_select_page.name = "RouteSelectPage"
	_route_select_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_route_select_page.visible = false
	add_child(_route_select_page)
	
	# 路线选择标题
	var route_title := Label.new()
	route_title.name = "RouteTitle"
	route_title.text = "选择你的道路"
	route_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	route_title.add_theme_font_size_override("font_size", 28)
	route_title.add_theme_color_override("font_color", Color.WHITE)
	route_title.position = Vector2(20, 60)
	route_title.size = Vector2(350, 40)
	_route_select_page.add_child(route_title)
	
	# 修仙描述
	_cultivation_desc = RichTextLabel.new()
	_cultivation_desc.name = "CultivationDesc"
	_cultivation_desc.bbcode_enabled = true
	_cultivation_desc.fit_content = true
	_cultivation_desc.scroll_active = false
	_cultivation_desc.position = Vector2(20, 140)
	_cultivation_desc.size = Vector2(350, 200)
	_cultivation_desc.text = _get_cultivation_desc()
	_route_select_page.add_child(_cultivation_desc)
	
	# 修仙按钮
	_btn_cultivation = Button.new()
	_btn_cultivation.name = "BtnCultivation"
	_btn_cultivation.text = "选择修仙之路"
	_btn_cultivation.add_theme_font_size_override("font_size", 20)
	_btn_cultivation.position = Vector2(40, 350)
	_btn_cultivation.size = Vector2(310, 55)
	_route_select_page.add_child(_btn_cultivation)
	
	# 军工描述
	_tech_desc = RichTextLabel.new()
	_tech_desc.name = "TechDesc"
	_tech_desc.bbcode_enabled = true
	_tech_desc.fit_content = true
	_tech_desc.scroll_active = false
	_tech_desc.position = Vector2(20, 420)
	_tech_desc.size = Vector2(350, 200)
	_tech_desc.text = _get_tech_desc()
	_route_select_page.add_child(_tech_desc)
	
	# 军工按钮
	_btn_tech = Button.new()
	_btn_tech.name = "BtnTech"
	_btn_tech.text = "选择军工之路"
	_btn_tech.add_theme_font_size_override("font_size", 20)
	_btn_tech.position = Vector2(40, 630)
	_btn_tech.size = Vector2(310, 55)
	_route_select_page.add_child(_btn_tech)
	
	# 返回按钮
	_btn_back = Button.new()
	_btn_back.name = "BtnBack"
	_btn_back.text = "返回"
	_btn_back.position = Vector2(120, 770)
	_btn_back.size = Vector2(150, 40)
	_route_select_page.add_child(_btn_back)
	
	# 加载页
	_loading_page = Control.new()
	_loading_page.name = "LoadingPage"
	_loading_page.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_page.visible = false
	add_child(_loading_page)
	
	_loading_label = Label.new()
	_loading_label.name = "LoadingLabel"
	_loading_label.text = "世界构建中..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 20)
	_loading_label.position = Vector2(50, 390)
	_loading_label.size = Vector2(290, 40)
	_loading_page.add_child(_loading_label)
	
	_loading_bar = ProgressBar.new()
	_loading_bar.name = "LoadingBar"
	_loading_bar.position = Vector2(65, 450)
	_loading_bar.size = Vector2(260, 20)
	_loading_bar.value = 0.0
	_loading_bar.show_percentage = false
	_loading_page.add_child(_loading_bar)

func _connect_signals() -> void:
	_btn_new_game.pressed.connect(_on_new_game)
	_btn_continue.pressed.connect(_on_continue)
	_btn_cultivation.pressed.connect(_on_select_cultivation)
	_btn_tech.pressed.connect(_on_select_tech)
	_btn_back.pressed.connect(_on_back_to_title)

func _initialize_ui() -> void:
	# 检查是否有存档
	if SaveSystemClass.has_any_save():
		_btn_continue.visible = true
	else:
		_btn_continue.visible = false

func _show_title() -> void:
	_title_page.visible = true
	_route_select_page.visible = false
	_loading_page.visible = false
	if SaveSystemClass.has_any_save():
		_btn_continue.visible = true
	else:
		_btn_continue.visible = false

func _show_route_select() -> void:
	_title_page.visible = false
	_route_select_page.visible = true
	_loading_page.visible = false
	_cultivation_desc.text = _get_cultivation_desc()
	_tech_desc.text = _get_tech_desc()

func _show_loading() -> void:
	_title_page.visible = false
	_route_select_page.visible = false
	_loading_page.visible = true
	if _loading_bar:
		_loading_bar.value = 0.0

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
	return """[center][color=#4fc3f7]🏯 修仙之路[/color][/center]

[b]修炼体系[/b]
  炼气 → 筑基 → 金丹 → 元婴
  → 化神 → 渡劫 → 大乘

[b]核心机制[/b]
  · 灵力管理 — 自动回复，消耗施法
  · 法术连击 — 连续命中伤害递增
  · 元素反应 — 火冰雷相互配合

[b]战斗风格[/b]
  爆发型输出，灵活闪避"""

func _get_tech_desc() -> String:
	return """[center][color=#ff6b35]🔧 军工之路[/color][/center]

[b]科技体系[/b]
  基础工坊 → 精密加工 → 动力核心
  → 机甲原型 → 重工量产
  → 核聚变引擎 → 星际科技

[b]核心机制[/b]
  · 弹药管理 — 弹匣换弹，资源规划
  · 过热系统 — 控制热量，防止宕机
  · 武器切换 — 多武器应对不同敌人

[b]战斗风格[/b]
  持续输出型，高攻脆皮"""
