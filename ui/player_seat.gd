class_name PlayerSeat
extends Control

enum SeatPlace { TOP, LEFT, RIGHT }

@onready var _name_label: Label = %NameLabel
@onready var _stack: CardStack = %CardStack


func setup(player: Player, active: bool, _status_text: String, p_side: SeatPlace = SeatPlace.TOP) -> void:
	_name_label.text = player.display_name
	_name_label.modulate = Color(1, 0.95, 0.55) if active else Color(0.92, 0.96, 0.9)
	var count := player.hand.size()
	if player.status == SuitBreakTypes.PlayerStatus.FINISHED:
		count = 0
	var stack_side := CardStack.FanPlace.TOP
	match p_side:
		SeatPlace.LEFT:
			stack_side = CardStack.FanPlace.LEFT
			_name_label.rotation_degrees = -90.0
			_name_label.position = Vector2(108, 118)
			_name_label.size = Vector2(140, 28)
			_stack.position = Vector2(4, 8)
		SeatPlace.RIGHT:
			stack_side = CardStack.FanPlace.RIGHT
			_name_label.rotation_degrees = 90.0
			_name_label.position = Vector2(28, 20)
			_name_label.size = Vector2(140, 28)
			_stack.position = Vector2(36, 8)
		_:
			_name_label.rotation_degrees = 0.0
			_name_label.position = Vector2(0, 108)
			_name_label.size = Vector2(200, 28)
			_stack.position = Vector2(20, 0)
	_stack.set_card_count(count, stack_side)
