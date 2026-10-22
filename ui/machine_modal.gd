extends PanelContainer

## Machine modal: header, recipe summary, and where the box it makes goes. Auto-In / Auto-Out are
## switched with the IN / OUT tags on the machine card; every upgrade lives in the skill tree.

signal closed

var machine := 0


func _ready() -> void:
	%Close.pressed.connect(closed.emit)
	Game.changed.connect(_refresh)


func open(i: int) -> void:
	machine = i
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
	_flow(i)
	%Flavour.text = Defs.FLAVOUR[g.id]
	%Note.text = "Speed, Yield, Chute and Hopper for the %s are bought in the Skill Tree." % g.name


## What this machine makes on its own, then one row per owned machine that eats that box:
## "12 [in] → 4 [out]" per second, what it really gets once the box has run dry. Whole boxes only.
func _flow(i: int) -> void:
	var out: int = Defs.GENS[i].out
	var d := Game.duty()
	for r in %Uses.get_children():
		r.free()
	for j in Defs.GENS.size():
		if Game.own[j] == 0 or not Defs.GENS[j].inputs.has(out):
			continue
		var w := Game.want(j, out)
		var row: Control = %Use.duplicate()
		row.visible = true
		row.get_node("Name").text = Defs.GENS[j].name.to_upper()
		row.get_node("In").text = Defs.whole(w * d[j])
		row.get_node("InChip").color = Defs.BOXES[out].color
		row.get_node("Out").text = Defs.whole(Game.own[j] * Game.mul(j) / Game.cyc(j) * d[j])
		row.get_node("OutChip").color = Defs.BOXES[Defs.GENS[j].out].color
		%Uses.add_child(row)
	var full: float = Game.own[i] * Game.mul(i) / Game.cyc(i)
	var k: String = Defs.BOXES[out].k
	%Flow.text = "Makes +%s %s/s" % [Defs.whole(full * d[i]), k] \
		+ (" (could make %s with enough input)." % Defs.whole(full) if Game.own[i] and d[i] < 1.0 else ".") \
		+ (" Where it goes, per second:" if %Uses.get_child_count() else "")
