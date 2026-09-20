class_name SimpleBot
extends Object

## Plays the lowest legal card. Fine for local testing until stronger AI exists.

static func choose(engine: GameEngine) -> Card:
	var options := engine.legal_cards(engine.state.current_player)
	options.sort_custom(func(a: Card, b: Card) -> bool:
		if a.rank == b.rank:
			return int(a.suit) < int(b.suit)
		return int(a.rank) < int(b.rank)
	)
	return options[0]
