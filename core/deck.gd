class_name Deck
extends Object

static func make_standard() -> Array[Card]:
	var cards: Array[Card] = []
	for suit in [
		SuitBreakTypes.Suit.SPADES,
		SuitBreakTypes.Suit.HEARTS,
		SuitBreakTypes.Suit.DIAMONDS,
		SuitBreakTypes.Suit.CLUBS,
	]:
		for rank in range(SuitBreakTypes.Rank.TWO, SuitBreakTypes.Rank.ACE + 1):
			cards.append(Card.new(suit, rank as SuitBreakTypes.Rank))
	return cards


static func shuffle(cards: Array[Card], rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: Card = cards[i]
		cards[i] = cards[j]
		cards[j] = tmp
