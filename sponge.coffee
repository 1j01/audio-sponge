
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

class Sponge
	constructor: ->
		@sources = [] # array of readable streams
	
	soak: (audio_glob, callback)->
		glob audio_glob, (err, files)=>
			console.log audio_glob
			return callback err if err
			console.log files
			for file in files
				stats = fs.statSync(file)
				file_size_in_bytes = stats.size
				# for [0..3]
				length = floorToMultiple(Math.random() * file_size_in_bytes, 2)
				length = Math.min(length, 1024 * 24)
				start = floorToMultiple(Math.random() * (file_size_in_bytes - length), 2)
				end = start + Math.max(0, length - 1)
				@sources.push(fs.createReadStream(file, {start, end}))
			
			callback null
	
	squeeze: (output_file)->
		# console.log ""
		# console.log "using some shit to create a masterpiece"
		# ws = fsu.createWriteStreamUnique(output_file)
		# for source in shuffleArray(@sources)
		# 	source.pipe(ws)
		# ws.on "open", ->
		# 	console.log ""
		# 	console.log "output to #{ws.path}"
		
		context = new AudioContext
		console.log "created AudioContext"
		
		channels = context.format.numberOfChannels
		{sampleRate} = context
		
		context.outStream = new Speaker
			channels: context.format.numberOfChannels
			bitDepth: context.format.bitDepth
			sampleRate: context.sampleRate
		console.log "created Speaker"
		
		# context.outStream = process.stdout
		
		# context.outStream = ws = fsu.createWriteStreamUnique(output_file)
		# ws = fsu.createWriteStreamUnique(output_file)
		# ws.on "open", ->
		# 	console.log ""
		# 	console.log "output to #{ws.path}"
		
		
		frameCount = sampleRate * 2
		myArrayBuffer = context.createBuffer(2, frameCount, sampleRate)
		
		console.log "frameCount", frameCount
		
		# Fill the buffer with white noise;
		# just random values between -1.0 and 1.0
		for channel in [0...channels]
			console.log "fill channel #{channel}"
			# This gives us the actual ArrayBuffer that contains the data
			nowBuffering = myArrayBuffer.getChannelData(channel)
			for i in [0..frameCount]
				# Math.random() is in [0; 1.0]
				# audio needs to be in [-1.0; 1.0]
				nowBuffering[i] = Math.random() * 2 - 1
		
		# Get an AudioBufferSourceNode.
		# This is the AudioNode to use when we want to play an AudioBuffer
		source = context.createBufferSource()
		# set the buffer in the AudioBufferSourceNode
		source.buffer = myArrayBuffer
		# connect the AudioBufferSourceNode to the
		# destination so we can hear the sound
		source.connect(context.destination)
		# start the source playing
		source.start(0)
		
		console.log "start!"


sponge = new Sponge
# sponge.soak("#{process.env.USERPROFILE}/Music/**/*.wav")
# sponge.soak "#{process.env.USERPROFILE}/Music/**/*.wav", ->
# sponge.soak "#{process.env.USERPROFILE}/Google Drive/**/*.m4a", -> # doesn't work well
# sponge.soak "#{process.env.USERPROFILE}/Google Drive/**/*.wav", ->
# sponge.soak "#{process.env.USERPROFILE}/Music/Audacity/**/*.au", ->
# sponge.soak "#{process.env.USERPROFILE}/Music/*.mp3", -> # mp3s don't work well, they're frequency encoded
# sponge.soak "#{process.env.USERPROFILE}/Music/*.mp3", ->
sponge.soak "#{process.env.USERPROFILE}/Music/**/*.wav", ->
# sponge.soak "#{process.env.USERPROFILE}/Google Drive/Sound/**/*.*", ->
	sponge.squeeze("output/output{-###}.waviness.waveform.wave.wav.raw.pcm")
	# sponge.squeeze("output/output.0x77{-###}.raw.shit.wav.exe.pcm")

# console.log "hey"
# audioConverter = require "audio-converter"
# console.log "um"
# audioConverter "#{process.env.USERPROFILE}/Google Drive/Sound/Piano Recordings", "temp",
# 	progressBar: yes
# .catch (err)->
# 	console.error err
# .then ->
# 	console.log "Converted!"
# 	sponge.soak "temp/*.mp3", ->
# 		sponge.squeeze()

# require "./soundcloud"
