
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

class Source
	constructor: (file)->
		stats = fs.statSync(file)
		file_size_in_bytes = stats.size
		length = floorToMultiple(Math.random() * file_size_in_bytes, 2)
		length = Math.min(length, 1024 * 24)
		start = floorToMultiple(Math.random() * (file_size_in_bytes - length), 2)
		end = start + Math.max(0, length - 1)
		@readStream = fs.createReadStream(file, {start, end})
	
	prepareAudioBuffer: (context, callback)->
		sampleRate = context.sampleRate # TODO: use sampleRate from source somehow
		channels = 1 #context.format.numberOfChannels
		buffers = []
		@readStream.on "data", (buffer)->
			buffers.push(buffer)
		@readStream.on "end", ->
			buffer = Buffer.concat(buffers)
			
			frameCount = sampleRate * 2
			audioBuffer = context.createBuffer(2, frameCount, sampleRate)
			
			# console.log "frameCount", frameCount
			
			for channel in [0...channels]
				# console.log "fill channel #{channel}"
				# audioBuffer.copyToChannel(buffer, channel)
				nowBuffering = audioBuffer.getChannelData(channel)
				for i in [0..frameCount]
					nowBuffering[i] = buffer[i]
			
			callback(audioBuffer)
	

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
		
		for source, i in shuffleArray(@sources)
			do (source, i)=>
				source.prepareAudioBuffer context, (audioBuffer)->
					source = context.createBufferSource()
					source.buffer = audioBuffer
					source.connect(context.destination)
					# source.start(Math.random() + i * 2)
					source.start(i * 1.5)
		
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
# sponge.soak "#{process.env.USERPROFILE}/Music/audiocheck.*.wav", ->
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
