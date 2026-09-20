class_name CardView
extends Control

signal clicked(card: Card)

var card: Card
var interactive: bool = false
var playable: bool = true


func bind(p_card: Card, face_up: bool = true, p_interactive: bool = false, p_playable: bool = true) -> void:
	card = p_card
	interactive = p_interactive and face_up
	playable = p_playable
	mouse_filter = Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if interactive and playable else Control.CURSOR_ARROW
	$Back.visible = not face_up
	$Face.visible = face_up
	$RankTop.visible = face_up
	$RankBottom.visible = face_up
	$SuitCenter.visible = face_up
	if face_up and card != null:
		var ink := Color(0.75, 0.12, 0.16) if card.is_red() else Color(0.12, 0.12, 0.14)
		var text := card.label()
		$RankTop.text = text
		$RankBottom.text = text
		$SuitCenter.text = card.suit_glyph()
		$RankTop.add_theme_color_override("font_color", ink)
		$RankBottom.add_theme_color_override("font_color", ink)
		$SuitCenter.add_theme_color_override("font_color", ink)
	$Dim.visible = interactive and not playable


func _gui_input(event: InputEvent) -> void:
	if not interactive or not playable or card == null:
		return
	if event is InputEventMouseButton:
		var mouse := event as InputEventMouseButton
		if mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(card)
