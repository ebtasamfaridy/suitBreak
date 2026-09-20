class_name PlayOutcome
extends RefCounted

var ok: bool = false
var error: String = ""
var round_ended: bool = false
var game_over: bool = false


static func fail(message: String) -> PlayOutcome:
	var outcome := PlayOutcome.new()
	outcome.ok = false
	outcome.error = message
	return outcome


static func ok_play(p_round_ended: bool, p_game_over: bool) -> PlayOutcome:
	var outcome := PlayOutcome.new()
	outcome.ok = true
	outcome.round_ended = p_round_ended
	outcome.game_over = p_game_over
	return outcome
