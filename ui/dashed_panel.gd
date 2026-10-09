extends PanelContainer

## PanelContainer with a 2px dashed outline (CSS border: 2px dashed), e.g. the "??? MACHINE" teaser.

@export var color := Color("#3a3a3d")
@export var dash := 6.0


func _draw() -> void:
	var r := Rect2(Vector2.ONE, size - Vector2(2, 2))
	for e in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.position.x, r.end.y), r.end],
			[r.position, Vector2(r.position.x, r.end.y)], [Vector2(r.end.x, r.position.y), r.end]]:
		draw_dashed_line(e[0], e[1], color, 2.0, dash)
