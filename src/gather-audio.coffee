randomWords = require "random-words"
shuffle = require "./shuffle"
Source = require "./Source"

# ---------------------
# Setup audio providers
# ---------------------
get_env_var = require "./get-env-var"

net_enabled = false

OGA_enabled = true

soundcloud_client_id = get_env_var "SOUNDCLOUD_CLIENT_ID"
soundcloud_enabled = soundcloud_client_id?

FS_audio_glob = get_env_var "AUDIO_SOURCE_FILES_GLOB"
FS_enabled = FS_audio_glob?

if not net_enabled
	soundcloud_enabled = false
	OGA_enabled = false

if soundcloud_enabled
	soundcloud = require "./audio-providers/soundcloud"
	soundcloud.init(id: soundcloud_client_id)

if FS_enabled
	FS = require "./audio-providers/filesystem"

if OGA_enabled
	OGA = require "./audio-providers/opengameart"
# ---------------------

module.exports = (new_source_callback)->
	sources = []

	# TODO: abstract "OR"-searching by using "a OR b" for OGA but multiple searches for SC
	# so we can do searches for themes globally, and expose that to the user

	on_new_source = (stream_url, attribution)=>
		new_source_callback new Source stream_url, attribution

	if soundcloud_enabled
		query = randomWords(1).join(" ")
		# TODO: named arguments
		soundcloud.search query, on_new_source, ()=>
			console.log "[SC] Done collecting track metadata from search"

	if OGA_enabled
		query = randomWords(5).join(" OR ")
		# TODO: named arguments
		OGA.search query,
			(err, stream_url, attribution)=>
				return console.error "[OGA] Error fetching track metadata:", err if err
				on_new_source(stream_url, attribution)
			()=>
				console.log "[OGA] Done collecting track metadata from search"
	
	if FS_enabled
		# TODO: named arguments
		FS.glob FS_audio_glob,
			(err, stream_url, attribution)=>
				return console.error "[FS] Error fetching track metadata:", err if err
				on_new_source(stream_url, attribution)
			()=>
				console.log "[FS] Done collecting track metadata from files"
