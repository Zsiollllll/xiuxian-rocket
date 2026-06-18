## SaveSystem — 本地存档管理
## 使用Godot ConfigFile实现单机多槽位存档。
## 存储：路线选择、境界/科技等级、资源、关卡进度、设置。
class_name SaveSystem
extends RefCounted

const SAVE_DIR: String = "user://saves"
const SAVE_FILE_PREFIX: String = "save_"
const MAX_SLOTS: int = 3
const SAVE_VERSION: String = "1.0"

# === 存档数据结构 ===
class GameSaveData:
	var slot_id: int = 0
	var version: String = ""
	var timestamp: String = ""
	var play_time_seconds: float = 0.0
	
	## 路线："" = 未选择, "cultivation" = 修仙, "tech" = 军工
	var route: String = ""
	
	## 修仙进度
	var cultivation_realm: int = 1  ## 1-7 对应炼气→大乘
	var cultivation_qi: float = 0.0  ## 当前灵力储备
	var cultivation_spells: Array = []  ## 已学法术ID列表
	
	## 军工进度
	var tech_level: int = 1  ## 1-7 对应基础工坊→星际科技
	var tech_parts: float = 0.0  ## 当前零件储备
	var tech_weapons: Array = []  ## 已解锁武器ID列表
	
	## 通用进度
	var current_chapter: int = 1
	var current_stage: int = 1
	var spirit_stones: int = 0  ## 灵石（通用货币）
	var achievements: Array = []
	
	## 设置
	var music_volume: float = 0.8
	var sfx_volume: float = 1.0
	var language: String = "zh_CN"

# ============================================
# 存档检测
# ============================================
static func has_any_save() -> bool:
	_ensure_dir()
	var dir := DirAccess.open(SAVE_DIR)
	if not dir:
		return false
	for i in range(MAX_SLOTS):
		if FileAccess.file_exists(_get_path(i)):
			return true
	return false

static func get_slot_info(slot_id: int) -> Dictionary:
	var path: String = _get_path(slot_id)
	if not FileAccess.file_exists(path):
		return {"exists": false}
	
	var config := ConfigFile.new()
	config.load(path)
	
	return {
		"exists": true,
		"route": config.get_value("meta", "route", ""),
		"chapter": config.get_value("meta", "chapter", 1),
		"timestamp": config.get_value("meta", "timestamp", ""),
		"play_time": config.get_value("meta", "play_time", 0.0),
	}

# ============================================
# 保存 / 加载
# ============================================
static func save_game(slot_id: int, data: GameSaveData) -> bool:
	_ensure_dir()
	
	var config := ConfigFile.new()
	
	## 元数据
	config.set_value("meta", "version", SAVE_VERSION)
	config.set_value("meta", "route", data.route)
	config.set_value("meta", "timestamp", Time.get_datetime_string_from_system())
	config.set_value("meta", "play_time", data.play_time_seconds)
	
	## 修仙数据
	config.set_value("cultivation", "realm", data.cultivation_realm)
	config.set_value("cultivation", "qi", data.cultivation_qi)
	config.set_value("cultivation", "spells", data.cultivation_spells)
	
	## 军工数据
	config.set_value("tech", "level", data.tech_level)
	config.set_value("tech", "parts", data.tech_parts)
	config.set_value("tech", "weapons", data.tech_weapons)
	
	## 通用数据
	config.set_value("progress", "chapter", data.current_chapter)
	config.set_value("progress", "stage", data.current_stage)
	config.set_value("progress", "spirit_stones", data.spirit_stones)
	config.set_value("progress", "achievements", data.achievements)
	
	## 设置
	config.set_value("settings", "music_volume", data.music_volume)
	config.set_value("settings", "sfx_volume", data.sfx_volume)
	config.set_value("settings", "language", data.language)
	
	var err := config.save(_get_path(slot_id))
	return err == OK

static func load_game(slot_id: int) -> GameSaveData:
	var path: String = _get_path(slot_id)
	if not FileAccess.file_exists(path):
		return null
	
	var config := ConfigFile.new()
	config.load(path)
	
	var data := GameSaveData.new()
	data.slot_id = slot_id
	data.version = config.get_value("meta", "version", "")
	data.timestamp = config.get_value("meta", "timestamp", "")
	data.play_time_seconds = config.get_value("meta", "play_time", 0.0)
	data.route = config.get_value("meta", "route", "")
	
	data.cultivation_realm = config.get_value("cultivation", "realm", 1)
	data.cultivation_qi = config.get_value("cultivation", "qi", 0.0)
	data.cultivation_spells = config.get_value("cultivation", "spells", [])
	
	data.tech_level = config.get_value("tech", "level", 1)
	data.tech_parts = config.get_value("tech", "parts", 0.0)
	data.tech_weapons = config.get_value("tech", "weapons", [])
	
	data.current_chapter = config.get_value("progress", "chapter", 1)
	data.current_stage = config.get_value("progress", "stage", 1)
	data.spirit_stones = config.get_value("progress", "spirit_stones", 0)
	data.achievements = config.get_value("progress", "achievements", [])
	
	data.music_volume = config.get_value("settings", "music_volume", 0.8)
	data.sfx_volume = config.get_value("settings", "sfx_volume", 1.0)
	data.language = config.get_value("settings", "language", "zh_CN")
	
	return data

static func delete_save(slot_id: int) -> bool:
	var path: String = _get_path(slot_id)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		return true
	return false

# ============================================
# 辅助
# ============================================
static func _get_path(slot_id: int) -> String:
	return SAVE_DIR.path_join(SAVE_FILE_PREFIX + str(slot_id) + ".cfg")

static func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

## 创建新存档的默认数据
static func create_new_data(route: String = "") -> GameSaveData:
	var data := GameSaveData.new()
	data.route = route
	data.play_time_seconds = 0.0
	data.cultivation_realm = 1
	data.tech_level = 1
	data.current_chapter = 1
	data.current_stage = 1
	data.spirit_stones = 100  ## 初始赠送
	return data
