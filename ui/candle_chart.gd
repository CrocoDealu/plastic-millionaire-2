extends Control

## 48-candle chart for the selected market: gridlines + right price axis, AVG and current-price
## lines, sale diamonds, candles or a close-price line, and time labels every 12 candles.
## Backgrounds come from the StyleBoxes set in market_panel.tscn.

const AXIS_W := 58.0
const TIME_H := 18.0

@export var plot_style: StyleBox
@export var axis_style: StyleBox

var _font: Font = preload("res://assets/fonts/Silkscreen-Regular.ttf")


func _ready() -> void:
	Game.changed.connect(queue_redraw)
	resized.connect(queue_redraw)


func _draw() -> void:
	var i := Game.sel
	var m: Dictionary = Game.market[i]
	var cs := Game.window(i)
	var plot := Rect2(0, 0, size.x - AXIS_W, size.y - TIME_H)
	var axis := Rect2(plot.end.x, 0, AXIS_W, plot.size.y)
	draw_style_box(plot_style, plot)
	draw_style_box(axis_style, axis)

	var hi: float = cs.map(func(c): return c.h).max()
	var lo: float = cs.map(func(c): return c.l).min()
	var pad: float = (hi - lo) * 0.12 if hi > lo else m.p * 0.05
	hi += pad
	lo -= pad
	var y := func(v: float) -> float: return roundf((hi - v) / (hi - lo) * plot.size.y)
	var slot := plot.size.x / Defs.N_CANDLES
	var chg := Game.change_pct(i)
	var chg_c := Defs.UP if chg >= 0.0 else Defs.DOWN

	for k in 5:
		var v := lo + (hi - lo) * (k + 0.5) / 5.0
		var ly: float = y.call(v)
		draw_dashed_line(Vector2(0, ly), Vector2(plot.size.x, ly), Defs.DIM_LINE, 1.0, 3.0)
		_text(Vector2(axis.position.x + 6.0, ly - 6.0), Defs.px(v), Defs.FAINT)

	var avg := Game.avg_of(i)
	var ay: float = y.call(avg)
	draw_dashed_line(Vector2(0, ay), Vector2(plot.size.x, ay), Defs.FAINT, 2.0, 2.0)
	_text(Vector2(8, ay - 15.0), "AVG " + Defs.px(avg), Defs.FAINT)

	if Game.chart == "candles":
		for j in cs.size():
			var c: Dictionary = cs[j]
			var col := Defs.UP if c.c >= c.o else Defs.DOWN
			if j == cs.size() - 1:
				col.a = 0.75
			var wx := roundf((j + 0.5) * slot)
			var wt: float = y.call(c.h)
			draw_rect(Rect2(wx - 1.0, wt, 2.0, maxf(1.0, y.call(c.l) - wt)), col)
			var top: float = y.call(maxf(c.o, c.c))
			var h := maxf(2.0, absf(y.call(c.o) - y.call(c.c)))
			draw_rect(Rect2(roundf(j * slot + slot * 0.18), top, roundf(slot * 0.64), h), col)
			if c.sold > 0:
				var d := Vector2(wx, y.call(c.l) + 8.0)
				draw_colored_polygon(PackedVector2Array([d + Vector2(0, -5.66), d + Vector2(5.66, 0), d + Vector2(0, 5.66), d + Vector2(-5.66, 0)]), Defs.CAUTION)
	else:
		var pts := PackedVector2Array()
		for j in cs.size():
			pts.append(Vector2((j + 0.5) * slot, y.call(cs[j].c)))
		draw_polyline(pts, chg_c, 3.0)

	var cy: float = y.call(m.p)
	draw_dashed_line(Vector2(0, cy), Vector2(plot.size.x, cy), chg_c, 2.0, 5.0)
	var tag := Rect2(axis.position.x + 2.0, cy - 8.0, AXIS_W - 4.0, 15.0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = chg_c
	sb.set_corner_radius_all(3)
	draw_style_box(sb, tag)
	var label := Defs.px(m.p)
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	_text(Vector2(tag.get_center().x - tw / 2.0, tag.position.y + 3.0), label, Defs.BG)

	for j in [0, 12, 24, 36]:
		if j < cs.size():
			_text(Vector2(j * slot, plot.end.y + 5.0), Defs.clock(cs[j].t), Defs.FAINT)


## Draws Silk 8 text with its top-left at `p`.
func _text(p: Vector2, t: String, c: Color) -> void:
	draw_string(_font, (p + Vector2(0, 8)).round(), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
