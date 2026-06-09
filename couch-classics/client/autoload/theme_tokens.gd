extends Node

const INK := Color("#17212b")
const PAPER := Color("#f6f1e8")
const MINT := Color("#dbeedc")
const CORAL := Color("#f08a7d")
const GOLD := Color("#f2c078")
const BLUE := Color("#7ec4cf")
const SLATE := Color("#51606f")
const GREEN := Color("#567d46")
const BOARD_DARK := Color("#5e6d4d")
const BOARD_LIGHT := Color("#e9dfc8")
const PANEL := Color("#fffaf0")

const SPACE_1 := 6
const SPACE_2 := 10
const SPACE_3 := 16
const SPACE_4 := 24
const RADIUS_CARD := 18
const RADIUS_BUTTON := 14

func panel_style(fill: Color = PANEL, border: Color = Color("#d9cfbd"), radius: int = RADIUS_CARD) -> StyleBoxFlat:
  var style := StyleBoxFlat.new()
  style.bg_color = fill
  style.border_color = border
  style.set_border_width_all(2)
  style.set_corner_radius_all(radius)
  style.content_margin_left = 14
  style.content_margin_right = 14
  style.content_margin_top = 12
  style.content_margin_bottom = 12
  return style

func button_style(fill: Color, border: Color = INK) -> StyleBoxFlat:
  var style := StyleBoxFlat.new()
  style.bg_color = fill
  style.border_color = border
  style.set_border_width_all(2)
  style.set_corner_radius_all(RADIUS_BUTTON)
  style.content_margin_left = 12
  style.content_margin_right = 12
  style.content_margin_top = 8
  style.content_margin_bottom = 8
  return style

func muted_button_style() -> StyleBoxFlat:
  return button_style(Color("#d8d6cd"), Color("#aaa395"))
