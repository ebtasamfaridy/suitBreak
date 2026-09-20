class_name Card
extends RefCounted

const SUIT_GLYPHS := ["♠", "♥", "♦", "♣"]
const SUIT_NAMES := ["Spades", "Hearts", "Diamonds", "Clubs"]

var suit: SuitBreakTypes.Suit
var rank: SuitBreakTypes.Rank


func _init(p_suit: SuitBreakTypes.Suit = SuitBreakTypes.Suit.SPADES, p_rank: SuitBreakTypes.Rank = SuitBreakTypes.Rank.TWO) -> void:
	suit = p_suit
	rank = p_rank


func is_red() -> bool:
	return suit == SuitBreakTypes.Suit.HEARTS or suit == SuitBreakTypes.Suit.DIAMONDS


func rank_label() -> String:
	match rank:
		SuitBreakTypes.Rank.JACK:
			return "J"
		SuitBreakTypes.Rank.QUEEN:
			return "Q"
		SuitBreakTypes.Rank.KING:
			return "K"
		SuitBreakTypes.Rank.ACE:
			return "A"
		_:
			return str(int(rank))


func suit_glyph() -> String:
	return SUIT_GLYPHS[int(suit)]


func suit_name() -> String:
	return SUIT_NAMES[int(suit)]


func label() -> String:
	return rank_label() + suit_glyph()


static func suit_name_of(p_suit: SuitBreakTypes.Suit) -> String:
	return SUIT_NAMES[int(p_suit)]
