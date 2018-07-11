fs = require "fs"
request = require "request"
lame = require "lame"
pcm = require "pcm-util"
# Meyda = require "meyda"
sliceAudioBuffer = require "./slice-audiobuffer.js"

max_buffers = parseInt(process.env.MAX_BUFFERS)
if not isFinite(max_buffers) then max_buffers = 50 # TODO: figure out how much this is and if it's reasonable
# actually probably better to define it in terms of samples (uh, you know, sample frames) or seconds
# NOTE: terminology is confusing; we've got samples which are buffers which have many samples
# which are sourced via Source (that's why it's called Source)... and then played via BufferSource nodes
# I should probably call samples slices or beats, and Source could just be a function or functions

# NOTE: you want this chance to be higher if there are less sources (or very short sources)
# and it also depends on MAX_BUFFERS (max_buffers)
# for very short sources it should probably take the whole thing as a sample
# or increase the probability in proportion to the length (although the length isn't necessarily known)
# this will be replaced at least somewhat by a threshold of energy/beat-like-ness
# (for percussion and then maybe harmonicness or whatever for melody)
take_sample_chance = parseInt(process.env.TAKE_SAMPLE_CHANCE)
if not isFinite(take_sample_chance) then take_sample_chance = 0.05

# TODO: this doesn't need to be a class
# if it is a class, maybe it should be an EventEmitter
module.exports =
class Source
	constructor: (uri, @metadata, @context, sample_callback, callback)->
	# constructor: (@metadata, @stream, @context, sample_callback, callback)->
		@metadata.number_of_samples = 0
		# should just accept a stream (pcm and format?)
		if uri.match(/http[s]:/)
			@uri = uri
			@readStream = request(uri, qs: client_id: process.env.SOUNDCLOUD_CLIENT_ID)
		else
			@uri = "file:///#{uri}"
			@readStream = fs.createReadStream(uri)

		# TODO: wav support and maybe other formats
		decoder = new lame.Decoder
		@readStream.on "error", callback
		@readStream.pipe(decoder)

		pcm_format = null
		buffers = []
		look_at_buffers_and_find_samples = (buffers)=>
			# console.log "       look_at_buffers_and_find_samples start (#{buffers.length} buffers)"
			if not pcm_format
				return console.warn "PCM format not determined yet from mp3 stream after #{buffers.length} data buffers"
			buffer = Buffer.concat(buffers)
			# console.log "looking at #{buffers.length} buffers (#{buffer.byteLength} bytes) for #{@uri} to find samples"
			@findSamplesFromBuffer(buffer, pcm_format, sample_callback)
			# console.log "       look_at_buffers_and_find_samples end"

		decoder.on "format", (format)=>
			pcm_format = format
			# console.log "got format:", format
			# if source.audioBuffer.sampleRate isnt context.sampleRate
			# 	console.log "source.audioBuffer.sampleRate (#{source.audioBuffer.sampleRate}) doesn't match context.sampleRate (#{context.sampleRate}); preemptively rejecting #{source}"

		decoder.on "data", (buffer)=>
			buffers.push(buffer)
			if buffers.length >= max_buffers
				look_at_buffers_and_find_samples(buffers)
				buffers = []
			
			decoder.pause()
			setTimeout =>
				decoder.resume()
			, 10
		decoder.on "end", =>
			look_at_buffers_and_find_samples(buffers)
			callback(null, @)
		decoder.on "error", callback
	
	toString: -> @uri
	
	# TODO: findInterestingSamplesFromBuffer
	findSamplesFromBuffer: (buffer, pcm_format, sample_callback)->
		# don't need that many samples
		return if Math.random() < take_sample_chance
		# TODO: find beats with Meyda or another module
		
		audiojs_audio_buffer = pcm.toAudioBuffer(buffer, pcm_format)
		
		duration = Math.random() / 2 + 0.1
		duration = Math.min(duration, audiojs_audio_buffer.duration)
		start = Math.random() * (audiojs_audio_buffer.duration - duration)
		duration = Math.max(0, duration - 0.01)
		end = start + duration
		new_audio_buffer = sliceAudioBuffer audiojs_audio_buffer, start, end, @context

		sample_callback(new_audio_buffer)
		@metadata.number_of_samples += 1
		

	# findBeats: ->
	# 	rms = Meyda.extract "rms", @buffer
	# 	console.log rms

