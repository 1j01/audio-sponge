fsu = require "fsu"
Sponge = require "./Sponge"

sponge = new Sponge
sponge.soak process.env.AUDIO_SOURCE_FILES_GLOB, (err)->
	return console.error err if err
	sponge.squeeze (err, context)->
		return console.error err if err
		
		output_file_path_pattern = "output/output{-###}.pcm"
		ws = fsu.createWriteStreamUnique(output_file_path_pattern)
		ws.on "open", ->
			console.log "Writing to #{ws.path}"
		context.pipe(ws)
		context.resume()
