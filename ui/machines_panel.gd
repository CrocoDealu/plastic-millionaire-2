extends PanelContainer

## Right column: MACHINES | UPGRADES selector with affordable-count badges, buy mode, the
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
	_tab(%MachinesTab, on_m, Game.machine_affordable_count())
	_tab(%UpgradesTab, not on_m, Game.upgrade_affordable_count())
	%ModeRow.visible = on_m
	%Modes.visible = Game.modes_on()
	%Note.visible = not Game.modes_on()
	for n: String in MODES:
		get_node("%" + n).theme_type_variation = &"BtnCGold" if Game.buy_mode == MODES[n] else &"BtnCGrey"
	var ti := range(Defs.GENS.size()).filter(func(i): return not Game.visible_tier(i))
	%Teaser.visible = on_m and not ti.is_empty()
	if not ti.is_empty():
		%Text.text = "Buy your first %s to reveal the next machine." % Defs.GENS[ti[0] - 1].name


func _tab(b: Button, selected: bool, badge: int) -> void:
	b.theme_type_variation = &"BtnGold" if selected else &"BtnGrey"
	b.get_node("HBox/Label").add_theme_color_override(&"font_color", Defs.GOLD if selected else Defs.MUTED)
	var bd: Control = b.get_node("HBox/Badge")
	bd.visible = badge > 0 and not selected
	bd.get_node("Label").text = str(badge)


func _process(_delta: float) -> void:
	# Badges blink (opacity 1 <-> .55, 1.2s steps(2)).
	var a := 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.6 else 0.55
	for b: Button in [%MachinesTab, %UpgradesTab]:
		b.get_node("HBox/Badge").modulate.a = a
