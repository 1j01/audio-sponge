
fs = require "fs"
fsu = require "fsu"
glob = require "glob"
{AudioContext} = require "web-audio-api"
# Meyda = require "meyda"


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
	constructor: (@path)->
		stats = fs.statSync(@path)
		file_size_in_bytes = stats.size
		length = floorToMultiple(Math.random() * file_size_in_bytes, 2)
		length = Math.min(length, 1024 * 24)
		start = floorToMultiple(Math.random() * (file_size_in_bytes - length), 2)
		end = start + Math.max(0, length - 1)
		
		# @headerStream = fs.createReadStream(file, {start: 0, end: 16*2048})
		# @readStream = fs.createReadStream(file, {start, end})
		
		# @readStream = fs.createReadStream(file)
		
		@buffer = fs.readFileSync(@path)
	
	toString: -> "file:#{@path}"
	
	prepareAudioBuffer: (context, callback)->
		# this works more or less
		context.decodeAudioData @buffer,
			(audioBuffer)->
				callback(null, audioBuffer)
			(err)->
				callback err
		
		# as does this
		# streamToBufferArray @readStream, (err, buffers)=>
		# 	return callback err if err
		# 	buffer = Buffer.concat(buffers)
		# 	context.decodeAudioData buffer,
		# 		(audioBuffer)->
		# 			callback(null, audioBuffer)
		# 		(err)->
		# 			callback err
		
		# either way it can definitely still run into some errors
		# like Error: the 2 AudioBuffers don't have the same sampleRate
		
		# this doesn't really work, though:
		# streamToBufferArray @headerStream, (err, buffers)=>
		# 	return callback err if err
		# 	streamToBufferArray @readStream, (err, more_buffers)=>
		# 		return callback err if err
		# 		console.log buffers.concat(more_buffers)
		# 		buffer = Buffer.concat(buffers.concat(more_buffers))
		# 		context.decodeAudioData buffer,
		# 			(audioBuffer)->
		# 				callback(null, audioBuffer)
		# 			(err)->
		# 				callback err
	
	# findBeats: ->
	# 	rms = Meyda.extract "rms", @buffer
	# 	console.log rms


module.exports =
class Sponge
	constructor: ->
		@sources = []
	
	soak: (audio_glob, callback)->
		glob audio_glob, (err, files)=>
			console.log "glob", audio_glob
			return callback err if err
			console.log "files:", files
			for file_path in files
				@sources.push(new Source(file_path))
			console.log "soaked up #{@sources.length} sources"
			callback null
	
	squeeze: (output_file)->
		
		context = new AudioContext
		console.log "created AudioContext"
		
		channels = context.format.numberOfChannels
		{sampleRate} = context
		
		last_context_time = context.currentTime
		last_time = Date.now() / 1000
		
		using_sources = (source for source, i in shuffleArray(@sources) when i < 30)
		console.log "preparing sources:"
		for source, i in using_sources
			do (source, i)=>
				source.prepareAudioBuffer context, (err, audioBuffer)->
					return console.error err if err
					return console.error "audioBuffer is #{audioBuffer}" unless audioBuffer
					if audioBuffer.sampleRate isnt context.sampleRate
						return console.log "audioBuffer.sampleRate (#{audioBuffer.sampleRate}) doesn't match context.sampleRate (#{context.sampleRate}); preemptively rejecting #{source}"
					# source.findBeats()
					buffer_source = context.createBufferSource()
					buffer_source.buffer = audioBuffer
					buffer_source.connect(context.destination)
					start_time = i * 1.5
					buffer_source.onended = =>
						console.log "source ##{i} ended: #{source}"
						delta_context_time = context.currentTime - last_context_time
						delta_time = Date.now() / 1000 - last_time
						# console.log "delta context time: #{elapsed_context_time.toFixed(2)}s, delta time: #{elapsed_time.toFixed(2)}"
						# console.log "playing at #{(delta_context_time/delta_time*100).toFixed(2)}% speed"
						last_context_time = context.currentTime
						last_time = Date.now() / 1000
					buffer_source.start(start_time)
					console.log "  #{source}"
					# setTimeout =>
					# 	console.log "theoretical start time for source ##{i}: #{source}"
					# , start_time * 1000
		
		console.log "start!"
		# context.outStream
		context

