path = require "path"
async = require "async"
glob = require "glob"
mm = require "music-metadata"
shuffle = require "../shuffle"

module.exports.glob = (audio_glob, track_callback, done_callback)->
	console.log "[FS] Globbing the filesystem for:", audio_glob
	glob audio_glob, (err, files)=>
		if err
			console.error "[FS] Error globbing the filesystem:", err if err
			done_callback()
			return
		# console.log "[FS] Files:", files
		console.log "[FS] Found #{files.length} files"
		async.eachLimit shuffle(files), 1,
			(file_path, callback)=>
				mm.parseFile file_path, {native: true}
				.then (metadata)=>
					return {
						link: "file:///" + file_path
						name: metadata.common.title
						author: {
							name: metadata.common.artist or metadata.common.artists.join(", ")
						}
					}
				.catch (err)=>
					console.error "[FS] [music-metadata] Error:", err
					return {
						link: "file:///" + file_path
						name: path.basename(file_path)
					}
				.then (attribution)=>
					# FIXME: callback within (implicitly) try-caught block (by `async`)
					track_callback(null, file_path, attribution)
					setTimeout =>
						callback null
					, 500 # TODO: does this actually help?
			(err)=>
				# FIXME: catches errors within track_callback
				console.error "[FS] Error:", err if err
				done_callback() # regardless of error
