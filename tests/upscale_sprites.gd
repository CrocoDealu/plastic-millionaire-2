extends SceneTree

## One-off: CSS draws the 9-slice sprites at 3x (slice 4 -> 12px border). StyleBoxTexture has
## no scale, so bake nearest-neighbour 3x copies into assets/ui/x3/.

const SRC := [
	"buttons/Blue/ButtonA_Unpressed", "buttons/Blue/ButtonA_Press", "buttons/Blue/ButtonC_Unpressed",
	"buttons/Gold/ButtonA_Highlighted", "buttons/Gold/ButtonC_Highlighted",
	"buttons/Orange/ButtonA_Highlighted", "buttons/Orange/ButtonCloseA_Highlighted",
	"panels/Black/PanelOutlined", "panels/Black/Panel", "panels/Black/PanelDigital", "panels/Gold/Panel",
	"Stars/Gold/Star_Full",
]

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/ui/x3")
	for s: String in SRC:
		var img := Image.load_from_file("res://assets/ui/%s.png" % s)
		img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
		img.save_png("res://assets/ui/x3/%s.png" % s.replace("/", "_"))
	print("done")
	quit()
