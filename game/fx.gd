extends CanvasLayer

## Screen-space juice and overlays: square particles, rising number floats, bump / shake / pulse
## helpers for buttons, the hover tooltip and the unlock toast. Positions are canvas (1280x720) coords.

const MAX_PARTS := 160
const MAX_FLOATS := 30
const FLOAT_RISE := 44.0
const FLOAT_DUR := 0.9
const PULSE_PERIOD := 1.6

var _parts: Array[Dictionary] = []
var _floats: Array[Dictionary] = []
var _canvas := Control.new()
var _font: Font = preload("res://assets/fonts/Silkscreen-Bold.ttf")
var _tip: PanelContainer = preload("res://ui/tooltip.tscn").instantiate()
var _tip_src: Control
var _tip_side := ""
var _tip_fn: Callable
var _toast: PanelContainer = preload("res://ui/toast.tscn").instantiate()
var _toast_at := -10.0


func _ready() -> void:
	layer = 1
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_fx)
	add_child(_canvas)
	add_child(_toast)
	add_child(_tip)


func _process(delta: float) -> void:
	for p in _parts:
		p.pos += p.vel * delta
		p.vel.y += p.g * delta
		p.life -= delta
	_parts = _parts.filter(func(p): return p.life > 0.0)
	for f in _floats:
		f.age += delta
	_floats = _floats.filter(func(f): return f.age < FLOAT_DUR)
	# Affordable buttons breathe: brightness 1 -> 1.5 -> 1 over 1.6s.
	var k := 1.0 + 0.5 * (0.5 - 0.5 * cos(Time.get_ticks_msec() / 1000.0 * TAU / PULSE_PERIOD))
	for n: CanvasItem in get_tree().get_nodes_in_group(&"pulse"):
		n.self_modulate = Color(k, k, k)
	_canvas.queue_redraw()
	if _tip.visible:
		if is_instance_valid(_tip_src) and _tip_src.is_visible_in_tree():
			_render_tip()
		else:
			tip_off()
	_step_toast()


func burst(at: Vector2, count: int, colors: Array, spd := 180.0, g := 600.0) -> void:
	for i in count:
		var a := randf() * TAU
		var v := randf_range(0.35, 1.0) * spd
		var life := randf_range(0.4, 0.8)
		_parts.append({pos = at, vel = Vector2(cos(a) * v, sin(a) * v - spd * 0.4), g = g, life = life, max = life,
			s = 3 + randi() % 4, c = colors.pick_random()})
	if _parts.size() > MAX_PARTS:
		_parts = _parts.slice(-MAX_PARTS)


func float_text(at: Vector2, text: String, color: Color, font_size := 14) -> void:
	_floats.append({pos = at, text = text, c = color, size = font_size, age = 0.0})
	if _floats.size() > MAX_FLOATS:
		_floats.pop_front()


## Centre of a control in canvas coordinates.
static func center(c: Control) -> Vector2:
	return c.get_global_rect().get_center()


## Purchase bump: scale 1.1 -> 1 over 220ms.
func bump(c: Control) -> void:
	c.pivot_offset = c.size / 2.0
	var t := c.create_tween()
	c.scale = Vector2(1.1, 1.1)
	t.tween_property(c, "scale", Vector2.ONE, 0.22)


## Can't-afford shake: +-5px horizontal over 300ms. Shakes the drawing, not the layout.
func shake(c: Control) -> void:
	var t := c.create_tween()
	t.tween_method(func(k: float): _apply_shake(c, sin(k * 18.0) * 5.0 * (1.0 - k)), 0.0, 1.0, 0.3)
	t.tween_callback(_apply_shake.bind(c, 0.0))


func _apply_shake(c: Control, dx: float) -> void:
	var prev: float = c.get_meta(&"shake_dx", 0.0)
	c.position.x += dx - prev
	c.set_meta(&"shake_dx", dx)


## Purchase / deny feedback in one call. Returns ok for chaining.
func button_fx(c: Control, ok: bool, label := "", colors: Array = [Defs.CAUTION, Defs.ORANGE, Color.WHITE]) -> bool:
	if not ok:
		shake(c)
		Sfx.play("deny")
		return false
	bump(c)
	var r := c.get_global_rect()
	burst(r.get_center(), 14, colors, 220.0, 500.0)
	if label:
		float_text(Vector2(r.get_center().x, r.position.y - 6.0), label, Defs.WARN, 13)
	return true


func _draw_fx() -> void:
	for p in _parts:
		var col: Color = p.c
		col.a = maxf(0.0, p.life / p.max)
		_canvas.draw_rect(Rect2(p.pos.round(), Vector2(p.s, p.s)), col)
	for f in _floats:
		var k: float = f.age / FLOAT_DUR
		var y: float = f.pos.y - FLOAT_RISE * (1.0 - pow(1.0 - k, 2.0))
		var sc: float = 0.6 + f.age * 4.0 if f.age < 0.1 else 1.0
		var fs := int(round(f.size * sc))
		var w := _font.get_string_size(f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var pos := Vector2(f.pos.x - w / 2.0, y + fs).round()
		var col: Color = f.c
		col.a = maxf(0.0, 1.0 - k * k)
		_canvas.draw_string(_font, pos + Vector2(2, 2), f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(Defs.INK, col.a))
		_canvas.draw_string(_font, pos, f.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)


# ---------------------------------------------------------------- tooltip

## Hover tooltip for `c`. `fn` returns [title, [[text, color], ...]] and is re-evaluated while shown.
## side: "left" (to the left of c), "up" (above), "down" (below).
func hover_tip(c: Control, side: String, fn: Callable) -> void:
	c.mouse_entered.connect(func(): _tip_src = c; _tip_side = side; _tip_fn = fn; _render_tip())
	c.mouse_exited.connect(tip_off)


func tip_off() -> void:
	_tip.visible = false
	_tip_src = null


func _render_tip() -> void:
	var v: Array = _tip_fn.call()
	if v.is_empty():
		tip_off()
		return
	_tip.get_node("%Title").text = v[0]
	var lines: Array = v[1]
	var box: VBoxContainer = _tip.get_node("%Lines")
	while box.get_child_count() < lines.size():
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(l)
	for i in box.get_child_count():
		var l: Label = box.get_child(i)
		l.visible = i < lines.size()
		if l.visible:
			l.text = lines[i][0]
			l.add_theme_color_override(&"font_color", lines[i][1] if lines[i].size() > 1 else Defs.SOFT)
	_tip.visible = true
	_tip.reset_size()
	var r := _tip_src.get_global_rect()
	var p := Vector2(r.position.x - 262.0, r.position.y - 8.0) if _tip_side == "left" else Vector2(r.position.x, r.end.y + 8.0)
	if _tip_side == "up":
		p.y = r.position.y - _tip.size.y - 8.0
	var vp := get_viewport().get_visible_rect().size
	_tip.position = Vector2(clampf(p.x, 8.0, vp.x - 262.0), clampf(p.y, 8.0, vp.y - _tip.size.y - 8.0)).round()


# ---------------------------------------------------------------- toast

func toast(title: String, sub: String) -> void:
	_toast.get_node("%Title").text = title
	_toast.get_node("%Sub").text = sub
	_toast.reset_size()
	_toast_at = Time.get_ticks_msec() / 1000.0


func _step_toast() -> void:
	var ta := Time.get_ticks_msec() / 1000.0 - _toast_at
	_toast.visible = ta < 3.0
	if not _toast.visible:
		return
	_toast.position = Vector2(roundf((get_viewport().get_visible_rect().size.x - _toast.size.x) / 2.0), roundf(76.0 - (20.0 * (1.0 - ta / 0.2) if ta < 0.2 else 0.0)))
	_toast.modulate.a = clampf((3.0 - ta) / 0.4, 0.0, 1.0) if ta > 2.6 else 1.0


## Affordable / ready buttons join the "pulse" group; leaving it restores normal brightness.
func pulse(n: CanvasItem, on: bool) -> void:
	if on == n.is_in_group(&"pulse"):
		return
	if on:
		n.add_to_group(&"pulse")
	else:
		n.remove_from_group(&"pulse")
		n.self_modulate = Color.WHITE
