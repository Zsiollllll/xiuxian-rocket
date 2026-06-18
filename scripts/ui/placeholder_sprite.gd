## PlaceholderSprite — 自动生成占位纹理的精灵
## 在没有美术资源时，生成带颜色和标签的矩形占位图。
class_name PlaceholderSprite
extends Sprite2D

@export var rect_color: Color = Color.BLUE
@export var rect_width: int = 48
@export var rect_height: int = 64
@export var label_text: String = ""

func _ready() -> void:
	texture = _generate_texture()

func _generate_texture() -> ImageTexture:
	var image: Image = Image.create(rect_width, rect_height, false, Image.FORMAT_RGBA8)
	image.fill(rect_color)
	
	# 边框
	var border_color: Color = rect_color.darkened(0.3)
	for x in range(rect_width):
		image.set_pixel(x, 0, border_color)
		image.set_pixel(x, rect_height - 1, border_color)
	for y in range(rect_height):
		image.set_pixel(0, y, border_color)
		image.set_pixel(rect_width - 1, y, border_color)
	
	# 简单的"眼睛"标记（两个白色点）
	var eye_color: Color = Color.WHITE
	var eye_y: int = rect_height / 3
	image.set_pixel(rect_width / 3, eye_y, eye_color)
	image.set_pixel(rect_width / 3 + 1, eye_y, eye_color)
	image.set_pixel(2 * rect_width / 3, eye_y, eye_color)
	image.set_pixel(2 * rect_width / 3 + 1, eye_y, eye_color)
	
	return ImageTexture.create_from_image(image)
