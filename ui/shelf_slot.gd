extends PanelContainer

## Warehouse shelf slot for one box type: stacked chip, count, net rate and value.

@export var box := 0

var _hover := false


func _ready() -> void:
	gui_input.connect(_on_input)
	mouse_entered.connect(func(): _hover = true; _refresh())
	mouse_exited.connect(func(): _hover = false; _refresh())
	Fx.hover_tip(self, "up", _tip)
	Game.changed.connect(_refresh)
	Game.produced.connect(_on_produced)
	_refresh()


func _refresh() -> void:
	var b: Dictionary = Defs.BOXES[box]
	var un := Game.unlocked(box)
	var vis := Game.visible_tier(box)
	var cnt: int = Game.inv[box]
	var r: float = Game.net_rates()[box]
	var value := Defs.cash(cnt * Game.market[box].p)
	%Label.text = "%s · %s" % [b.k, b.name.to_upper()] if un else ("%s · LOCKED" % b.k if vis else "??? · LOCKED")
	%Count.text = Defs.fmt(cnt) if un else "—"
	if un:
		%Rate.text = ("%s%s/s · %s" % ["+" if r > 0.0 else "", Defs.rt(r), value]) if r != 0.0 else value
	else:
		%Rate.text = "Build %s" % Defs.GENS[box].name if vis else "Expand the line"
	Defs.tint(%Rate, &"font_color", Defs.FAINT if not un else Defs.UP if r > 0.0 else Defs.WARN if r < 0.0 else Defs.MUTED)
	for c: BoxChip in [%A, %B, %C]:
		c.color = b.color
		c.locked = not un
	%B.visible = un and cnt >= 10
	%C.visible = un and cnt >= 100
	modulate.a = 1.0 if un else 0.55
	theme_type_variation = &"SlotHover" if _hover else &"SlotSel" if Game.sel == box else &"Slot"


## One float per landing, so two +1s in a row show as two +1s. %Pop only marks where they start.
func _on_produced(i: int, q: int) -> void:
	if i == box and is_visible_in_tree():
		Fx.float_text(%Pop.global_position, "+" + Defs.fmt(q), Defs.BOXES[box].color, 12)


func _on_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Game.select(box):
		Sfx.play("tick")


func _tip() -> Array:
	var b: Dictionary = Defs.BOXES[box]
	if not Game.unlocked(box):
		if Game.visible_tier(box):
			return [b.name.to_upper(), [["Build a %s to start producing these and open the %s market." % [Defs.GENS[box].name, b.k]]]]
		return ["???", [["Keep expanding the line to reveal this box."]]]
	var f: Vector2 = Game.flows()[box]
	var r := f.x - f.y
	var cnt: int = Game.inv[box]
	return ["%s · $%s" % [b.name.to_upper(), Defs.px(Game.market[box].p)], [
		["%s in stock · %s" % [Defs.fmt(cnt), Defs.cash(cnt * Game.market[box].p)], Defs.GOLD],
		["Made +%s/s · used −%s/s" % [Defs.rt(f.x), Defs.rt(f.y)]] if f.y > 0.0 else ["Made +%s/s" % Defs.rt(f.x)],
		["Net %s%s/s" % ["+" if r >= 0.0 else "", Defs.rt(r)], Defs.UP if r >= 0.0 else Defs.WARN],
		["Click to open its market."]]]
