## DualBattleHUD — 双体系自适应战斗界面 (全代码构建版)
## 所有UI元素在 _ready() 中动态创建，避免TSCN解析问题
class_name DualBattleHUD
extends Control

const CultivationControllerClass = preload("res://scripts/player/cultivation_controller.gd")
const TechControllerClass = preload("res://scripts/player/tech_controller.gd")
const TouchInputAreaClass = preload("res://scripts/ui/touch_input_area.gd")
const DamageNumberClass = preload("res://scripts/ui/damage_number.gd")

# Widget references (created in _ready)
var _player_hp_bar: ProgressBar = null
var _dodge_indicator: ColorRect = null
var _death_overlay: ColorRect = null
var _damage_layer: Control = null
var _touch_area: Control = null

# Cultivation widgets
var _qi_bar: ProgressBar = null
var _combo_label: Label = null
var _spell_button: Button = null
var _spell_cd_label: Label = null
var _btn_fire: Button = null
var _btn_ice: Button = null
var _btn_thunder: Button = null

# Tech widgets
var _ammo_label: Label = null
var _heat_bar: ProgressBar = null
var _reload_button: Button = null
var _btn_normal: Button = null
var _btn_ap: Button = null
var _btn_explosive: Button = null
var _heavy_button: Button = null
var _heavy_cd_label: Label = null

# State
var _player = null
var _current_enemy = null
var _system: String = ""
var _eb = null
var _damage_number_scene: PackedScene = preload("res://scenes/damage_number.tscn")

func _ready() -> void:
	_eb = get_node_or_null("/root/EventBus")
	_build_ui()
	_connect_signals()

# ============================================
# UI 构建
# ============================================
func _build_ui() -> void:
	_build_common()
	_build_cultivation_widgets()
	_build_tech_widgets()
	# Start with cultivation hidden, will be shown by bind_*

func _build_common() -> void:
	# Player HP bar
	_player_hp_bar = _make_progress_bar("PlayerHPBar", 15, 620, 375, 645, 100.0)

	# Dodge indicator
	_dodge_indicator = ColorRect.new()
	_dodge_indicator.name = "DodgeIndicator"
	_dodge_indicator.visible = false
	_dodge_indicator.position = Vector2(80, 550)
	_dodge_indicator.size = Vector2(230, 25)
	_dodge_indicator.color = Color(0.2, 0.2, 0.2, 0.7)
	add_child(_dodge_indicator)
	
	var dl = Label.new()
	dl.name = "DodgeLabel"
	dl.position = Vector2(0, 0)
	dl.size = Vector2(230, 25)
	dl.text = "闪避冷却中..."
	dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dodge_indicator.add_child(dl)

	# Death overlay
	_death_overlay = ColorRect.new()
	_death_overlay.name = "DeathOverlay"
	_death_overlay.visible = false
	_death_overlay.size = Vector2(390, 844)
	_death_overlay.color = Color(0, 0, 0, 0.6)
	add_child(_death_overlay)
	
	var dlab = Label.new()
	dlab.name = "DeathLabel"
	dlab.position = Vector2(70, 380)
	dlab.size = Vector2(250, 50)
	dlab.text = "你倒下了..."
	dlab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlab.add_theme_font_size_override("font_size", 36)
	dlab.add_theme_color_override("font_color", Color.RED)
	_death_overlay.add_child(dlab)

	# Touch area
	_touch_area = Control.new()
	_touch_area.name = "TouchArea"
	_touch_area.position = Vector2(0, 450)
	_touch_area.size = Vector2(390, 210)
	_touch_area.set_script(TouchInputAreaClass)
	add_child(_touch_area)

	# Damage layer
	_damage_layer = Control.new()
	_damage_layer.name = "DamageLayer"
	_damage_layer.size = Vector2(390, 844)
	_damage_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_layer)

	# Wave label
	var wi = Control.new()
	wi.name = "WaveInfo"
	wi.position = Vector2(120, 110)
	wi.size = Vector2(150, 25)
	add_child(wi)
	
	var wl = Label.new()
	wl.name = "WaveLabel"
	wl.size = Vector2(150, 25)
	wl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wi.add_child(wl)

func _build_cultivation_widgets() -> void:
	var y_base: float = 660.0
	
	# Qi bar
	_qi_bar = _make_progress_bar("Cult_QiBar", 15, y_base, 375, 20, 100.0)
	_qi_bar.visible = false
	
	# Element buttons
	_btn_fire = _make_button("Cult_BtnFire", 120, y_base + 22, 45, 20, "火")
	_btn_ice = _make_button("Cult_BtnIce", 170, y_base + 22, 45, 20, "冰")
	_btn_thunder = _make_button("Cult_BtnThunder", 220, y_base + 22, 45, 20, "雷")
	
	# Combo label
	_combo_label = _make_label("Cult_ComboLabel", 280, y_base + 22, 95, 20, "0")
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_size_override("font_size", 18)
	
	# Spell button
	_spell_button = _make_button("Cult_SpellButton", 15, y_base + 50, 360, 50, "释放法术（消耗30灵力）")
	_spell_button.add_theme_font_size_override("font_size", 16)
	
	# Spell CD
	_spell_cd_label = _make_label("Cult_SpellCD", 300, y_base + 55, 70, 40, "")
	_spell_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_spell_cd_label.add_theme_color_override("font_color", Color.RED)
	_spell_cd_label.visible = false

func _build_tech_widgets() -> void:
	var y_base: float = 660.0
	
	# Ammo
	_ammo_label = _make_label("Tech_AmmoLabel", 15, y_base, 180, 25, "12 / 12")
	_ammo_label.add_theme_font_size_override("font_size", 18)
	
	# Reload
	_reload_button = _make_button("Tech_ReloadButton", 280, y_base, 95, 25, "换弹")
	
	# Heat bar
	_heat_bar = _make_progress_bar("Tech_HeatBar", 15, y_base + 30, 360, 18, 0.0)
	
	# Ammo type buttons
	_btn_normal = _make_button("Tech_BtnNormal", 15, y_base + 52, 40, 20, "普")
	_btn_ap = _make_button("Tech_BtnAP", 60, y_base + 52, 45, 20, "穿甲")
	_btn_explosive = _make_button("Tech_BtnExplosive", 110, y_base + 52, 45, 20, "爆裂")
	
	# Heavy button
	_heavy_button = _make_button("Tech_HeavyButton", 15, y_base + 78, 360, 32, "发射重武器")
	_heavy_button.add_theme_font_size_override("font_size", 16)
	
	# Heavy CD
	_heavy_cd_label = _make_label("Tech_HeavyCD", 300, y_base + 82, 70, 26, "")
	_heavy_cd_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_heavy_cd_label.add_theme_color_override("font_color", Color.RED)
	_heavy_cd_label.visible = false

# ============================================
# Signal connections
# ============================================
func _connect_signals() -> void:
	if _eb:
		_eb.damage_number_request.connect(_on_damage_number_request)
		_eb.enemy_died.connect(_on_enemy_died)
		_eb.player_damaged.connect(_on_player_damaged)
		_eb.player_died.connect(_on_player_died)
	if _touch_area and _touch_area.has_signal("touch_event"):
		_touch_area.touch_event.connect(_on_touch_event)

# ============================================
# Route binding
# ============================================
func bind_cultivation_player(player) -> void:
	_player = player
	_system = "cultivation"
	_set_widgets_visible("cult", true)
	_set_widgets_visible("tech", false)
	if _player:
		_player.health_changed.connect(_on_player_health_changed)
		_player.qi_changed.connect(_on_qi_changed)
		_player.combo_changed.connect(_on_combo_changed)
		_player.skill_used.connect(_on_spell_used)
		_player.dodge_used.connect(_on_dodge_used)
		_player_hp_bar.max_value = _player.combat_data.player_max_hp
		_player_hp_bar.value = _player.current_hp
		_qi_bar.max_value = _player.max_qi
		_qi_bar.value = _player.current_qi
		_combo_label.text = "0"
	_connect_cult_buttons()

func bind_tech_player(player) -> void:
	_player = player
	_system = "tech"
	_set_widgets_visible("cult", false)
	_set_widgets_visible("tech", true)
	if _player:
		_player.health_changed.connect(_on_player_health_changed)
		_player.ammo_changed.connect(_on_ammo_changed)
		_player.overheat_changed.connect(_on_overheat_changed)
		_player.skill_used.connect(_on_heavy_used)
		_player.dodge_used.connect(_on_dodge_used)
		_player_hp_bar.max_value = _player.combat_data.player_max_hp
		_player_hp_bar.value = _player.current_hp
		_heat_bar.max_value = _player._max_heat
		_heat_bar.value = _player._heat
		_ammo_label.text = "%d / %d" % [_player._magazine_current, _player._magazine_max]
	_connect_tech_buttons()

func _set_widgets_visible(kind: String, v: bool) -> void:
	if kind == "cult":
		for w in [_qi_bar, _combo_label, _spell_button, _btn_fire, _btn_ice, _btn_thunder]:
			if w: w.visible = v
	else:
		for w in [_ammo_label, _reload_button, _heat_bar, _btn_normal, _btn_ap, _btn_explosive, _heavy_button]:
			if w: w.visible = v

func _connect_cult_buttons() -> void:
	_spell_button.pressed.connect(_on_spell_pressed)
	_btn_fire.pressed.connect(func(): if _player and _player.has_method("set_element"): _player.set_element(1))
	_btn_ice.pressed.connect(func(): if _player and _player.has_method("set_element"): _player.set_element(2))
	_btn_thunder.pressed.connect(func(): if _player and _player.has_method("set_element"): _player.set_element(3))

func _connect_tech_buttons() -> void:
	_heavy_button.pressed.connect(_on_heavy_pressed)
	_reload_button.pressed.connect(func(): if _player and _player.has_method("reload"): _player.reload())
	_btn_normal.pressed.connect(func(): if _player and _player.has_method("switch_ammo"): _player.switch_ammo(0))
	_btn_ap.pressed.connect(func(): if _player and _player.has_method("switch_ammo"): _player.switch_ammo(1))
	_btn_explosive.pressed.connect(func(): if _player and _player.has_method("switch_ammo"): _player.switch_ammo(2))

# ============================================
# Enemy binding
# ============================================
func bind_enemy(enemy) -> void:
	if _current_enemy and _current_enemy.health_changed.is_connected(_on_enemy_health_changed):
		_current_enemy.health_changed.disconnect(_on_enemy_health_changed)
	_current_enemy = enemy

func set_wave(current: int, total: int) -> void:
	var wi = get_node_or_null("WaveInfo")
	if wi:
		var wl = wi.get_node_or_null("WaveLabel")
		if wl: wl.text = "第 %d / %d 波" % [current, total]

# ============================================
# Input handlers
# ============================================
func _on_touch_event(event_type: String, position: Vector2, direction: Vector2) -> void:
	if _player: _player.on_touch_event(event_type, position, direction)

func _on_spell_pressed() -> void:
	if _player and _player.has_method("cast_spell"): _player.cast_spell()

func _on_heavy_pressed() -> void:
	if _player and _player.has_method("use_heavy_weapon"): _player.use_heavy_weapon()

# ============================================
# Player state callbacks
# ============================================
func _on_player_health_changed(current_hp: float, max_hp: float) -> void:
	_player_hp_bar.value = current_hp
	if max_hp > 0 and current_hp / max_hp < 0.3:
		_player_hp_bar.add_theme_color_override("font_color", Color.RED)

func _on_qi_changed(current_qi: float, _max_qi: float) -> void:
	_qi_bar.value = current_qi

func _on_combo_changed(combo: int) -> void:
	_combo_label.text = str(combo)
	if combo >= 5: _combo_label.add_theme_color_override("font_color", Color.GOLD)
	elif combo >= 3: _combo_label.add_theme_color_override("font_color", Color.ORANGE)
	else: _combo_label.add_theme_color_override("font_color", Color.WHITE)

func _on_ammo_changed(current: int, _max: int) -> void:
	_ammo_label.text = "%d / %d" % [current, _max]
	if current <= 3: _ammo_label.add_theme_color_override("font_color", Color.RED)

func _on_overheat_changed(heat: float, _max: float) -> void:
	_heat_bar.value = heat

func _on_spell_used(_name: String, cooldown: float) -> void:
	_spell_button.disabled = true
	_spell_cd_label.visible = true
	_spell_cd_label.text = "%.1f" % cooldown
	get_tree().create_timer(cooldown).timeout.connect(func():
		_spell_button.disabled = false; _spell_cd_label.visible = false)

func _on_heavy_used(_name: String, cooldown: float) -> void:
	_heavy_button.disabled = true
	_heavy_cd_label.visible = true
	_heavy_cd_label.text = "%.1f" % cooldown
	get_tree().create_timer(cooldown).timeout.connect(func():
		_heavy_button.disabled = false; _heavy_cd_label.visible = false)

func _on_dodge_used(cooldown: float) -> void:
	_dodge_indicator.visible = true
	get_tree().create_timer(cooldown).timeout.connect(func(): _dodge_indicator.visible = false)

func _on_enemy_health_changed(_c: float, _m: float) -> void: pass
func _on_enemy_died(_n: String) -> void: _current_enemy = null
func _on_player_damaged(_d: float, _h: float) -> void: pass

func _on_player_died() -> void:
	_death_overlay.visible = true

func _on_damage_number_request(damage: float, position: Vector2, is_critical: bool) -> void:
	if not _damage_layer: return
	var dn = _damage_number_scene.instantiate()
	_damage_layer.add_child(dn)
	dn.position = position - Vector2(0, 60)
	dn.setup(damage, is_critical)

# ============================================
# Widget factory helpers
# ============================================
func _make_button(p_name: String, x: float, y: float, w: float, h: float, p_text: String) -> Button:
	var b = Button.new()
	b.name = p_name
	b.position = Vector2(x, y)
	b.size = Vector2(w, h)
	b.text = p_text
	b.visible = false
	add_child(b)
	return b

func _make_label(p_name: String, x: float, y: float, w: float, h: float, p_text: String) -> Label:
	var l = Label.new()
	l.name = p_name
	l.position = Vector2(x, y)
	l.size = Vector2(w, h)
	l.text = p_text
	l.visible = false
	add_child(l)
	return l

func _make_progress_bar(p_name: String, x: float, y: float, w: float, h: float, val: float) -> ProgressBar:
	var pb = ProgressBar.new()
	pb.name = p_name
	pb.position = Vector2(x, y)
	pb.size = Vector2(w, h)
	pb.value = val
	pb.show_percentage = false
	pb.visible = false
	add_child(pb)
	return pb
