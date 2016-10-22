
fs = require "fs"
fsu = require "fsu"
glob = require "glob"
Speaker = require "speaker"
{AudioContext} = require "web-audio-api"

shuffleArray = (array)->
	for i in [array.length-1..0]
		j = Math.floor(Math.random() * (i + 1))
		[array[i], array[j]] = [array[j], array[i]]
	array

floorToMultiple = (x, n)-> Math.floor(x / n) * n

streamToBufferArray = (stream, callback)->
	buffers = []
	stream.on "data", (buffer)->
		buffers.push(buffer)
	stream.on "end", ->
		buffer = Buffer.concat(buffers)
		callback(null, buffers)
	stream.on "error", callback

class Source
	constructor: (file)->
		stats = fs.statSync(file)
		file_size_in_bytes = stats.size
		length = floorToMultiple(Math.random() * file_size_in_bytes, 2)
		length = Math.min(length, 1024 * 24)
		start = floorToMultiple(Math.random() * (file_size_in_bytes - length), 2)
		end = start + Math.max(0, length - 1)
		
		# @headerStream = fs.createReadStream(file, {start: 0, end: 1024})
		# @readStream = fs.createReadStream(file, {start, end})
		
		# @headerStream = fs.createReadStream(file, {start: 0, end: 0})
		# @readStream = fs.createReadStream(file)
		
		@readStream = fs.createReadStream(file)
		
		# @buffer = fs.readFileSync(file)
	
	prepareAudioBuffer: (context, callback)->
		# this works more or less
		# context.decodeAudioData @buffer,
		# 	(audioBuffer)->
		# 		callback(null, audioBuffer)
		# 	(err)->
		# 		callback err
		
		# as does this
		streamToBufferArray @readStream, (err, buffers)=>
			return callback err if err
			buffer = Buffer.concat(buffers)
			context.decodeAudioData buffer,
				(audioBuffer)->
					callback(null, audioBuffer)
				(err)->
					callback err
		
		# it can definitely still run into some errors
		# like Error: the 2 AudioBuffers don't have the same sampleRate
		
		# this doesn't work, though:
		# streamToBufferArray @headerStream, (err, buffers)=>
		# 	return callback err if err
		# 	streamToBufferArray @readStream, (err, more_buffers)=>
		# 		return callback err if err
		# 		console.log buffers.concat(more_buffers)
		# 		buffer = Buffer.concat(buffers.concat(more_buffers))


class Sponge
	constructor: ->
		@sources = [] # array of readable streams
	
	soak: (audio_glob, callback)->
		glob audio_glob, (err, files)=>
			console.log audio_glob
			return callback err if err
			console.log files
			for file in files
				@sources.push(new Source(file))
			console.log "soaked up #{@sources.length} sources"
			callback null
	
	squeeze: (output_file)->
		
		context = new AudioContext
		console.log "created AudioContext"
		
		channels = context.format.numberOfChannels
		{sampleRate} = context
		
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
		
		for source, i in shuffleArray(@sources)
			do (source, i)=>
				source.prepareAudioBuffer context, (err, audioBuffer)->
					return console.error err if err
					return console.error "audioBuffer is #{audioBuffer}" unless audioBuffer
					source = context.createBufferSource()
					source.buffer = audioBuffer
					source.connect(context.destination)
					source.start(i * 1.5)
		
		console.log "start!"


sponge = new Sponge
# sponge.soak "#{process.env.USERPROFILE}/Google Drive/**/*.m4a", -> # doesn't work well
# sponge.soak "#{process.env.USERPROFILE}/Music/*.mp3", ->
# sponge.soak "#{process.env.USERPROFILE}/Music/*.ogg", ->
# sponge.soak "#{process.env.USERPROFILE}/Music/**/*.wav", -> # many wav files
# sponge.soak "#{process.env.USERPROFILE}/Google Drive/**/*.wav", ->
sponge.soak "#{process.env.USERPROFILE}/Music/*.wav", -> # less wav files
# sponge.soak "#{process.env.USERPROFILE}/Music/audiocheck.*.wav", -> # very few wav files
# sponge.soak "#{process.env.USERPROFILE}/Google Drive/Sound/**/*.*", -> # "whatever"
	# sponge.squeeze("output/output{-###}.waviness.waveform.wave.wav.raw.pcm")
	# sponge.squeeze("output/output.0x77{-###}.raw.shit.wav.exe.pcm")
	sponge.squeeze()

# require "./soundcloud"
