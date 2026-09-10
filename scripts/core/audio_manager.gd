extends Node
## 音频管理骨架（技术方案 2.1）：混音 Bus、BGM 切换、音效池。
## P0 无音频资产：接口先行，播放为安全空操作；资产到位后 register_sfx 即接入。

const SFX_POOL_SIZE := 8

var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_library: Dictionary = {}

func _ready() -> void:
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "Master"
		add_child(player)
		_sfx_players.append(player)

## 注册音效流，例如 register_sfx(&"hit_light", preload("res://assets/audio/hit_light.wav"))
func register_sfx(sfx_id: StringName, stream: AudioStream) -> void:
	_sfx_library[sfx_id] = stream

func play_sfx(sfx_id: StringName, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not _sfx_library.has(sfx_id):
		return
	for player in _sfx_players:
		if not player.playing:
			player.stream = _sfx_library[sfx_id]
			player.volume_db = volume_db
			player.pitch_scale = pitch_scale
			player.play()
			return

func play_bgm(_track_id: StringName) -> void:
	pass # P4 打磨期接入
