## TouchInputArea — 触摸操作热区
## 处理竖屏下半屏的所有触摸输入，转换为游戏指令。
class_name TouchInputArea
extends Control

# === 信号 ===
## [param event_type] "tap" / "swipe"
## [param position] 触摸位置(屏幕坐标)
## [param direction] 滑动方向(仅swipe)
signal touch_event(event_type: String, position: Vector2, direction: Vector2)

# === 触摸状态 ===
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time: float = 0.0
var _is_touching: bool = false
var _swipe_threshold: float = 30.0  ## 滑动判定最小距离
var _tap_max_time: float = 0.25  ## 最大点击判定时间(秒)
var _tap_max_distance: float = 20.0  ## 最大点击判定距离

func _ready() -> void:
	# 确保控件接收输入
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	# 半透明背景,方便看到操作区域
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.3, 0.3, 0.3, 0.1)
	add_theme_stylebox_override("panel", style)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)

func _handle_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_start_pos = event.position
		_touch_start_time = Time.get_ticks_msec() / 1000.0
		_is_touching = true
	else:
		# 手指抬起
		if _is_touching:
			var elapsed: float = Time.get_ticks_msec() / 1000.0 - _touch_start_time
			var distance: float = event.position.distance_to(_touch_start_pos)
			
			if elapsed < _tap_max_time and distance < _tap_max_distance:
				# 判定为点击 → 普攻
				touch_event.emit("tap", event.position, Vector2.ZERO)
		
		_is_touching = false

func _handle_drag(event: InputEventScreenDrag) -> void:
	if not _is_touching:
		return
	
	var current_pos: Vector2 = event.position
	var distance: float = current_pos.distance_to(_touch_start_pos)
	
	if distance >= _swipe_threshold:
		var direction: Vector2 = current_pos - _touch_start_pos
		# 只取主要方向(上下左右)
		direction = _snap_to_cardinal(direction)
		touch_event.emit("swipe", current_pos, direction)
		
		# 重置起点，允许连续滑动
		_touch_start_pos = current_pos
		_touch_start_time = Time.get_ticks_msec() / 1000.0

## 将方向吸附到主要方向（上下左右）
func _snap_to_cardinal(dir: Vector2) -> Vector2:
	var abs_x: float = absf(dir.x)
	var abs_y: float = absf(dir.y)
	
	if abs_x > abs_y:
		return Vector2(signf(dir.x), 0.0)
	else:
		return Vector2(0.0, signf(dir.y))
