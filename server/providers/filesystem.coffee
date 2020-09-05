path = require "path"
async = require "async"
glob = require "glob"
mm = require "music-metadata"
shuffle = require "../shuffle"

module.exports.glob = (glob_string, track_callback, done_callback)->
	console.log "[FS] Globbing the filesystem for:", glob_string
	glob glob_string, (err, files)=>
		if err
			console.error "[FS] Error globbing the filesystem:", err if err
			done_callback()
			return
		console.log "[FS] Found #{files.length} files:", files
		async.eachLimit shuffle(files), 1,
			(file_path, callback)=>
				# NOTE: MUST not call callback herein syncronously!
				# An error in the callback would be caught by `async` and lead to confusion.
				attribution = {
					link: "file:///" + file_path
					name: path.basename(file_path)
					provider: "filesystem"
				}
				mm.parseFile file_path, {native: true}
				.then (metadata)=>
					attribution.name = metadata.common.title ? attribution.name
					attribution.author = {
						name: metadata.common.artist or metadata.common.artists?.join(", ")
					}
				.catch track_callback
				.then =>
					track_callback(null, file_path, attribution)
					setTimeout =>
						callback null
					, 500 # TODO: does this actually help?
				# Promises swallow errors like a whale swallows copies of Moby Dick or some shit.
				.catch (error)=>
					# throw error # THIS WILL NOT WORK because errors are swallowed even in .catch blocks!
					# could use:
					#	console.error error
					#	process.exit(1)
					# but I think this is a bit better:
					process.nextTick =>
						throw error
					# allow for normal uncaught error handling, and graceful shutdown if there is any
			(err)=>
				console.error "[FS] Error:", err if err
				done_callback() # regardless of error
