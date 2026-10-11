extends PanelContainer

## Box Press: click the upper stage to slam the piston; it crafts the next box tier from
## warehouse inputs, the boxes fly out and settle on the floor; click or drag across them to collect. Layout lives in press_panel.tscn.

@export var show_pacing := true

const FLOOR := 320.0
const GRAV := 1400.0
const MAX_DROPS := 40
const PRESS_H := 260.0
const SLAM := 0.1  # full downstroke seconds; boxes eject when the head bottoms out
const SLAM_MIN := 0.03  # a click with the head already down still gets a short, audible hit
const HOLD := 0.03  # head rests on the squashed blank before lifting
const RETURN := 0.2
const REGROW := 0.12  # fresh blank rises out of the die once the head is back at the top
const QUAKE_BASE := 3.0
const QUAKE_MAX := 7.0  # combo grows the stage shake up to this many px
const SWEEP_EVERY := 1.5
const SWEEP_SPEED := 140.0
const SWEEP_CARRY := 8
const COMBO_WINDOW := 0.45
const STREAK_WINDOW := 0.7
const DIE_TOP := 178.0
const DIE_W := 150.0
const BLANK := Vector2(40, 36)
const SPARKS := [Color("#77746c"), Color("#9a968c"), Color("#f5c518")]

var _drops: Array[Dictionary] = []
var _press_at := -10.0
var _slam := SLAM  # this stroke's downstroke time; shorter when the head was already partway down
var _from := 0.0  # stroke fraction (0 = up, 1 = on the die) the head started this slam from
var _f := 0.0
var _grow := BLANK.y  # unsquashed height of the blank on the die; 0 while it's shattered
var _grow_from := BLANK.y
var _combo := 0
var _last_press := -10.0
var _streak := 0
var _last_coll := -10.0
var _sweep_t := 0.0
var _sweep_dir := 1.0  # alternates each pass: 1 = left to right
var _sweeping := false
var _train: Array[Dictionary] = []  # boxes being pushed ahead of the sweeper, nearest first
var _milestone_rows := {}
var _blank_cols: Array = []

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
	Fx.hover_tip(%PressTitle, "", _press_tip)
	Game.changed.connect(_refresh)
	_refresh()


func _press_tip() -> Array:
	var t := Game.press_target()
	return ["BOX PRESS", [
		["%s → 1 %s" % [Defs.recipe(t), Defs.BOXES[t].k], Defs.BOXES[t].color],
		["UP TO %d PER SLAM" % Game.per_press(), Defs.TEXT]]]


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _refresh() -> void:
	# The blank and recipe show what the next slam crafts; both dim while inputs are short.
	var t := Game.press_target()
	var col: Color = Defs.BOXES[t].color
	var ok := Game.can_press()
	_blank_cols = [col]
	var cols := PackedColorArray([col if ok else col.lerp(Defs.BG, 0.65)])  # shader ignores modulate
	cols.resize(Defs.BOXES.size())
	%Blank.material.set_shader_parameter(&"cols", cols)
	%Recipe.text = "%s → %s" % [Defs.recipe(t), Defs.BOXES[t].k]
	Defs.tint(%Recipe, &"font_color", col if ok else Defs.FAINT)
	if not ok:
		%Hover.visible = false
	_refresh_slots(t)
	if not show_pacing:
		return
	%Clock.text = "PLAYTEST " + Defs.mmss(Game.play)
	for k: String in _milestone_rows:
		var done := Game.ms.has(k)
		var c := Defs.TEXT if done else Defs.FAINT
		_milestone_rows[k][1].text = Defs.mmss(Game.ms[k]) if done else "—"
		for l: Label in _milestone_rows[k]:
			Defs.tint(l, &"font_color", c)


## One chip per box the recipe needs, inputs in recipe order: solid if the warehouse has it,
## a dashed placeholder in that colour if not. ×N = slams' worth of inputs on hand.
func _refresh_slots(t: int) -> void:
	var need: Array[int] = []
	for k: int in Defs.GENS[t].inputs:
		for j in Defs.GENS[t].inputs[k]:
			need.append(k)
	var chips := %Slots.get_children().filter(func(c): return c is BoxChip)
	var used := {}
	for j in chips.size():
		var chip: BoxChip = chips[j]
		chip.visible = j < need.size()
		if not chip.visible:
			continue
		var k := need[j]
		used[k] = used.get(k, 0) + 1
		var col: Color = Defs.BOXES[k].color
		chip.color = col
		chip.outline = col.darkened(0.35)
		chip.locked = Game.inv[k] < used[k]
	var n := Game.batches(t, 999999)
	%Ready.text = "×" + Defs.fmt(n)
	Defs.tint(%Ready, &"font_color", Defs.TEXT if n > 0 else Defs.FAINT)


func _on_stage_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var hit := _hit(e.position)
		if hit >= 0:
			_collect(hit)
		elif e.position.y < PRESS_H:
			_press()
	elif e is InputEventMouseMotion:
		%Hover.visible = e.position.y < PRESS_H and Game.can_press()
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
	var per := Game.press()
	if per == 0:
		return
	var t := _now()
	_combo = _combo + 1 if t - _last_press < COMBO_WINDOW else 1
	_last_press = t
	# Slam from wherever the head is, so rapid clicks keep it low and hammer down instead of snapping it up.
	_press_at = t
	_from = _f
	_grow_from = _grow
	_slam = maxf(SLAM_MIN, SLAM * (1.0 - _from))
	get_tree().create_timer(_slam).timeout.connect(_eject.bind(Game.press_target(), per, _combo))


func _eject(c: int, per: int, combo: int) -> void:
	var w := stage.size.x
	for j in per:
		var s: float = [18.0, 20.0, 22.0].pick_random()
		var dir := -1.0 if randf() < 0.5 else 1.0
		_drops.append({x = w / 2.0 - s / 2.0 + dir * 62.0, y = 168.0, s = s, vx = dir * randf_range(60, 230),
			vy = -randf_range(220, 400), rot = 0.0, vr = dir * randf_range(200, 600), rest = false, c = c})
	if _drops.size() > MAX_DROPS:
		var n := _drops.size() - MAX_DROPS
		_credit(_drops.slice(0, n))
		_drops = _drops.slice(n)
	var o := stage.global_position
	Fx.burst(o + Vector2(w / 2.0 - 70.0, 184.0), 5, SPARKS, 120.0, 300.0)
	Fx.burst(o + Vector2(w / 2.0 + 70.0, 184.0), 5, SPARKS, 120.0, 300.0)
	if %Blank.visible:  # the blank shatters
		Fx.burst(o + Vector2(w / 2.0, DIE_TOP - 4.0), 12, _blank_cols, 200.0, 700.0)
	Sfx.play("press", combo)
	Fx.quake(stage, minf(QUAKE_BASE + combo * 0.5, QUAKE_MAX))


func _collect(idx: int) -> void:
	var d: Dictionary = _drops.pop_at(idx)
	var t := _now()
	_streak = _streak + 1 if t - _last_coll < STREAK_WINDOW else 0
	_last_coll = t
	var o := stage.global_position
	var c := o + Vector2(d.x + d.s / 2.0, d.y + d.s / 2.0)
	var col: Color = Defs.BOXES[d.c].color
	Fx.float_text(Vector2(c.x, o.y + d.y - 8.0), "+1", col, int(13 + mini(_streak, 10) * 0.6))
	Fx.burst(c, 6, [col, Defs.CAUTION, Color.WHITE], 150.0, 500.0)
	Sfx.play("collect", _streak)
	Game.collect(d.c, 1)


## Banks drops that left the floor without a click (overflow, sweeper).
func _credit(ds: Array) -> void:
	for d: Dictionary in ds:
		Game.collect(d.c, 1)


func _process(delta: float) -> void:
	var dt := minf(0.1, delta)
	_step_drops(dt)
	# Piston accelerates down to the die over _slam, holds, then eases back up over RETURN.
	var pa := _now() - _press_at
	_f = 0.0
	if pa < _slam:
		_f = lerpf(_from, 1.0, pow(pa / _slam, 2.0))
	elif pa < _slam + HOLD:
		_f = 1.0
	elif pa < _slam + HOLD + RETURN:
		_f = 1.0 - ease((pa - _slam - HOLD) / RETURN, 0.5)
	var head_top := roundf(118.0 + 32.0 * _f)
	%Head.position.y = head_top
	%Rod.size.y = head_top - 64.0
	# Blank shatters on impact; the die stays empty while the head lifts, then a fresh one
	# rises out of it once the head is back at the top. The slamming head squashes it wider and flatter.
	var back := _slam + HOLD + RETURN
	if pa < _slam:
		_grow = _grow_from
	elif pa < back:
		_grow = 0.0
	else:
		_grow = BLANK.y * clampf((pa - back) / REGROW, 0.0, 1.0)
	var bh := roundf(minf(_grow, DIE_TOP - head_top - 24.0))
	%Blank.visible = bh > 0.0
	var bw := minf(DIE_W, roundf(BLANK.x * _grow / bh)) if pa < _slam and bh > 0.0 else BLANK.x
	%Blank.size = Vector2(bw, bh)
	%Blank.position = Vector2(roundf(stage.size.x / 2.0 - bw / 2.0), DIE_TOP - bh)
	var combo_on := _combo >= 5 and _now() - _last_press < STREAK_WINDOW
	%Combo.visible = combo_on
	if combo_on:
		%Combo.text = "COMBO ×%d" % _combo
		var fs := int(minf(22.0, 12.0 + _combo * 0.4))
		if %Combo.get_theme_font_size(&"font_size") != fs:
			%Combo.add_theme_font_size_override(&"font_size", fs)
	if _sweeping:
		_step_sweep(dt)
	elif Game.up.has("sweep"):
		_sweep_t += dt
		if _sweep_t >= SWEEP_EVERY and _drops.any(func(d): return d.rest):
			_sweep_t = 0.0
			_start_sweep()
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


func _start_sweep() -> void:
	var sw: Control = %Sweeper
	sw.position.x = -sw.size.x if _sweep_dir > 0.0 else stage.size.x
	sw.visible = true
	_sweeping = true
	_train.clear()


## Drives across the floor pushing resting boxes it reaches (up to SWEEP_CARRY; once full it
## rolls over the rest). Boxes never collide with each other, so pushed ones all ride against
## the sweeper's face, overlapping. Credited only once off the far edge.
func _step_sweep(dt: float) -> void:
	var sw: Control = %Sweeper
	sw.position.x += _sweep_dir * SWEEP_SPEED * dt
	var x0 := sw.position.x
	var x1 := x0 + sw.size.x
	for i in range(_drops.size() - 1, -1, -1):
		var d := _drops[i]
		if _train.size() < SWEEP_CARRY and d.rest and d.x < x1 and d.x + d.s > x0:
			_drops.remove_at(i)
			_train.append(d)
	for d in _train:
		d.y = FLOOR - d.s
		d.rot = 0.0
		d.x = x1 if _sweep_dir > 0.0 else x0 - d.s
	if x0 > stage.size.x or x1 < 0.0:
		_finish_sweep()


func _finish_sweep() -> void:
	%Sweeper.visible = false
	_sweeping = false
	var ex := stage.size.x - 16.0 if _sweep_dir > 0.0 else 16.0
	_sweep_dir = -_sweep_dir
	var n := _train.size()
	if n == 0:
		return
	var o := stage.global_position
	Fx.float_text(o + Vector2(ex, FLOOR - 30.0), "+%d" % n, Defs.BOXES[_train[0].c].color, 16)
	Fx.burst(o + Vector2(ex, FLOOR - 6.0), 8, [Defs.ORANGE, Defs.CAUTION], 140.0, 500.0)
	Sfx.play("collect", 6)
	_credit(_train)
	_train.clear()


func _draw_boxes() -> void:
	for d in _drops + _train:
		var s: float = d.s
		var at := Vector2(d.x + s / 2.0, d.y + s / 2.0).round()
		boxes.draw_set_transform(at, deg_to_rad(roundf(d.rot)))
		_draw_box(Rect2(-s / 2.0, -s / 2.0, s, s), Defs.BOXES[d.c].color)
	boxes.draw_set_transform(Vector2.ZERO)


func _draw_box(r: Rect2, col: Color) -> void:
	var s := r.size.x
	boxes.draw_rect(r, col)
	boxes.draw_rect(Rect2(r.position, Vector2(s, 3)), Color(1, 1, 1, 0.35))
	boxes.draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(3, s - 3)), Color(1, 1, 1, 0.35))
	boxes.draw_rect(Rect2(r.position + Vector2(s - 4, 0), Vector2(4, s)), Color(0, 0, 0, 0.3))
	boxes.draw_rect(Rect2(r.position + Vector2(0, s - 4), Vector2(s - 4, 4)), Color(0, 0, 0, 0.3))
