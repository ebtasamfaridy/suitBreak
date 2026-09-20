extends Control

const CARD_VIEW := preload("res://scenes/cards/card_view.tscn")
const PILE_ANGLES := [-22.0, 8.0, 26.0, -10.0, 16.0, -28.0, 4.0, 20.0]
const BOT_DELAY := 0.65
const MENU_SCENE := "res://main.tscn"

@onready var _felt: TextureRect = %Felt
@onready var _center_well: Panel = %CenterWell
@onready var _back_button: Button = %BackButton
@onready var _status_label: Label = %StatusLabel
@onready var _discard_label: Label = %DiscardLabel
@onready var _suit_label: Label = %SuitLabel
@onready var _seat_top: PlayerSeat = %SeatTop
@onready var _seat_left: PlayerSeat = %SeatLeft
@onready var _seat_right: PlayerSeat = %SeatRight
@onready var _center_cards: Control = %CenterCards
@onready var _hand: Control = %Hand
@onready var _turn_banner: PanelContainer = %TurnBanner
@onready var _turn_label: Label = %TurnLabel
@onready var _preview_layer: ColorRect = %CardPreview
@onready var _preview_card: CardView = %PreviewCard
@onready var _local_name: Label = %LocalName
@onready var _game_over: ColorRect = %GameOverLayer
@onready var _result_label: Label = %ResultLabel
@onready var _menu_button: Button = %MenuButton
@onready var _again_button: Button = %AgainButton

var _engine := GameEngine.new()
var _busy := false
var _end_sfx_played := false


func _ready() -> void:
	_paint_table()
	GameAudio.play_music("game")
	_back_button.pressed.connect(_on_menu_pressed)
	_menu_button.pressed.connect(_on_menu_pressed)
	_again_button.pressed.connect(_on_again_pressed)
	resized.connect(_on_resized)
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


func _on_resized() -> void:
	if _engine.state.players.is_empty():
		return
	var human := _local_player()
	if human == null:
		return
	_rebuild_hand(human, _engine.legal_cards(human))
	_rebuild_center_cards(_engine.state.table_cards)


func _paint_table() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(0.2, 0.58, 0.28))
	grad.set_color(1, Color(0.04, 0.16, 0.08))
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.46)
	tex.fill_to = Vector2(0.5, 0.02)
	tex.width = 128
	tex.height = 128
	_felt.texture = tex
	var well := StyleBoxFlat.new()
	well.bg_color = Color(0.04, 0.22, 0.1, 0.55)
	well.set_corner_radius_all(140)
	well.set_border_width_all(0)
	_center_well.add_theme_stylebox_override("panel", well)
	var banner := StyleBoxFlat.new()
	banner.bg_color = Color(0.96, 0.84, 0.22, 0.92)
	banner.set_corner_radius_all(8)
	_turn_banner.add_theme_stylebox_override("panel", banner)


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


func _on_card_played(card: Card) -> void:
	_commit_play.call_deferred(card)


func _commit_play(card: Card) -> void:
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
		GameAudio.play_sfx("illegal")
		return
	_cue_play_audio(outcome)
	_refresh()
	_broadcast_snapshot()
	await _advance_bots()


func _on_card_preview_started(card: Card) -> void:
	_preview_card.set_display_size(Vector2(140, 196))
	_preview_card.bind(card, true, false, false)
	_preview_layer.visible = true


func _on_card_preview_ended() -> void:
	_preview_layer.visible = false


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
	_cue_play_audio(outcome)
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
	var prev_discard := _engine.state.discard_pile.size()
	var prev_table := _engine.state.table_cards.size()
	var prev_over := _engine.is_game_over()
	_engine.apply_snapshot(data)
	_busy = false
	_cue_snapshot_audio(prev_discard, prev_table, prev_over)
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
	_end_sfx_played = false
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
		var bot_outcome := _engine.play_card(_engine.state.current_player, bot_card)
		_cue_play_audio(bot_outcome)
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
	_discard_label.text = "Pile %d" % state.discard_pile.size()
	if state.current_round != null and state.current_round.has_current_suit and state.game_phase == SuitBreakTypes.GamePhase.IN_ROUND:
		_suit_label.text = Card.suit_name_of(state.current_round.current_suit)
	else:
		_suit_label.text = "No suit"
	_rebuild_seats()
	_rebuild_center_cards(state.table_cards)
	var human := _local_player()
	if human == null:
		return
	_local_name.text = human.display_name
	_local_name.modulate = Color(1, 0.95, 0.55) if _is_my_turn() and not _engine.is_game_over() else Color.WHITE
	var legal := _engine.legal_cards(human)
	_rebuild_hand(human, legal)
	_update_turn_banner()
	if _is_my_turn() and not _busy and not _engine.is_game_over():
		_status_label.text = ""
	elif MatchSettings.networked and _is_human_seat_turn() and not _is_my_turn():
		_status_label.text = "Waiting for %s..." % state.current_player.display_name
	_game_over.visible = _engine.is_game_over()
	if _engine.is_game_over():
		_result_label.text = _game_over_text()
		_again_button.visible = (not MatchSettings.networked) or SuitBreakNetwork.I.is_host()


func _update_turn_banner() -> void:
	var show := _is_my_turn() and not _busy and not _engine.is_game_over()
	_turn_banner.visible = show
	if show:
		_turn_label.text = "Your turn"


func _other_players() -> Array[Player]:
	var local := _local_player()
	var others: Array[Player] = []
	for player in _engine.state.players:
		if local != null and player.id == local.id:
			continue
		others.append(player)
	return others


func _rebuild_seats() -> void:
	var seats: Array[PlayerSeat] = [_seat_top, _seat_left, _seat_right]
	var places: Array[PlayerSeat.SeatPlace] = [
		PlayerSeat.SeatPlace.TOP,
		PlayerSeat.SeatPlace.LEFT,
		PlayerSeat.SeatPlace.RIGHT,
	]
	for seat in seats:
		seat.visible = false
	var others := _other_players()
	if others.size() == 1:
		_seat_top.visible = true
		_seat_top.setup(others[0], others[0] == _engine.state.current_player, _status_text(others[0]), PlayerSeat.SeatPlace.TOP)
		return
	if others.size() == 2:
		_seat_left.visible = true
		_seat_right.visible = true
		_seat_left.setup(others[0], others[0] == _engine.state.current_player, _status_text(others[0]), PlayerSeat.SeatPlace.LEFT)
		_seat_right.setup(others[1], others[1] == _engine.state.current_player, _status_text(others[1]), PlayerSeat.SeatPlace.RIGHT)
		return
	for i in others.size():
		if i >= seats.size():
			break
		seats[i].visible = true
		seats[i].setup(others[i], others[i] == _engine.state.current_player, _status_text(others[i]), places[i])


func _status_text(player: Player) -> String:
	match player.status:
		SuitBreakTypes.PlayerStatus.FINISHED:
			return "Finished"
		SuitBreakTypes.PlayerStatus.LOSER:
			return "Loser · %d cards" % player.hand.size()
		_:
			return "%d cards" % player.hand.size()


func _clear(host: Node) -> void:
	var kids := host.get_children()
	for child in kids:
		host.remove_child(child)
		child.queue_free()


func _rebuild_center_cards(cards: Array[Card]) -> void:
	_clear(_center_cards)
	if cards.is_empty():
		return
	var card_size := CardView.SIZE_PILE
	for i in cards.size():
		var view: CardView = CARD_VIEW.instantiate()
		_center_cards.add_child(view)
		view.set_display_size(card_size)
		view.pivot_offset = card_size * 0.5
		var t := 0.5 if cards.size() == 1 else float(i) / float(cards.size() - 1)
		view.position = Vector2(lerpf(36.0, 150.0, t), 18.0 + float(i % 3) * 6.0)
		view.rotation_degrees = PILE_ANGLES[i % PILE_ANGLES.size()]
		view.z_index = i
		view.bind(cards[i], true, false, false)


func _rebuild_hand(human: Player, legal: Array[Card]) -> void:
	_clear(_hand)
	var sorted: Array[Card] = []
	sorted.assign(human.hand)
	sorted.sort_custom(func(a: Card, b: Card) -> bool:
		if a.suit == b.suit:
			return int(a.rank) < int(b.rank)
		return int(a.suit) < int(b.suit)
	)
	var count := sorted.size()
	if count == 0:
		return
	var card_size := CardView.SIZE_HAND
	var area_w := maxf(_hand.size.x, 320.0)
	var area_h := maxf(_hand.size.y, 180.0)
	var span := clampf(float(count - 1) * 5.5, 8.0, 52.0)
	var step := mini(56, int((area_w - card_size.x) / maxi(count, 1)))
	step = clampi(step, 28, 56)
	var total_w := card_size.x + float(count - 1) * float(step)
	var start_x := (area_w - total_w) * 0.5
	for i in count:
		var card: Card = sorted[i]
		var view: CardView = CARD_VIEW.instantiate()
		_hand.add_child(view)
		view.set_display_size(card_size)
		var t := 0.5 if count == 1 else float(i) / float(count - 1)
		var tilt := lerpf(-span * 0.5, span * 0.5, t)
		view.rotation_degrees = tilt
		var can_play := _is_my_turn() and not _busy and legal.has(card)
		var lift := 28.0 if can_play else 0.0
		var arc := absf(tilt) * 0.55
		view.position = Vector2(start_x + float(i) * float(step), area_h - card_size.y - 10.0 - lift + arc)
		view.z_index = i
		view.bind(card, true, true, can_play)
		view.played.connect(_on_card_played)
		view.preview_started.connect(_on_card_preview_started)
		view.preview_ended.connect(_on_card_preview_ended)


func _cue_play_audio(outcome: PlayOutcome) -> void:
	if outcome == null or not outcome.ok:
		return
	GameAudio.play_sfx("play_card")
	if outcome.discarded:
		GameAudio.play_sfx("discard")
	if outcome.game_over:
		_cue_game_over_audio()


func _cue_snapshot_audio(prev_discard: int, prev_table: int, prev_over: bool) -> void:
	if _engine.is_game_over() and not prev_over:
		GameAudio.play_sfx("play_card")
		if _engine.state.discard_pile.size() > prev_discard:
			GameAudio.play_sfx("discard")
		_cue_game_over_audio()
		return
	if _engine.state.discard_pile.size() > prev_discard:
		GameAudio.play_sfx("play_card")
		GameAudio.play_sfx("discard")
		return
	if _engine.state.table_cards.size() != prev_table:
		GameAudio.play_sfx("play_card")


func _cue_game_over_audio() -> void:
	if _end_sfx_played:
		return
	_end_sfx_played = true
	var local := _local_player()
	var lost := false
	for player in _engine.state.players:
		if player.status == SuitBreakTypes.PlayerStatus.LOSER:
			if local != null and player.id == local.id:
				lost = true
			break
	GameAudio.play_sfx("lose" if lost else "win")


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
