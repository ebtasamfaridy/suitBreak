class_name GameEngine
extends RefCounted

## Authoritative rules. Host runs this; clients only apply snapshots.

var state := GameState.new()
var rng := RandomNumberGenerator.new()
var _round_order: Array[Player] = []


func start(config: GameConfig, humans: Array = []) -> void:
	state = GameState.new()
	state.config = config
	state.game_phase = SuitBreakTypes.GamePhase.DEALING
	rng.randomize()
	if config.rng_seed != 0:
		rng.seed = config.rng_seed
	_setup_players(config.player_count, humans)
	_deal()
	_rebuild_active()
	var leader := _find_ace_of_spades_holder()
	state.opening_ace_pending = true
	state.last_message = "%s received A♠ and must play it to open the game." % leader.display_name
	_begin_round(leader)
	_assert_invariants()


func is_game_over() -> bool:
	return state.game_phase == SuitBreakTypes.GamePhase.GAME_OVER


func is_human_turn() -> bool:
	return is_turn_for_peer(-1)


func is_turn_for_peer(local_peer_id: int) -> bool:
	if state.game_phase != SuitBreakTypes.GamePhase.IN_ROUND:
		return false
	if state.current_player == null:
		return false
	if local_peer_id > 0:
		return state.current_player.peer_id == local_peer_id
	return state.current_player.is_human


func player_for_peer(peer_id: int) -> Player:
	for player in state.players:
		if player.peer_id == peer_id:
			return player
	return null


func play_suit_rank(player: Player, suit: SuitBreakTypes.Suit, rank: SuitBreakTypes.Rank) -> PlayOutcome:
	for card in player.hand:
		if card.suit == suit and card.rank == rank:
			return play_card(player, card)
	return PlayOutcome.fail("That card is not in the player's hand.")


func legal_cards(player: Player) -> Array[Card]:
	var result: Array[Card] = []
	if state.game_phase != SuitBreakTypes.GamePhase.IN_ROUND:
		return result
	if player != state.current_player:
		return result
	var round_state := state.current_round
	if round_state == null:
		return result
	if state.opening_ace_pending:
		for card in player.hand:
			if card.suit == SuitBreakTypes.Suit.SPADES and card.rank == SuitBreakTypes.Rank.ACE:
				result.append(card)
		return result
	if not round_state.has_current_suit:
		result.assign(player.hand)
		return result
	for card in player.hand:
		if card.suit == round_state.current_suit:
			result.append(card)
	if result.is_empty():
		result.assign(player.hand)
	return result


func play_card(player: Player, card: Card) -> PlayOutcome:
	if state.game_phase != SuitBreakTypes.GamePhase.IN_ROUND:
		return PlayOutcome.fail("The round is not in progress.")
	if player != state.current_player:
		return PlayOutcome.fail("It is not %s's turn." % player.display_name)
	var hand_index := player.hand.find(card)
	if hand_index < 0:
		return PlayOutcome.fail("That card is not in the player's hand.")
	if not _is_legal(player, card):
		if state.opening_ace_pending:
			return PlayOutcome.fail("The opening play must be A♠.")
		return PlayOutcome.fail("That play does not follow the current suit.")

	player.hand.remove_at(hand_index)
	state.opening_ace_pending = false
	state.table_cards.append(card)

	var round_state := state.current_round
	round_state.cards_played.append(card)
	round_state.players_who_played.append(player)
	_note_highest(round_state, player, card)

	if not round_state.has_current_suit:
		round_state.has_current_suit = true
		round_state.current_suit = card.suit
		state.last_message = "%s leads %s. Current suit: %s." % [
			player.display_name, card.label(), Card.suit_name_of(card.suit)
		]
	elif card.suit != round_state.current_suit:
		round_state.suit_break_player = player
		round_state.round_end_reason = SuitBreakTypes.RoundEndReason.SUIT_BREAK
		state.last_message = "%s breaks the suit with %s." % [player.display_name, card.label()]
		var ended := _end_round()
		_assert_invariants()
		return ended
	else:
		state.last_message = "%s follows with %s." % [player.display_name, card.label()]

	if round_state.players_who_played.size() >= _round_order.size():
		round_state.round_end_reason = SuitBreakTypes.RoundEndReason.ALL_FOLLOWED
		var followed := _end_round()
		_assert_invariants()
		return followed

	state.current_player = _round_order[round_state.players_who_played.size()]
	_assert_invariants()
	return PlayOutcome.ok_play(false, false)


func _setup_players(count: int, humans: Array) -> void:
	if humans.is_empty():
		for i in count:
			if i == 0:
				state.players.append(Player.new(0, "You", true, 0))
			else:
				state.players.append(Player.new(i, "Bot %d" % i, false, 0))
		return
	var bot_n := 1
	for i in count:
		if i < humans.size():
			var entry: Dictionary = humans[i]
			state.players.append(Player.new(
				i,
				str(entry.get("name", "Player %d" % (i + 1))),
				true,
				int(entry.get("peer_id", 0))
			))
		else:
			state.players.append(Player.new(i, "Bot %d" % bot_n, false, 0))
			bot_n += 1


func _deal() -> void:
	var cards := Deck.make_standard()
	Deck.shuffle(cards, rng)
	var seat := 0
	for card in cards:
		state.players[seat].hand.append(card)
		seat = (seat + 1) % state.players.size()


func _find_ace_of_spades_holder() -> Player:
	for player in state.players:
		for card in player.hand:
			if card.suit == SuitBreakTypes.Suit.SPADES and card.rank == SuitBreakTypes.Rank.ACE:
				return player
	push_error("Ace of Spades was not dealt.")
	return state.players[0]


func _begin_round(leader: Player) -> void:
	state.game_phase = SuitBreakTypes.GamePhase.IN_ROUND
	state.current_leader = leader
	state.current_player = leader
	state.table_cards.clear()
	_round_order = _active_clockwise_from(leader)
	var round_state := RoundState.new()
	round_state.leader = leader
	state.current_round = round_state


func _active_clockwise_from(leader: Player) -> Array[Player]:
	var order: Array[Player] = []
	var n := state.players.size()
	for i in n:
		var player := state.players[(leader.id + i) % n]
		if player.status == SuitBreakTypes.PlayerStatus.ACTIVE:
			order.append(player)
	return order


func _is_legal(player: Player, card: Card) -> bool:
	return legal_cards(player).has(card)


func _note_highest(round_state: RoundState, player: Player, card: Card) -> void:
	if round_state.highest_card == null or int(card.rank) > int(round_state.highest_card.rank):
		round_state.highest_card = card
		round_state.highest_card_player = player


func _end_round() -> PlayOutcome:
	var round_state := state.current_round
	var discarded := false
	if round_state.round_end_reason == SuitBreakTypes.RoundEndReason.SUIT_BREAK:
		var collector := _collector_after_suit_break(round_state)
		if collector != null:
			for card in state.table_cards:
				collector.hand.append(card)
			state.last_message += " %s takes the table cards. %s should lead next." % [
				collector.display_name, round_state.suit_break_player.display_name
			]
		else:
			_move_table_to_discard()
			discarded = true
			state.last_message += " Nobody could take the cards, so they were discarded."
	else:
		_move_table_to_discard()
		discarded = true
		state.last_message += " Everyone followed. Cards go to the discard pile. %s played the highest card." % (
			round_state.highest_card_player.display_name if round_state.highest_card_player else "Nobody"
		)

	state.table_cards.clear()
	_mark_finished_players()
	_rebuild_active()

	if state.active_players.size() <= 1:
		state.game_phase = SuitBreakTypes.GamePhase.GAME_OVER
		state.current_player = null
		if state.active_players.size() == 1:
			var loser := state.active_players[0]
			loser.status = SuitBreakTypes.PlayerStatus.LOSER
			state.last_message += " %s is the sole loser." % loser.display_name
		else:
			state.last_message += " Every player emptied their hand."
		return PlayOutcome.ok_play(true, true, discarded)

	var intended := round_state.suit_break_player if round_state.round_end_reason == SuitBreakTypes.RoundEndReason.SUIT_BREAK else round_state.highest_card_player
	var next_leader := _first_active_from(intended)
	state.last_message += " %s leads." % next_leader.display_name
	_begin_round(next_leader)
	return PlayOutcome.ok_play(true, false, discarded)


func _collector_after_suit_break(round_state: RoundState) -> Player:
	if round_state.highest_card_player != null and not round_state.highest_card_player.hand.is_empty():
		return round_state.highest_card_player
	var best: Player = null
	var best_rank := -1
	for i in round_state.cards_played.size():
		var player := round_state.players_who_played[i]
		var card := round_state.cards_played[i]
		if player.hand.is_empty():
			continue
		if int(card.rank) > best_rank:
			best_rank = int(card.rank)
			best = player
	return best


func _move_table_to_discard() -> void:
	for card in state.table_cards:
		state.discard_pile.append(card)


func _mark_finished_players() -> void:
	for player in state.players:
		if player.status == SuitBreakTypes.PlayerStatus.ACTIVE and player.hand.is_empty():
			player.status = SuitBreakTypes.PlayerStatus.FINISHED


func _rebuild_active() -> void:
	state.active_players.clear()
	for player in state.players:
		if player.status == SuitBreakTypes.PlayerStatus.ACTIVE:
			state.active_players.append(player)


func _first_active_from(intended: Player) -> Player:
	var n := state.players.size()
	var start := intended.id if intended != null else 0
	for i in n:
		var player := state.players[(start + i) % n]
		if player.status == SuitBreakTypes.PlayerStatus.ACTIVE:
			return player
	return state.active_players[0]


func _assert_invariants() -> void:
	var counted := state.discard_pile.size() + state.table_cards.size()
	for player in state.players:
		counted += player.hand.size()
		if player.status == SuitBreakTypes.PlayerStatus.FINISHED and not player.hand.is_empty():
			push_error("Finished player still has cards: %s" % player.display_name)
	if counted != 52:
		push_error("Card locations do not sum to 52 (found %d)." % counted)


func to_snapshot() -> Dictionary:
	var players_data: Array = []
	for player in state.players:
		var hand_data: Array = []
		for card in player.hand:
			hand_data.append(_card_to_arr(card))
		players_data.append({
			"id": player.id,
			"name": player.display_name,
			"human": player.is_human,
			"peer": player.peer_id,
			"status": int(player.status),
			"hand": hand_data,
		})
	var table_data: Array = []
	for card in state.table_cards:
		table_data.append(_card_to_arr(card))
	var round_data := {}
	if state.current_round != null:
		var round_state := state.current_round
		round_data = {
			"has_suit": round_state.has_current_suit,
			"suit": int(round_state.current_suit) if round_state.has_current_suit else -1,
			"leader": round_state.leader.id if round_state.leader else -1,
			"reason": int(round_state.round_end_reason),
			"break": round_state.suit_break_player.id if round_state.suit_break_player else -1,
			"high": _card_to_arr(round_state.highest_card) if round_state.highest_card else [],
			"high_player": round_state.highest_card_player.id if round_state.highest_card_player else -1,
		}
	return {
		"phase": int(state.game_phase),
		"message": state.last_message,
		"opening": state.opening_ace_pending,
		"discard": state.discard_pile.size(),
		"current": state.current_player.id if state.current_player else -1,
		"leader": state.current_leader.id if state.current_leader else -1,
		"table": table_data,
		"round": round_data,
		"players": players_data,
	}


func apply_snapshot(data: Dictionary) -> void:
	state = GameState.new()
	state.game_phase = data.get("phase", 0) as SuitBreakTypes.GamePhase
	state.last_message = str(data.get("message", ""))
	state.opening_ace_pending = bool(data.get("opening", false))
	for _i in int(data.get("discard", 0)):
		state.discard_pile.append(Card.new())
	for row in data.get("table", []):
		state.table_cards.append(_card_from_arr(row))
	for row in data.get("players", []):
		var player := Player.new(
			int(row.get("id", 0)),
			str(row.get("name", "")),
			bool(row.get("human", false)),
			int(row.get("peer", 0))
		)
		player.status = int(row.get("status", 0)) as SuitBreakTypes.PlayerStatus
		for card_row in row.get("hand", []):
			player.hand.append(_card_from_arr(card_row))
		state.players.append(player)
	_rebuild_active()
	state.current_player = _player_by_id(int(data.get("current", -1)))
	state.current_leader = _player_by_id(int(data.get("leader", -1)))
	var round_data: Dictionary = data.get("round", {})
	if not round_data.is_empty():
		var round_state := RoundState.new()
		round_state.has_current_suit = bool(round_data.get("has_suit", false))
		if round_state.has_current_suit:
			round_state.current_suit = int(round_data.get("suit", 0)) as SuitBreakTypes.Suit
		round_state.leader = _player_by_id(int(round_data.get("leader", -1)))
		round_state.round_end_reason = int(round_data.get("reason", 0)) as SuitBreakTypes.RoundEndReason
		round_state.suit_break_player = _player_by_id(int(round_data.get("break", -1)))
		var high: Array = round_data.get("high", [])
		if not high.is_empty():
			round_state.highest_card = _card_from_arr(high)
		round_state.highest_card_player = _player_by_id(int(round_data.get("high_player", -1)))
		state.current_round = round_state


func _player_by_id(id: int) -> Player:
	if id < 0:
		return null
	for player in state.players:
		if player.id == id:
			return player
	return null


func _card_to_arr(card: Card) -> Array:
	return [int(card.suit), int(card.rank)]


func _card_from_arr(row: Array) -> Card:
	if row.size() < 2:
		return Card.new()
	return Card.new(int(row[0]) as SuitBreakTypes.Suit, int(row[1]) as SuitBreakTypes.Rank)
