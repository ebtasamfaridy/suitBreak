extends Node

## Plays looping BGM plus one-shot SFX. Music track changes with menu / lobby / table.

const MUSIC := {
	"menu": preload("res://audio/music/menu.wav"),
	"lobby": preload("res://audio/music/lobby.wav"),
	"game": preload("res://audio/music/game.wav"),
}

const SFX := {
	"click": preload("res://audio/sfx/ui_click.wav"),
	"host": preload("res://audio/sfx/host.wav"),
	"join": preload("res://audio/sfx/join.wav"),
	"play_card": preload("res://audio/sfx/play_card.wav"),
	"discard": preload("res://audio/sfx/discard.wav"),
	"win": preload("res://audio/sfx/win.wav"),
	"lose": preload("res://audio/sfx/lose.wav"),
	"illegal": preload("res://audio/sfx/illegal.wav"),
	"player_join": preload("res://audio/sfx/player_join.wav"),
	"start_match": preload("res://audio/sfx/start_match.wav"),
}

var _music: AudioStreamPlayer
var _sfx_a: AudioStreamPlayer
var _sfx_b: AudioStreamPlayer
var _use_b := false
var _track := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.volume_db = -10.0
	_music.finished.connect(_on_music_finished)
	add_child(_music)
	_sfx_a = AudioStreamPlayer.new()
	_sfx_a.volume_db = -6.0
	add_child(_sfx_a)
	_sfx_b = AudioStreamPlayer.new()
	_sfx_b.volume_db = -6.0
	add_child(_sfx_b)
	get_tree().node_added.connect(_on_node_added)
	play_music("menu")


func play_music(track: String) -> void:
	if not MUSIC.has(track):
		return
	if _track == track and _music.playing:
		return
	_track = track
	_music.stream = _looped_stream(MUSIC[track])
	_music.play()


func play_sfx(kind: String) -> void:
	if not SFX.has(kind):
		return
	var player := _sfx_b if _use_b else _sfx_a
	_use_b = not _use_b
	player.stream = SFX[kind]
	player.play()


func _looped_stream(stream: AudioStream) -> AudioStream:
	if stream is AudioStreamWAV:
		var wav := (stream as AudioStreamWAV).duplicate() as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		var channels := 2 if wav.stereo else 1
		var bytes_per_sample := 2
		match wav.format:
			AudioStreamWAV.FORMAT_8_BITS:
				bytes_per_sample = 1
			AudioStreamWAV.FORMAT_IMA_ADPCM, AudioStreamWAV.FORMAT_QOA:
				bytes_per_sample = 0
		if bytes_per_sample > 0 and not wav.data.is_empty():
			wav.loop_end = int(wav.data.size() / float(bytes_per_sample * channels))
		return wav
	return stream


func _on_music_finished() -> void:
	if _track == "" or _music.stream == null:
		return
	_music.play()


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		if not button.pressed.is_connected(_on_any_button):
			button.pressed.connect(_on_any_button)


func _on_any_button() -> void:
	play_sfx("click")
