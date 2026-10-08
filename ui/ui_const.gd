class_name UiConst
extends RefCounted

# Colors scripts need for state-driven text; panel/button looks live in control_room_theme.tres.
const ROOT := Color("#0d1020")
const TEXT := Color("#dfe6ff")
const MUTED := Color("#8a93b8")
const LOCKED := Color("#4a5378")
const LINE := Color("#2a3358")
const CYAN := Color("#4fd6ff")
const GREEN := Color("#5dff8a")
const GOLD := Color("#ffc940")
const WARN := Color("#ff7a6a")
const WARN_TEXT := Color("#ffb3a8")

const MACHINE_SPRITES := {&"g1_sorter": "sorting table sprite", &"g2_pelletizer": "pelletizer sprite", &"g3_loom": "loom sprite"}

## 1,234 under 10k · 12.3k under 1M · 1.23M above.
static func fmt(value: float) -> String:
	if value >= 999_950.0:  # anything that would print as "1000.0k"
		return "%.2fM" % (value / 1_000_000.0)
	if value >= 10_000.0:
		return "%.1fk" % (value / 1000.0)
	var digits := str(floori(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(-3)
	return digits + grouped
