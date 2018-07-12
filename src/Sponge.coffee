{StreamAudioContext, AudioBuffer} = require "web-audio-engine"
randomWords = require "random-words"
Chorus = require "../lib/chorus"
# Granular = require "../lib/granular"
shuffle = require "./shuffle"
Rhythm = require "./Rhythm"
Source = require "./Source"

# ---------------------
# Setup audio providers
# ---------------------
get_env_var = require "./get-env-var"

soundcloud_client_id = get_env_var "SOUNDCLOUD_CLIENT_ID"
soundcloud_enabled = soundcloud_client_id?
if soundcloud_enabled
	soundcloud = require "./audio-providers/soundcloud"
	soundcloud.init(id: soundcloud_client_id)

FS_audio_glob = get_env_var "AUDIO_SOURCE_FILES_GLOB"
FS_enabled = FS_audio_glob?
if FS_enabled
	FS = require "./audio-providers/filesystem"

OGA_enabled = true
if OGA_enabled
	OGA = require "./audio-providers/opengameart"
# ---------------------

module.exports =
class Sponge
	constructor: ->
		@sources = []
		@source_samples = []
	
	start: (callback)->
		
		@context = new StreamAudioContext()
		console.log "Created StreamAudioContext"
		
		# @chorus = new Chorus(@context)
		# @chorus.output.connect(@context.destination)

		# TODO: maybe add a limiter to avoid clipping in a more robust way than just gain reduction
		# see https://webaudiotech.com/sites/limiter_comparison/
		@pre_global_fx_gain = @context.createGain()
		# @pre_global_fx_gain.connect(@chorus.input)
		@pre_global_fx_gain.connect(@context.destination)
		@pre_global_fx_gain.gain.setValueAtTime(0.1, 0) # avoid clipping!

		@pre_global_fx = @pre_global_fx_gain

		@gather_sources()

		# @layers = []
		@schedule_sounds @context.currentTime

		callback(null, @context)
	
	gather_sources: ->
		# TODO: gather sources as a continuous process!!!
		# either
			# after a while, pausing along with the stream like schedule_sounds
		# or
			# when run out / near running out
		# also try again on errors, probably with exponential backoff, esp. if we have multiple providers enabled (but probably regardless?)

		# TODO: add rule to never use the same source twice

		# TODO: abstract "OR"-searching by using "a OR b" for OGA but multiple searches for SC
		# so we can do searches for themes globally, and maybe expose that to the user
		# (altho there's of course a rabbit hole of content/suggestion filtering...)
		# (altho it could already grab anything by chance)

		on_new_source = (stream_url, attribution)=>
			@sources.push new Source stream_url, attribution, @context,
				(new_sample)=>
					@source_samples.push(new_sample)
				(err, source)=>
					return console.error err if err
					console.log "Done with #{source}"
					# console.log "Source Samples: #{@source_samples.length}"

		if soundcloud_enabled
			query = randomWords(1).join(" ")
			# TODO: named arguments
			soundcloud.search query, on_new_source, ()=>
				console.log "[SC] Done collecting track metadata from search"

		if OGA_enabled
			query = randomWords(5).join(" OR ")
			# TODO: named arguments
			OGA.search query,
				(err, stream_url, attribution)=>
					return console.error "[OGA] Error fetching track metadata:", err if err
					on_new_source(stream_url, attribution)
				()=>
					console.log "[OGA] Done collecting track metadata from search"
		
		if FS_enabled
			# TODO: named arguments
			FS.glob FS_audio_glob,
				(err, stream_url, attribution)=>
					return console.error "[FS] Error fetching track metadata:", err if err
					on_new_source(stream_url, attribution)
				()=>
					console.log "[FS] Done collecting track metadata from files"

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
				# TODO: envelopes (to avoid clicking at start/end of sliced audio),
				# or granular synthesis, which would have envelopes, lots of envelopes..
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
