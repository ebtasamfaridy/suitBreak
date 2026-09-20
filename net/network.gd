class_name SuitBreakNetwork
extends Node

## LAN host/join, same pattern as LanBattle (tic-tac-toe): ENet on PORT plus UDP discovery.
## Autoloaded as /root/Network. Use SuitBreakNetwork.I from other scripts.

static var I: SuitBreakNetwork

const PORT: int = 7010
const DISCOVERY_PORT: int = 7011
const DISCOVERY_MAGIC: String = "SUITBREAK_V1"
const DISCOVERY_INTERVAL: float = 1.0
const MAX_PLAYERS: int = 4

signal connection_succeeded
signal connection_failed
signal server_disconnected
signal player_connected(id: int)
signal player_disconnected(id: int)
signal host_discovered(ip: String)
signal match_started
signal lobby_updated

var roster: Array = []
var expected_players: int = 2
var local_name: String = "Player"
var peer_names: Dictionary = {}

var _advertise_peer: PacketPeerUDP = null
var _discovery_peer: PacketPeerUDP = null
var _advertising: bool = false
var _discovering: bool = false
var _broadcast_accum: float = 0.0


func _enter_tree() -> void:
	I = self


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game(max_players: int = MAX_PLAYERS, player_name: String = "Host") -> Error:
	expected_players = clampi(max_players, 2, MAX_PLAYERS)
	local_name = _clean_name(player_name, "Host")
	peer_names.clear()
	peer_names[1] = local_name
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(PORT, expected_players - 1)
	if err != OK:
		push_error("SuitBreakNetwork.host_game failed on port %d (err=%d)" % [PORT, err])
		return err
	multiplayer.multiplayer_peer = peer
	rebuild_host_roster()
	return OK


func join_game(ip: String, player_name: String = "Player") -> Error:
	local_name = _clean_name(player_name, "Player")
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, PORT)
	if err != OK:
		push_error("SuitBreakNetwork.join_game to %s:%d failed (err=%d)" % [ip, PORT, err])
		return err
	multiplayer.multiplayer_peer = peer
	return OK


func close_connection() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	roster.clear()
	peer_names.clear()
	stop_advertising_host()
	stop_discovery()


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func has_session() -> bool:
	return multiplayer.multiplayer_peer != null


func connected_count() -> int:
	if not has_session():
		return 0
	if is_host():
		rebuild_host_roster()
		return roster.size()
	return roster.size() if roster.size() > 0 else 1


func ready_to_start() -> bool:
	return is_host() and connected_count() >= 2


func start_advertising_host() -> void:
	if _advertising:
		return
	_advertise_peer = PacketPeerUDP.new()
	_advertise_peer.set_broadcast_enabled(true)
	_broadcast_accum = DISCOVERY_INTERVAL
	_advertising = true


func stop_advertising_host() -> void:
	if not _advertising:
		return
	_advertising = false
	if _advertise_peer != null:
		_advertise_peer.close()
		_advertise_peer = null


func start_discovery() -> void:
	if _discovering:
		return
	_discovery_peer = PacketPeerUDP.new()
	var err := _discovery_peer.bind(DISCOVERY_PORT)
	if err != OK:
		push_error("SuitBreakNetwork.start_discovery bind %d failed (err=%d)" % [DISCOVERY_PORT, err])
		_discovery_peer = null
		return
	_discovering = true


func stop_discovery() -> void:
	if not _discovering:
		return
	_discovering = false
	if _discovery_peer != null:
		_discovery_peer.close()
		_discovery_peer = null


func _process(delta: float) -> void:
	if _advertising and _advertise_peer != null:
		_broadcast_accum += delta
		if _broadcast_accum >= DISCOVERY_INTERVAL:
			_broadcast_accum = 0.0
			_send_broadcasts()
	if _discovering and _discovery_peer != null:
		while _discovery_peer.get_available_packet_count() > 0:
			var data := _discovery_peer.get_packet()
			var msg := data.get_string_from_utf8()
			if msg != DISCOVERY_MAGIC:
				continue
			var ip := _discovery_peer.get_packet_ip()
			if ip in IP.get_local_addresses():
				continue
			host_discovered.emit(ip)


func _send_broadcasts() -> void:
	if _advertise_peer == null:
		return
	var data := DISCOVERY_MAGIC.to_utf8_buffer()
	_advertise_peer.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	_advertise_peer.put_packet(data)
	for subnet_addr in _subnet_broadcast_addresses():
		_advertise_peer.set_dest_address(subnet_addr, DISCOVERY_PORT)
		_advertise_peer.put_packet(data)


func _subnet_broadcast_addresses() -> Array:
	var result: Array = []
	for addr in IP.get_local_addresses():
		if ":" in addr:
			continue
		if addr.begins_with("127."):
			continue
		var parts := addr.split(".")
		if parts.size() != 4:
			continue
		result.append("%s.%s.%s.255" % [parts[0], parts[1], parts[2]])
	return result


func rebuild_host_roster() -> void:
	var ids: Array[int] = [1]
	if multiplayer.multiplayer_peer != null:
		for peer_id in multiplayer.get_peers():
			var pid := int(peer_id)
			if not ids.has(pid):
				ids.append(pid)
	for key in peer_names.keys():
		var pid := int(key)
		if pid != 1 and not ids.has(pid):
			ids.append(pid)
	ids.sort()
	roster.clear()
	var seat := 1
	for pid in ids:
		var fallback := local_name if pid == 1 else "Player %d" % (seat)
		var pname := str(peer_names.get(pid, fallback))
		roster.append({"peer_id": pid, "name": pname})
		seat += 1


func announce_local_name() -> void:
	if not has_session():
		return
	if is_host():
		peer_names[1] = local_name
		rebuild_host_roster()
		_broadcast_lobby()
		return
	rpc_id(1, "register_player_name", local_name)


@rpc("any_peer", "reliable")
func register_player_name(player_name: String) -> void:
	if not is_host():
		return
	var sender := multiplayer.get_remote_sender_id()
	if sender == 0:
		return
	peer_names[sender] = _clean_name(player_name, "Player")
	rebuild_host_roster()
	_broadcast_lobby()
	player_connected.emit(sender)


func _broadcast_lobby() -> void:
	if not is_host():
		return
	rpc("_rpc_lobby_state", roster, expected_players)
	lobby_updated.emit()


@rpc("authority", "call_local", "reliable")
func _rpc_lobby_state(p_roster: Array, p_expected: int) -> void:
	roster = p_roster
	expected_players = p_expected
	lobby_updated.emit()


func _clean_name(player_name: String, fallback: String) -> String:
	var cleaned := player_name.strip_edges()
	if cleaned == "":
		return fallback
	return cleaned.substr(0, 16)


func start_match() -> void:
	if not is_host():
		return
	rebuild_host_roster()
	if roster.size() < 2:
		return
	stop_advertising_host()
	rpc("_rpc_begin_match", roster, expected_players)


@rpc("authority", "call_local", "reliable")
func _rpc_begin_match(p_roster: Array, p_expected: int) -> void:
	roster = p_roster
	expected_players = p_expected
	MatchSettings.networked = true
	MatchSettings.player_count = p_expected
	match_started.emit()
	get_tree().call_deferred("change_scene_to_file", "res://scenes/table/table.tscn")


func _on_peer_connected(id: int) -> void:
	if multiplayer.is_server():
		if not peer_names.has(id):
			peer_names[id] = "Player"
		rebuild_host_roster()
		_broadcast_lobby()
		player_connected.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if multiplayer.is_server():
		peer_names.erase(id)
		rebuild_host_roster()
		_broadcast_lobby()
		player_disconnected.emit(id)


func _on_connected_to_server() -> void:
	if not is_host():
		call_deferred("announce_local_name")
	connection_succeeded.emit()


func _on_connection_failed() -> void:
	close_connection()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	close_connection()
	server_disconnected.emit()
