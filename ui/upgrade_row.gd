extends PanelContainer

## One automation row in the machine modal: SELF-START / HOPPER (`ain`) or CHUTE (`aout`).
## They're bought in the skill tree; here the button only switches them on and off.

@export var key := "ain"

var machine := 0


func _ready() -> void:
	%Btn.pressed.connect(_press)


func refresh() -> void:
	var i := machine
	var on := Game.ai(i) if key == "ain" else Game.ao(i)
	var name_desc: Array = {
		ain = ["SELF-START" if i == 0 else "HOPPER", "Starts every cycle on its own." if i == 0 else "Pulls inputs from the warehouse and starts cycles on its own."],
		aout = ["CHUTE", "Finished boxes go straight to the warehouse."],
	}[key]
	%Name.text = name_desc[0]
	%Desc.text = name_desc[1]
	%Flavour.text = Defs.FLAVOUR[key]
	%Eff.text = "ACTIVE" if on else "PAUSED"
	Defs.tint(%Eff, &"font_color", Defs.UP if on else Defs.MUTED)
	%Label.text = "ON" if on else "OFF"
	(%Badge.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color = Defs.LIT_BG if on else Defs.BG
	Defs.tint(%Label, &"font_color", Defs.CAUTION if on else Defs.FAINT)
	var btn: Array = ["TURN OFF", &"BtnOrange", Defs.TEXT] if on else ["TURN ON", &"BtnGold", Defs.GOLD]
	%Btn.text = btn[0]
	%Btn.theme_type_variation = btn[1]
	for s in [&"font_color", &"font_hover_color", &"font_pressed_color", &"font_hover_pressed_color"]:
		Defs.tint(%Btn, s, btn[2])


func _press() -> void:
	Game.toggle_auto(machine, key)
	Fx.bump(%Btn)
	Sfx.play("tick")
