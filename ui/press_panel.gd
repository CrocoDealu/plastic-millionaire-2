extends PanelContainer

## Box Press: click the upper stage to slam the piston; boxes in every unlocked colour fly out
## and settle on the floor; click or drag across them to collect. Once you own a Forge, the
## OPEN ??? button loads the box-opening slam.
## Below it, the news ticker. Layout lives in press_panel.tscn.

const FLOOR := 320.0
const GRAV := 1400.0
const MAX_DROPS := 40  # resting boxes on the floor
const PRESS_H := 260.0
const SLAM := 0.1  # full downstroke seconds; boxes eject when the head bottoms out
const SLAM_MIN := 0.03  # a click with the head already down still gets a short, audible hit
const HOLD := 0.03  # head rests on the squashed blank before lifting
const RETURN := 0.2
const REGROW := 0.12  # fresh blank rises out of the die once the head is back at the top
const QUAKE_BASE := 3.0
const QUAKE_MAX := 7.0  # combo grows the stage shake up to this many px
const SWEEP_SPEED := 140.0
const STREAK_WINDOW := 0.7
const DIE_TOP := 178.0
const DIE_W := 150.0
const BLANK := Vector2(40, 36)
const SPARKS := [Color("#77746c"), Color("#9a968c"), Color("#f5c518")]
const NEWS_SPEED := 45.0  # px/s
const NEWS_HOLD := 2.0  # priority headlines sit still at the left edge first

var _drops: Array[Dictionary] = []
var _press_at := -10.0
var _slam := SLAM  # this stroke's downstroke time; shorter when the head was already partway down
var _from := 0.0  # stroke fraction (0 = up, 1 = on the die) the head started this slam from
var _f := 0.0
var _grow := BLANK.y  # unsquashed height of the blank on the die; 0 while it's shattered
var _grow_from := BLANK.y
var _streak := 0
var _last_coll := -10.0
var _sweep_t := 0.0
var _sweep_dir := 1.0  # alternates each pass: 1 = left to right
var _sweeping := false
var _train: Array[Dictionary] = []  # boxes being pushed ahead of the sweeper, nearest first
var _blank_cols: Array = []
var _news_x := 0.0
var _news_hold := 0.0

@onready var stage: Control = %Stage
@onready var boxes: Control = %Boxes
@onready var _font: Font = get_theme_font(&"font", &"Silk")


func _ready() -> void:
	boxes.draw.connect(_draw_boxes)
	stage.gui_input.connect(_on_stage_input)
	stage.mouse_exited.connect(func(): %Hover.visible = false)
	Fx.hover_tip(%Open, "", _open_tip)
	%Open.pressed.connect(Game.toggle_arm)
	Game.changed.connect(_refresh)
	Game.news.connect(_show_news.bind(true))
	_show_news(Game.news_line(), false)
	_refresh()


func _open_tip() -> Array:
	var lines := [["%s → ???" % Defs.recipe(Defs.MYSTERY), Defs.TEXT], [Defs.ENDING.tip, Defs.WARN]]
	if Game.armed:
		lines.append(["Loaded. The next slam opens it.", Defs.GOLD])
	elif Game.can_open():
		lines.append(["Click to load it into the press.", Defs.MUTED])
	return ["???", lines]


## Pool headlines scroll in from the right; priority ones replace the current line at the left edge.
func _show_news(text: String, priority: bool) -> void:
	%Headline.text = text
	%Headline.reset_size()
	_news_x = 0.0 if priority else %Strip.size.x
	_news_hold = NEWS_HOLD if priority else 0.0


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _refresh() -> void:
	# The blank cycles through every box colour unlocked so far; a loaded ??? turns it black.
	var cols := PackedColorArray()
	for i in Defs.BOXES.size():
		if Game.unlocked(i):
			cols.append(Defs.BOXES[i].color)
	if Game.armed:
		cols = PackedColorArray([Defs.INK, Defs.DEAD])
	_blank_cols = Array(cols)
	%Blank.material.set_shader_parameter(&"n", cols.size())
	cols.resize(Defs.BOXES.size())
	%Blank.material.set_shader_parameter(&"cols", cols)
	%Open.visible = Game.mystery_shown()
	%Open.text = "LOADED ???" if Game.armed else "OPEN ???"
	%Open.theme_type_variation = &"BtnGold" if Game.can_open() else &"BtnGrey"
	Fx.pulse(%Open, Game.armed)


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


## Only boxes resting on the floor: airborne ones fly through the press area, where fast
## clicks would otherwise snatch them mid-air instead of slamming.
func _hit(p: Vector2) -> int:
	for i in range(_drops.size() - 1, -1, -1):
		var d := _drops[i]
		if d.rest and Rect2(d.x, d.y, d.s, d.s).grow(2.0).has_point(p):
			return i
	return -1


func _press() -> void:
	var drops := Game.press()
	var t := _now()
	# Slam from wherever the head is, so rapid clicks keep it low and hammer down instead of snapping it up.
	_press_at = t
	_from = _f
	_grow_from = _grow
	_slam = maxf(SLAM_MIN, SLAM * (1.0 - _from))
	get_tree().create_timer(_slam).timeout.connect(_eject.bind(drops, Game.combo))


## `drops` is Game.press()'s [colour, boxes] pairs; empty means the ??? slam (no box).
func _eject(drops: Array, combo: int) -> void:
	var w := stage.size.x
	for p: Array in drops:
		var m: int = p[1]
		var s: float = 24.0 if m > 1 else [18.0, 20.0, 22.0].pick_random()
		var dir := -1.0 if randf() < 0.5 else 1.0
		_drops.append({x = w / 2.0 - s / 2.0 + dir * 62.0, y = 168.0, s = s, vx = dir * randf_range(60, 230),
			vy = -randf_range(220, 400), rot = 0.0, vr = dir * randf_range(200, 600), rest = false, c = p[0], m = m})
	var o := stage.global_position
	Fx.burst(o + Vector2(w / 2.0 - 70.0, 184.0), 5, SPARKS, 120.0, 300.0)
	Fx.burst(o + Vector2(w / 2.0 + 70.0, 184.0), 5, SPARKS, 120.0, 300.0)
	if %Blank.visible:  # the blank shatters
		Fx.burst(o + Vector2(w / 2.0, DIE_TOP - 4.0), 12, _blank_cols, 200.0, 700.0)
	Sfx.play("press", combo)
	Fx.quake(stage, QUAKE_MAX if drops.is_empty() else minf(QUAKE_BASE + combo * 0.5, QUAKE_MAX))


func _collect(idx: int) -> void:
	var d: Dictionary = _drops.pop_at(idx)
	var t := _now()
	_streak = _streak + 1 if t - _last_coll < STREAK_WINDOW else 0
	_last_coll = t
	var o := stage.global_position
	var c := o + Vector2(d.x + d.s / 2.0, d.y + d.s / 2.0)
	var col: Color = Defs.BOXES[d.c].color
	Fx.float_text(Vector2(c.x, o.y + d.y - 8.0), "+" + Defs.fmt(d.m), col, int(13 + mini(_streak, 10) * 0.6))
	Fx.burst(c, 6, [col, Defs.CAUTION, Color.WHITE], 150.0, 500.0)
	Sfx.play("collect", _streak)
	Game.collect(d.c, d.m)


## Banks drops that left the floor without a click (overflow, sweeper).
func _credit(ds: Array) -> void:
	for d: Dictionary in ds:
		Game.collect(d.c, d.m)


func _process(delta: float) -> void:
	var dt := minf(0.1, delta)
	_step_drops(dt)
	if _news_hold > 0.0:
		_news_hold -= dt
	else:
		_news_x -= NEWS_SPEED * dt
	if _news_x < -%Headline.size.x:
		_show_news(Game.news_line(), false)
	%Headline.position.x = roundf(_news_x)
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
	var combo := Game.combo_live()
	%Combo.visible = combo >= 5
	if %Combo.visible:
		var boost := Game.press_boost()
		%Combo.text = "COMBO ×%d" % combo + (" · MACHINES +%d%%" % roundi((boost - 1.0) * 100.0) if boost > 1.0 else "")
		Defs.tint(%Combo, &"font_color", Defs.GOLD if boost >= 2.0 else Defs.ORANGE)
		var fs := int(minf(22.0, 12.0 + combo * 0.4))
		if %Combo.get_theme_font_size(&"font_size") != fs:
			%Combo.add_theme_font_size_override(&"font_size", fs)
	if _sweeping:
		_step_sweep(dt)
	elif Game.sk_own("sweep"):
		_sweep_t += dt
		if _sweep_t >= Game.skv("sweep", "every", 0.0) and _drops.any(func(d): return d.rest):
			_sweep_t = 0.0
			_start_sweep()
	boxes.queue_redraw()


func _step_drops(dt: float) -> void:
	# Only resting boxes count toward the cap (oldest banked first): culling airborne ones made
	# fast slams look like boxes vanished halfway down. Airborne count is bounded by click speed.
	var resting := _drops.filter(func(d): return d.rest)
	if resting.size() > MAX_DROPS:
		var gone := resting.slice(0, resting.size() - MAX_DROPS)
		_credit(gone)
		_drops = _drops.filter(func(d): return not gone.any(func(g): return is_same(g, d)))  # by identity: equal dicts are distinct boxes
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


## Drives across the floor pushing resting boxes it reaches (up to the upgrade's `carry`; once full it
## rolls over the rest). Boxes never collide with each other, so pushed ones all ride against
## the sweeper's face, overlapping. Credited only once off the far edge.
func _step_sweep(dt: float) -> void:
	var sw: Control = %Sweeper
	sw.position.x += _sweep_dir * SWEEP_SPEED * dt
	var x0 := sw.position.x
	var x1 := x0 + sw.size.x
	for i in range(_drops.size() - 1, -1, -1):
		var d := _drops[i]
		if _train.size() < Game.skv("sweep", "carry", 0) and d.rest and d.x < x1 and d.x + d.s > x0:
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
		if d.m > 1:  # bundle count stays upright while the box tumbles
			boxes.draw_set_transform(at)
			var t := Defs.fmt(d.m)
			var tw := _font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
			boxes.draw_string(_font, Vector2(-tw / 2.0, 3.0).round(), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Defs.INK)
	boxes.draw_set_transform(Vector2.ZERO)


func _draw_box(r: Rect2, col: Color) -> void:
	var s := r.size.x
	boxes.draw_rect(r, col)
	boxes.draw_rect(Rect2(r.position, Vector2(s, 3)), Color(1, 1, 1, 0.35))
	boxes.draw_rect(Rect2(r.position + Vector2(0, 3), Vector2(3, s - 3)), Color(1, 1, 1, 0.35))
	boxes.draw_rect(Rect2(r.position + Vector2(s - 4, 0), Vector2(4, s)), Color(0, 0, 0, 0.3))
	boxes.draw_rect(Rect2(r.position + Vector2(0, s - 4), Vector2(s - 4, 4)), Color(0, 0, 0, 0.3))
