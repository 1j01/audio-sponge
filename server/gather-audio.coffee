randomWords = require "random-words"
shuffle = require "./shuffle"
Source = require "./Source"

# ---------------------
# Setup providers
# ---------------------
get_env_var = require "./get-env-var"

net_enabled = true

youtube_api_id = get_env_var "YOUTUBE_API_KEY"
youtube_enabled = youtube_api_id?

FS_audio_glob = get_env_var "FILESYSTEM_GLOB"
FS_enabled = false #FS_audio_glob?

if not net_enabled
	youtube_enabled = false
	OGA_enabled = false

if youtube_enabled
	YT = require "./audio-providers/youtube"
	YT.init(id: youtube_api_id)

if FS_enabled
	FS = require "./audio-providers/filesystem"

if OGA_enabled
	OGA = require "./audio-providers/opengameart"
# ---------------------

module.exports = (query, new_source_callback)->
	sources = []

	# TODO: abstract "OR"-searching by using "a OR b" for OGA but multiple searches for SC
	# so we can do searches for themes globally, and expose that to the user

	on_new_source = (stream_url, attribution)=>
		new_source_callback new Source stream_url, attribution

	if youtube_enabled
		# query = randomWords(1).join(" ")
		# TODO: named arguments
		YT.search query, on_new_source, ()=>
			console.log "[YT] Done collecting track metadata from search"

	if FS_enabled
		# TODO: named arguments
		FS.glob FS_audio_glob,
			(err, stream_url, attribution)=>
				return console.error "[FS] Error fetching track metadata:", err if err
				on_new_source(stream_url, attribution)
			()=>
				console.log "[FS] Done collecting track metadata from files"
