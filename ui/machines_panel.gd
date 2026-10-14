extends PanelContainer

## Right column: MACHINES | SKILL TREE | INBOX selector, buy mode, the machine cards with a
## "??? MACHINE" teaser, and received emails (newest first). SKILL TREE opens the tree overlay.

signal open_machine(i: int)
signal open_tree

const MODES := {"X1": "x1", "X10": "x10", "Max": "max"}


func _ready() -> void:
	%MachinesTab.pressed.connect(_set_tab.bind("machines"))
	%TreeTab.pressed.connect(func(): Fx.tip_off(); open_tree.emit())
	%InboxTab.pressed.connect(_set_tab.bind("inbox"))
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


func _process(_delta: float) -> void:
	if %Badge.visible:
		%Badge.modulate.a = 1.0 if fmod(Time.get_ticks_msec() / 1000.0, 1.2) < 0.6 else 0.55


func _refresh() -> void:
	if Game.rtab == "upgrades":
		Game.rtab = "machines"  # pre-tree saves
	var on_m := Game.rtab == "machines"
	_tab(%MachinesTab, on_m)
	_tab(%TreeTab, false)
	var aff := Game.tree_affordable()
	%Badge.visible = aff > 0
	%Badge.text = str(aff)
	_tab(%InboxTab, Game.rtab == "inbox")
	_refresh_inbox()
	%ModeRow.visible = on_m
	%Modes.visible = Game.modes_on()
	%Note.visible = not Game.modes_on()
	%Note.text = "×10 / MAX AT %d OWNED" % Defs.BUY_MODES_AT
	for n: String in MODES:
		get_node("%" + n).theme_type_variation = &"BtnCGold" if Game.buy_mode == MODES[n] else &"BtnCGrey"
	var ti := range(Defs.GENS.size()).filter(func(i): return not Game.visible_tier(i))
	%Teaser.visible = on_m and not ti.is_empty()
	if not ti.is_empty():
		%Text.text = "Buy your first %s to reveal the next machine." % Defs.GENS[ti[0] - 1].name


func _tab(b: Button, selected: bool) -> void:
	b.theme_type_variation = &"BtnGold" if selected else &"BtnGrey"
	Defs.tint(b.get_node("HBox/Label"), &"font_color", Defs.GOLD if selected else Defs.MUTED)


## Rows Mail0..7 show the inbox while its tab is open; the tab shows an unread count otherwise.
func _refresh_inbox() -> void:
	var mails := Game.inbox()
	var open := Game.rtab == "inbox"
	if open:
		Game.mail_seen = mails.size()
	var unread := mails.size() - Game.mail_seen
	%InboxTab.get_node("HBox/Label").text = "INBOX (%d)" % unread if unread > 0 else "INBOX"
	for j in 8:
		var row: Control = get_node("VBox/Scroll/List/Mail%d" % j)
		row.visible = open and j < mails.size()
		if row.visible:
			row.get_node("VBox/From").text = Defs.EMAILS[mails[j]][0].to_upper()
			row.get_node("VBox/Body").text = Defs.EMAILS[mails[j]][1]
