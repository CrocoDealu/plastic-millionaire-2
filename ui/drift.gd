extends Control

## 14 faint box-coloured squares rising behind the panels with a slight sway and spin.

var _drift: Array[Dictionary] = []


func _ready() -> void:
	for j in 14:
		_drift.append({x = randf() * 1280.0, s = randf_range(24, 90), sp = randf_range(5, 16), ph = randf() * 940.0,
			c = Defs.BOXES[j % 5].color, rs = randf_range(-12, 12)})


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var tt := Time.get_ticks_msec() / 1000.0
	for d in _drift:
		var s: float = roundf(d.s)
		var x: float = roundf(d.x + sin(tt * 0.3 + d.ph) * 30.0)
		var y: float = roundf(820.0 - fmod(tt * d.sp + d.ph, 940.0))
		draw_set_transform(Vector2(x + s / 2.0, y + s / 2.0), deg_to_rad(fmod(roundf(tt * d.rs), 360.0)))
		var r := Rect2(-s / 2.0, -s / 2.0, s, s)
		var c: Color = d.c
		draw_rect(r, Color(c, 0.09))
		draw_rect(Rect2(r.position, Vector2(s, 6)), Color(1, 1, 1, 0.25 * 0.09))
		draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(6, s - 6)), Color(1, 1, 1, 0.25 * 0.09))
		draw_rect(Rect2(r.position + Vector2(s - 8, 0), Vector2(8, s)), Color(0, 0, 0, 0.3 * 0.09))
		draw_rect(Rect2(r.position + Vector2(0, s - 8), Vector2(s - 8, 8)), Color(0, 0, 0, 0.3 * 0.09))
	draw_set_transform(Vector2.ZERO)
