class_name GameState
extends RefCounted

var config: GameConfig
var players: Array[Player] = []
var active_players: Array[Player] = []
var discard_pile: Array[Card] = []
var table_cards: Array[Card] = []
var current_leader: Player
var current_player: Player
var game_phase: SuitBreakTypes.GamePhase = SuitBreakTypes.GamePhase.IDLE
var current_round: RoundState
var last_message: String = ""
## True until the opening A♠ has been played.
var opening_ace_pending: bool = false
