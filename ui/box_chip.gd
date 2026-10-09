@tool
class_name BoxChip
extends Control

## A bevelled pixel box (CSS: inset -d -d dark, inset l l light). Dashed outline when locked.

@export var color := Color("#b9b5aa"):
	set(v): color = v; queue_redraw()
@export var dark := 4:
	set(v): dark = v; queue_redraw()
@export var light := 3:
	set(v): light = v; queue_redraw()
@export var locked := false:
	set(v): locked = v; queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size)
	if locked:
		draw_rect(r, Color("#26262a"))
		_dashed(r, Color("#4a4a4d"), 2.0)
		return
	draw_rect(r, color)
	if light > 0:
		draw_rect(Rect2(0, 0, size.x, light), Color(1, 1, 1, 0.3))
		draw_rect(Rect2(0, light, light, size.y - light), Color(1, 1, 1, 0.3))
	if dark > 0:
		draw_rect(Rect2(size.x - dark, 0, dark, size.y), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(0, size.y - dark, size.x - dark, dark), Color(0, 0, 0, 0.3))


func _dashed(r: Rect2, c: Color, w: float) -> void:
	var dash := 6.0
	var x := 0.0
	while x < r.size.x:
		var len := minf(dash, r.size.x - x)
		draw_rect(Rect2(x, 0, len, w), c)
		draw_rect(Rect2(x, r.size.y - w, len, w), c)
		x += dash * 2.0
	var y := 0.0
	while y < r.size.y:
		var len := minf(dash, r.size.y - y)
		draw_rect(Rect2(0, y, w, len), c)
		draw_rect(Rect2(r.size.x - w, y, w, len), c)
		y += dash * 2.0
