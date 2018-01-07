async = require "async"
glob = require "glob"
{StreamAudioContext, AudioBuffer} = require "web-audio-engine"
Rhythm = require "./Rhythm"
Source = require "./Source"
sliceAudioBuffer = require "./slice-audiobuffer.js"

shuffleArray = (array)->
	for i in [array.length-1..0]
		j = Math.floor(Math.random() * (i + 1))
		[array[i], array[j]] = [array[j], array[i]]
	array

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

		# FIXME: blocking the web server while "preparing sources"
		# FIXME: out of memory error that wasn't a problem with web-audio-api
		# I'm avoiding it temporarily by globbing for audio files that are generally short
		# I'll probably fix/avoid it by making source stuff async

		# ==== JS stack trace =========================================
		#
		# Security context: 0000023CF4CCFB61 <JS Object>
		# 	1: IterableToArrayLike(aka IterableToArrayLike) [native typedarray.js:1804] [pc=0000039C9F2C61C2] (this=0000023CF4C04381 <undefined>,bw=000002C0D7506A41 <an Uint8Array with map 0000005450E06569>)
		# 	2: from [native typedarray.js:1822] [pc=0000039C9F2C5BD2] (this=0000023CF4CB91F1 <JS Function Uint8Array (SharedFunctionInfo 0000023CF4C69E91)>,aK=000002C0D7506A41 <an Uint8Array with map 000...
		# 
		# FATAL ERROR: CALL_AND_RETRY_LAST Allocation failed - JavaScript heap out of memory

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
				
				@schedule_sounds using_sources, context, context.currentTime
	
	schedule_sounds: (using_sources, context, schedule_start_time)->
		console.log "schedule sounds for context time #{schedule_start_time}"
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
					oscillator.frequency.value = 440 * Math.pow(2, beat_type_index/12)
					oscillator.detune.value = Math.random() * 10
					oscillator.connect(context.destination)
					oscillator.start(start_time)
					oscillator.stop(start_time + 0.05)
				
				# TODO: visualize the rhythm, possibly by sending it in time to the client
				# TODO: layers of sound, with potentially different or similar rhythms
				# phase in and out layers and their sources
				# TODO: apply effects to layers (layers = tracks)
				for super_duper_measure_i in [0...4]
					rhythm = new Rhythm
					console.log rhythm.toString()
					beats = rhythm.getBeats()
					for super_measure_i in [0...4]
						shuffleArray(beat_audio_buffers)
						for beat in beats
							start_time = schedule_start_time + (beat.time + super_measure_i + super_duper_measure_i * 4) / bps
							add_beat(beat.type, start_time)
				
				scheduled_length = 4 * 4 / bps
				the_before_fore_time = context.currentTime
				next_start_time = context.currentTime + scheduled_length
				scheduling_window = 0.2 # or scheduled_length / 2
				next_schedule_time_minimum = next_start_time - scheduling_window
				wait_before_trying_to_schedule_next = scheduled_length - scheduling_window
				
				setTimeout =>
					diff = context.currentTime - the_before_fore_time
					console.log "setTimeout, wanted: something less than #{scheduled_length}, got (context.currentTime difference): #{diff}"
					iid = setInterval =>
						if context.currentTime < next_schedule_time_minimum
							# console.log "waiting for context.currentTime (#{context.currentTime}) to continue to at least #{next_schedule_time_minimum}"
						else
							clearInterval iid
							@schedule_sounds using_sources, context, next_start_time
					, 50
				, wait_before_trying_to_schedule_next * 1000
