## DamageNumber — 浮动伤害数字
## 从受击位置飘出，短暂显示后消失。
class_name DamageNumber
extends Label

func _ready() -> void:
	# 设置默认样式
	horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_theme_font_size_override("font_size", 20)
	add_theme_color_override("font_color", Color.WHITE)

## 初始化伤害数字 [param damage] 伤害值 [param is_critical] 是否暴击
func setup(damage: float, is_critical: bool = false) -> void:
	text = str(int(damage))
	
	if is_critical:
		text = "暴击! " + text
		add_theme_color_override("font_color", Color.ORANGE)
		add_theme_font_size_override("font_size", 28)
	
	# 动画：向上飘 + 淡出
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 60, 0.8)
	tween.tween_property(self, "modulate:a", 0.0, 0.6).set_delay(0.2)
	tween.chain().tween_callback(queue_free)
