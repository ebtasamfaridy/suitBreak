extends Control

@onready var _status_label: Label = %StatusLabel
@onready var _list_label: Label = %PlayerList
@onready var _start_button: Button = %StartButton
@onready var _leave_button: Button = %LeaveButton

var _last_roster := 0


func _ready() -> void:
	if SuitBreakNetwork.I == null:
		_status_label.text = "Network failed to load. Reload the project."
		return
	_start_button.pressed.connect(_on_start_pressed)
	_leave_button.pressed.connect(_on_leave_pressed)
	SuitBreakNetwork.I.player_connected.connect(_on_lobby_changed)
	SuitBreakNetwork.I.player_disconnected.connect(_on_lobby_changed)
	SuitBreakNetwork.I.lobby_updated.connect(_on_lobby_changed)
	SuitBreakNetwork.I.server_disconnected.connect(_on_host_lost)
	_start_button.visible = SuitBreakNetwork.I.is_host()
	if SuitBreakNetwork.I.is_host():
		SuitBreakNetwork.I.announce_local_name()
	_refresh()
	_last_roster = SuitBreakNetwork.I.roster.size()
	GameAudio.play_music("lobby")


func _exit_tree() -> void:
	if SuitBreakNetwork.I == null:
		return
	if SuitBreakNetwork.I.player_connected.is_connected(_on_lobby_changed):
		SuitBreakNetwork.I.player_connected.disconnect(_on_lobby_changed)
	if SuitBreakNetwork.I.player_disconnected.is_connected(_on_lobby_changed):
		SuitBreakNetwork.I.player_disconnected.disconnect(_on_lobby_changed)
	if SuitBreakNetwork.I.lobby_updated.is_connected(_on_lobby_changed):
		SuitBreakNetwork.I.lobby_updated.disconnect(_on_lobby_changed)
	if SuitBreakNetwork.I.server_disconnected.is_connected(_on_host_lost):
		SuitBreakNetwork.I.server_disconnected.disconnect(_on_host_lost)


func _on_lobby_changed(_id: int = 0) -> void:
	_refresh()
	var n := SuitBreakNetwork.I.roster.size() if SuitBreakNetwork.I else 0
	if n > _last_roster:
		GameAudio.play_sfx("player_join")
	_last_roster = n


func _refresh() -> void:
	if SuitBreakNetwork.I == null:
		return
	var n := SuitBreakNetwork.I.roster.size()
	if n == 0:
		n = SuitBreakNetwork.I.connected_count()
	var need := SuitBreakNetwork.I.expected_players
	if SuitBreakNetwork.I.is_host():
		var ip := _get_local_ip()
		_status_label.text = "Hosting at %s\n%d of %d in the room. Start when ready." % [
			ip if ip != "" else "(no LAN IP)", n, need
		]
		var can_start := n >= 2
		_start_button.disabled = not can_start
		_start_button.text = "Start Game" if can_start else "Waiting for another player..."
	else:
		_status_label.text = "Joined as %s.\nWaiting for the host to start..." % SuitBreakNetwork.I.local_name
	var lines: PackedStringArray = PackedStringArray()
	var my_id := multiplayer.get_unique_id() if SuitBreakNetwork.I.has_session() else 0
	if SuitBreakNetwork.I.roster.is_empty():
		lines.append("• %s (you)" % SuitBreakNetwork.I.local_name)
	else:
		for entry in SuitBreakNetwork.I.roster:
			var pname := str(entry.get("name", "Player"))
			if int(entry.get("peer_id", 0)) == my_id:
				pname += " (you)"
			lines.append("• " + pname)
	_list_label.text = "\n".join(lines)


func _on_start_pressed() -> void:
	_refresh()
	if SuitBreakNetwork.I.roster.size() < 2:
		_status_label.text = "Still waiting for another phone to join."
		return
	GameAudio.play_sfx("start_match")
	SuitBreakNetwork.I.start_match()


func _on_leave_pressed() -> void:
	SuitBreakNetwork.I.close_connection()
	MatchSettings.networked = false
	get_tree().change_scene_to_file("res://main.tscn")


func _on_host_lost() -> void:
	MatchSettings.networked = false
	get_tree().change_scene_to_file("res://main.tscn")


func _get_local_ip() -> String:
	for addr in IP.get_local_addresses():
		if ":" in addr or addr.begins_with("127."):
			continue
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
	return ""
