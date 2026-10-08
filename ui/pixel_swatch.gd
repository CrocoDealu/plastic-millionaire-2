@tool
class_name PixelSwatch
extends Control

## Flat pixel square with the design's bevel: light top-left edge, dark bottom-right edge.

@export var color := Color.WHITE:
	set(value):
		color = value
		queue_redraw()
@export var bevel := true:
	set(value):
		bevel = value
		queue_redraw()
## 4px translucent ring around the square (gold drops).
@export var glow := false:
	set(value):
		glow = value
		queue_redraw()

func _draw() -> void:
	if glow:
		draw_rect(Rect2(Vector2(-4, -4), size + Vector2(8, 8)), Color(color, 0.3))
	draw_rect(Rect2(Vector2.ZERO, size), color)
	if bevel:
		draw_rect(Rect2(0, 0, size.x, 3), Color(1, 1, 1, 0.25))
		draw_rect(Rect2(0, 3, 3, size.y - 3), Color(1, 1, 1, 0.25))
		draw_rect(Rect2(0, size.y - 4, size.x, 4), Color(0, 0, 0, 0.35))
		draw_rect(Rect2(size.x - 4, 0, 4, size.y - 4), Color(0, 0, 0, 0.35))
