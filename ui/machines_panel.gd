extends PanelContainer

## Right column: MACHINES | UPGRADES selector, buy mode, the
## machine cards with a "??? MACHINE" teaser, and the general upgrades list.

signal open_machine(i: int)

const MODES := {"X1": "x1", "X10": "x10", "Max": "max"}


func _ready() -> void:
	%MachinesTab.pressed.connect(_set_tab.bind("machines"))
	%UpgradesTab.pressed.connect(_set_tab.bind("upgrades"))
	for n: String in MODES:
		get_node("%" + n).pressed.connect(func(): Game.set_pref("buy_mode", MODES[n]); Sfx.play("tick"))
	for i in Defs.GENS.size():
		get_node("%%Machine%d" % i).open_requested.connect(open_machine.emit)
	Game.changed.connect(_refresh)
	_refresh()


func _set_tab(t: String) -> void:
	Fx.tip_off()
	Game.set_pref("rtab", t)
	Sfx.play("tick")


func _refresh() -> void:
	var on_m := Game.rtab == "machines"
	_tab(%MachinesTab, on_m)
	_tab(%UpgradesTab, not on_m)
	%ModeRow.visible = on_m
	%Modes.visible = Game.modes_on()
	%Note.visible = not Game.modes_on()
	for n: String in MODES:
		get_node("%" + n).theme_type_variation = &"BtnCGold" if Game.buy_mode == MODES[n] else &"BtnCGrey"
	var ti := range(Defs.GENS.size()).filter(func(i): return not Game.visible_tier(i))
	%Teaser.visible = on_m and not ti.is_empty()
	if not ti.is_empty():
		%Text.text = "Buy your first %s to reveal the next machine." % Defs.GENS[ti[0] - 1].name


func _tab(b: Button, selected: bool) -> void:
	b.theme_type_variation = &"BtnGold" if selected else &"BtnGrey"
	b.get_node("HBox/Label").add_theme_color_override(&"font_color", Defs.GOLD if selected else Defs.MUTED)

