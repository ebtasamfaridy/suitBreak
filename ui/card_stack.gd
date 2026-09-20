class_name CardStack
extends Control

const CARD_SIZE := Vector2(58, 82)

enum FanPlace { TOP, LEFT, RIGHT }

var side: FanPlace = FanPlace.TOP


func set_card_count(count: int, p_side: FanPlace = FanPlace.TOP) -> void:
	side = p_side
	for child in get_children():
		child.queue_free()
	var shown := mini(count, 8)
	if shown <= 0:
		custom_minimum_size = Vector2(80, 90)
		return
	var span := clampf(float(shown - 1) * 9.0, 10.0, 46.0)
	for i in shown:
		var tile := _make_back()
		add_child(tile)
		var t := 0.5 if shown == 1 else float(i) / float(shown - 1)
		var tilt := lerpf(-span * 0.5, span * 0.5, t)
		tile.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y)
		match side:
			FanPlace.LEFT:
				tile.rotation_degrees = 90.0 + tilt
				tile.position = Vector2(8.0, 18.0 + t * 22.0 * float(shown - 1))
			FanPlace.RIGHT:
				tile.rotation_degrees = -90.0 + tilt
				tile.position = Vector2(18.0, 18.0 + t * 22.0 * float(shown - 1))
			_:
				tile.rotation_degrees = tilt
				tile.position = Vector2(t * 22.0 * float(shown - 1), 12.0 + absf(tilt) * 0.35)
		tile.z_index = i
	match side:
		FanPlace.LEFT, FanPlace.RIGHT:
			custom_minimum_size = Vector2(110, 70 + shown * 18)
		_:
			custom_minimum_size = Vector2(70 + shown * 18, 110)


func _make_back() -> Panel:
	var card := Panel.new()
	card.custom_minimum_size = CARD_SIZE
	card.size = CARD_SIZE
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.12, 0.22, 0.48)
	sb.set_corner_radius_all(8)
	sb.set_border_width_all(2)
	sb.border_color = Color(0.72, 0.82, 0.95)
	sb.shadow_color = Color(0, 0, 0, 0.4)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(1, 2)
	card.add_theme_stylebox_override("panel", sb)
	var inner := ColorRect.new()
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.position = Vector2(6, 6)
	inner.size = CARD_SIZE - Vector2(12, 12)
	inner.color = Color(0.18, 0.32, 0.62)
	card.add_child(inner)
	return card
