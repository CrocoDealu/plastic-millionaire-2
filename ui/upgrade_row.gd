extends PanelContainer

## One per-machine upgrade row in the machine modal: SPEED / YIELD (5 levels) or AUTO-IN /
## AUTO-OUT (owned once, then the button toggles it on and off).

@export var key := "spd"

var machine := 0


func _ready() -> void:
	%Btn.pressed.connect(_press)


func refresh() -> void:
	var i := machine
	var x: Dictionary = Game.mx[i]
	var ob: Dictionary = Defs.BOXES[Defs.GENS[i].out]
	var c := Game.cyc(i)
	var mul := Game.mul(i)
	var leveled := key == "spd" or key == "yld"
	var lvl: int = x[key] if leveled else (1 if (Game.ai(i) if key == "ain" else Game.ao(i)) else 0)
	var maxed := Game.mu_maxed(i, key)
	var cost := Game.mu_cost(i, key)
	var own: int = Game.own[i]
	var can := not maxed and own > 0 and Game.money >= cost
	var name_desc: Array = {
		spd = ["SPEED", "Each level cuts cycle time by 20%.",
			"%.1fS CYCLE" % c if maxed else "%.1fS → %.1fS" % [c, c * 0.8]],
		yld = ["YIELD", "Each level adds +1 box to every batch.",
			"%d PER BATCH" % mul if maxed else "%d → %d %s PER BATCH" % [mul, mul + 1, ob.k]],
		ain = ["AUTO-IN", "Starts every cycle on its own." if i == 0 else "Pulls inputs from the warehouse and starts cycles on its own.",
			("ACTIVE" if Game.ai(i) else "PAUSED") if x.ain else "NO MORE RUN CLICKS"],
		aout = ["AUTO-OUT", "Finished boxes go straight to the warehouse.",
			("ACTIVE" if Game.ao(i) else "PAUSED") if x.aout else "NO MORE COLLECT CLICKS"],
	}[key]
	%Name.text = name_desc[0]
	%Desc.text = name_desc[1]
	%Eff.text = name_desc[2]
	%Eff.add_theme_color_override(&"font_color", Defs.UP if maxed else Defs.CAUTION)
	%Label.text = "LV %d" % lvl if leveled else ("ON" if lvl else "OFF")
	_badge(lvl > 0)
	%Pips.visible = leveled
	for k in 5:
		%Pips.get_child(k).color = Defs.CAUTION if k < lvl else Defs.LINE
	theme_type_variation = &"CardLargeAfford" if can else &"CardLarge"
	var btn: Array = ["MAXED" if leveled else "OWNED", &"BtnOwned", Defs.UP] if maxed else ["BUILD FIRST", &"BtnGrey", Defs.FAINT] if not own else [Defs.cash(cost), &"BtnGold" if can else &"BtnGrey", Defs.GOLD if can else Defs.FAINT]
	var pulse := can
	if not leveled and maxed:
		var on := lvl > 0
		btn = ["TURN OFF", &"BtnOrange", Defs.TEXT] if on else ["TURN ON", &"BtnGold", Defs.GOLD]
		%Eff.add_theme_color_override(&"font_color", Defs.UP if on else Defs.MUTED)
		pulse = false
	%Btn.text = btn[0]
	%Btn.theme_type_variation = btn[1]
	for s in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		%Btn.add_theme_color_override(s, btn[2])
	Fx.pulse(%Btn, pulse)


func _badge(lit: bool) -> void:
	(%Badge.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color = Defs.LIT_BG if lit else Defs.BG
	%Label.add_theme_color_override(&"font_color", Defs.CAUTION if lit else Defs.FAINT)


func _press() -> void:
	var i := machine
	if (key == "ain" or key == "aout") and Game.mu_maxed(i, key):
		Game.toggle_auto(i, key)
		Fx.bump(%Btn)
		Sfx.play("tick")
		return
	if Game.mu_maxed(i, key):
		return
	var cost := Game.mu_cost(i, key)
	var out_c: Color = Defs.BOXES[Defs.GENS[i].out].color
	if Fx.button_fx(%Btn, Game.buy_mu(i, key), "-" + Defs.cash(cost), [Defs.CAUTION, out_c, Color.WHITE]):
		Sfx.play("buy")
