async = require "async"
glob = require "glob"
{StreamAudioContext, AudioBuffer} = require "web-audio-engine"
SC = require "node-soundcloud"
Rhythm = require "./Rhythm"
Source = require "./Source"

shuffleArray = (array) ->
    i = array.length
    while --i > 0
        j = ~~(Math.random() * (i + 1))
        temp = array[j]
        array[j] = array[i]
        array[i] = temp
    # Note: not returning an array because the fact that it modifies the array in-place
	# is not signalled by the function name
	# so it had better be signalled by the return value

module.exports =
class Sponge
	constructor: ->
		@sources = []
		@source_samples = []
	
	start: (callback)->
		
		@context = context = new StreamAudioContext()
		console.log "created StreamAudioContext"
		
		@gather_sources()
		# TODO: gather sources as a continuous process
		# either
			# after a while, pausing along with the stream like schedule_sounds
		# or
			# when run out / near running out

		@schedule_sounds context.currentTime

		callback(null, context)
	
	gather_sources: ->
		# TODO: search for random search terms
		# or at least use something more random
		# my feed is mostly Best Acquaintences...
		SC.get "/me/activities/tracks/affiliated", (err, data)=>
			return console.error err if err
			tracks = (item.origin for item in data.collection)
			tracks = tracks.filter((track)-> track.streamable)

			shuffleArray(tracks)
			async.eachLimit tracks, 2,
				(track, callback)=>
					metadata = {
						link: track.permalink_url
						name: track.title
						author: {
							name: track.user.username
							link: track.user.permalink_url
						}
						# soundcloud_data: track
					}
					@sources.push new Source track.stream_url, metadata, @context,
						(new_sample)=>
							@source_samples.push(new_sample)
						(err, source)=>
							return callback err if err
							console.log "  done with #{source}"
							console.log "    currently #{@source_samples.length} samples"
							setTimeout =>
								callback null
							, 500 # does this actually help?
				(err)=>
					console.log "done with all sources"

			console.log "soaking up sample slices from #{@sources.length} sources..."

		# TODO: DRY and reenable FS support
		# maybe read metadata from files
		# audio_glob = process.env.AUDIO_SOURCE_FILES_GLOB
		
		# console.log "AUDIO_SOURCE_FILES_GLOB", audio_glob
		# if audio_glob?
		# 	glob audio_glob, (err, files)=>
		# 		return console.error err if err
		# 		shuffleArray(files)
		# 		console.log "files:", files
		# 		async.eachLimit files, 1,
		# 			(file_path, callback)=>
		# 				@sources.push new Source file_path, @context,
		# 					(new_sample)=>
		# 						@source_samples.push(new_sample)
		# 					(err, source)=>
		# 						return callback err if err
		# 						console.log "  done with #{source}"
		# 						console.log "    currently #{@source_samples.length} samples"
		# 						setTimeout =>
		# 							callback null
		# 						, 500 # does this actually help?
		# 			(err)=>
		# 				console.log "done with all sources"

		# 		console.log "soaking up sample slices from #{@sources.length} sources..."

	schedule_sounds: (schedule_start_time)->
		{context} = @
		console.log "schedule sounds for context time #{schedule_start_time}"
		console.log "#{@source_samples.length} samples to work with >:)"
		beat_audio_buffers = @source_samples

		bpm = 128 / 4
		bps = bpm / 60
		add_beat = (beat_type_index, start_time)=>
			beat_audio_buffer = beat_audio_buffers[beat_type_index]
			if not beat_audio_buffer
				console.error "not enough beat types yet, using an oscillator; wanted: beat type #{beat_type_index} out of #{beat_audio_buffers.length}"
				
				# use an oscillator as a placeholder for sampled beats

				gain = context.createGain()
				gain.gain.value = 0.3
				gain.connect(context.destination)

				oscillator = context.createOscillator()
				oscillator.frequency.value = 440 * Math.pow(2, beat_type_index/12)
				oscillator.detune.value = Math.random() * 10
				oscillator.connect(gain)
				oscillator.start(start_time)
				# oscillator.stop(start_time + 0.1)
				oscillator.stop(start_time + 0.005)
			else
				# TODO: envelopes
				buffer_source = context.createBufferSource()
				buffer_source.buffer = beat_audio_buffer
				buffer_source.connect(context.destination)
				buffer_source.start(start_time)
				# buffer_source.stop(start_time + 0.05)

		# TODO: visualize the rhythm, possibly by sending it (in time) to the client
		# TODO: layers of sound (i.e. tracks), with potentially different or similar/related rhythms for melody and percussion
		# TODO: phase in and out layers and their sources
		# TODO: apply effects to tracks, especially reverb, but also random, crazy DSP

		# NOTE: super_duper_measure_i is obselete now that schedule_sounds recursively loops
		# and enabling it (i.e. with a 4 instead of a 1) just means it won't use any newly gathered beat samples
		# (at that point / until later) (unnecessarily)
		for super_duper_measure_i in [0...1]
			rhythm = new Rhythm
			console.log rhythm.toString()
			beats = rhythm.getBeats()
			for super_measure_i in [0...4]
				shuffleArray(beat_audio_buffers)
				for beat in beats
					start_time = schedule_start_time + (beat.time + super_measure_i + super_duper_measure_i * 4) / bps
					add_beat(beat.type, start_time)
		
		# TODO: make it so this doesn't need to be updated, i.e. by incrementing it in the loop above
		scheduled_length = 4 * 1 / bps

		# TODO: simplify the following to use a single setTimeout loop
		# maybe look at other peoples code for scheduling to see how to do it better
		# currently it does a kind of silly thing of waiting until the last second (or 0.2 seconds) to schedule
		the_before_fore_time = context.currentTime
		next_start_time = context.currentTime + scheduled_length
		scheduling_window = 0.2 # or scheduled_length / 2
		next_schedule_time_minimum = next_start_time - scheduling_window
		wait_before_trying_to_schedule_next = scheduled_length - scheduling_window
		
		setTimeout =>
			diff = context.currentTime - the_before_fore_time

			if diff >= scheduled_length
				console.warn "WARNING: after setTimeout, context time difference was #{diff}; should be less than #{scheduled_length}"
			# else
			# 	console.log "after setTimeout, context time difference of #{diff} (which should be less than #{scheduled_length})"
			do wait_until_near_schedule_time = =>
				if context.currentTime < next_schedule_time_minimum
					# console.log "waiting for context.currentTime (#{context.currentTime}) to continue to at least #{next_schedule_time_minimum}"
					setTimeout wait_until_near_schedule_time, 50
				else
					@schedule_sounds next_start_time
		, wait_before_trying_to_schedule_next * 1000
