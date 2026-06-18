## QuickSmokeTest — 快速冒烟测试
extends SceneTree

func _init() -> void:
	print("=".repeat(50))
	print("快速冒烟测试")
	print("=".repeat(50))
	
	# 1. 主菜单
	print("\n[1] 主菜单场景...")
	var s: PackedScene = load("res://scenes/main_menu.tscn")
	var n = s.instantiate()
	print("  root:", n.name, " type:", n.get_class())
	print("  children:", n.get_child_count())
	for c in n.get_children():
		print("    -", c.name, ":", c.get_class())
	
	# 检查有无按钮
	var tp = n.get_node_or_null("TitlePage")
	if tp:
		var btn = n.find_child("BtnNewGame", true, false)
		print("  BtnNewGame found:", btn != null)
	root.add_child(n)
	await _wait(5)
	
	# 2. 战斗场景
	print("\n[2] 战斗场景...")
	var eb = root.get_node_or_null("EventBus")
	if not eb:
		print("  ERROR: EventBus not found! Is it registered as autoload?")
		quit(1)
		return
	eb.set_meta("selected_route", "cultivation")
	
	var s2: PackedScene = load("res://scenes/battle_arena.tscn")
	var n2 = s2.instantiate()
	root.add_child(n2)
	await _wait(15)
	
	var ctrl = n2.get_node_or_null("BattleArenaController")
	var arena = n2.get_node_or_null("BattleArena")
	if arena:
		var ps = arena.get_node_or_null("PlayerSpawn")
		if ps:
			var p = ps.get_node_or_null("Player")
			if p:
				print("  Player HP:", p.get("current_hp"))
	
	var alive = 0
	if ctrl and ctrl.has_method("get"):
		alive = ctrl.get("_alive")
	print("  Enemies alive:", alive)
	
	# 模拟战斗
	print("\n[3] 模拟攻击...")
	if arena:
		var ps = arena.get_node_or_null("PlayerSpawn")
		if ps:
			var p = ps.get_node_or_null("Player")
			if p and p.has_method("on_touch_event"):
				for _i in range(10):
					p.on_touch_event("tap", Vector2.ZERO, Vector2.ZERO)
					await _wait(1)
				p.on_touch_event("swipe", Vector2.ZERO, Vector2(0, -1))
				await _wait(2)
	
	# 检查存档
	print("\n[4] 存档...")
	var SaveSys = load("res://scripts/systems/save_system.gd")
	var d = SaveSys.create_new_data("cultivation")
	d.spirit_stones = 500
	var ok = SaveSys.save_game(1, d)
	print("  Save:", "OK" if ok else "FAIL")
	var ld = SaveSys.load_game(1)
	print("  Load:", "OK" if ld else "FAIL")
	SaveSys.delete_save(1)
	
	print("\n" + "=".repeat(50))
	print("冒烟测试完成")
	print("=".repeat(50))
	quit(0)

func _wait(frames: int) -> void:
	for _i in range(frames):
		await process_frame
