class_name UIStyle
extends RefCounted
## Fonts, colours and the theme: bone, rust and dust, with the Visitors' teal.

const BONE := Color(0.93, 0.89, 0.8)
const DIM := Color(0.68, 0.64, 0.56)
const RUST := Color(0.85, 0.45, 0.22)
const TEAL := Color(0.35, 1.0, 0.85)
const BG := Color(0.07, 0.06, 0.05, 0.92)
const GOOD := Color(0.55, 1.0, 0.6)
const BAD := Color(1.0, 0.45, 0.4)

static var _fonts: Dictionary = {}
static var _theme: Theme = null


static func font(n: String) -> Font:
	if _fonts.has(n):
		return _fonts[n]
	var path := "res://ui/fonts/%s.woff2" % n
	var f: FontFile = load(path) as FontFile if ResourceLoader.exists(path) else null
	if f == null:
		var data := FileAccess.get_file_as_bytes(path)
		if data.is_empty():
			return ThemeDB.fallback_font
		f = FontFile.new()
		f.data = data
	f.generate_mipmaps = true
	_fonts[n] = f
	return f


static func title() -> Font:
	return font("Oswald-SemiBold")


static func body() -> Font:
	return font("Barlow-Medium")


static func bold() -> Font:
	return font("Barlow-Bold")


static func panel(bg: Color = BG, border: Color = Color(0.4, 0.32, 0.22, 0.8)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(1)
	s.set_corner_radius_all(3)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.4)
	s.shadow_size = 8
	return s


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body()
	t.default_font_size = 18
	t.set_color("font_color", "Label", BONE)
	t.set_color("font_color", "Button", BONE)
	t.set_color("font_hover_color", "Button", Color(1, 1, 1))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.42))
	t.set_font("font", "Button", bold())
	t.set_font_size("font_size", "Button", 18)
	var b := panel(Color(0.16, 0.12, 0.09, 0.95), Color(0.55, 0.4, 0.25, 0.9))
	b.content_margin_top = 6
	b.content_margin_bottom = 6
	b.shadow_size = 0
	var bh := b.duplicate() as StyleBoxFlat
	bh.bg_color = Color(0.32, 0.2, 0.12, 0.98)
	bh.border_color = RUST
	var bp := bh.duplicate() as StyleBoxFlat
	bp.bg_color = Color(0.45, 0.25, 0.12)
	var bd := b.duplicate() as StyleBoxFlat
	bd.bg_color = Color(0.1, 0.09, 0.08, 0.8)
	bd.border_color = Color(0.25, 0.22, 0.2)
	t.set_stylebox("normal", "Button", b)
	t.set_stylebox("hover", "Button", bh)
	t.set_stylebox("pressed", "Button", bp)
	t.set_stylebox("disabled", "Button", bd)
	t.set_stylebox("focus", "Button", bh)
	t.set_stylebox("panel", "PanelContainer", panel())
	t.set_stylebox("panel", "Panel", panel())
	var tab := b.duplicate() as StyleBoxFlat
	t.set_stylebox("tab_unselected", "TabContainer", tab)
	t.set_stylebox("tab_hovered", "TabContainer", bh)
	t.set_stylebox("tab_selected", "TabContainer", bp)
	t.set_stylebox("panel", "TabContainer", panel(Color(0.08, 0.07, 0.06, 0.6)))
	t.set_font("font", "TabContainer", title())
	t.set_font_size("font_size", "TabContainer", 20)
	t.set_color("font_selected_color", "TabContainer", Color(1, 0.9, 0.7))
	t.set_color("font_unselected_color", "TabContainer", DIM)
	var sl := StyleBoxFlat.new()
	sl.bg_color = Color(0.2, 0.17, 0.14)
	sl.content_margin_top = 3
	sl.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", sl)
	t.set_font("font", "OptionButton", bold())
	_theme = t
	return t


static func label(text: String, size: int = 18, col: Color = BONE, f: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	return l


static func button(text: String, cb: Callable, min_w: float = 0.0) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 38)
	b.pressed.connect(func() -> void:
		Sfx.play("ui", -6.0)
		cb.call())
	return b
