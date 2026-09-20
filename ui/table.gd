extends Control

const CARD_VIEW := preload("res://scenes/cards/card_view.tscn")
const BOT_DELAY := 0.65
const MENU_SCENE := "res://main.tscn"

@onready var _back_button: Button = %BackButton
@onready var _status_label: Label = %StatusLabel
@onready var _discard_label: Label = %DiscardLabel
@onready var _suit_label: Label = %SuitLabel
@onready var _opponents: HBoxContainer = %Opponents
@onready var _table_cards: HBoxContainer = %TableCards
@onready var _hand: HBoxContainer = %Hand
@onready var _game_over: ColorRect = %GameOverLayer
@onready var _result_label: Label = %ResultLabel
@onready var _menu_button: Button = %MenuButton
@onready var _again_button: Button = %AgainButton

var _engine := GameEngine.new()
var _busy := false


func _ready() -> void:
	_back_button.pressed.connect(_on_menu_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_again_button.pressed.connect(_on_again_pressed)
	if MatchSettings.networked:
		set_multiplayer_authority(1)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		SuitBreakNetwork.I.server_disconnected.connect(_on_host_lost)
		if SuitBreakNetwork.I.is_host():
			var config := GameConfig.new()
			config.player_count = clampi(maxi(SuitBreakNetwork.I.roster.size(), MatchSettings.player_count), 2, 4)
			_engine.start(config, SuitBreakNetwork.I.roster)
			_refresh()
			await _advance_bots()
			_broadcast_snapshot()
		else:
			_status_label.text = "Waiting for the host..."
			_retry_snapshot()
		return
	var local_config := GameConfig.new()
	local_config.player_count = MatchSettings.player_count
	_engine.start(local_config)
	_refresh()
	await _advance_bots()


func _exit_tree() -> void:
	if SuitBreakNetwork.I.server_disconnected.is_connected(_on_host_lost):
		SuitBreakNetwork.I.server_disconnected.disconnect(_on_host_lost)


func _on_menu_pressed() -> void:
	SuitBreakNetwork.I.close_connection()
	MatchSettings.networked = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_again_pressed() -> void:
	if MatchSettings.networked:
		if SuitBreakNetwork.I.is_host():
			rpc("restart_match")
		return
	get_tree().reload_current_scene()


func _on_card_clicked(card: Card) -> void:
	if _busy or not _is_my_turn():
		return
	if MatchSettings.networked and not SuitBreakNetwork.I.is_host():
		_busy = true
		rpc_id(1, "request_play", int(card.suit), int(card.rank))
		return
	_busy = true
	var outcome := _engine.play_card(_engine.state.current_player, card)
	if not outcome.ok:
		_busy = false
		_status_label.text = outcome.error
		return
	_refresh()
	_broadcast_snapshot()
	await _advance_bots()


@rpc("any_peer", "reliable")
func request_play(suit: int, rank: int) -> void:
	if not SuitBreakNetwork.I.is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	var player := _engine.player_for_peer(sender)
	if player == null:
		return
	if _engine.state.current_player != player:
		return
	var outcome := _engine.play_suit_rank(player, suit as SuitBreakTypes.Suit, rank as SuitBreakTypes.Rank)
	if not outcome.ok:
		_broadcast_snapshot()
		return
	_refresh()
	_broadcast_snapshot()
	await _advance_bots()


@rpc("any_peer", "reliable")
func request_snapshot() -> void:
	if not SuitBreakNetwork.I.is_host():
		return
	rpc_id(multiplayer.get_remote_sender_id(), "apply_snapshot", _engine.to_snapshot())


@rpc("any_peer", "reliable")
func apply_snapshot(data: Dictionary) -> void:
	if SuitBreakNetwork.I.is_host():
		return
	_engine.apply_snapshot(data)
	_busy = false
	_refresh()


@rpc("any_peer", "call_local", "reliable")
func restart_match() -> void:
	if not MatchSettings.networked:
		return
	if not SuitBreakNetwork.I.is_host():
		return
	var config := GameConfig.new()
	config.player_count = clampi(maxi(SuitBreakNetwork.I.roster.size(), MatchSettings.player_count), 2, 4)
	_engine.start(config, SuitBreakNetwork.I.roster)
	_refresh()
	_broadcast_snapshot()
	await _advance_bots()
	_broadcast_snapshot()


func _retry_snapshot() -> void:
	if not is_inside_tree() or SuitBreakNetwork.I.is_host():
		return
	if not _engine.state.players.is_empty():
		return
	rpc_id(1, "request_snapshot")
	get_tree().create_timer(0.4).timeout.connect(_retry_snapshot)


func _broadcast_snapshot() -> void:
	if not MatchSettings.networked or not SuitBreakNetwork.I.is_host():
		return
	rpc("apply_snapshot", _engine.to_snapshot())


func _advance_bots() -> void:
	if MatchSettings.networked and not SuitBreakNetwork.I.is_host():
		_busy = false
		_refresh()
		return
	_busy = true
	while is_inside_tree() and not _engine.is_game_over() and not _is_human_seat_turn():
		await get_tree().create_timer(BOT_DELAY).timeout
		if not is_inside_tree():
			return
		if _engine.state.current_player == null or _engine.state.current_player.is_human:
			break
		var bot_card := SimpleBot.choose(_engine)
		_engine.play_card(_engine.state.current_player, bot_card)
		_refresh()
		_broadcast_snapshot()
	_busy = false
	_refresh()
	_broadcast_snapshot()


func _is_human_seat_turn() -> bool:
	var current := _engine.state.current_player
	return current != null and current.is_human


func _is_my_turn() -> bool:
	return _engine.is_turn_for_peer(_local_peer())


func _local_peer() -> int:
	if MatchSettings.networked and multiplayer.multiplayer_peer != null:
		return multiplayer.get_unique_id()
	return -1


func _local_player() -> Player:
	if _engine.state.players.is_empty():
		return null
	if MatchSettings.networked:
		var mine := _engine.player_for_peer(_local_peer())
		if mine != null:
			return mine
	return _engine.state.players[0]


func _refresh() -> void:
	if _engine.state.players.is_empty():
		return
	var state := _engine.state
	_status_label.text = state.last_message
	_discard_label.text = "Discard: %d" % state.discard_pile.size()
	if state.current_round != null and state.current_round.has_current_suit and state.game_phase == SuitBreakTypes.GamePhase.IN_ROUND:
		_suit_label.text = "Suit: %s" % Card.suit_name_of(state.current_round.current_suit)
	else:
		_suit_label.text = "Suit: —"
	_rebuild_opponents()
	_rebuild_row(_table_cards, state.table_cards, true, false)
	var human := _local_player()
	if human == null:
		return
	var legal := _engine.legal_cards(human)
	_rebuild_hand(human, legal)
	%HandLabel.text = "Your hand · %s" % _status_text(human)
	if _is_my_turn() and not _busy:
		_status_label.text = "%s  Your turn — play a highlighted card." % state.last_message
	elif MatchSettings.networked and _is_human_seat_turn() and not _is_my_turn():
		_status_label.text = "%s  Waiting for %s..." % [state.last_message, state.current_player.display_name]
	_game_over.visible = _engine.is_game_over()
	if _engine.is_game_over():
		_result_label.text = _game_over_text()
		_again_button.visible = (not MatchSettings.networked) or SuitBreakNetwork.I.is_host()


func _clear(host: Node) -> void:
	while host.get_child_count() > 0:
		var child := host.get_child(0)
		host.remove_child(child)
		child.free()


func _rebuild_opponents() -> void:
	_clear(_opponents)
	var local := _local_player()
	for player in _engine.state.players:
		if local != null and player.id == local.id:
			continue
		var box := VBoxContainer.new()
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		var name_label := Label.new()
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.text = player.display_name
		if player == _engine.state.current_player:
			name_label.text += "  ●"
		var info := Label.new()
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		info.text = _status_text(player)
		box.add_child(name_label)
		box.add_child(info)
		_opponents.add_child(box)


func _status_text(player: Player) -> String:
	match player.status:
		SuitBreakTypes.PlayerStatus.FINISHED:
			return "Finished"
		SuitBreakTypes.PlayerStatus.LOSER:
			return "Loser · %d cards" % player.hand.size()
		_:
			return "%d cards" % player.hand.size()


func _rebuild_row(host: HBoxContainer, cards: Array[Card], face_up: bool, interactive: bool) -> void:
	_clear(host)
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "No cards on the table"
		host.add_child(empty)
		return
	for card in cards:
		var view: CardView = CARD_VIEW.instantiate()
		host.add_child(view)
		view.bind(card, face_up, interactive, false)


func _rebuild_hand(human: Player, legal: Array[Card]) -> void:
	_clear(_hand)
	var sorted: Array[Card] = []
	sorted.assign(human.hand)
	sorted.sort_custom(func(a: Card, b: Card) -> bool:
		if a.suit == b.suit:
			return int(a.rank) < int(b.rank)
		return int(a.suit) < int(b.suit)
	)
	for card in sorted:
		var view: CardView = CARD_VIEW.instantiate()
		_hand.add_child(view)
		var can_play := _is_my_turn() and not _busy and legal.has(card)
		view.bind(card, true, true, can_play)
		view.clicked.connect(_on_card_clicked)


func _game_over_text() -> String:
	var local := _local_player()
	for player in _engine.state.players:
		if player.status == SuitBreakTypes.PlayerStatus.LOSER:
			if local != null and player.id == local.id:
				return "You were last with cards.\nYou lose."
			return "%s was last with cards.\nYou emptied your hand — you are not the loser." % player.display_name
	return "The game ended."


func _on_peer_disconnected(_id: int) -> void:
	_status_label.text = "A player left the room."


func _on_host_lost() -> void:
	_status_label.text = "Host disconnected."
	_busy = true
	MatchSettings.networked = false
