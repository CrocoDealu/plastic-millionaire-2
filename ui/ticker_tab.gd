extends PanelContainer

## One market tab: chip, ticker, price and change over the visible window.

@export var box := 0

var _hover := false


func _ready() -> void:
	gui_input.connect(_on_input)
	mouse_entered.connect(func(): _hover = true; _refresh())
	mouse_exited.connect(func(): _hover = false; _refresh())
	Fx.hover_tip(self, "down", _tip)
	Game.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var b: Dictionary = Defs.BOXES[box]
	var un := Game.unlocked(box)
	var vis := Game.visible_tier(box)
	var cg := Game.change_pct(box)
	%Tk.text = b.k if un or vis else "???"
	%Chip.color = b.color if un else Defs.LINE
	%Price.text = "$" + Defs.px(Game.market[box].p) if un else ("LOCKED" if vis else "???")
	%Price.add_theme_color_override(&"font_color", Defs.TEXT if un else Defs.FAINT)
	%Chg.text = Defs.pct(cg) if un else ""
	%Chg.add_theme_color_override(&"font_color", Defs.UP if cg >= 0.0 else Defs.DOWN)
	modulate.a = 1.0 if un else 0.5
	theme_type_variation = &"TabHover" if _hover else &"TabSel" if Game.sel == box else &"Tab"


func _process(_delta: float) -> void:
	# A newly opened market pulses (brightness 1 -> 1.5) for 4s.
	var age := Game.now() - float(Game.new_mk.get(box, -100.0))
	var k := 1.0
	if age < 4.0:
		k = 1.0 + 0.5 * (0.5 - 0.5 * cos(age * TAU / 0.7))
	self_modulate = Color(k, k, k)


func _on_input(e: InputEvent) -> void:
	if not (e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT):
		return
	if Game.select(box):
		Sfx.play("tick")
	else:
		Fx.shake(self)
		Sfx.play("deny")


func _tip() -> Array:
	if Game.unlocked(box):
		return []
	return ["MARKET LOCKED", [["Build a %s to list %ses." % [Defs.GENS[box].name, Defs.BOXES[box].name] if Game.visible_tier(box) else "A later machine opens this market."]]]
