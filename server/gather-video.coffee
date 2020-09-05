randomWords = require "random-words"
shuffle = require "./shuffle"
Source = require "./Source"

# ---------------------
# Setup providers
# ---------------------
get_env_var = require "./get-env-var"

net_enabled = true

youtube_api_key = get_env_var "YOUTUBE_API_KEY"
youtube_api_enabled = youtube_api_key?

FS_audio_glob = get_env_var "FILESYSTEM_GLOB"
FS_enabled = false #FS_audio_glob?

bing_enabled = true

if not net_enabled
	youtube_api_enabled = false
	bing_enabled = false

if youtube_api_enabled
	YT = require "./providers/youtube-search-api"
	YT.init(key: youtube_api_key)

if bing_enabled
	bing = require "./providers/bing"

if FS_enabled
	FS = require "./providers/filesystem"
# ---------------------

module.exports = (query, new_source_callback)->
	sources = []

	# TODO: abstract "OR"-searching by using "a OR b" for OGA but multiple searches for SC
	# so we can do searches for themes globally, and expose that to the user

	on_new_source = (file_path, attribution)=>
		new_source_callback new Source file_path, attribution

	if youtube_api_enabled
		# query = randomWords(1).join(" ")
		# TODO: named arguments
		YT.searchAndDownload query, on_new_source, ()=>
			console.log "[YT] Done"

	if bing_enabled
		# query = randomWords(1).join(" ")
		# TODO: named arguments
		bing.searchAndDownload query, on_new_source, ()=>
			console.log "[bing] Done"

	if FS_enabled
		# TODO: named arguments
		FS.glob FS_audio_glob,
			(err, file_path, attribution)=>
				return console.error "[FS] Error fetching track metadata:", err if err
				on_new_source(file_path, attribution)
			()=>
				console.log "[FS] Done"
