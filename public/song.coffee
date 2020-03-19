shuffle = (array) ->
	array = Array.from(array)
	i = array.length
	while --i > 0
		j = ~~(Math.random() * (i + 1))
		temp = array[j]
		array[j] = array[i]
		array[i] = temp
	return array


# TODO: findInterestingSamplesFromAudioBuffer
findSamplesFromAudioBuffer = (audio_buffer, sample_callback)->
	# TODO: find beats with Meyda or another module
	
	samples_to_take = Math.max(2, Math.min(10, audio_buffer.length / 10))
	for [0..samples_to_take]
		duration = Math.random() / 2 + 0.1
		duration = Math.min(duration, audio_buffer.duration)
		start = Math.random() * (audio_buffer.duration - duration)
		duration = Math.max(0, duration - 0.01)
		end = start + duration
		new_audio_buffer = sliceAudioBuffer audio_buffer, start, end, window.audioContext

		sample_callback(new_audio_buffer)
		# metadata.number_of_samples[this particular source] += 1

class @Song
	constructor: (audio_buffers, song_over)->

		# @sources = []
		@source_samples = []
		for audio_buffer in audio_buffers
			findSamplesFromAudioBuffer audio_buffer, (sample)=>
				@source_samples.push(sample)
				console.log("#{@source_samples.length} source_samples")

		@context = window.audioContext

		# @chorus = new Chorus(@context)
		# @chorus.output.connect(@context.destination)

		# TODO: maybe add a limiter to avoid clipping in a more robust way than just gain reduction
		# see https://webaudiotech.com/sites/limiter_comparison/
		@pre_global_fx_gain = @context.createGain()
		# @pre_global_fx_gain.connect(@chorus.input)
		@pre_global_fx_gain.gain.setValueAtTime(0.1, 0) # avoid clipping!

		@pre_global_fx = @pre_global_fx_gain

		# @layers = []
		@schedule_sounds @context.currentTime, song_over

	connect: (destination)->
		@pre_global_fx_gain.connect(destination)

	schedule_sounds: (schedule_start_time, song_over)->
		{context} = @
		console.log "Scheduling output for context time #{schedule_start_time}"
		console.log "Source Samples: #{@source_samples.length}"
		beat_audio_buffers = @source_samples

		bpm = 128 / 4
		bps = bpm / 60
		add_beat = (beat_type_index, start_time)=>
			beat_audio_buffer = beat_audio_buffers[beat_type_index]
			if not beat_audio_buffer
				console.error "Not enough beat types yet, using an oscillator; wanted: beat type #{beat_type_index} out of #{beat_audio_buffers.length}"
				
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

		# TODO: visualize the rhythm
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
		

		setTimeout =>
			song_over()
		, scheduled_length * 1000

		###
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
					@schedule_sounds next_start_time, song_over
		, wait_before_trying_to_schedule_next * 1000
		###
