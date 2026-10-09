extends PanelContainer

## Box Press: click the upper stage to slam the piston, grey boxes fly out and settle on the
## floor; click or drag across them to collect. Layout lives in press_panel.tscn.

@export var show_pacing := true

const FLOOR := 320.0
const GRAV := 1400.0
const MAX_DROPS := 40
const PRESS_H := 260.0
const SWEEP_EVERY := 1.5
const COMBO_WINDOW := 0.45
const STREAK_WINDOW := 0.7
const BOX_C := Color("#b9b5aa")
const SPARKS := [Color("#77746c"), Color("#9a968c"), Color("#f5c518")]

var _drops: Array[Dictionary] = []
var _press_at := -10.0
var _combo := 0
var _last_press := -10.0
var _streak := 0
var _last_coll := -10.0
var _sweep_t := 0.0
var _milestone_rows := {}

@onready var stage: Control = %Stage
@onready var boxes: Control = %Boxes


func _ready() -> void:
	boxes.draw.connect(_draw_boxes)
	stage.gui_input.connect(_on_stage_input)
	stage.mouse_exited.connect(func(): %Hover.visible = false)
	%Playtest.visible = show_pacing
	%HowTo.visible = not show_pacing
	for m: Array in Defs.MILESTONES:
		var row := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = m[1]
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_l.clip_text = true
		var t := Label.new()
		for l: Label in [name_l, t]:
			l.add_theme_font_size_override(&"font_size", 11)
			row.add_child(l)
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		%Milestones.add_child(row)
		_milestone_rows[m[0]] = [name_l, t]
	Game.changed.connect(_refresh)
	_refresh()


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _refresh() -> void:
	%PerPress.text = "%d GRY PER PRESS" % Game.per_press()
	%Sweeper.visible = Game.up.has("sweep")
	if not show_pacing:
		return
	%Clock.text = "PLAYTEST " + Defs.mmss(Game.play)
	%Wait.text = "WAIT %dS · MAX %dS" % [floori(Game.wait_cur), floori(Game.wait_max)]
	%Wait.add_theme_color_override(&"font_color", Defs.WARN if Game.wait_cur > 20.0 else Defs.MUTED)
	for k: String in _milestone_rows:
		var done := Game.ms.has(k)
		var c := Defs.TEXT if done else Defs.FAINT
		_milestone_rows[k][1].text = Defs.mmss(Game.ms[k]) if done else "—"
		for l: Label in _milestone_rows[k]:
			l.add_theme_color_override(&"font_color", c)


func _on_stage_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(e.position)
		if hit >= 0:
			_collect(hit)
		elif e.position.y < PRESS_H:
			_press()
	elif e is InputEventMouseMotion:
		%Hover.visible = e.position.y < PRESS_H
		if e.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var hit := _hit(e.position)
			if hit >= 0:
				_collect(hit)


func _hit(p: Vector2) -> int:
	for i in range(_drops.size() - 1, -1, -1):
		var d := _drops[i]
		if Rect2(d.x, d.y, d.s, d.s).grow(2.0).has_point(p):
			return i
	return -1


func _press() -> void:
	var t := _now()
	var per := Game.press()
	_combo = _combo + 1 if t - _last_press < COMBO_WINDOW else 1
	_last_press = t
	_press_at = t
	var w := stage.size.x
	for j in per:
		var s: float = [18.0, 20.0, 22.0, 24.0].pick_random()
		var dir := -1.0 if randf() < 0.5 else 1.0
		_drops.append({x = w / 2.0 - s / 2.0 + dir * 62.0, y = 168.0, s = s, vx = dir * randf_range(60, 230),
			vy = -randf_range(220, 400), rot = 0.0, vr = dir * randf_range(200, 600), rest = false})
	if _drops.size() > MAX_DROPS:
		var n := _drops.size() - MAX_DROPS
		_drops = _drops.slice(n)
		Game.collect_grey(n)
	var o := stage.global_position
	Fx.burst(o + Vector2(w / 2.0 - 70.0, 184.0), 5, SPARKS, 120.0, 300.0)
	Fx.burst(o + Vector2(w / 2.0 + 70.0, 184.0), 5, SPARKS, 120.0, 300.0)
	Sfx.play("press", _combo)


func _collect(idx: int) -> void:
	var d: Dictionary = _drops.pop_at(idx)
	var t := _now()
	_streak = _streak + 1 if t - _last_coll < STREAK_WINDOW else 0
	_last_coll = t
	var o := stage.global_position
	var c := o + Vector2(d.x + d.s / 2.0, d.y + d.s / 2.0)
	Fx.float_text(Vector2(c.x, o.y + d.y - 8.0), "+1", BOX_C, int(13 + mini(_streak, 10) * 0.6))
	Fx.burst(c, 6, [BOX_C, Defs.CAUTION, Color.WHITE], 150.0, 500.0)
	Sfx.play("collect", _streak)
	Game.collect_grey(1, true)


func _process(delta: float) -> void:
	var dt := minf(0.1, delta)
	_step_drops(dt)
	# Piston slams down 54px in 50ms and returns over 200ms.
	var pa := _now() - _press_at
	var f := pa / 0.05 if pa < 0.05 else (1.0 - (pa - 0.05) / 0.2 if pa < 0.25 else 0.0)
	var head_top := roundf(96.0 + 54.0 * f)
	%Head.position.y = head_top
	%Rod.size.y = head_top - 64.0
	var combo_on := _combo >= 5 and _now() - _last_press < STREAK_WINDOW
	%Combo.visible = combo_on
	if combo_on:
		%Combo.text = "COMBO ×%d" % _combo
		%Combo.add_theme_font_size_override(&"font_size", int(minf(22.0, 12.0 + _combo * 0.4)))
	if Game.up.has("sweep"):
		_sweep_t += dt
		if _sweep_t >= SWEEP_EVERY:
			_sweep_t = 0.0
			_sweep()
	boxes.queue_redraw()


func _step_drops(dt: float) -> void:
	var w := stage.size.x
	for d in _drops:
		if d.rest:
			continue
		d.vy += GRAV * dt
		d.x += d.vx * dt
		d.y += d.vy * dt
		d.rot += d.vr * dt
		if d.x < 4.0:
			d.x = 4.0
			d.vx = absf(d.vx) * 0.5
		if d.x > w - 4.0 - d.s:
			d.x = w - 4.0 - d.s
			d.vx = -absf(d.vx) * 0.5
		if d.vy > 0.0 and d.y + d.s >= FLOOR:  # boxes only hit the floor, never each other
			d.y = FLOOR - d.s
			if d.vy > 220.0:
				d.vy = -d.vy * 0.3
				d.vx *= 0.6
				d.vr *= 0.5
			else:
				d.vy = 0.0
				d.vx = 0.0
				d.vr = 0.0
				d.rot = roundf(d.rot / 90.0) * 90.0
				d.rest = true


func _sweep() -> void:
	var rest := _drops.filter(func(d): return d.rest)
	if rest.is_empty():
		return
	var ax: float = rest.reduce(func(a, d): return a + d.x, 0.0) / rest.size()
	_drops = _drops.filter(func(d): return not d.rest)
	# CSS: transition left 300ms steps(5)
	var from: float = %Sweeper.position.x
	var to := maxf(0.0, ax - 22.0)
	%Sweeper.create_tween().tween_method(func(k: float): %Sweeper.position.x = lerpf(from, to, ceilf(k * 5.0) / 5.0), 0.0, 1.0, 0.3)
	var o := stage.global_position
	Fx.float_text(o + Vector2(ax, FLOOR - 30.0), "+%d" % rest.size(), BOX_C, 16)
	Fx.burst(o + Vector2(ax, FLOOR - 6.0), 8, [Defs.ORANGE, Defs.CAUTION], 140.0, 500.0)
	Sfx.play("collect", 6)
	Game.collect_grey(rest.size())


func _draw_boxes() -> void:
	for d in _drops:
		var s: float = d.s
		boxes.draw_set_transform(Vector2(d.x + s / 2.0, d.y + s / 2.0).round(), deg_to_rad(roundf(d.rot)))
		var r := Rect2(-s / 2.0, -s / 2.0, s, s)
		boxes.draw_rect(r, BOX_C)
		boxes.draw_rect(Rect2(r.position, Vector2(s, 3)), Color(1, 1, 1, 0.35))
		boxes.draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(3, s - 3)), Color(1, 1, 1, 0.35))
		boxes.draw_rect(Rect2(r.position + Vector2(s - 4, 0), Vector2(4, s)), Color(0, 0, 0, 0.3))
		boxes.draw_rect(Rect2(r.position + Vector2(0, s - 4), Vector2(s - 4, 4)), Color(0, 0, 0, 0.3))
	boxes.draw_set_transform(Vector2.ZERO)
