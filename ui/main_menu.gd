extends Control

const LOBBY_SCENE := "res://scenes/menus/lobby.tscn"
const JOIN_TIMEOUT_SECONDS := 6.0

@onready var _count_option: OptionButton = %PlayerCountOption
@onready var _name_input: LineEdit = %NameInput
@onready var _host_button: Button = %HostButton
@onready var _join_button: Button = %JoinButton
@onready var _bots_button: Button = %PlayBotsButton
@onready var _ip_input: LineEdit = %IpInput
@onready var _status_label: Label = %StatusLabel

var _join_attempt: int = 0
var _going_to_lobby: bool = false


func _ready() -> void:
	if SuitBreakNetwork.I == null:
		push_error("SuitBreakNetwork autoload missing")
		return
	_count_option.clear()
	_count_option.add_item("2 players", 2)
	_count_option.add_item("3 players", 3)
	_count_option.add_item("4 players", 4)
	var select := 0
	for i in _count_option.item_count:
		if _count_option.get_item_id(i) == MatchSettings.player_count:
			select = i
			break
	_count_option.select(select)
	if MatchSettings.display_name != "" and MatchSettings.display_name != "Player":
		_name_input.text = MatchSettings.display_name
	_host_button.pressed.connect(_on_host_pressed)
	_join_button.pressed.connect(_on_join_pressed)
	_bots_button.pressed.connect(_on_bots_pressed)
	SuitBreakNetwork.I.connection_succeeded.connect(_on_connection_succeeded)
	SuitBreakNetwork.I.connection_failed.connect(_on_connection_failed)
	SuitBreakNetwork.I.host_discovered.connect(_on_host_discovered)
	SuitBreakNetwork.I.close_connection()
	MatchSettings.networked = false
	var guess := _guess_host_ip()
	if guess != "":
		_ip_input.text = guess
	SuitBreakNetwork.I.start_discovery()
	_status_label.text = "Host a room on Wi‑Fi hotspot, or join the host phone."
	GameAudio.play_music("menu")


func _exit_tree() -> void:
	if SuitBreakNetwork.I.connection_succeeded.is_connected(_on_connection_succeeded):
		SuitBreakNetwork.I.connection_succeeded.disconnect(_on_connection_succeeded)
	if SuitBreakNetwork.I.connection_failed.is_connected(_on_connection_failed):
		SuitBreakNetwork.I.connection_failed.disconnect(_on_connection_failed)
	if SuitBreakNetwork.I.host_discovered.is_connected(_on_host_discovered):
		SuitBreakNetwork.I.host_discovered.disconnect(_on_host_discovered)
	SuitBreakNetwork.I.stop_discovery()


func _on_host_pressed() -> void:
	GameAudio.play_sfx("host")
	MatchSettings.player_count = _count_option.get_item_id(_count_option.selected)
	MatchSettings.display_name = _player_name()
	SuitBreakNetwork.I.stop_discovery()
	var err := SuitBreakNetwork.I.host_game(MatchSettings.player_count, MatchSettings.display_name)
	if err != OK:
		_status_label.text = "Could not host (error %d). Check Wi‑Fi / INTERNET permission." % err
		return
	SuitBreakNetwork.I.start_advertising_host()
	MatchSettings.networked = true
	_go_to_lobby()


func _on_join_pressed() -> void:
	GameAudio.play_sfx("join")
	var ip := _ip_input.text.strip_edges()
	if ip == "":
		ip = _guess_host_ip()
		if ip == "":
			ip = "127.0.0.1"
	SuitBreakNetwork.I.stop_discovery()
	MatchSettings.display_name = _player_name()
	var err := SuitBreakNetwork.I.join_game(ip, MatchSettings.display_name)
	if err != OK:
		_status_label.text = "Could not join (error %d). Check the host IP." % err
		SuitBreakNetwork.I.start_discovery()
		return
	_status_label.text = "Connecting to %s..." % ip
	_set_busy(true)
	_join_attempt += 1
	var attempt := _join_attempt
	get_tree().create_timer(JOIN_TIMEOUT_SECONDS).timeout.connect(_on_join_timeout.bind(attempt, ip))


func _on_join_timeout(attempt: int, ip: String) -> void:
	if attempt != _join_attempt or _going_to_lobby:
		return
	if multiplayer.multiplayer_peer == null:
		return
	SuitBreakNetwork.I.close_connection()
	_status_label.text = "No reply from %s. Use the IP shown on the host phone." % ip
	_set_busy(false)
	SuitBreakNetwork.I.start_discovery()


func _on_connection_succeeded() -> void:
	_join_attempt += 1
	_set_busy(false)
	MatchSettings.networked = true
	_go_to_lobby()


func _on_connection_failed() -> void:
	_join_attempt += 1
	_status_label.text = "Connection failed. Check Wi‑Fi and the host IP."
	_set_busy(false)
	SuitBreakNetwork.I.start_discovery()


func _on_host_discovered(ip: String) -> void:
	if _ip_input.has_focus():
		return
	if _ip_input.text == ip:
		return
	_ip_input.text = ip
	if not _going_to_lobby:
		_status_label.text = "Found host at %s. Tap Join Room." % ip


func _on_bots_pressed() -> void:
	GameAudio.play_sfx("start_match")
	MatchSettings.player_count = _count_option.get_item_id(_count_option.selected)
	MatchSettings.display_name = _player_name()
	MatchSettings.networked = false
	SuitBreakNetwork.I.close_connection()
	get_tree().change_scene_to_file("res://scenes/table/table.tscn")


func _go_to_lobby() -> void:
	if _going_to_lobby:
		return
	_going_to_lobby = true
	get_tree().call_deferred("change_scene_to_file", LOBBY_SCENE)


func _set_busy(busy: bool) -> void:
	_host_button.disabled = busy
	_join_button.disabled = busy
	_bots_button.disabled = busy
	_ip_input.editable = not busy
	_name_input.editable = not busy
	_count_option.disabled = busy


func _player_name() -> String:
	var n := _name_input.text.strip_edges()
	if n == "":
		return "Player"
	return n.substr(0, 16)


func _guess_host_ip() -> String:
	var our_ip := _get_local_ip()
	if our_ip == "":
		return ""
	var parts := our_ip.split(".")
	if parts.size() != 4:
		return ""
	if parts[3] == "1":
		return "127.0.0.1"
	return "%s.%s.%s.1" % [parts[0], parts[1], parts[2]]


func _get_local_ip() -> String:
	var fallback := ""
	for addr in IP.get_local_addresses():
		if ":" in addr or addr.begins_with("127."):
			continue
		if addr.begins_with("192.168.") or addr.begins_with("10."):
			return addr
		if addr.begins_with("172."):
			var parts := addr.split(".")
			if parts.size() >= 2:
				var second := int(parts[1])
				if second >= 16 and second <= 31:
					return addr
		if fallback == "":
			fallback = addr
	return fallback
