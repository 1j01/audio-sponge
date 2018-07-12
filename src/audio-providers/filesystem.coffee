async = require "async"
glob = require "glob"

# TODO: DRY and reenable FS support
# maybe read metadata from files
# audio_glob = process.env.AUDIO_SOURCE_FILES_GLOB

# console.log "[FS] AUDIO_SOURCE_FILES_GLOB:", audio_glob
# if audio_glob?
# 	glob audio_glob, (err, files)=>
# 		return console.error "[FS] Error globbing filesystem:", err if err
# 		shuffleArray(files)
# 		console.log "[FS] Files:", files
# 		async.eachLimit files, 1,
# 			(file_path, callback)=>
# 				@sources.push new Source file_path, @context,
# 					(new_sample)=>
# 						@source_samples.push(new_sample)
# 					(err, source)=>
# 						return callback err if err
# 						console.log "[FS] Done with #{source}"
# 						setTimeout =>
# 							callback null
# 						, 500 # does this actually help?
# 			(err)=>
# 				console.log "[FS] Done with all sources"

# 		console.log "[FS] Soaking up sample slices from #{@sources.length} sources..."
