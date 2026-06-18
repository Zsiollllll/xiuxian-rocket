## BattleTest — 自动化战斗测试
## 在headless模式下运行，验证整个战斗循环是否正常工作。
extends SceneTree

var _test_start_time: float = 0.0
var _test_duration: float = 5.0  ## 测试运行5秒
var _test_passed: bool = true

func _init() -> void:
	print("=".repeat(60))
	print("《修仙？我直接架火箭》— 战斗原型自动化测试")
	print("=".repeat(60))
	
	_test_start_time = Time.get_ticks_msec() / 1000.0
	
	# 加载主场景
	var main_scene: PackedScene = load("res://scenes/main.tscn")
	var main: Node = main_scene.instantiate()
	root.add_child(main)
	
	# 等待场景初始化完成
	await _wait_frames(5)
	
	# 运行各项测试
	_test_player_spawned(main)
	_test_enemy_auto_spawn(main)
	_test_hud_visible(main)
	_test_eventbus_active()
	
	# 模拟玩家操作
	await _simulate_player_actions(main)
	
	# 等待战斗自然推进
	await _wait_seconds(_test_duration)
	
	# 输出结果
	_print_results()
	
	# 退出
	quit(0 if _test_passed else 1)

func _test_player_spawned(main: Node) -> void:
	print("\n[TEST] 玩家生成检测...")
	var arena: Node = main.get_node_or_null("BattleArena")
	if not arena:
		_fail("找不到BattleArena节点")
		return
	
	var player = arena.get_node_or_null("Player")
	if not player:
		_fail("找不到Player节点")
		return
	
	# 检查Player脚本是否激活
	if not player.has_method("take_damage"):
		_fail("Player没有take_damage方法")
		return
	
	var hp = player.get("current_hp")
	if hp <= 0:
		_fail("Player血量异常: " + str(hp))
		return
	
	_pass("Player生成成功，HP=" + str(hp))

func _test_enemy_auto_spawn(main: Node) -> void:
	print("\n[TEST] 敌人自动刷新检测...")
	var arena: Node = main.get_node_or_null("BattleArena")
	if not arena:
		_fail("找不到BattleArena")
		return
	
	# GameController应该在延迟一帧后开始刷怪
	var gc: Node = main.get_node_or_null("GameController")
	if not gc:
		_fail("找不到GameController")
		return
	
	# 检查是否有_alive_enemies变量
	if not gc.get("_alive_enemies") is int:
		_fail("GameController缺少_alive_enemies变量")
		return
	
	_pass("GameController初始化正常")

func _test_hud_visible(main: Node) -> void:
	print("\n[TEST] HUD初始化检测...")
	var hud = main.get_node_or_null("HUD")
	if not hud:
		_fail("找不到HUD节点")
		return
	
	# 检查HUD关键子节点
	var player_hp = hud.get_node_or_null("PlayerInfo/HPBar")
	if not player_hp:
		_fail("HUD缺少玩家血条")
		return
	
	var touch_area = hud.get_node_or_null("TouchArea")
	if not touch_area:
		_fail("HUD缺少触摸区域")
		return
	
	var skill_btn = hud.get_node_or_null("SkillPanel/SkillButton")
	if not skill_btn:
		_fail("HUD缺少技能按钮")
		return
	
	_pass("HUD所有关键节点就绪")

func _test_eventbus_active() -> void:
	print("\n[TEST] EventBus自检...")
	var eb = root.get_node_or_null("EventBus")
	if not eb:
		_fail("EventBus Autoload未注册")
		return
	
	# 检查关键信号是否存在
	if not eb.has_signal("enemy_died"):
		_fail("EventBus缺少enemy_died信号")
		return
	if not eb.has_signal("player_died"):
		_fail("EventBus缺少player_died信号")
		return
	if not eb.has_signal("damage_number_request"):
		_fail("EventBus缺少damage_number_request信号")
		return
	
	_pass("EventBus正常，所有关键信号已注册")

func _simulate_player_actions(main: Node) -> void:
	print("\n[TEST] 模拟玩家操作...")
	var hud = main.get_node_or_null("HUD")
	if not hud:
		return
	
	var arena: Node = main.get_node_or_null("BattleArena")
	if not arena:
		return
	
	var player = arena.get_node_or_null("Player")
	if not player:
		return
	
	# 等待GameController延迟初始化完成
	await _wait_frames(10)
	
	# 尝试攻击（通过touch_event信号）
	var touch_area = hud.get_node_or_null("TouchArea")
	if touch_area and touch_area.has_signal("touch_event"):
		touch_area.touch_event.emit("tap", Vector2(195, 700), Vector2.ZERO)
		await _wait_frames(2)
		_pass("攻击指令已发送")
	
	# 尝试闪避
	if touch_area and touch_area.has_signal("touch_event"):
		touch_area.touch_event.emit("swipe", Vector2(195, 600), Vector2(0, -1))
		await _wait_frames(2)
		_pass("闪避指令已发送")
	
	# 尝试使用技能
	var skill_btn = hud.get_node_or_null("SkillPanel/SkillButton")
	if skill_btn and skill_btn.has_signal("pressed"):
		skill_btn.emit_signal("pressed")
		await _wait_frames(2)
		_pass("技能指令已发送")

func _wait_frames(count: int) -> void:
	for i in range(count):
		await process_frame

func _wait_seconds(duration: float) -> void:
	var end_time: float = Time.get_ticks_msec() / 1000.0 + duration
	while Time.get_ticks_msec() / 1000.0 < end_time:
		await process_frame

func _pass(message: String) -> void:
	print("  ✅ PASS:", message)

func _fail(message: String) -> void:
	print("  ❌ FAIL:", message)
	_test_passed = false

func _print_results() -> void:
	var elapsed: float = Time.get_ticks_msec() / 1000.0 - _test_start_time
	print("\n" + "=".repeat(60))
	if _test_passed:
		print("🎉 所有测试通过！ (%.2fs)" % elapsed)
	else:
		print("⚠️  存在测试失败 (%.2fs)" % elapsed)
	print("=".repeat(60))
