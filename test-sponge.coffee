
Speaker = require "speaker"
Sponge = require "./Sponge"

sponge = new Sponge
# sponge.soak "#{process.env.USERPROFILE}/Google Drive/**/*.m4a", -> # doesn't seem to work
# sponge.soak "#{process.env.USERPROFILE}/Music/*.mp3", ->
# sponge.soak "#{process.env.USERPROFILE}/Music/*.ogg", ->
sponge.soak "#{process.env.USERPROFILE}/Music/**/*.wav", -> # many wav files
# sponge.soak "#{process.env.USERPROFILE}/Google Drive/**/*.wav", -> # many wav files, lots of game sound effects here
# sponge.soak "#{process.env.USERPROFILE}/Music/*.wav", -> # less wav files
# sponge.soak "#{process.env.USERPROFILE}/Music/audiocheck.*.wav", -> # very few wav files
# sponge.soak "#{process.env.USERPROFILE}/Google Drive/Sound/**/*.*", -> # all kinds of file types, "just whatever"
	# sponge.squeeze("output/output{-###}.pcm")
	context = sponge.squeeze()
	
	context.outStream = new Speaker
		channels: context.format.numberOfChannels
		bitDepth: context.format.bitDepth
		sampleRate: context.sampleRate
	console.log "created Speaker"
	
	# context.outStream = ws = fsu.createWriteStreamUnique(output_file)
	# ws = fsu.createWriteStreamUnique(output_file)
	# ws.on "open", ->
	# 	console.log ""
	# 	console.log "output to #{ws.path}"
	
