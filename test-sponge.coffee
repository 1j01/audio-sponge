
# fsu = require "fsu"
Speaker = require "speaker"
Sponge = require "./Sponge"

sponge = new Sponge
sponge.soak process.env.AUDIO_GLOB, ->
	context = sponge.squeeze()
	
	context.outStream = new Speaker
		channels: context.format.numberOfChannels
		bitDepth: context.format.bitDepth
		sampleRate: context.sampleRate
	console.log "created Speaker"
	
	# context.outStream = ws = fsu.createWriteStreamUnique(output_file)
	# ws = fsu.createWriteStreamUnique(output_file)
	# ws.on "open", ->
	# 	console.log "writing to #{ws.path}"
	
