extends PanelContainer

## One machine type: recipe, cycle bar, output rate, IN/OUT auto toggles, RUN/COLLECT and BUY.
## Clicking the card body opens its upgrades modal.

signal open_requested(i: int)

@export var index := 0
@export var tag_on: StyleBox
@export var tag_off: StyleBox

var _hover := false


func _ready() -> void:
	gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			open_requested.emit(index))
	mouse_entered.connect(func(): _hover = true; _refresh())
	mouse_exited.connect(func(): _hover = false; _refresh())
	%Act.pressed.connect(_act)
	%Buy.pressed.connect(_buy)
	Fx.hover_tip(%Buy, "left", _buy_tip)
	for pair in [[%InTag, "ain"], [%OutTag, "aout"]]:
		var tag: Control = pair[0]
		tag.gui_input.connect(_on_tag_input.bind(tag, pair[1]))
	Game.changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	visible = Game.rtab == "machines" and Game.visible_tier(index)
	if not visible:
		return
	var g: Dictionary = Defs.GENS[index]
	var x: Dictionary = Game.mx[index]
	var ob: Dictionary = Defs.BOXES[g.out]
	var own: int = Game.own[index]
	var q := Game.qty_for(index)
	var cost := Game.gen_cost(index, q)
	var can := Game.money >= cost
	var c := Game.cyc(index)
	var mul := Game.mul(index)

	%Chip.color = ob.color
	%Name.text = g.name.to_upper()
	%Own.text = "×" + Defs.fmt(own) if own else ""
	var ins: Array = g.inputs.keys()
	for k in 2:
		var p: Control = [%In0, %In1][k]
		p.visible = k < ins.size()
		if p.visible:
			p.get_node("HBox/Dot").color = Defs.BOXES[ins[k]].color
			p.get_node("HBox/Label").text = "%d %s" % [g.inputs[ins[k]], Defs.BOXES[ins[k]].k]
	%NoInput.visible = ins.is_empty()
	%Out.get_node("HBox/Dot").color = ob.color
	%Out.get_node("HBox/Label").text = "%d %s" % [mul, ob.k]
	%Out.get_node("HBox/Label").add_theme_color_override(&"font_color", ob.color)
	%Every.text = "EVERY %.1fS" % c

	%Bar.value = minf(100.0, x.t / c * 100.0) if x.run else (100.0 if x.held > 0 else 0.0)
	%Bar.get_theme_stylebox(&"fill").bg_color = Defs.GOLD if x.held > 0 else ob.color
	%Rate.text = "+%s %s/s" % [Defs.rt(maxi(own, 1) * mul / c), ob.k]
	%Rate.add_theme_color_override(&"font_color", Defs.SOFT if own else Defs.MUTED)

	%Autos.visible = x.ain or x.aout
	_tag(%InTag, x.ain, Game.ai(index))
	_tag(%OutTag, x.aout, Game.ao(index))

	var can_start: bool = own > 0 and ins.all(func(k): return Game.inv[k] >= g.inputs[k])
	var act: Array
	if x.held > 0:
		act = ["COLLECT " + Defs.fmt(x.held), &"BtnGold", Defs.GOLD, true]
	elif x.run:
		act = ["%.1fS" % maxf(0.0, c - x.t), &"BtnGrey", Defs.SOFT, false]
	elif not own:
		act = ["RUN", &"BtnGrey", Defs.DEAD, false]
	elif Game.ai(index):
		act = ["WAITING", &"BtnGrey", Defs.WARN, false]
	elif can_start:
		act = ["RUN", &"BtnOrange", Defs.TEXT, true]
	else:
		act = ["NO INPUT", &"BtnGrey", Defs.FAINT, false]
	%Act.text = act[0]
	%Act.theme_type_variation = act[1]
	_fg(%Act, act[2])
	Fx.pulse(%Act, act[3])

	%Label.text = "BUY ×%d" % q
	%Cost.text = Defs.cash(cost)
	%Buy.theme_type_variation = &"BtnGold" if can else &"BtnGrey"
	for l: Label in [%Label, %Cost]:
		l.add_theme_color_override(&"font_color", Defs.GOLD if can else Defs.FAINT)
	Fx.pulse(%Buy, can)
	theme_type_variation = &"CardHover" if _hover else &"CardAfford" if can or Game.machine_upgrades_affordable(index) else &"Card"


func _tag(tag: PanelContainer, owned: bool, on: bool) -> void:
	tag.visible = owned
	tag.add_theme_stylebox_override(&"panel", tag_on if on else tag_off)
	tag.get_node("HBox/Dot").color = Defs.UP if on else Defs.DEAD
	tag.get_node("HBox/Label").add_theme_color_override(&"font_color", Defs.CAUTION if on else Defs.FAINT)
	tag.tooltip_text = "Auto-%s %s · click to toggle" % ["In" if tag == %InTag else "Out", "on" if on else "off"]


func _fg(b: Button, c: Color) -> void:
	for s in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		b.add_theme_color_override(s, c)


func _on_tag_input(e: InputEvent, tag: Control, k: String) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		Game.toggle_auto(index, k)
		Fx.bump(tag)
		Sfx.play("tick")


func _act() -> void:
	var ob: Dictionary = Defs.BOXES[Defs.GENS[index].out]
	match Game.gen_act(index):
		Game.Act.COLLECTED:
			var r: Rect2 = %Act.get_global_rect()
			Fx.float_text(Vector2(r.get_center().x, r.position.y - 6.0), "+%s %s" % [Defs.fmt(Game.last_collected), ob.k], ob.color, 15)
			Fx.burst(r.get_center(), 12, [ob.color, Defs.GOLD, Color.WHITE], 200.0, 500.0)
			Fx.bump(%Act)
			Sfx.play("collect", 8)
		Game.Act.STARTED:
			Fx.bump(%Act)
			Sfx.play("press", 4)
		Game.Act.DENIED:
			Fx.shake(%Act)
			Sfx.play("deny")


func _buy() -> void:
	var cost := Game.gen_cost(index, Game.qty_for(index))
	var out_c: Color = Defs.BOXES[Defs.GENS[index].out].color
	if Fx.button_fx(%Buy, Game.buy_gen(index), "-" + Defs.cash(cost), [Defs.CAUTION, out_c, Color.WHITE]):
		Sfx.play("buy")


func _buy_tip() -> Array:
	var i := index
	var g: Dictionary = Defs.GENS[i]
	var q := Game.qty_for(i)
	var cost := Game.gen_cost(i, q)
	var c := Game.cyc(i)
	var mul := Game.mul(i)
	var ob: Dictionary = Defs.BOXES[g.out]
	var out_r := q * mul / c
	var val: float = out_r * Game.market[g.out].p
	var lines := [["+%s %s per second" % [Defs.rt(out_r), ob.k], ob.color]]
	for k: int in g.inputs:
		var use: float = q * g.inputs[k] / c
		lines.append(["−%s %s per second" % [Defs.rt(use), Defs.BOXES[k].k], Defs.WARN])
		val -= use * Game.market[k].p
	lines.append(["≈ +%s/s of box value at current prices" % Defs.cash(val), Defs.GOLD])
	lines.append(["After: %d owned · +%s %s/s" % [Game.own[i] + q, Defs.rt((Game.own[i] + q) * mul / c), ob.k]])
	if Game.money < cost:
		lines.append(["Need %s more" % Defs.cash(cost - Game.money), Defs.WARN])
	return ["BUY %d × %s · %s" % [q, g.name.to_upper(), Defs.cash(cost)], lines]
