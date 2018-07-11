async = require "async"
glob = require "glob"
{StreamAudioContext, AudioBuffer} = require "web-audio-engine"
SC = require "node-soundcloud"
get_env_var = require "./get-env-var" # TODO: remove me
soundcloud_enabled = (get_env_var "SOUNDCLOUD_CLIENT_ID")?
OGA = require "./opengameart"
OGA_enabled = true
shuffle = require "./shuffle"
Rhythm = require "./Rhythm"
Source = require "./Source"
Chorus = require "../lib/chorus"
randomWords = require "random-words"

module.exports =
class Sponge
	constructor: ->
		@sources = []
		@source_samples = []
	
	start: (callback)->
		
		@context = new StreamAudioContext()
		console.log "Created StreamAudioContext"
		
		# TODO: configure compressor
		# set it up so comparisons can be made, such as by alternating between configurations periodically
		# maybe use a limiter like https://webaudiotech.com/sites/limiter_comparison/
		# (to avoid clipping in a more robust way)
		@compressor = @context.createDynamicsCompressor()
		@compressor.connect(@context.destination)

		@chorus = new Chorus(@context)
		@chorus.output.connect(@compressor)

		@pre_global_fx_gain = @context.createGain()
		@pre_global_fx_gain.connect(@chorus.input)
		@pre_global_fx_gain.gain.setValueAtTime(0.1, 0) # avoid clipping!

		@pre_global_fx = @pre_global_fx_gain

		@gather_sources()
		# TODO: gather sources as a continuous process!!!
		# either
			# after a while, pausing along with the stream like schedule_sounds
		# or
			# when run out / near running out

		@schedule_sounds @context.currentTime

		callback(null, @context)
	
	gather_sources: ->
		# TODO: add rule to never use the same source twice

		if soundcloud_enabled
			# TODO: abstract OR searching by using OR for OGA but multiple searches for SC
			# so we can do searches for themes globally, and maybe expose that to the user (altho there's a rabbit hole of content/suggestion filtering...)
			query = randomWords(1).join(" ")
			console.log "[SC] Searching SoundCloud for \"#{query}\""
			SC.get "/tracks", {q: query}, (err, tracks)=>
				if err
					console.error "[SC] Error searching for tracks:", err if err
					return
				tracks = tracks.filter((track)-> track.streamable)

				async.eachLimit shuffle(tracks), 2,
					(track, callback)=>
						metadata = {
							link: track.permalink_url
							name: track.title
							author: {
								name: track.user.username
								link: track.user.permalink_url
							}
						}
						@sources.push new Source track.stream_url, metadata, @context,
							(new_sample)=>
								@source_samples.push(new_sample)
							(err, source)=>
								return callback err if err
								console.log "[SC] Done with #{source}"
								# console.log "[SC] Currently #{@source_samples.length} samples"
								setTimeout =>
									callback null
								, 500 # does this actually help?
					(err)=>
						console.error "[SC] Error:", err if err
						console.log "[SC] Done with all sources"

				console.log "[SC] Soaking up sample slices from #{@sources.length} sources..."

		# TODO: DRY!
		if OGA_enabled
			query = randomWords(5).join(" OR ")
			console.log "[OGA] Searching OpenGameArt for \"#{query}\""
			# TODO: try again on errors, as part of continuously finding sources
			# maybe with exponential backoff, esp. if we have multiple providers enabled (but probably regardless?)
			# Note: no console.log "[OGA] Soaking up sample slices from #{@sources.length} sources..."
			OGA query,
				(err)=>
					return console.error "[OGA] Error searching OpenGameArt:", err if err
					console.log "[OGA] Done with all sources"
				(err, track)=>
					return console.error "[OGA] Error fetching track metadata:", err if err

					metadata = {
						link: track.permalink_url
						name: track.title
						author: {
							name: track.user.username
							link: track.user.permalink_url
						}
					}
					@sources.push new Source track.stream_url, metadata, @context,
						(new_sample)=>
							@source_samples.push(new_sample)
						(err, source)=>
							return console.error "[OGA] Error:", err if err
							console.log "[OGA] Done with #{source}"
		
		# TODO: DRY and reenable FS support
		# maybe read metadata from files
		# audio_glob = process.env.AUDIO_SOURCE_FILES_GLOB
		
		# console.log "[FS] AUDIO_SOURCE_FILES_GLOB:", audio_glob
		# if audio_glob?
		# 	glob audio_glob, (err, files)=>
		# 		return console.error "[FS] Error globbing filesystem:", err if err
		# 		shuffleArray(files)
		# 		console.log "[FS] Files:", files
		# 		async.eachLimit files, 1,
		# 			(file_path, callback)=>
		# 				@sources.push new Source file_path, @context,
		# 					(new_sample)=>
		# 						@source_samples.push(new_sample)
		# 					(err, source)=>
		# 						return callback err if err
		# 						console.log "[FS] Done with #{source}"
		# 						setTimeout =>
		# 							callback null
		# 						, 500 # does this actually help?
		# 			(err)=>
		# 				console.log "[FS] Done with all sources"

		# 		console.log "[FS] Soaking up sample slices from #{@sources.length} sources..."

	schedule_sounds: (schedule_start_time)->
		{context} = @
		console.log "Scheduling output for context time #{schedule_start_time}"
		console.log "Source Samples: #{@source_samples.length}"
		beat_audio_buffers = @source_samples

		bpm = 128 / 4
		bps = bpm / 60
		add_beat = (beat_type_index, start_time)=>
			beat_audio_buffer = beat_audio_buffers[beat_type_index]
			if not beat_audio_buffer
				# console.error "Not enough beat types yet, using an oscillator; wanted: beat type #{beat_type_index} out of #{beat_audio_buffers.length}"
				
				# use an oscillator as a placeholder for sampled beats

				gain = context.createGain()
				gain.gain.value = 0.3
				gain.connect(@pre_global_fx)

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
				buffer_source.connect(@pre_global_fx)
				buffer_source.start(start_time)
				# buffer_source.stop(start_time + 0.05)

		# TODO: visualize the rhythm, possibly by sending it (in time) to the client
		# TODO: layers of sound (i.e. tracks), with potentially different or similar/related rhythms for melody and percussion
		# TODO: phase in and out layers and their sources
		# TODO: apply effects to tracks, especially reverb, but also random, crazy DSP

		rhythm = new Rhythm
		# console.log rhythm.toString()
		beats = rhythm.getBeats()
		scheduled_length = 0
		for super_measure_i in [0...4]
			shuffle(beat_audio_buffers)
			for beat in beats
				start_time = schedule_start_time + (beat.time + super_measure_i) / bps
				add_beat(beat.type, start_time)
			scheduled_length += 1 / bps
		
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
			# 	console.log "After setTimeout, context time difference of #{diff} (which should be less than #{scheduled_length})"
			do wait_until_near_schedule_time = =>
				if context.currentTime < next_schedule_time_minimum
					# console.log "Waiting for context.currentTime (#{context.currentTime}) to continue to at least #{next_schedule_time_minimum}"
					setTimeout wait_until_near_schedule_time, 50
				else
					@schedule_sounds next_start_time
		, wait_before_trying_to_schedule_next * 1000
