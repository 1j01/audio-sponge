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
	for [0...samples_to_take]
		duration = Math.random() / 2 + 0.1
		duration = Math.min(duration, audio_buffer.duration)
		start = Math.random() * (audio_buffer.duration - duration)
		duration = Math.max(0, duration - 0.01)
		end = start + duration
		new_audio_buffer = sliceAudioBuffer audio_buffer, start, end, window.audioContext

		sample_callback(new_audio_buffer)
		# metadata.number_of_samples[this particular source] += 1

class @Song
	constructor: (audio_buffers, midi_array_buffer)->

		# @sources = []
		@source_samples = []
		for audio_buffer in audio_buffers
			findSamplesFromAudioBuffer audio_buffer, (sample)=>
				@source_samples.push(sample)
			# console.log("#{@source_samples.length} source_samples")

		@midi = new Midi(midi_array_buffer)

		@context = window.audioContext

		# TODO: maybe add a limiter to avoid clipping in a more robust way than just gain reduction
		# see https://webaudiotech.com/sites/limiter_comparison/
		@pre_global_fx_gain = @context.createGain()
		# @pre_global_fx_gain.connect(@chorus.input)
		@pre_global_fx_gain.gain.setValueAtTime(0.1, 0) # avoid clipping!

		@post_global_fx_gain = @context.createGain()

		@output = @post_global_fx_gain

		# @chorus = new Chorus(@context)
		# @chorus.output

		@reverb = new SimpleReverb(@context)

		@pre_global_fx_gain.connect(@reverb.input)
		@pre_global_fx_gain.connect(@post_global_fx_gain) # dry
		@reverb.output.connect(@post_global_fx_gain) # wet

	schedule: ()->
		{context} = @
		schedule_start_time = context.currentTime
		console.log "Scheduling output for context time #{schedule_start_time}"
		console.log "Source Samples: #{@source_samples.length}"
		beat_audio_buffers = @source_samples

		bpm = 128 / 4
		bps = bpm / 60
		add_beat = (midi_note_val, is_percussion, variation, start_time)=>
			beat_type_index = if is_percussion then midi_note_val % beat_audio_buffers.length else variation
			beat_audio_buffer = beat_audio_buffers[beat_type_index]
			if not beat_audio_buffer
				console.error "Not enough beat types yet, using an oscillator; wanted: beat type #{beat_type_index} out of #{beat_audio_buffers.length}"
				
				# use an oscillator as a placeholder for sampled beats

				gain = context.createGain()
				gain.gain.value = 0.3
				gain.connect(@pre_global_fx_gain)

				oscillator = context.createOscillator()
				oscillator.frequency.value = 440 * Math.pow(2, midi_note_val/12)
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
				if not is_percussion
					# assuming all samples randomly happen to be tuned to 440 Hz or something
					buffer_source.playbackRate.value = Math.pow(2, midi_note_val/12)
				buffer_source.connect(@pre_global_fx_gain)
				buffer_source.start(start_time)
				# buffer_source.stop(start_time + 0.05)

		# TODO: visualize the rhythm
		# TODO: layers of sound (i.e. tracks), with potentially different or similar/related rhythms for melody and percussion
		# TODO: phase in and out layers and their sources
		# TODO: apply effects to tracks, especially reverb, but also random, crazy DSP

		max_time = 0
		for track, track_index in @midi.tracks
			for note in track.notes
				# note has {name, duration, time, velocity}
				start_time = schedule_start_time + note.time
				# Channel 10 is (coded 9) is reserved for percussion. Channel 11 (coded 10) may be percussion.
				add_beat(note.midi, (track.channel in [9, 10]), track_index, start_time)
				max_time = Math.max(max_time, note.time)
			# break if track.notes.length > 0 # only do one track...
			# I'm wondering if there might be performance implications for scheduling sounds out of order
			# or just having lots of notes scheduled

		return max_time + 1 # one extra second for sounds to finish 
