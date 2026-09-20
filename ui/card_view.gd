class_name CardView
extends Control

signal played(card: Card)
signal preview_started(card: Card)
signal preview_ended

const LONG_PRESS_MS := 420
const SIZE_HAND := Vector2(92, 130)
const SIZE_PILE := Vector2(108, 152)
const SIZE_OPP := Vector2(58, 82)

var card: Card
var interactive: bool = false
var playable: bool = true

var _pressing := false
var _long_press_fired := false
var _press_started_ms := 0


func _ready() -> void:
	set_process(false)


func set_display_size(card_size: Vector2) -> void:
	custom_minimum_size = card_size
	size = card_size
	pivot_offset = Vector2(card_size.x * 0.5, card_size.y)


func bind(p_card: Card, face_up: bool = true, p_interactive: bool = false, p_playable: bool = true) -> void:
	card = p_card
	interactive = p_interactive and face_up
	playable = p_playable
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive else Control.CURSOR_ARROW
	if size.x < 8.0:
		set_display_size(SIZE_HAND)
	_apply_face_style(face_up)
	$Back.visible = not face_up
	$Face.visible = face_up
	$RankTop.visible = face_up
	$SuitTop.visible = face_up
	$RankBottom.visible = face_up
	$SuitCenter.visible = face_up
	if face_up and card != null:
		var ink := Color(0.78, 0.1, 0.14) if card.is_red() else Color(0.1, 0.1, 0.12)
		$RankTop.text = card.rank_label()
		$SuitTop.text = card.suit_glyph()
		$RankBottom.text = card.rank_label()
		$SuitCenter.text = card.suit_glyph()
		$RankTop.add_theme_color_override("font_color", ink)
		$SuitTop.add_theme_color_override("font_color", ink)
		$RankBottom.add_theme_color_override("font_color", ink)
		$SuitCenter.add_theme_color_override("font_color", ink)
	$Dim.visible = interactive and not playable
	$Highlight.visible = interactive and playable


func _apply_face_style(_face_up: bool) -> void:
	var face := $Face as Panel
	var back := $Back as Panel
	var highlight := $Highlight as Panel
	var gold := interactive and playable
	var face_bg := Color(1.0, 0.93, 0.52) if gold else Color(0.98, 0.97, 0.94)
	var face_border := Color(0.82, 0.62, 0.08) if gold else Color(0.78, 0.76, 0.72)
	face.add_theme_stylebox_override("panel", _card_style(face_bg, face_border, 10))
	back.add_theme_stylebox_override("panel", _card_style(Color(0.12, 0.22, 0.48), Color(0.72, 0.82, 0.95), 10))
	highlight.add_theme_stylebox_override("panel", _card_style(Color(1, 1, 1, 0), Color(0.95, 0.78, 0.12), 10))


func _card_style(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(2)
	sb.border_color = border
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(1, 3)
	return sb


func _gui_input(event: InputEvent) -> void:
	if not interactive or card == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_begin_press()
		else:
			_end_press()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_begin_press()
		else:
			_end_press()


func _process(_delta: float) -> void:
	if not _pressing or _long_press_fired:
		return
	if Time.get_ticks_msec() - _press_started_ms >= LONG_PRESS_MS:
		_long_press_fired = true
		preview_started.emit(card)


func _begin_press() -> void:
	_pressing = true
	_long_press_fired = false
	_press_started_ms = Time.get_ticks_msec()
	set_process(true)


func _end_press() -> void:
	set_process(false)
	if _pressing and not _long_press_fired and playable:
		played.emit(card)
	if _long_press_fired:
		preview_ended.emit()
	_pressing = false
	_long_press_fired = false
