extends RefCounted
class_name GameAudioService

## The game's voice: four loopable synthesized themes and a drawer of
## one-shot effects, all generated in-repo (no external assets). Scenes
## ask for a theme by key; the service keeps one music player per scene
## root and crossfades on change. SFX are fire-and-forget.

const MUSIC := {
	"town": "res://resources/audio/music_town.wav",
	"wilds": "res://resources/audio/music_wilds.wav",
	"hold": "res://resources/audio/music_hold.wav",
	"overworld": "res://resources/audio/music_overworld.wav"
}

const SFX := {
	"swing": "res://resources/audio/sfx_swing.wav",
	"hit": "res://resources/audio/sfx_hit.wav",
	"coin": "res://resources/audio/sfx_coin.wav",
	"eat": "res://resources/audio/sfx_eat.wav",
	"drink": "res://resources/audio/sfx_drink.wav",
	"bow": "res://resources/audio/sfx_bow.wav",
	"magic": "res://resources/audio/sfx_magic.wav",
	"raid_horn": "res://resources/audio/sfx_raid_horn.wav",
	"splash": "res://resources/audio/sfx_splash.wav",
	"till": "res://resources/audio/sfx_till.wav",
	"harvest": "res://resources/audio/sfx_harvest.wav",
	"mount": "res://resources/audio/sfx_mount.wav",
	"forge": "res://resources/audio/sfx_forge.wav",
	"enchant": "res://resources/audio/sfx_enchant.wav",
	"death": "res://resources/audio/sfx_death.wav",
	"step": "res://resources/audio/sfx_step_grass.wav"
}

const MUSIC_DB := -10.0
const SFX_DB := -6.0
const CROSSFADE_SECONDS := 1.6

static var _stream_cache: Dictionary = {}

static func _load_stream(path: String, looped: bool) -> AudioStream:
	var cache_key := "%s|%s" % [path, looped]
	if _stream_cache.has(cache_key):
		return _stream_cache[cache_key] as AudioStream
	if not ResourceLoader.exists(path):
		return null
	var stream := load(path) as AudioStream
	if stream is AudioStreamWAV and looped:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = wav.data.size() / 2
	_stream_cache[cache_key] = stream
	return stream

## Starts (or crossfades to) a looping theme on the scene root. Calling
## with the already-playing key is free.
static func play_music(scene_root: Node, music_key: String) -> void:
	var stream := _load_stream(String(MUSIC.get(music_key, "")), true)
	if stream == null:
		return
	var player := scene_root.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if player != null and String(player.get_meta("music_key", "")) == music_key:
		return
	if player != null:
		# Fade the old theme out and free it; the new one fades in beside it.
		player.name = "MusicPlayerFading"
		var fade_out := scene_root.create_tween()
		fade_out.tween_property(player, "volume_db", -40.0, CROSSFADE_SECONDS)
		fade_out.tween_callback(player.queue_free)
	var next_player := AudioStreamPlayer.new()
	next_player.name = "MusicPlayer"
	next_player.stream = stream
	next_player.volume_db = -40.0
	next_player.set_meta("music_key", music_key)
	scene_root.add_child(next_player)
	next_player.play()
	var fade_in := scene_root.create_tween()
	fade_in.tween_property(next_player, "volume_db", MUSIC_DB, CROSSFADE_SECONDS)

## One-shot effect; the player frees itself when done.
static func play_sfx(scene_root: Node, sfx_key: String) -> void:
	var stream := _load_stream(String(SFX.get(sfx_key, "")), false)
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = SFX_DB
	scene_root.add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
