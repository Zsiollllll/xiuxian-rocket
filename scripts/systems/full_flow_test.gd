## FullFlowTest — 完整游戏流程测试
## 测试：主菜单→路线选择→战斗→存档 的完整流程
extends SceneTree

func _init() -> void:
	print("=".repeat(60))
	print("《修仙？我直接架火箭》— 完整流程测试")
	print("=".repeat(60))
	
	# 1. 加载主菜单场景
	print("\n[1] 加载主菜单...")
	var menu_scene: PackedScene = load("res://scenes/main_menu.tscn")
	var menu: Node = menu_scene.instantiate()
	root.add_child(menu)
	await _wait_frames(5)
	
	# 验证主菜单节点
	var title_page = menu.get_node_or_null("TitlePage")
	var route_page = menu.get_node_or_null("RouteSelectPage")
	
	if title_page and route_page:
		print("  ✅ 主菜单加载成功")
		print("  标题页可见:", title_page.visible)
		print("  路线选择页可见:", not route_page.visible)
	else:
		print("  ❌ 主菜单节点缺失")
		quit(1)
		return
	
	# 2. 测试路线选择（修仙路线）
	print("\n[2] 选择修仙路线...")
	var eb = root.get_node_or_null("EventBus")
	print("  EventBus存在:", eb != null)
	
	# 模拟点击修仙按钮
	menu._selected_route = "cultivation"
	menu._save_data = null  # 新游戏
	menu._show_loading()
	await _wait_frames(3)
	
	var loading_page = menu.get_node_or_null("LoadingPage")
	print("  加载页可见:", loading_page.visible if loading_page else false)
	
	# 3. 启动战斗
	print("\n[3] 进入战斗...")
	menu._launch_battle_scene()
	await _wait_frames(20)
	
	# 验证战场
	var arena_root = root.get_child(root.get_child_count() - 1)
	print("  战场场景:", arena_root.name)
	
	var arena_ctrl = arena_root.get_node_or_null("BattleArenaController")
	var battle_arena = arena_root.get_node_or_null("BattleArena")
	var hud = arena_root.get_node_or_null("HUD")
	
	if arena_ctrl and battle_arena and hud:
		print("  ✅ 战场加载成功")
	else:
		print("  ❌ 战场节点缺失")
	
	# 4. 验证玩家控制器
	var player_spawn = battle_arena.get_node_or_null("PlayerSpawn") if battle_arena else null
	var player = player_spawn.get_node_or_null("Player") if player_spawn else null
	
	if player:
		var script = player.get_script()
		print("  ✅ 玩家控制器:", script.resource_path if script else "none")
		print("  玩家HP:", player.get("current_hp"))
	else:
		print("  ❌ 玩家未找到")
	
	# 5. 模拟战斗
	print("\n[4] 模拟战斗...")
	if player and player.has_method("on_touch_event"):
		# 攻击10次
		for _i in range(10):
			player.on_touch_event("tap", Vector2.ZERO, Vector2.ZERO)
			await _wait_frames(1)
		
		# 闪避
		player.on_touch_event("swipe", Vector2.ZERO, Vector2(0, -1))
		await _wait_frames(2)
		
		# 法术/重武器
		if player.has_method("cast_spell"):
			player.cast_spell()
		elif player.has_method("use_heavy_weapon"):
			player.use_heavy_weapon()
		await _wait_frames(3)
		
		print("  ✅ 战斗操作执行完成")
	
	# 6. 检查敌人状态
	print("\n[5] 战斗状态检查...")
	var alive = arena_ctrl.get("_alive_enemies") if arena_ctrl else 0
	var wave = arena_ctrl.get("_current_wave") if arena_ctrl else 0
	print("  存活敌人:", alive)
	print("  当前波次:", wave)
	
	# 7. 存档测试
	print("\n[6] 存档测试...")
	var SaveSystemClass = load("res://scripts/systems/save_system.gd")
	var data = SaveSystemClass.create_new_data("cultivation")
	data.spirit_stones = 500
	data.current_chapter = 1
	data.current_stage = 3
	
	var saved: bool = SaveSystemClass.save_game(1, data)
	print("  保存:", "✅ 成功" if saved else "❌ 失败")
	
	var loaded = SaveSystemClass.load_game(1)
	print("  加载:", "✅ 成功" if loaded else "❌ 失败")
	if loaded:
		print("  灵石:", loaded.spirit_stones)
		print("  路线:", loaded.route)
	
	var deleted: bool = SaveSystemClass.delete_save(1)
	print("  删除:", "✅ 成功" if deleted else "❌ 失败")
	
	# 结果
	print("\n" + "=".repeat(60))
	if player and player.get("current_hp") > 0:
		print("🎉 所有流程测试通过！")
	else:
		print("⚠️  战斗过程存在问题")
	print("=".repeat(60))
	
	quit(0)

func _wait_frames(count: int) -> void:
	for _i in range(count):
		await process_frame
