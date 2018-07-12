fsu = require "fsu"
Sponge = require "./Sponge"

sponge = new Sponge
sponge.start (err, context)->
	return console.error err if err
	
	output_file_path_pattern = "output/output{-###}.pcm"
	ws = fsu.createWriteStreamUnique(output_file_path_pattern)
	ws.on "open", ->
		console.log "Writing to #{ws.path}"
	context.pipe(ws)
	context.resume()
