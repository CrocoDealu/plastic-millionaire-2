extends PanelContainer

## Quotes drawer row: ticker, last, change, window high/low and the time of the last tick.

@export var box := 0


func _ready() -> void:
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and Game.select(box):
			Sfx.play("tick"))
	mouse_entered.connect(func(): theme_type_variation = &"QuoteRowSel")
	mouse_exited.connect(refresh)


func refresh() -> void:
	var b: Dictionary = Defs.BOXES[box]
	var m: Dictionary = Game.market[box]
	var un := Game.unlocked(box)
	var fresh := un and Game.now() - float(m.upd) < 0.45
	var cs := Game.window(box)
	var cg := Game.change_pct(box)
	%Chip.color = b.color if un else Defs.LINE
	%Name.text = b.k if un else "???"
	%Last.text = "$" + Defs.px(m.p) if un else "LOCKED"
	%Last.add_theme_color_override(&"font_color", Defs.CAUTION if fresh else Defs.TEXT)
	%Chg.text = Defs.pct(cg) if un else "—"
	%Chg.add_theme_color_override(&"font_color", Defs.UP if cg >= 0.0 else Defs.DOWN)
	%Hi.text = Defs.px(cs.map(func(c): return c.h).max()) if un else "—"
	%Lo.text = Defs.px(cs.map(func(c): return c.l).min()) if un else "—"
	%Upd.text = Defs.clock(m.upd) if un else "—"
	%Upd.add_theme_color_override(&"font_color", Defs.CAUTION if fresh else Defs.FAINT)
	modulate.a = 1.0 if un else 0.45
	theme_type_variation = &"QuoteRowSel" if Game.sel == box or get_global_rect().has_point(get_global_mouse_position()) else &"QuoteRow"
