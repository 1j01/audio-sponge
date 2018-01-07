
fs = require "fs"
async = require "async"
glob = require "glob"
{StreamAudioContext, AudioBuffer} = require "web-audio-engine"
# Meyda = require "meyda"
Rhythm = require "./Rhythm"
sliceAudioBuffer = require "./slice-audiobuffer.js"

# process.on "unhandledRejection", (reason, p)->
# 	console.error("Unhandled Rejection:", p)

shuffleArray = (array)->
	for i in [array.length-1..0]
		j = Math.floor(Math.random() * (i + 1))
		[array[i], array[j]] = [array[j], array[i]]
	array

# floorToMultiple = (x, n)-> Math.floor(x / n) * n

###
streamToBufferArray = (stream, callback)->
	buffers = []
	stream.on "data", (buffer)->
		buffers.push(buffer)
	stream.on "end", ->
		# buffer = Buffer.concat(buffers)
		callback(null, buffers)
	stream.on "error", callback
###

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
	
	# TODO: get sounds from online
	soak: (audio_glob, callback)->
		glob audio_glob, (err, files)=>
			console.log "glob", audio_glob
			return callback err if err
			console.log "files:", files
			for file_path in files #shuffleArray(files).slice(0, 20)
				@sources.push(new Source(file_path))
			console.log "soaked up #{@sources.length} sources"
			if @sources.length > 0
				callback null
			else
				callback new Error("no audio files were added as sources")
	
	squeeze: (callback)->
		
		context = new StreamAudioContext()
		console.log "created StreamAudioContext"
		
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
	
	# FIXME: horrible lag that manifests as long pauses in the stream
	# TODO: phase in and out sources
	# TODO: effects

	schedule_sounds: (using_sources, context)->
		audio_start_time = context.currentTime
		async.map using_sources,
			(source, callback)=>
				{audioBuffer} = source
				duration = Math.random() / 2 + 0.1
				duration = Math.min(duration, audioBuffer.duration)
				start = Math.random() * (audioBuffer.duration - duration)
				end = start + Math.max(0, duration - 0.01)
				new_audio_buffer = sliceAudioBuffer audioBuffer, start, end, context
				callback(null, new_audio_buffer)
			(err, beat_audio_buffers)=>
				bpm = 128 / 4
				bps = bpm / 60
				add_beat = (beat_type_index, start_time)=>
					beat_audio_buffer = beat_audio_buffers[beat_type_index]
					if not beat_audio_buffer
						console.error "Not enough sources, or beat types rather! Wanted: beat type #{beat_type_index} out of #{beat_audio_buffers.length}"
						return
					buffer_source = context.createBufferSource()
					buffer_source.buffer = beat_audio_buffer
					buffer_source.connect(context.destination)
					buffer_source.start(start_time)
					# buffer_source.stop(start_time + 0.05)

					oscillator = context.createOscillator()
					# oscillator.type = 
					# console.log beat_type_index
					oscillator.frequency.value = 440 * Math.pow(2, beat_type_index/12) #Math.random() * 440 + 100
					oscillator.detune.value = Math.random() * 10
					oscillator.connect(context.destination)
					oscillator.start(start_time)
					oscillator.stop(start_time + 0.05)
				
				for super_duper_measure_i in [0...4]
					rhythm = new Rhythm
					console.log rhythm.toString()
					beats = rhythm.getBeats()
					# console.log beats
					for super_measure_i in [0...4]
						shuffleArray(beat_audio_buffers)
						for beat in beats
							# add_beat(beat.type, (beat.time + (super_measure_i + super_duper_measure_i * 4) * 4) / bps)
							start_time = audio_start_time + (beat.time + super_measure_i + super_duper_measure_i * 4) / bps
							add_beat(beat.type, start_time)
				
				scheduled_length = 4 * 4 / bps
				the_before_fore_time = context.currentTime
				# TODO: better scheduling
				setTimeout(=>
					# the_after_wafter_mathter_matter_latter = context.currentTime
					diff = context.currentTime - the_before_fore_time
					console.log "setTimeout, wanted: #{scheduled_length}, actual: #{diff}"
					@schedule_sounds using_sources, context
				, scheduled_length * 1000)
		
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

