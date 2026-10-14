class_name TreeCanvas
extends Control

## The skill tree graph (Defs.SK) on a fixed 1192×590 canvas (scrolls vertically): tier chips, connector edges, and
## each node's slot with its name / pips / status plates. Hover focuses a node (it stays focused),
## click buys its next stage. Nodes more than one step past what you own aren't drawn at all. Positions come from the grid, so this is drawn rather than laid out.

signal focus_changed

const P := "res://assets/ui/SkillTree/"
const SIZE := {large = 56.0, sharp = 42.0, round = 44.0}
const SLOT := {large = "SkillSlotLarge", sharp = "SkillSlotSharp", round = "SkillSlotRound"}
const FOCUS := {large = "FocusLarge", sharp = "FocusSharp", round = "FocusRegular"}
const BG := Color("#0e0e10")
const HALF := 32.0  # half the 64px slot box: also the hit area
const BUY_S := 0.22
const DENY_S := 0.3

var focus := "press"
var _anim := {}  # node id -> [kind ("buy" | "deny"), start s]
var _tex := {}
var _info := {}

@onready var _font: Font = get_theme_font(&"font", &"Silk")


func _ready() -> void:
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED  # connector strips tile along the edge
	mouse_exited.connect(func(): mouse_default_cursor_shape = CURSOR_ARROW)


## Grid -> canvas: rows start below the tier chips.
static func pos(nd: Dictionary) -> Vector2:
	return Vector2(36 + nd.c * 70, 86 + nd.r * 52)


static func state(f: Dictionary) -> String:
	return "hidden" if f.hidden else "owned" if f.done else "aff" if f.can else "avail" if f.ok or f.own else "locked"


func _t(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(P + path + ".png")
	return _tex[path]


func _hit(p: Vector2) -> String:
	for nd: Dictionary in Defs.SK:
		var d := (p - pos(nd)).abs()
		if d.x <= HALF and d.y <= HALF and Game.node_info(nd.id).shown:
			return nd.id
	return ""


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion:
		var id := _hit(e.position)
		mouse_default_cursor_shape = CURSOR_POINTING_HAND if id and Game.node_info(id).can else CURSOR_ARROW
		if id and id != focus:
			focus = id
			focus_changed.emit()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		var id := _hit(e.position)
		if id:
			buy(id)
			accept_event()


## Buys `id`'s next stage, with the bought / denied feedback on its node.
func buy(id: String) -> void:
	var f := Game.node_info(id)
	focus = id
	focus_changed.emit()
	if f.done or f.hidden:
		return
	var at := get_global_transform() * pos(f.nd)
	if Game.buy_sk(id):
		_anim[id] = ["buy", _now()]
		Fx.burst(at, 14, [Defs.CAUTION, Defs.sk_color(f.nd), Color.WHITE], 220.0, 500.0)
		Fx.float_text(at - Vector2(0, HALF + 6.0), "-" + Defs.cash(f.nx.c), Defs.WARN, 13)
		Sfx.play("buy")
	else:
		_anim[id] = ["deny", _now()]
		Sfx.play("deny")


static func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		queue_redraw()  # pulse and focus frames animate


func _draw() -> void:
	_info.clear()
	for nd: Dictionary in Defs.SK:
		_info[nd.id] = Game.node_info(nd.id)
	for t in Defs.GENS.size():
		_draw_chip(t)
	for nd: Dictionary in Defs.SK:
		if not _info[nd.id].shown:
			continue
		for p: String in nd.par:
			if not _info[p].shown:
				continue
			var a := pos(Defs.SKM[p])
			var b := pos(nd)
			var lit: bool = Game.sk_own(p) > 0 and not _info[nd.id].hidden
			draw_set_transform(a, (b - a).angle(), Vector2(2, 2))
			draw_texture_rect(_t(("Yellow" if lit else "Grey") + "/ConnectorHorizontal"), Rect2(0, -8, roundf(a.distance_to(b)) / 2.0, 16), true)
	var t := _now()
	for nd: Dictionary in Defs.SK:
		if not _info[nd.id].shown:
			continue
		var dx := 0.0
		var sc := 1.0
		var an: Array = _anim.get(nd.id, [])
		if an:
			var a: float = t - an[1]
			if an[0] == "buy" and a < BUY_S:
				sc = lerpf(1.1, 1.0, a / BUY_S)
			elif an[0] == "deny" and a < DENY_S:
				dx = 5.0 * sin(a / DENY_S * TAU * 2.0)
			else:
				_anim.erase(nd.id)
		draw_set_transform(pos(nd) + Vector2(dx, 0), 0.0, Vector2(sc, sc))
		draw_slot(self, Vector2.ZERO, nd, _info[nd.id], nd.id == focus)
		_draw_labels(nd, _info[nd.id])
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Node `nd`'s slot centred at `c` on `ci`: background mask, fill diamond, slot sprite, focus frame.
## Also used for the detail bar's icon.
func draw_slot(ci: CanvasItem, c: Vector2, nd: Dictionary, f: Dictionary, focused: bool) -> void:
	var st := state(f)
	var s: float = SIZE[nd.k]
	_diamond(ci, c, roundf(s * 0.68), BG)
	var fill := 0.0 if st == "hidden" else roundf(s * 0.36) if f.done else roundf(s * 0.22) if f.own else 0.0
	if fill > 0.0:
		var col := Defs.sk_color(nd)
		_diamond(ci, c, fill, col)
		var h := fill * sqrt(2.0) / 2.0
		ci.draw_polyline(PackedVector2Array([c + Vector2(-h + 2, 0), c + Vector2(0, -h + 2), c + Vector2(h - 2, 0)]), Color(1, 1, 1, 0.35), 2.0)
		ci.draw_polyline(PackedVector2Array([c + Vector2(-h + 2, 0), c + Vector2(0, h - 2), c + Vector2(h - 2, 0)]), Color(0, 0, 0, 0.3), 3.0)
	var folder := "Grey/" if st == "hidden" or st == "locked" else "White/" if st == "avail" else "Yellow/"
	var tex := _t(folder + SLOT[nd.k] + ("Placeholder" if st == "hidden" else ""))
	var b := 1.0
	if st == "aff":
		b = 1.0 + 0.25 * (1.0 - cos(_now() / 1.6 * TAU))  # 1 -> 1.5 -> 1 brightness pulse
	ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s) / 2.0, Vector2(s, s)), false, Color(b, b, b))
	if focused:
		var frame := 0.0 if fmod(_now(), 0.8) < 0.4 else 64.0
		ci.draw_texture_rect_region(_t("White/SkillSlot_" + FOCUS[nd.k]), Rect2(c - Vector2(HALF, HALF), Vector2(64, 64)), Rect2(frame, 0, 32, 32))


static func _diamond(ci: CanvasItem, c: Vector2, side: float, col: Color) -> void:
	var h := side * sqrt(2.0) / 2.0
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -h), c + Vector2(h, 0), c + Vector2(0, h), c + Vector2(-h, 0)]), col)


## Name (next stage, or current once maxed), stage pips and status, each on a dark plate.
func _draw_labels(nd: Dictionary, f: Dictionary) -> void:
	var st := state(f)
	if st == "hidden":
		return
	var stg: Dictionary = f.cur if f.done else f.nx
	var y := HALF + 3.0
	var nm: String = stg.n.to_upper()
	var lh := _font.get_height(8) * 1.15
	var ns := _font.get_multiline_string_size(nm, HORIZONTAL_ALIGNMENT_CENTER, 68.0, 8)
	var lines := roundi(ns.y / _font.get_height(8))
	draw_rect(Rect2(-ns.x / 2.0 - 3.0, y, ns.x + 6.0, lh * lines + 2.0), BG)
	draw_multiline_string(_font, Vector2(-34, y + 1.0 + _font.get_ascent(8)), nm, HORIZONTAL_ALIGNMENT_CENTER, 68.0, 8, -1,
		Defs.FAINT if st == "locked" else Defs.TEXT)
	y += lh * lines + 2.0 + 3.0
	if f.n > 1:
		var pw := 8.0 if f.n <= 5 else 5.0  # Speed / Yield have 8 stages: keep them inside the column
		var w: float = f.n * (pw + 2.0) - 2.0
		draw_rect(Rect2(-w / 2.0 - 3.0, y, w + 6.0, 4.0), BG)
		for j in f.n:
			draw_rect(Rect2(-w / 2.0 + j * (pw + 2.0), y, pw, 4.0), Defs.sk_color(nd) if j < f.own else Defs.LINE)
		y += 4.0 + 3.0
	var sub: String
	if nd.id == "press":
		sub = "%d PER SLAM" % Game.per_press()
	elif f.done:
		sub = "MAXED" if f.n > 1 else "OWNED"
	elif not f.ok:
		sub = "NEXT LOCKED" if f.own else "LOCKED"
	else:
		sub = Defs.cash(f.nx.c)
	var col := Defs.UP if f.done else Defs.GOLD if st == "aff" else Defs.FAINT if st == "locked" or not f.ok else Defs.MUTED
	var sw := _font.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	draw_rect(Rect2(-sw / 2.0 - 3.0, y, sw + 6.0, _font.get_height(8)), BG)
	draw_string(_font, Vector2(-sw / 2.0, y + _font.get_ascent(8)), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, col)


func _draw_chip(t: int) -> void:
	var v := Game.visible_tier(t)
	var r := Rect2(pos({c = 3 + 3 * t, r = 0}).x - 30.0, 21.0, 130.0, 26.0)
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(13)
	sb.border_color = Defs.LINE if v else Color("#26262a")
	draw_style_box(sb, r)
	var label := "%s · %s" % [Defs.BOXES[t].k, Defs.GENS[t].name.to_upper()] if v else "??? · HIDDEN"
	var tw := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x
	var x0 := r.get_center().x - (tw + 14.0) / 2.0
	draw_rect(Rect2(x0, r.get_center().y - 4.0, 8.0, 8.0), Defs.BOXES[t].color if v else Defs.LINE)
	draw_string(_font, Vector2(x0 + 14.0, r.get_center().y - _font.get_height(8) / 2.0 + _font.get_ascent(8)), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Defs.SOFT if v else Defs.DEAD)
