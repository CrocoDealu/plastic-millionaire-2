extends PanelContainer

## Skill tree overlay: header (affordable / owned counts, money), the TreeCanvas graph, and the
## detail bar for the focused node with its BUY button.

signal closed

@onready var _lines: Array[Label] = [$Pad/VBox/Detail/HBox/Info/Line0, $Pad/VBox/Detail/HBox/Info/Line1,
	$Pad/VBox/Detail/HBox/Info/Line2, $Pad/VBox/Detail/HBox/Info/Line3]


func _ready() -> void:
	%Close.pressed.connect(closed.emit)
	%Buy.pressed.connect(func(): %Canvas.buy(%Canvas.focus))
	%Canvas.focus_changed.connect(_refresh)
	%Icon.draw.connect(func():
		var f := Game.node_info(%Canvas.focus)
		%Canvas.draw_slot(%Icon, %Icon.size / 2.0, f.nd, f, false))
	Game.changed.connect(_refresh)


func open() -> void:
	visible = true
	_refresh()


func _process(_delta: float) -> void:
	if visible:
		%Icon.queue_redraw()


func _refresh() -> void:
	if not visible:
		return
	%Money.text = Defs.cash(Game.money)
	_refresh_detail()


func _refresh_detail() -> void:
	if not Game.node_info(%Canvas.focus).shown:
		%Canvas.focus = "press"  # e.g. after a reset
	var f := Game.node_info(%Canvas.focus)
	var nd: Dictionary = f.nd
	var lines := []
	var btn: Array
	if f.hidden:
		%DKicker.text = "HIDDEN TIER"
		Defs.tint(%DKicker, &"font_color", Defs.FAINT)
		%DTitle.text = "???"
		lines.append(["Buy your first %s to reveal this tier." % Defs.GENS[nd.tier - 1].name, Defs.MUTED])
		%DFlavour.text = ""
		btn = ["HIDDEN", &"BtnGrey", Defs.FAINT]
	else:
		var kind: String = {large = "CENTRE", sharp = "SPINE", round = "UPGRADE"}[nd.k]
		var br: String = "%s · %s" % [Defs.BOXES[nd.tier].k, Defs.GENS[nd.tier].name.to_upper()] if nd.has("tier") else Defs.BRANCH[nd.br][0]
		var stage := " · STAGE %d / %d" % [f.n if f.done else f.own + 1, f.n] if f.n > 1 else ""
		%DKicker.text = "%s · %s%s" % [br, kind, stage]
		Defs.tint(%DKicker, &"font_color", Defs.sk_color(nd))
		var st: Dictionary = f.cur if f.done else f.nx
		%DTitle.text = st.n.to_upper()
		if f.own and not f.done:
			lines.append(["Now: " + Defs.sk_desc(nd.id, f.cur), Defs.MUTED])
			lines.append(["Next: " + Defs.sk_desc(nd.id, f.nx), Defs.TEXT])
		else:
			lines.append([Defs.sk_desc(nd.id, st), Defs.TEXT])
		var req := _req(f)
		if req:
			lines.append([req, Defs.WARN])
		if f.ok and not f.can:
			lines.append(["Need %s more" % Defs.cash(f.nx.c - Game.money), Defs.WARN])
		%DFlavour.text = st.get("fl", nd.fl)
		btn = ["OWNED", &"BtnOwned", Defs.UP] if f.done else ["LOCKED", &"BtnGrey", Defs.FAINT] if not f.ok \
			else ["BUY · " + Defs.cash(f.nx.c), &"BtnGold" if f.can else &"BtnGrey", Defs.GOLD if f.can else Defs.FAINT]
	for k in _lines.size():
		_lines[k].visible = k < lines.size()
		if _lines[k].visible:
			_lines[k].text = lines[k][0]
			Defs.tint(_lines[k], &"font_color", lines[k][1])
	%DFlavour.visible = %DFlavour.text != ""
	%Buy.text = btn[0]
	%Buy.theme_type_variation = btn[1]
	for s in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		Defs.tint(%Buy, s, btn[2])
	Fx.pulse(%Buy, f.can and not f.hidden)


## "NEEDS SELF-START · OWN 1 RED STACKER" for whatever blocks the next stage.
static func _req(f: Dictionary) -> String:
	if f.done:
		return ""
	var parts: Array = f.mp.map(func(p): return "NEEDS " + Defs.SKM[p].st[0].n.to_upper())
	var nx: Dictionary = f.nx
	var pre := "NEXT: " if f.own else ""
	if nx.has("g") and Game.own[nx.g[0]] < nx.g[1]:
		var g: Array = nx.g
		parts.append("%sOWN %d %s%s" % [pre, g[1], Defs.GENS[g[0]].name.to_upper(), "S" if g[1] > 1 else ""])
	if nx.has("need") and Game.sk_own(nx.need[0]) < nx.need[1]:
		parts.append(pre + "NEEDS " + Defs.SKM[nx.need[0]].st[nx.need[1] - 1].n.to_upper())
	return " · ".join(parts)
