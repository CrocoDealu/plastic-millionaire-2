extends PanelContainer

## General upgrade (Defs.UPS[index]): name, description and a buy button showing cost,
## requirement or OWNED.

@export var index := 0


func _ready() -> void:
	%Btn.pressed.connect(_buy)
	Fx.hover_tip(%Btn, "left", _tip)
	Game.changed.connect(_refresh)
	_refresh()


func _u() -> Dictionary:
	return Defs.UPS[index]


func _refresh() -> void:
	var u := _u()
	visible = Game.rtab == "upgrades" and Game.up_visible(u)
	var owned: bool = Game.up.has(u.id)
	var locked := not owned and not Game.up_req_met(u.id)
	var can: bool = not owned and not locked and Game.money >= u.cost
	%Name.text = u.name.to_upper()
	%Name.add_theme_color_override(&"font_color", Defs.UP if owned else Defs.MUTED if locked else Defs.TEXT)
	%Desc.text = u.desc
	%Btn.text = "OWNED" if owned else u.req_t if locked else Defs.cash(u.cost)
	%Btn.theme_type_variation = &"BtnGold" if can else &"BtnOwned" if owned else &"BtnGrey"
	%Btn.add_theme_font_size_override(&"font_size", 9)
	Fx.pulse(%Btn, can)
	modulate.a = 0.55 if owned else 0.6 if locked else 1.0
	theme_type_variation = &"CardAfford" if can else &"Card"


func _buy() -> void:
	var u := _u()
	if Game.up.has(u.id):
		return
	if Fx.button_fx(%Btn, Game.buy_up(u.id), "-" + Defs.cash(u.cost)):
		Sfx.play("buy")


func _tip() -> Array:
	var u := _u()
	var lines := [[u.desc]]
	if Game.up.has(u.id):
		lines.append(["Owned", Defs.UP])
	elif not Game.up_req_met(u.id):
		lines.append(["Locked · " + u.req_t.to_lower(), Defs.WARN])
	elif Game.money < u.cost:
		lines.append(["Need %s more" % Defs.cash(u.cost - Game.money), Defs.WARN])
	return ["%s · %s" % [u.name.to_upper(), Defs.cash(u.cost)], lines]
