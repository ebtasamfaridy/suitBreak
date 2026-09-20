class_name SuitBreakTypes
extends Object

## Shared enums for SuitBreak. Rule behavior lives in the game engine later.

enum Suit {
	SPADES,
	HEARTS,
	DIAMONDS,
	CLUBS,
}

## Rank order from lowest to highest: 2 … A (see docs/game_rules.md).
enum Rank {
	TWO = 2,
	THREE = 3,
	FOUR = 4,
	FIVE = 5,
	SIX = 6,
	SEVEN = 7,
	EIGHT = 8,
	NINE = 9,
	TEN = 10,
	JACK = 11,
	QUEEN = 12,
	KING = 13,
	ACE = 14,
}

enum PlayerStatus {
	ACTIVE,
	FINISHED,
	LOSER,
}

enum GamePhase {
	IDLE,
	DEALING,
	IN_ROUND,
	ROUND_RESOLVED,
	GAME_OVER,
}

enum RoundEndReason {
	NONE,
	SUIT_BREAK,
	ALL_FOLLOWED,
}
