extends PanelContainer

signal pressed

# style -> [row variation, title color, button variation]
const LOOKS := {
	"afford": [&"RowIdle", UiConst.TEXT, &"BuyAfford"],
	"expensive": [&"RowIdle", UiConst.TEXT, &"BuyExpensive"],
	"owned": [&"RowOwned", UiConst.GREEN, &"BuyOwned"],
	"toggle_off": [&"RowOwned", UiConst.GREEN, &"BuyExpensive"],
	"locked": [&"RowIdle", UiConst.TEXT, &"BuyLocked"],
	"achieved": [&"RowAchieved", UiConst.GOLD, &"BuyAchieved"],
	"unachieved": [&"RowIdle", UiConst.MUTED, &"BuyLocked"],
}

func _ready() -> void:
	%Buy.pressed.connect(pressed.emit)

## spec: name, desc, optional tag/button/style/cost. Without a style, affordability picks afford/expensive.
func show_spec(spec: Dictionary, money: int) -> void:
	var style: String = spec.get("style", "")
	if style.is_empty():
		style = "afford" if money >= spec.get("cost", 0) else "expensive"
	var look: Array = LOOKS[style]
	theme_type_variation = look[0]
	%Name.text = spec["name"]
	%Name.add_theme_color_override("font_color", look[1])
	%Tag.text = spec.get("tag", "")
	%Desc.text = spec["desc"]
	%Buy.text = spec["button"] if spec.has("button") else "$ %s" % UiConst.fmt(spec.get("cost", 0))
	%Buy.theme_type_variation = look[2]
