class_name SoundCatalog
extends RefCounted
## Shared native AudioStreams, with editable event metadata in one Resource catalog.

const LIBRARY := preload("res://resources/audio/sound_events.tres")

static func definitions() -> Dictionary:
	return LIBRARY.events

static func load_entry(definition: Dictionary) -> Dictionary:
	var entry := definition.duplicate(true)
	var streams: Array[AudioStream] = []
	for path: String in entry.get("files", []):
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			if stream != null:
				streams.append(stream)
		else:
			push_warning("SoundCatalog: missing audio file '%s'" % path)
	entry["streams"] = streams
	entry["stream"] = streams[0] if not streams.is_empty() else null
	return entry

static func loop_stream(stream: AudioStream) -> AudioStream:
	if stream == null:
		return null
	var result := stream.duplicate() as AudioStream
	if result is AudioStreamOggVorbis:
		result.loop = true
	elif result is AudioStreamWAV:
		result.loop_mode = AudioStreamWAV.LOOP_FORWARD
		result.loop_begin = 0
		result.loop_end = roundi(result.get_length() * result.mix_rate)
	return result
