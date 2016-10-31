
fs = require "fs"
async = require "async"
glob = require "glob"
{AudioContext, AudioBuffer} = require "web-audio-api"
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

sliceAudioBuffer = (audioBuffer, startOffset, endOffset, audioContext)->
		{numberOfChannels, duration, sampleRate, frameCount} = audioBuffer
		
		# newAudioBuffer = audioContext.createBuffer(numberOfChannels, endOffset - startOffset, sampleRate)
		# tempArray = new Float32Array(frameCount)
		# 
		# for channel in [0..numberOfChannels]
		# 	audioBuffer.copyFromChannel(tempArray, channel, startOffset)
		# 	newAudioBuffer.copyToChannel(tempArray, channel, 0)
		
		# newAudioBuffer.set(audioBuffer, startOffset)
		
		# newAudioBuffer
		
		array =
			for channel in [0...numberOfChannels]
				samples = audioBuffer.getChannelData(channel)
				samples.slice(startOffset * sampleRate, endOffset * sampleRate)
			
		AudioBuffer.fromArray(array, sampleRate)


class Source
	constructor: (@path)->
		# stats = fs.statSync(@path)
		# file_size_in_bytes = stats.size
		# length = floorToMultiple(Math.random() * file_size_in_bytes, 2)
		# length = Math.min(length, 1024 * 24)
		# start = floorToMultiple(Math.random() * (file_size_in_bytes - length), 2)
		# end = start + Math.max(0, length - 1)
		
		# @headerStream = fs.createReadStream(@path, {start: 0, end: 16*2048})
		# @readStream = fs.createReadStream(@path, {start, end})
		
		# @readStream = fs.createReadStream(@path)
		
		@buffer = fs.readFileSync(@path)
	
	toString: -> "file:#{@path}"
	
	prepareAudioBuffer: (context, callback)->
		# this works
		context.decodeAudioData @buffer,
			(@audioBuffer)=>
				callback(null)
			(err)=>
				callback(err)
		
		# as does this
		# streamToBufferArray @readStream, (err, buffers)=>
		# 	return callback err if err
		# 	buffer = Buffer.concat(buffers)
		# 	context.decodeAudioData buffer,
		# 		(@audioBuffer)=>
		# 			callback(null)
		# 		(err)=>
		# 			callback(err)
		
		# this doesn't really work, though:
		# streamToBufferArray @headerStream, (err, buffers)=>
		# 	return callback err if err
		# 	streamToBufferArray @readStream, (err, more_buffers)=>
		# 		return callback err if err
		# 		# console.log buffers.concat(more_buffers)
		# 		buffer = Buffer.concat(buffers.concat(more_buffers))
		# 		context.decodeAudioData buffer,
		# 			(@audioBuffer)=>
		# 				callback(null)
		# 			(err)=>
		# 				callback(err)
		# it'd need to align with the frame boundaries
		# offset by the header which may not always be a multiple of the frame size
		# I could get this information with node-wav,
		# but I don't really want to create a dependency on a specific file type
	
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
	
	squeeze: (callback)->
		
		context = new AudioContext
		console.log "created AudioContext"
		
		channels = context.format.numberOfChannels
		{sampleRate} = context
		
		some_sources = (source for source, i in shuffleArray(@sources) when i < 30)
		console.log "preparing sources:"
		async.filter some_sources,
			(source, callback)=>
				source.prepareAudioBuffer context, (err)->
					return callback err if err
					return callback new Error "source.audioBuffer is #{source.audioBuffer}" unless source.audioBuffer
					if source.audioBuffer.sampleRate isnt context.sampleRate
						console.log "source.audioBuffer.sampleRate (#{source.audioBuffer.sampleRate}) doesn't match context.sampleRate (#{context.sampleRate}); preemptively rejecting #{source}"
						callback(null, no)
					else
						console.log "  #{source}"
						callback(null, yes)
			(err, using_sources)=>
				return callback err if err
				
				callback(null, context)
				
				@schedule_sounds using_sources, context

	schedule_sounds: (using_sources, context)->
		async.map using_sources,
			(source, callback)=>
				{audioBuffer} = source
				# duration = floorToMultiple(Math.random() * audioBuffer.duration, 2)
				duration = Math.random() / 2 + 0.1
				duration = Math.min(duration, audioBuffer.duration)
				start = Math.random() * (audioBuffer.duration - duration)
				end = start + Math.max(0, duration - 0.01)
				newAudioBuffer = sliceAudioBuffer audioBuffer, start, end, context
				callback(null, newAudioBuffer)
			(err, beats)->
				rhythm = "a a a bca a a bca a a bca addddd"
				bpm = 128
				bps = 60 / bpm
				add_beat = (beat_type_index, t)->
					beat_audio_buffer = beats[beat_type_index]
					buffer_source = context.createBufferSource()
					buffer_source.buffer = beat_audio_buffer
					buffer_source.connect(context.destination)
					start_time = t * bps
					buffer_source.start(start_time)
				for super_measure_i in [0..4]
					shuffleArray(beats)
					for ch, beat_i in rhythm when ch isnt " "
						beat_type_index = parseInt(ch, 36) - 9
						add_beat(beat_type_index, (beat_i + super_measure_i * rhythm.length) / 2)
		
		# async.eachOf using_sources,
		# 	(source, i, callback)=>
		# 		# source.findBeats()
		# 		buffer_source = context.createBufferSource()
		# 		buffer_source.buffer = source.audioBuffer
		# 		buffer_source.connect(context.destination)
		# 		start_time = i * 1.5
		# 		buffer_source.onended = =>
		# 			console.log "source ##{i} ended: #{source}"
		# 			callback(null)
		# 		buffer_source.start(start_time)
		# 		# setTimeout =>
		# 		# 	console.log "theoretical start time for source ##{i}: #{source}"
		# 		# , start_time * 1000
		# 	(err)->
		# 		callback(err)

