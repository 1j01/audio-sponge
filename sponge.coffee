
fs = require "fs"
async = require "async"
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
				
				@schedule_sounds using_sources, context, (err)=>
					return console.error err if err
					console.log "the end? what? this is supposed to be an infinite audio stream!"
					console.log "alas, that feature isn't exactly implemented yet"

	schedule_sounds: (using_sources, context, callback)->
		async.eachOf using_sources,
			(source, i, callback)=>
				# source.findBeats()
				buffer_source = context.createBufferSource()
				buffer_source.buffer = source.audioBuffer
				buffer_source.connect(context.destination)
				start_time = i * 1.5
				buffer_source.onended = =>
					console.log "source ##{i} ended: #{source}"
					callback(null)
				buffer_source.start(start_time)
				# setTimeout =>
				# 	console.log "theoretical start time for source ##{i}: #{source}"
				# , start_time * 1000
			(err)->
				callback(err)

