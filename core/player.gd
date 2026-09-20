class_name Player
extends RefCounted

var id: int
var display_name: String
var is_human: bool = false
var peer_id: int = 0
var status: SuitBreakTypes.PlayerStatus = SuitBreakTypes.PlayerStatus.ACTIVE
var hand: Array[Card] = []


func _init(p_id: int = 0, p_display_name: String = "", p_is_human: bool = false, p_peer_id: int = 0) -> void:
	id = p_id
	display_name = p_display_name
	is_human = p_is_human
	peer_id = p_peer_id


func has_suit(suit: SuitBreakTypes.Suit) -> bool:
	for card in hand:
		if card.suit == suit:
			return true
	return false
