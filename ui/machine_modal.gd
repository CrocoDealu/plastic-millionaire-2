extends PanelContainer

## Machine modal: header, recipe summary, and the Hopper / Chute on-off toggles once they're
## bought in the skill tree (every machine upgrade lives in the tree).

signal closed

var machine := 0


func _ready() -> void:
	%Close.pressed.connect(closed.emit)
	Game.changed.connect(_refresh)


func open(i: int) -> void:
	machine = i
	for r in [$VBox/Ain, $VBox/Aout]:
		r.machine = i
	visible = true
	_refresh()


func _refresh() -> void:
	if not visible:
		return
	var i := machine
	var g: Dictionary = Defs.GENS[i]
	var ob: Dictionary = Defs.BOXES[g.out]
	var recipe := " + ".join(g.inputs.keys().map(func(k): return "%d %s" % [g.inputs[k], Defs.BOXES[k].k]))
	%Chip.color = ob.color
	%Kicker.text = "MACHINE %d / %d · ×%s OWNED" % [i + 1, Defs.GENS.size(), Defs.fmt(Game.own[i])]
	%Name.text = g.name.to_upper()
	%Summary.text = "%s → %d %s every %.1fs per machine. Skill tree upgrades apply to every %s you own." % [
		recipe if recipe else "No input", Game.mul(i), ob.k, Game.cyc(i), g.name]
	%Flavour.text = Defs.FLAVOUR[g.id]
	for r in [$VBox/Ain, $VBox/Aout]:
		r.refresh()
	var x: Dictionary = Game.mx[i]
	$VBox/Ain.visible = x.ain
	$VBox/Aout.visible = x.aout
	%Note.text = "Speed, Yield, Chute and Hopper for the %s are bought in the Skill Tree." % g.name
