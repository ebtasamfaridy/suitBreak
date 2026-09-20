class_name RoundState
extends RefCounted

var leader: Player
var has_current_suit: bool = false
var current_suit: SuitBreakTypes.Suit
var cards_played: Array[Card] = []
var players_who_played: Array[Player] = []
var suit_break_player: Player
var round_end_reason: SuitBreakTypes.RoundEndReason = SuitBreakTypes.RoundEndReason.NONE
var highest_card: Card
var highest_card_player: Player
