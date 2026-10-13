extends RefCounted
class_name AgroUITheme
## Design system minimalista/moderno 100% em codigo (sem assets).
## Superficies claras, texto escuro, um unico destaque verde.

const INK := Color("#21252b")
const MUTED_INK := Color("#6b7280")
const CREAM := Color("#ffffff")
const FIELD_GREEN := Color("#1e6b3a")
const ACCENT_GREEN := Color("#2e7d4f")
const ACCENT_HOVER := Color("#35945c")
const ACCENT_PRESS := Color("#256b43")
const PANEL_BG := Color("#ffffff")
const PANEL_DARK := Color("#232a33")
const SOFT_BG := Color("#f1f3f5")
const BORDER := Color("#d9dee4")
const DISABLED_BG := Color("#e5e7eb")
const DISABLED_INK := Color("#9aa1ab")

static func apply_to(root: Control) -> void:
	var ui_theme := Theme.new()
	ui_theme.set_color("font_color", "Label", INK)
	ui_theme.set_color("font_color", "Button", INK)
	ui_theme.set_color("font_hover_color", "Button", INK)
	ui_theme.set_color("font_pressed_color", "Button", CREAM)
	ui_theme.set_color("font_focus_color", "Button", INK)
	ui_theme.set_color("font_disabled_color", "Button", DISABLED_INK)
	ui_theme.set_font_size("font_size", "Label", 14)
	ui_theme.set_font_size("font_size", "Button", 15)
	ui_theme.set_stylebox("panel", "PanelContainer", _panel(PANEL_BG, 12, 14))
	ui_theme.set_stylebox("normal", "Button", _button(PANEL_BG, BORDER, 8, 8))
	ui_theme.set_stylebox("hover", "Button", _button(SOFT_BG, BORDER, 8, 8))
	ui_theme.set_stylebox("pressed", "Button", _button(ACCENT_PRESS, ACCENT_PRESS, 8, 8))
	ui_theme.set_stylebox("disabled", "Button", _button(DISABLED_BG, DISABLED_BG, 8, 8))
	ui_theme.set_stylebox("focus", "Button", _focus())
	ui_theme.set_stylebox("panel", "TabContainer", _panel(PANEL_BG, 8, 0))
	ui_theme.set_stylebox("tab_selected", "TabContainer", _button(ACCENT_GREEN, ACCENT_GREEN, 6, 8))
	ui_theme.set_stylebox("tab_unselected", "TabContainer", _button(SOFT_BG, BORDER, 6, 8))
	ui_theme.set_stylebox("tab_hover", "TabContainer", _button(DISABLED_BG, BORDER, 6, 8))
	ui_theme.set_color("font_selected_color", "TabContainer", CREAM)
	ui_theme.set_color("font_unselected_color", "TabContainer", MUTED_INK)
	ui_theme.set_color("font_hover_color", "TabContainer", INK)
	root.theme = ui_theme

static func style_panel(panel: PanelContainer, variant: String = "light") -> void:
	var bg := PANEL_BG
	if variant == "dark" or variant == "screws":
		bg = PANEL_DARK
	panel.add_theme_stylebox_override("panel", _panel(bg, 12, 14))

static func style_primary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button(ACCENT_GREEN, ACCENT_GREEN, 8, 10))
	button.add_theme_stylebox_override("hover", _button(ACCENT_HOVER, ACCENT_HOVER, 8, 10))
	button.add_theme_stylebox_override("pressed", _button(ACCENT_PRESS, ACCENT_PRESS, 8, 10))
	button.add_theme_stylebox_override("disabled", _button(DISABLED_BG, DISABLED_BG, 8, 10))
	button.add_theme_color_override("font_color", CREAM)
	button.add_theme_color_override("font_hover_color", CREAM)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_focus_color", CREAM)
	button.add_theme_color_override("font_disabled_color", DISABLED_INK)
	button.add_theme_font_size_override("font_size", 15)

static func style_secondary_button(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _button(PANEL_BG, BORDER, 8, 10))
	button.add_theme_stylebox_override("hover", _button(SOFT_BG, BORDER, 8, 10))
	button.add_theme_stylebox_override("pressed", _button(DISABLED_BG, BORDER, 8, 10))
	button.add_theme_stylebox_override("disabled", _button(DISABLED_BG, DISABLED_BG, 8, 10))
	button.add_theme_color_override("font_color", INK)
	button.add_theme_color_override("font_hover_color", INK)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_focus_color", INK)
	button.add_theme_color_override("font_disabled_color", DISABLED_INK)

static func set_label_color(label: Label, color: Color) -> void:
	label.add_theme_color_override("font_color", color)

static func _panel(bg: Color, radius: int, inset: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	if bg == PANEL_DARK:
		style.set_border_width_all(0)
	else:
		style.set_border_width_all(1)
		style.border_color = BORDER
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

static func _button(bg: Color, border: Color, radius: int, inset: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(radius)
	style.set_border_width_all(1)
	style.border_color = border
	style.content_margin_left = inset
	style.content_margin_right = inset
	style.content_margin_top = inset
	style.content_margin_bottom = inset
	return style

static func _focus() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.set_border_width_all(2)
	style.border_color = ACCENT_GREEN
	style.set_corner_radius_all(8)
	return style
